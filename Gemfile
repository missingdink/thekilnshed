source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

####
# When you run Bridgetown commands, use the binstub:
#
#   bin/bridgetown start (or console, etc.)
####

# Bridgetown core
gem "bridgetown", "~> 2.2.0"

# File-based dynamic routing (uncomment if needed)
# gem "bridgetown-routes", "~> 1.0.0", group: :bridgetown_plugins

# Rack server
gem "puma", "~> 8.0.2"

# HTML sanitization for content from Decap
gem "sanitize"

# Foreman runs Bridgetown + Decap server together in dev
gem "foreman"

# ActiveSupport for date/string helpers in templates
gem "activesupport"

group :test, optional: true do
  gem "nokogiri"
  gem "minitest"
end

# Bridgetown plugins
gem "bridgetown-svg-inliner"
gem "bridgetown-feed", "~> 4.0.0"
gem "bridgetown-sitemap", "~> 3.0.1"
gem "bridgetown-image-pipeline", "~> 0.1.0"
