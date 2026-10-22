# frozen_string_literal: true

# Resolves the identity-verification provider active on this server: TruAnon
# (the default) or fediverse-verified, chosen by the identity_verification_provider
# setting or IDENTITY_VERIFICATION_PROVIDER. Call through here rather than
# referencing a concrete provider directly.
class IdentityVerification
  PROVIDERS = {
    'truanon' => 'TruAnonService',
    'fediverse_verified' => 'FediverseVerifiedService',
  }.freeze

  def self.provider_name
    name = Setting.identity_verification_provider.presence || ENV.fetch('IDENTITY_VERIFICATION_PROVIDER', 'truanon')
    PROVIDERS.key?(name) ? name : 'truanon'
  end

  def self.provider_class
    PROVIDERS.fetch(provider_name).constantize
  end

  def self.covers_remote_accounts?
    provider_class.covers_remote_accounts?
  end

  def self.cached_badge(account)
    provider_class.cached_badge(account)
  end

  def self.for(account)
    provider_class.new(account)
  end

  def self.active?
    provider_class.active?
  end

  def self.configured?
    provider_class.configured?
  end
end
