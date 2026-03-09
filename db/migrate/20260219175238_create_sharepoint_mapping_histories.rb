# frozen_string_literal: true

class CreateSharepointMappingHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :sharepoint_mapping_histories do |t|
      t.references :project,      null: false, foreign_key: true, index: true
      t.integer    :changed_by_id, null: false
      t.string     :action,        null: false   # CREATE | UPDATE | REMOVE
      t.string     :sharepoint_site_id
      t.string     :sharepoint_site_name
      t.string     :sharepoint_folder_id
      t.string     :sharepoint_folder_path
      t.timestamps
    end
  end
end
