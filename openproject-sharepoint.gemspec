Gem::Specification.new do |s|
  s.name        = "openproject-sharepoint"
  s.version     = "1.0.0"
  s.authors     = "GoSoft"
  s.email       = "dev@gosoft.co.th"
  s.homepage    = "https://www.gosoft.co.th"
  s.summary     = "OpenProject SharePoint Integration"
  s.description = "Links OpenProject projects to SharePoint Document Libraries and " \
                  "browses files via the Microsoft Graph API."
  s.license     = "GPLv3"
  s.files       = Dir["{app,config,db,frontend,lib}/**/*"] + %w[README.md]
  s.metadata["rubygems_mfa_required"] = "true"
end
