# frozen_string_literal: true

# Resolves the identity-verification provider active on this server. There is
# one registered provider today (TruAnonService); call through here rather
# than referencing a concrete provider directly, so a second provider can be
# added without touching every call site.
class IdentityVerification
  def self.provider_class
    TruAnonService
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
