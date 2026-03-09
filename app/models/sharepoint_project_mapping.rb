# frozen_string_literal: true

class SharepointProjectMapping < ApplicationRecord
  belongs_to :project

  validates :sharepoint_site_id, presence: true
  validates :project_id, uniqueness: true

  after_create  { record_history("CREATE") }
  after_update  { record_history("UPDATE") }
  after_destroy { record_history("REMOVE") }

  private

  def record_history(action)
    SharepointMappingHistory.create!(
      project_id:             project_id,
      changed_by_id:          User.current.id,
      action:,
      sharepoint_site_id:     sharepoint_site_id,
      sharepoint_site_name:   sharepoint_site_name,
      sharepoint_folder_id:   sharepoint_folder_id,
      sharepoint_folder_path: sharepoint_folder_path
    )
  end
end
