# frozen_string_literal: true

module Projects
  module Settings
    class SharepointController < Projects::SettingsController
      menu_item :settings_sharepoint

      def show
        @mapping = SharepointProjectMapping.find_by(project_id: @project.id)
      end

      def sites
        q      = params[:q].to_s.strip
        cursor = params[:cursor].to_s.strip.presence
        return render json: { sites: [], next_cursor: nil } if q.blank? && cursor.blank?

        result = sharepoint_service.list_sites(query: q.presence, cursor: cursor)
        if result.success?
          render json: result.result
        else
          render json: { error: result.errors.first }, status: :unprocessable_entity
        end
      end

      def site_items
        site_id   = params[:site_id].to_s.strip
        folder_id = params[:folder_id].to_s.strip.presence
        return render json: { error: "site_id required" }, status: :bad_request if site_id.blank?

        result = sharepoint_service.list_drive_items(site_id: site_id, folder_id: folder_id)
        if result.success?
          render json: result.result
        else
          render json: { error: result.errors.first }, status: :unprocessable_entity
        end
      end

      def update
        mapping = SharepointProjectMapping.find_or_initialize_by(project_id: @project.id)
        mapping.assign_attributes(mapping_params)
        if mapping.save
          flash[:notice] = t("sharepoint.project_settings.saved")
        else
          flash[:error] = mapping.errors.full_messages.to_sentence
        end
        redirect_to project_settings_sharepoint_path(@project)
      end

      def destroy
        SharepointProjectMapping.find_by(project_id: @project.id)&.destroy!
        flash[:notice] = t("sharepoint.project_settings.removed")
        redirect_to project_settings_sharepoint_path(@project)
      end

      private

      def mapping_params
        params.expect(sharepoint_mapping: %i[sharepoint_site_id sharepoint_site_name
                                             sharepoint_folder_id sharepoint_folder_path])
      end

      def sharepoint_service
        config = {
          "tenant_id" => Setting.sharepoint_tenant_id.to_s,
          "client_id" => Setting.sharepoint_client_id.to_s,
          "client_secret" => Setting.sharepoint_client_secret.to_s,
          "site_id" => "root"
        }
        ::SharepointService.new(config:)
      end
    end
  end
end
