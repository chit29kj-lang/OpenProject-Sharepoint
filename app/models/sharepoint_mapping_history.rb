# frozen_string_literal: true

class SharepointMappingHistory < ApplicationRecord
  belongs_to :project
  belongs_to :changed_by, class_name: "User", foreign_key: "changed_by_id"

  validates :action, inclusion: { in: %w[CREATE UPDATE REMOVE] }

  scope :recent, -> { order(created_at: :desc) }
end
