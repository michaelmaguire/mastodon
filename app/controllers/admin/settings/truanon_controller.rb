# frozen_string_literal: true

class Admin::Settings::TruanonController < Admin::SettingsController
  private

  def after_update_redirect_path
    admin_settings_truanon_path
  end

  # A blank private-key field means "leave the stored key unchanged", so the
  # secret never has to be re-entered and is never echoed back into the form.
  def settings_params
    super.tap do |permitted|
      permitted.delete(:truanon_private_key) if permitted[:truanon_private_key].blank?
    end
  end
end
