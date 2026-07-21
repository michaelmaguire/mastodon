# frozen_string_literal: true

# Refreshes one account's badge cache (rank/score) from a live, switch-gated
# check. Enqueued when a member's full profile is viewed — never for account
# objects embedded in timelines — so a hit happens on viewing the whole badge,
# not per post. The badge always paints from the cached rank/score.
class TruanonRefreshWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 2

  def perform(account_id)
    account = Account.find_by(id: account_id)
    return unless account&.local?

    IdentityVerification.for(account).refresh_cache!
  end
end
