# frozen_string_literal: true

# Badge cache only: rank + score (color derives from rank). This is the display
# data the badge/checkmark render from — never a fetch per view. The member's
# identity details and public URL are NEVER stored; those are fetched live into
# the profile boxes and discarded.
class AddTruanonBadgeToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :truanon_verified, :boolean, default: false, null: false
    add_column :accounts, :truanon_rank, :string
    add_column :accounts, :truanon_score, :string
    add_column :accounts, :truanon_checked_at, :datetime
  end
end
