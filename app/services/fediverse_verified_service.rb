# frozen_string_literal: true

# fediverse-verified: an IdentityVerificationProvider (see that class) backed by
# signed, portable proofs instead of a central service.
#
# A person gets a proof from a verifier (e.g. Fediverse Verify), which checks a
# government digital ID once and publishes a page that links back to the
# account (rel="me") plus a W3C Verifiable Credential signed with a
# DataIntegrityProof (eddsa-jcs-2022) by the verifier's ActivityPub actor. The
# person adds the page to a profile field, as with any verified link.
#
# This server then, for any account (local or remote):
# - finds green-checked profile fields whose page has a credential (<url>.json);
# - verifies its signature with ActivityPub::ObjectIntegrityProof (FEP-8b32),
#   which also resolves the issuing actor;
# - accepts it only if the issuer is on this server's trust list
#   (FEDIVERSE_VERIFIED_TRUSTED_ISSUERS), the credential names this account, and
#   it isn't a test proof (unless FEDIVERSE_VERIFIED_ALLOW_TEST_PROOFS=true);
# - caches level, 18+, name and issuer for the badge and for filtering.
#
# Levels: "person" (a real person, no name) or "legal_name"; 18+ is separate.
class FediverseVerifiedService < IdentityVerificationProvider
  CREDENTIAL_TYPE = 'FediverseVerifiedCredential'
  LEVELS = %w(person legal_name).freeze
  LEVEL_LABELS = { 'person' => 'fediverse-verified person', 'legal_name' => 'fediverse-verified name' }.freeze

  def self.trusted_issuers
    (Setting.fediverse_verified_trusted_issuers.presence || ENV.fetch('FEDIVERSE_VERIFIED_TRUSTED_ISSUERS', ''))
      .split(/[\s,]+/).compact_blank
  end

  def self.configured?
    trusted_issuers.any?
  end

  def self.enabled?
    Setting.fediverse_verified_enabled || ENV['FEDIVERSE_VERIFIED_ENABLED'] == 'true'
  end

  # Proofs made with test wallets (identity_check_method "mock") never count,
  # whatever the trust list says, unless explicitly allowed for development.
  def self.allow_test_proofs?
    ENV['FEDIVERSE_VERIFIED_ALLOW_TEST_PROOFS'] == 'true'
  end

  # Unlike a central service, proofs are public and checked by every server,
  # so remote accounts get a badge too.
  def self.covers_remote_accounts?
    true
  end

  def self.cached_badge(account)
    # No badge at all without a proof: not being fediverse-verified must never look suspicious.
    return nil unless LEVELS.include?(account.fediverse_verified_level)

    rank = LEVEL_LABELS[account.fediverse_verified_level]
    rank += ' · 18+' if account.fediverse_verified_age_over18
    { rank: rank, score: nil, provider: 'fediverse_verified',
      description: I18n.t("fediverse_verified.descriptions.#{account.fediverse_verified_level}"), issuer: account.fediverse_verified_issuer }
  end

  def configured?
    self.class.configured?
  end

  def active?
    self.class.active?
  end

  # Owner panel state, as for every provider.
  def resolve_verification
    return { configured: false } unless configured?
    return { configured: true, disabled: true } unless self.class.enabled?

    credential = verified_credential
    return { configured: true, anchored: false } if credential.nil?

    badge = self.class.cached_badge(@account)
    { configured: true, anchored: true, rank: badge[:rank], score: nil }
  end

  def badge_data
    credential = active? ? verified_credential : nil
    return { verified: false, rank: 'Unknown', score: nil } if credential.nil?

    subject = credential['credentialSubject']
    rank = LEVEL_LABELS[subject['verification_level']]
    rank += ' · 18+' if subject['age_over_18'] == true
    { verified: true, rank: rank, score: nil }
  end

  # Persists the checked result. Only what a badge and filters need; the name
  # is published by the person on the proof page and cached here for display.
  def refresh_cache!
    credential = active? ? verified_credential : nil
    subject = credential&.dig('credentialSubject') || {}
    @account.update_columns(
      fediverse_verified_level: credential ? subject['verification_level'] : nil,
      fediverse_verified_age_over18: credential ? subject['age_over_18'] == true : false,
      fediverse_verified_name: credential && subject['verification_level'] == 'legal_name' ? subject['name'] : nil,
      fediverse_verified_issuer: credential&.dig('issuer'),
      fediverse_verified_checked_at: Time.current
    )
    badge_data
  end

  # Detail rows for the profile box, from the cached, verified credential.
  def card_data
    return { sections: [] } unless active? && LEVELS.include?(@account.fediverse_verified_level)

    items = []
    items << { type: 'name', name: 'Name', display: @account.fediverse_verified_name } if @account.fediverse_verified_name.present?
    items << { type: 'age', name: 'Age', display: '18 or over' } if @account.fediverse_verified_age_over18
    items << { type: 'issuer', name: 'Verified by', display: @account.fediverse_verified_issuer }
    { sections: [{ kind: 'fediverse_verified', label: self.class.cached_badge(@account)[:rank], items: items }] }
  end

  private

  # The first trusted, valid credential among the account's green-checked links.
  def verified_credential
    @account.fields.select(&:verified?).each do |field|
      credential = fetch_credential(field.value_for_verification)
      next if credential.nil?

      return credential if acceptable?(credential)
    end
    nil
  end

  def fetch_credential(url)
    return if url.blank?

    body = Request.new(:get, "#{url}.json").add_headers('Accept' => 'application/vc+ld+json, application/json').perform do |res|
      res.code == 200 ? res.body_with_limit : nil
    end
    json = body.present? ? JSON.parse(body) : nil
    json.is_a?(Hash) && Array(json['type']).include?(CREDENTIAL_TYPE) ? json : nil
  rescue *Mastodon::HTTP_CONNECTION_ERRORS, JSON::ParserError, Mastodon::HostValidationError, Mastodon::LengthValidationError,
         Addressable::URI::InvalidURIError
    nil
  end

  def test_proof?(credential)
    Array(credential['evidence']).any? { |e| e.is_a?(Hash) && e['identity_check_method'] == 'mock' }
  end

  def acceptable?(credential)
    issuer_actor = ActivityPub::ObjectIntegrityProof.new(credential).verify_actor!
    return false if issuer_actor.nil?
    return false unless self.class.trusted_issuers.include?(issuer_actor.uri) && credential['issuer'] == issuer_actor.uri

    return false if test_proof?(credential) && !self.class.allow_test_proofs?

    subject = credential['credentialSubject']
    subject.is_a?(Hash) &&
      LEVELS.include?(subject['verification_level']) &&
      subject['id'] == ActivityPub::TagManager.instance.uri_for(@account) &&
      subject['account_profile_url'].to_s.casecmp?(ActivityPub::TagManager.instance.url_for(@account))
  end
end
