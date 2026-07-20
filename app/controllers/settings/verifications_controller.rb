# frozen_string_literal: true

class Settings::VerificationsController < Settings::BaseController
  before_action :set_account
  before_action :set_verified_links
  before_action :set_truanon

  def show; end

  # This page hosts two independent forms:
  #   * author attribution (account[attribution_domains]) — Mastodon's own
  #   * TruAnon identity switches (user[settings_attributes]) — ours
  # Route each by which one was submitted.
  def update
    saved = params.key?(:user) ? update_truanon_settings : update_account

    if saved
      redirect_to settings_verification_path, notice: I18n.t('generic.changes_saved_msg')
    else
      render :show
    end
  end

  private

  def update_truanon_settings
    current_user.update(user_settings_params)
  end

  def update_account
    return false unless UpdateAccountService.new.call(@account, account_params)

    ActivityPub::UpdateDistributionWorker.perform_in(ActivityPub::UpdateDistributionWorker::DEBOUNCE_DELAY, @account.id)
    true
  end

  def user_settings_params
    params.expect(user: [settings_attributes: UserSettings.keys])
  end

  def account_params
    params.expect(account: [:attribution_domains]).tap do |params|
      params[:attribution_domains] = params[:attribution_domains].split if params[:attribution_domains]
    end
  end

  def set_account
    @account = current_account
  end

  def set_verified_links
    @verified_links = @account.fields.select(&:verified?)
  end

  # Owner-initiated live check: resolves anchored status and, when not yet
  # anchored, a one-time verify URL. Cheap enough for a settings page; the
  # per-viewer badge fetch (switch-gated + cached) is a separate concern.
  def set_truanon
    service = TruAnonService.new(@account)
    @truanon = service.resolve_verification
    @truanon_verify_url = service.verify_url
    @truanon_public_profile_url = service.public_profile_url
  end
end
