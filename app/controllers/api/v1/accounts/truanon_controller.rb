# frozen_string_literal: true

# Live, switch-filtered TruAnon details for a member's profile boxes.
#
# Fetched per view and never stored — the granted personal/contact/social
# anchors are read live, filtered by the member's switches (and reduced by
# private mode), and returned display-safe. The private key stays server-side.
class Api::V1::Accounts::TruanonController < Api::BaseController
  before_action -> { authorize_if_got_token! :read, :'read:accounts' }
  before_action :set_account

  def show
    render json: TruAnonService.new(@account).card_data
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end
end
