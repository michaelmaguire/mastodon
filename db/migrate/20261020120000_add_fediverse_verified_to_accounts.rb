# frozen_string_literal: true

# fediverse-verified badge cache: the checked level, 18+, (for the name level)
# the published name, and the issuing verifier. Indexed for filtering by
# level (see docs/proposal-filtering.md in fediverse-verified).
class AddFediverseVerifiedToAccounts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :accounts, :fediverse_verified_level, :string
    add_column :accounts, :fediverse_verified_age_over_18, :boolean, default: false, null: false
    add_column :accounts, :fediverse_verified_name, :string
    add_column :accounts, :fediverse_verified_issuer, :string
    add_column :accounts, :fediverse_verified_checked_at, :datetime
    add_index :accounts, [:fediverse_verified_level, :fediverse_verified_age_over_18],
              where: 'fediverse_verified_level IS NOT NULL', algorithm: :concurrently,
              name: 'index_accounts_on_fediverse_verified'
  end
end
