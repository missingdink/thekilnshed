require "net/http"
require "json"

# Pulls the latest Instagram posts from the studio's Behold JSON feed at
# build time and exposes them as `site.data.instagram_posts`. Fetching at
# build time keeps feed usage to one view per build rather than one per
# visitor. Without a feed URL (local dev, or an outage in CI) the gallery
# falls back to the CMS-managed images.
class Builders::InstagramFeed < SiteBuilder
  LIMIT = 12

  def build
    hook :site, :post_read do |site|
      site.data[:instagram_posts] = posts
    end
  end

  private

  def posts
    @posts ||= fetch_posts
  end

  def fetch_posts
    feed_url = ENV["BEHOLD_FEED_URL"]
    return [] if feed_url.to_s.empty?

    response = Net::HTTP.get_response(URI(feed_url))

    unless response.is_a?(Net::HTTPSuccess)
      Bridgetown.logger.warn "Instagram:", "feed request failed (#{response.code}); using CMS gallery"
      return []
    end

    feed = JSON.parse(response.body)
    items = feed.is_a?(Array) ? feed : feed.fetch("posts", [])

    items.first(LIMIT).map do |item|
      {
        image_src: image_for(item),
        caption: item["prunedCaption"] || item["caption"],
        permalink: item["permalink"],
        posted_at: item["timestamp"] && Time.parse(item["timestamp"])
      }
    end.select { |post| post[:image_src] && post[:permalink] }
  rescue StandardError => e
    Bridgetown.logger.warn "Instagram:", "feed unavailable (#{e.message}); using CMS gallery"
    []
  end

  # Behold-hosted sizes don't expire, unlike Instagram's own media URLs.
  def image_for(item)
    item.dig("sizes", "medium", "mediaUrl") ||
      (item["mediaType"] == "VIDEO" ? item["thumbnailUrl"] : item["mediaUrl"])
  end
end
