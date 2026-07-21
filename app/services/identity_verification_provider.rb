# frozen_string_literal: true

# The pluggable contract behind automatic identity verification: a member
# anchors their identity once with a provider and a rank/score badge follows
# them across the site, on their own terms — the continuous, privacy-forward
# counterpart to the manual rel="me" link verification Mastodon already
# offers.
#
# TruAnonService is the reference implementation. A second provider can be
# added by subclassing this with the same contract and registering it in
# IdentityVerification.provider_class; the rest of the app calls through
# IdentityVerification rather than a concrete provider.
class IdentityVerificationProvider
  def self.configured?
    raise NotImplementedError
  end

  def self.enabled?
    raise NotImplementedError
  end

  def self.active?
    enabled? && configured?
  end

  def initialize(account)
    @account = account
  end

  def configured?
    raise NotImplementedError
  end

  def active?
    raise NotImplementedError
  end

  # Owner panel state: { configured:, disabled:, error:, anchored:, rank:, score: }
  def resolve_verification
    raise NotImplementedError
  end

  # Display cache payload for the badge: { verified:, rank:, score: }
  def badge_data
    raise NotImplementedError
  end

  # Persists badge_data to the account's cache columns.
  def refresh_cache!
    raise NotImplementedError
  end

  # Live, switch-filtered detail rows for the profile boxes. Never stored.
  def card_data
    raise NotImplementedError
  end
end
