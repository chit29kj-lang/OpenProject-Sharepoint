# frozen_string_literal: true

module Admin
  module Sharepoint
    class CredentialsController < ApplicationController
      before_action :require_admin

      layout "admin"

      def show; end

      def update
        %i[sharepoint_tenant_id sharepoint_client_id sharepoint_client_secret].each do |key|
          Setting[key] = params[key] if params.key?(key)
        end
        flash[:notice] = t("sharepoint.admin.saved")
        redirect_to admin_sharepoint_credentials_path
      end

      def test
        config = {
          "tenant_id" => Setting.sharepoint_tenant_id.to_s,
          "client_id" => Setting.sharepoint_client_id.to_s,
          "client_secret" => Setting.sharepoint_client_secret.to_s,
          "site_id" => "root"
        }
        result = ::SharepointService.new(config:).list_sites
        if result.success?
          render json: { ok: true, message: t("sharepoint.admin.test_ok", count: result.result[:sites].size) }
        else
          render json: { ok: false, message: result.errors.first }, status: :unprocessable_entity
        end
      end
    end
  end
end
