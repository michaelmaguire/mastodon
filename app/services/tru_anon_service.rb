# frozen_string_literal: true

# TruAnon — automatic identity verification for Mastodon.
#
# The continuous, privacy-forward companion to the manual rel="me" link
# verification Mastodon already offers: a member anchors their identity once and
# a rank/score badge follows them across the site, on their own terms.
#
# Contract mirrors the maintained TruAnon WordPress plugin:
#   * Current v2 API (https://truanon.com/api/v2); the private key travels in the
#     Authorization header and never reaches a browser.
#   * Only a clean HTTP 200 carrying a real rank is an answer. A transport error,
#     a 401/5xx, or an "Unknown" rank is never recorded as a verdict.
#   * The badge fetch is gated on the member's `wants_verified_identity` switch
#     (see #badge_data). The owner panel (#resolve_verification) fetches live so a
#     member can always see and manage their own status.
class TruAnonService
  API_BASE = 'https://truanon.com/api'
  API_V2   = "#{API_BASE}/v2".freeze

  IGNORED_ANCHORS = %w(fullname bio).freeze
  SECTION_LABELS  = { 'personal' => 'Personal', 'contact' => 'Contact', 'social' => 'Social' }.freeze

  attr_reader :verify_url, :public_profile_url

  def initialize(account)
    @account      = account
    # Admin settings take precedence; the ENV vars remain a fallback so an
    # operator can configure the service either way.
    @service_name = Setting.truanon_service_name.presence || ENV.fetch('TRUANON_SERVICE_NAME', nil)
    @private_key  = Setting.truanon_private_key.presence || ENV.fetch('TRUANON_PRIVATE_KEY', nil)
  end

  def configured?
    @service_name.present? && @private_key.present?
  end

  # Live profile fetch (v2). Returns the parsed body hash on a clean 200, else
  # nil — the strict rule the cache/badge path depends on.
  def fetch_profile
    return nil unless configured?

    result = fetch("#{API_V2}/get_profile", id: @account.username, service: @service_name)
    result[:status] == 200 ? result[:body] : nil
  end

  # Owner panel state. Fetches live (owner-initiated) and distinguishes real
  # failure reasons so the panel can speak plainly: a disabled service is an
  # admin problem, not "try again later".
  def resolve_verification
    return { configured: false } unless configured?

    result = fetch("#{API_V2}/get_profile", id: @account.username, service: @service_name)
    body   = result[:body]
    code   = body.is_a?(Hash) ? body['code'] : nil

    # A member the service has never seen simply hasn't anchored yet — offer the
    # verify flow rather than reporting this as an error.
    if code == 'member_unknown'
      @verify_url = build_verify_url
      return { configured: true, anchored: false }
    end

    return { configured: true, error: true, error_code: code } unless result[:status] == 200 && body.is_a?(Hash) && body['type'] != 'error'

    @public_profile_url = extract_public_profile_url(body)

    if anchored?(body)
      { configured: true, anchored: true, rank: body['rank'], score: body['score'] }
    else
      @verify_url = build_verify_url
      { configured: true, anchored: false }
    end
  end

  # Display cache payload for a badge/checkmark. Switch-gated: a member with the
  # master switch off is never fetched and reads as Unknown.
  def badge_data
    return unknown unless configured? && @account.user&.settings&.[](:wants_verified_identity)

    body = fetch_profile
    return unknown if body.nil? || !anchored?(body)

    { verified: true, rank: body['rank'], score: body['score'].to_s }
  end

  # Store only the badge cache — rank + score — from a live, switch-gated check.
  # The badge and per-post checkmark render from these; nothing identifying (no
  # URL, no anchors) is ever written here.
  def refresh_cache!
    data = badge_data
    @account.update_columns(
      truanon_verified: data[:verified],
      truanon_rank: data[:verified] ? data[:rank] : nil,
      truanon_score: data[:verified] ? data[:score] : nil,
      truanon_checked_at: Time.current
    )
    data
  end

  # Live, switch-filtered granted details for the profile boxes. Fetched per
  # view and NEVER stored — honors show_personal/contact/social and private
  # mode (which strips links and reduces identifiers). Returns display-safe
  # sections the frontend renders as boxes.
  def card_data
    return { sections: [] } unless configured? && @account.user&.settings&.[](:wants_verified_identity)

    body = fetch_profile
    return { sections: [] } unless body.is_a?(Hash) && anchored?(body)

    build_sections(body).merge(rank: body['rank'])
  end

  private

  def unknown
    { verified: false, rank: 'Unknown', score: '' }
  end

  def build_sections(body)
    settings = @account.user&.settings
    private_mode = settings&.[](:make_private)
    allowed = {
      'personal' => settings&.[](:show_personal),
      'contact' => settings&.[](:show_contact),
      'social' => settings&.[](:show_social),
    }

    grouped = { 'personal' => [], 'contact' => [], 'social' => [] }
    profile_url = nil

    Array(body['anchors']).each do |anchor|
      next unless anchor.is_a?(Hash)

      type    = anchor['type'].to_s.downcase
      kind    = anchor['kind'].to_s
      display = anchor['display'].to_s
      next if display.empty?

      # The public TruAnon profile link — surfaced as the "Verified Identity"
      # row and gated on the member showing their social links. Dropped in
      # private mode. Fetched live here, never stored.
      if type == 'truanon'
        profile_url = display if allowed['social'] && !private_mode
        next
      end
      next if IGNORED_ANCHORS.include?(type)

      kind = 'contact' if kind == 'primary'
      next unless grouped.key?(kind)

      display = display.sub(%r{/.*\z}, '') if private_mode && kind == 'social'
      display = redact_contact(display)    if private_mode && kind == 'contact'
      grouped[kind] << { type: type, name: anchor['name'].to_s, display: display }
    end

    sections = SECTION_LABELS.filter_map do |kind, label|
      next unless allowed[kind] && grouped[kind].any?

      { kind: kind, label: label, items: grouped[kind] }
    end

    { sections: sections, profile_url: profile_url }
  end

  # Private mode: an email keeps only its domain, a phone only its last two digits.
  def redact_contact(display)
    return "@#{display.split('@').last}" if display.include?('@')

    digits = display.gsub(/\D+/, '')
    digits.length >= 7 ? "··· #{digits[-2..]}" : display
  end

  def anchored?(body)
    body['rank'].present? && body['rank'] != 'Unknown'
  end

  def build_verify_url
    result = fetch("#{API_BASE}/get_token", id: @account.username, service: @service_name)
    token  = result[:body].is_a?(Hash) ? result[:body]['id'] : nil
    return nil if token.blank?

    "#{API_BASE}/verifyProfile?#{URI.encode_www_form(id: @account.username, service: @service_name, token: token)}"
  end

  def extract_public_profile_url(body)
    anchor = Array(body['anchors']).find { |a| a.is_a?(Hash) && a['type'] == 'truanon' }
    anchor && anchor['display']
  end

  # Returns { status:, body: } — status 0 on a transport failure. Callers decide
  # what a non-200 means; nothing here is treated as a verdict.
  def fetch(url, params = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params.any?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 5
    http.read_timeout = 15

    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = @private_key

    res = http.request(req)
    { status: res.code.to_i, body: parse(res.body) }
  rescue => e
    Rails.logger.warn("TruAnonService: #{e.class} #{e.message}")
    { status: 0, body: nil }
  end

  def parse(raw)
    JSON.parse(raw)
  rescue
    nil
  end
end
