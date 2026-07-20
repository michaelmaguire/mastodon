# frozen_string_literal: true

# Read/write the current member's TruAnon identity switches for the web UI's
# "Identity display settings" modal. These live in user settings (not account
# columns), so they have their own small endpoint rather than travelling through
# update_credentials.
class Api::V1::TruanonSettingsController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:accounts' }, only: :show
  before_action -> { doorkeeper_authorize! :write, :'write:accounts' }, only: :update
  before_action :require_user!

  KEYS = %i(wants_verified_identity show_personal show_contact show_social make_private).freeze

  def show
    render json: settings_hash
  end

  def update
    KEYS.each do |key|
      next unless params.key?(key)

      current_user.settings[key.to_s] = ActiveModel::Type::Boolean.new.cast(params[key])
    end

    current_user.save!
    render json: settings_hash
  end

  private

  def settings_hash
    KEYS.index_with { |key| current_user.settings[key.to_s] }
  end
end
