# frozen_string_literal: true

# Re-checks an account's fediverse-verified credential and updates its cache:
# after its profile links are verified, and periodically (so removed or
# withdrawn proofs stop showing).
class FediverseVerifiedRefreshWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 2, lock: :until_executed, lock_ttl: 1.hour.to_i

  def perform(account_id)
    account = Account.find_by(id: account_id)
    return if account.nil? || !FediverseVerifiedService.active?

    FediverseVerifiedService.new(account).refresh_cache!
  end
end
