# frozen_string_literal: true

module Projects
  module Sharepoint
    class FilesController < ApplicationController
      before_action :find_project_by_project_id
      before_action :authorize
      before_action :consume_sharepoint_params

      def index
        @mapping = SharepointProjectMapping.find_by(project_id: @project.id)

        return unless @mapping

        # Breadcrumb: JSON array of {id, name} accumulated via URL param :crumb
        @breadcrumb = []
        if @sp_crumb.present?
          begin
            @breadcrumb = JSON.parse(@sp_crumb)
          rescue JSON::ParserError
            @breadcrumb = []
          end
        end

        result = sharepoint_service.list_drive_items(
          site_id:   @mapping.sharepoint_site_id,
          folder_id: @sp_folder_id.presence || @mapping.sharepoint_folder_id
        )

        if result.success?
          @items = result.result
          @folder_id = @sp_folder_id
        else
          @error = result.errors.first
          @items = []
        end
      end

      private

      # Remove our custom query params from the shared `params` hash **before**
      # the layout renders its menu partials.  Each menu partial calls
      # params.permit(...) with its own subset; leaving :folder_id / :crumb in
      # params causes Rails to log "Unpermitted parameters" once per partial.
      def consume_sharepoint_params
        @sp_folder_id = params.delete(:folder_id)
        @sp_crumb     = params.delete(:crumb)
      end

      def sharepoint_service
        ::SharepointService.new(config: {
          "tenant_id"     => Setting.sharepoint_tenant_id.to_s,
          "client_id"     => Setting.sharepoint_client_id.to_s,
          "client_secret" => Setting.sharepoint_client_secret.to_s,
          "site_id"       => "root"
        })
      end
    end
  end
end
