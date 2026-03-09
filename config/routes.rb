# frozen_string_literal: true

Rails.application.routes.draw do
  # Admin: MS Graph API credentials
  namespace "admin" do
    namespace "sharepoint" do
      resource :credentials, only: %i[show update] do
        post :test, on: :member
      end
    end
  end

  # Project settings (site mapping) + files browser
  # as: "project" mirrors the main app's resources :projects nesting prefix
  scope "projects/:project_id", as: "project", module: "projects" do
    namespace "settings" do
      resource :sharepoint, controller: "sharepoint", only: %i[show update destroy] do
        get :sites,       on: :member
        get :site_items,  on: :member
      end
    end

    namespace "sharepoint" do
      resources :files, only: %i[index]
    end
  end
end
