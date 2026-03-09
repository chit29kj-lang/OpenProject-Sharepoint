# frozen_string_literal: true

require "open_project/plugins"

module OpenProject::Sharepoint
  class Engine < ::Rails::Engine
    engine_name :openproject_sharepoint

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-sharepoint",
             author_url: "https://www.gosoft.co.th",
             bundled: true

    # Register menu items after load_config_initializers so that :settings
    # (defined in the main app's menus.rb) already exists when we push
    # :settings_sharepoint as its child.  Using an initializer (not
    # config.to_prepare) keeps the block in the queue exactly ONCE –
    # no "Child already added" on development request reload.
    initializer "sharepoint.menu_items", after: "load_config_initializers" do
      Redmine::MenuManager.map :admin_menu do |menu|
        menu.push :sharepoint_credentials,
                  { controller: "/admin/sharepoint/credentials", action: "show" },
                  caption: :label_sharepoint,
                  icon: "file-directory",
                  if: ->(_) { User.current.admin? }
      end

      Redmine::MenuManager.map :project_menu do |menu|
        menu.push :sharepoint,
                  { controller: "/projects/sharepoint/files", action: "index" },
                  caption: :label_sharepoint,
                  param: :project_id,
                  icon: "file-directory",
                  before: :settings,
                  if: ->(project) { project.module_enabled?(:sharepoint_integration) }

        menu.push :settings_sharepoint,
                  { controller: "/projects/settings/sharepoint", action: "show" },
                  parent: :settings,
                  caption: :label_sharepoint,
                  if: ->(project) { project.module_enabled?(:sharepoint_integration) }
      end
    end

    # Permissions, Project Module & Settings registration
    config.to_prepare do
      # Settings
      {
        sharepoint_tenant_id:     { default: "", format: :string,
                                    description: "Azure Active Directory – Directory (tenant) ID"       },
        sharepoint_client_id:     { default: "", format: :string,
                                    description: "Azure App Registration – Application (client) ID"     },
        sharepoint_client_secret: { default: "", format: :string,
                                    description: "Azure App Registration – Client Secret value"         },
        sharepoint_root_url:      { default: "", format: :string,
                                    description: "SharePoint root URL (e.g. https://contoso.sharepoint.com)" }
      }.each do |name, opts|
        Settings::Definition.add(name, **opts) unless Settings::Definition[name]
      end
      OpenProject::AccessControl.map do |map|
        map.project_module :sharepoint_integration do |sp|
          sp.permission :manage_sharepoint_mapping,
                        { "projects/settings/sharepoint" => %i[show update destroy sites site_items] },
                        permissible_on: :project,
                        require: :member

          sp.permission :view_sharepoint_files,
                        { "projects/sharepoint/files" => %i[index] },
                        permissible_on: :project,
                        public: true
        end
      end
    end
  end
end
