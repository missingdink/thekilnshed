require "date"
require "json"
require "net/http"
require "uri"

# Loads The Kiln Shed's classes and workshops from Square and normalizes
# them into ClassListing records for templates.
#
# SQUARE_ENV selects the source:
#   fixture    (default) reads config/fixtures/square_catalog.json
#   sandbox    calls the Square Sandbox Catalog API
#   production calls the Square Catalog API
#
# sandbox and production need SQUARE_ACCESS_TOKEN. SQUARE_API_VERSION is
# optional; Square uses the app's default version when it is unset.
#
# Square Online stores event dates outside the Catalog API, so schedules
# are read from item custom attributes keyed class_start_date,
# class_end_date, class_start_time and class_end_time. Those definitions
# must exist in the Square account before going live.
module SquareCatalog
  FIXTURE_PATH = File.expand_path("../config/fixtures/square_catalog.json", __dir__)

  HOSTS = {
    "sandbox" => "https://connect.squareupsandbox.com",
    "production" => "https://connect.squareup.com",
  }.freeze

  COURSE_CATEGORIES = ["Multi-Week Courses"].freeze
  CLASS_CATEGORIES = (COURSE_CATEGORIES + ["Workshops"]).freeze
  HIDDEN_VISIBILITY = %w[HIDDEN UNAVAILABLE].freeze

  class Error < StandardError; end

  ClassListing = Struct.new(
    :id, :name, :kind, :category, :description_html, :description_text,
    :price_cents, :start_date, :end_date, :start_time, :end_time, :url,
    :image, :alt_text, :featured, :card_text,
    keyword_init: true
  ) do
    def course?
      kind == :course
    end

    def workshop?
      kind == :workshop
    end

    def price
      return "" unless price_cents

      dollars, cents = price_cents.divmod(100)
      cents.zero? ? "$#{dollars}" : format("$%d.%02d", dollars, cents)
    end

    def weekday
      start_date&.strftime("%A")
    end

    def multi_day?
      start_date && end_date && end_date != start_date
    end

    def date_range
      return "" unless start_date
      return start_date.strftime("%b %-d") unless multi_day?

      "#{start_date.strftime('%b %-d')} - #{end_date.strftime('%b %-d')}"
    end

    def time_range
      [start_time, end_time].compact.join(" - ")
    end

    # Short text for cards: the CMS blurb when set, else Square's description.
    def summary(length = 220)
      text = card_text.to_s.strip
      return text unless text.empty?

      description_text.to_s.gsub(/\s+/, " ").then { |t| t.length > length ? "#{t[0, length].sub(/\s+\S*\z/, '')}..." : t }
    end

    def upcoming?(today = Date.today)
      (end_date || start_date).nil? || (end_date || start_date) >= today
    end
  end

  module_function

  def env
    ENV.fetch("SQUARE_ENV", "fixture")
  end

  # Returns every visible class, sorted by start date. Past classes are
  # dropped for live sources; the fixture keeps them so the page always
  # has something to render.
  def classes(source: env, today: Date.today)
    listings = normalize(payload_for(source))
    source == "fixture" ? listings : listings.select { |c| c.upcoming?(today) }
  end

  def payload_for(source)
    case source
    when "fixture" then JSON.parse(File.read(FIXTURE_PATH))
    when *HOSTS.keys then fetch_catalog(source)
    else raise Error, "Unknown SQUARE_ENV #{source.inspect}; use fixture, sandbox or production"
    end
  end

  # Pages through ListCatalog for items and categories.
  def fetch_catalog(source)
    token = ENV["SQUARE_ACCESS_TOKEN"].to_s
    raise Error, "SQUARE_ACCESS_TOKEN is required when SQUARE_ENV=#{source}" if token.empty?

    objects = []
    cursor = nil
    loop do
      uri = URI("#{HOSTS.fetch(source)}/v2/catalog/list")
      params = { types: "ITEM,CATEGORY" }
      params[:cursor] = cursor if cursor
      uri.query = URI.encode_www_form(params)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/json"
      request["Square-Version"] = ENV["SQUARE_API_VERSION"] if ENV["SQUARE_API_VERSION"]

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      raise Error, "Square catalog request failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      objects.concat(body.fetch("objects", []))
      cursor = body["cursor"]
      break if cursor.nil? || cursor.empty?
    end
    { "objects" => objects }
  end

  # Layers CMS-managed extras (photo, blurb, featured, hide) onto Square
  # listings. Extras are matched by Square item ID; unmatched extras are
  # ignored so a stale entry never breaks the build.
  def apply_extras(listings, extras)
    by_id = Array(extras).each_with_object({}) do |extra, map|
      id = extra["square_id"].to_s.strip
      map[id] = extra unless id.empty?
    end

    listings.filter_map do |listing|
      extra = by_id[listing.id]
      next listing unless extra
      next if extra["hide"]

      listing.image = present(extra["image"])
      listing.alt_text = present(extra["alt_text"])
      listing.card_text = present(extra["card_text"])
      listing.featured = extra["featured"] == true
      listing
    end
  end

  def present(value)
    value = value.to_s.strip
    value.empty? ? nil : value
  end

  def normalize(payload)
    objects = payload.fetch("objects", [])
    categories = objects
      .select { |o| o["type"] == "CATEGORY" && !o["is_deleted"] }
      .to_h { |o| [o["id"], o.dig("category_data", "name")] }

    objects
      .select { |o| o["type"] == "ITEM" && !o["is_deleted"] }
      .filter_map { |o| build_listing(o, categories) }
      .sort_by { |c| [c.start_date || Date.new(9999), c.name] }
  end

  def build_listing(object, categories)
    data = object.fetch("item_data", {})
    return if HIDDEN_VISIBILITY.include?(data["ecom_visibility"])

    category_ids = Array(data["categories"]).map { |c| c["id"] }
    category_ids << data["category_id"] if data["category_id"]
    category = category_ids.map { |id| categories[id] }.compact.find { |name| CLASS_CATEGORIES.include?(name) }
    return unless category || data["product_type"] == "EVENT"

    attrs = object.fetch("custom_attribute_values", {})
    attr = ->(key) { attrs.dig(key, "string_value").to_s.strip.then { |v| v.empty? ? nil : v } }

    ClassListing.new(
      id: object["id"],
      name: data["name"].to_s.strip,
      kind: COURSE_CATEGORIES.include?(category) ? :course : :workshop,
      category: category,
      description_html: data["description_html"] || data["description"].to_s,
      description_text: (data["description_plain"] || data["description"]).to_s.strip,
      price_cents: first_price(data),
      start_date: parse_date(attr.call("class_start_date")),
      end_date: parse_date(attr.call("class_end_date")),
      start_time: attr.call("class_start_time"),
      end_time: attr.call("class_end_time"),
      url: data["ecom_uri"]
    )
  end

  def first_price(data)
    Array(data["variations"])
      .map { |v| v.dig("item_variation_data", "price_money", "amount") }
      .compact
      .min
  end

  def parse_date(value)
    value && Date.iso8601(value)
  rescue Date::Error
    nil
  end
end
