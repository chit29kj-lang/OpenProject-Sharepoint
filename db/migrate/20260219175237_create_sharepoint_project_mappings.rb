# frozen_string_literal: true

class CreateSharepointProjectMappings < ActiveRecord::Migration[7.2]
  def change
    create_table :sharepoint_project_mappings do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.string :sharepoint_site_id,   null: false
      t.string :sharepoint_site_name
      t.string :sharepoint_folder_id
      t.string :sharepoint_folder_path
      t.timestamps
    end
  end
end
