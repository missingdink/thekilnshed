require "active_support"
require "active_support/core_ext"

Bridgetown.configure do |config|
  url ENV.fetch("SITE_URL", "__SITE_URL__")
  base_path ENV.fetch("BASE_PATH", "/")
  base_url config.url + config.base_path

  timezone "America/Chicago"
  template_engine "erb"
  permalink "pretty"

  available_locales ["en"]
  default_locale "en"
  prefix_default_locale false

  init :"bridgetown-feed"
  init :"bridgetown-sitemap"
  init :"bridgetown-image-pipeline"
  init :"bridgetown-svg-inliner"
end
