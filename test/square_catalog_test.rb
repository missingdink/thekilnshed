require_relative "test_helper"
require_relative "../plugins/square_catalog"

class SquareCatalogTest < Minitest::Test
  def listings
    @listings ||= SquareCatalog.classes(source: "fixture")
  end

  def find(name_fragment)
    listings.find { |c| c.name.include?(name_fragment) }
  end

  def test_skips_items_hidden_from_square_online
    refute find("CUPS"), "hidden items should not render"
    refute find("Plates"), "hidden items should not render"
  end

  def test_sorts_by_start_date
    dates = listings.map(&:start_date)
    assert_equal dates.sort, dates
  end

  def test_splits_courses_from_workshops
    assert find("POTTERY 101 - TUES").course?
    assert find("Handle those handles").workshop?
  end

  def test_reads_schedule_from_custom_attributes
    course = find("POTTERY 101 - TUES")
    assert_equal Date.new(2026, 10, 13), course.start_date
    assert_equal "Tuesday", course.weekday
    assert_equal "Oct 13 - Nov 10", course.date_range
    assert_equal "6:00 PM - 8:30 PM", course.time_range
  end

  def test_formats_price_and_checkout_link
    workshop = find("Handle those handles")
    assert_equal "$75", workshop.price
    assert_equal "https://thekilnshed.square.site/s/order?cs=true&cst=custom&item=169", workshop.url
  end

  def test_live_sources_drop_past_classes
    payload = JSON.parse(File.read(SquareCatalog::FIXTURE_PATH))
    upcoming = SquareCatalog.normalize(payload).select { |c| c.upcoming?(Date.new(2026, 11, 24)) }
    assert_equal ["Handbuilding 101 NOV12-DEC10"], upcoming.map(&:name)
  end

  def test_live_source_requires_token
    original = ENV.delete("SQUARE_ACCESS_TOKEN")
    assert_raises(SquareCatalog::Error) { SquareCatalog.classes(source: "sandbox") }
  ensure
    ENV["SQUARE_ACCESS_TOKEN"] = original if original
  end

  def test_extras_add_photo_blurb_and_featured_flag
    extras = [{
      "square_id" => "FIXTURE0196JARSLIDS00000",
      "image" => "/images/brown-jug.png",
      "alt_text" => "A brown jug",
      "card_text" => "Lids that fit.",
      "featured" => true,
    }]
    jars = SquareCatalog.apply_extras(listings, extras).find { |c| c.name.start_with?("Jars") }
    assert_equal "/images/brown-jug.png", jars.image
    assert_equal "Lids that fit.", jars.summary
    assert jars.featured
  end

  def test_extras_can_hide_a_class
    extras = [{ "square_id" => "PM2MH5V4BFBENO6ZFB7V3PLT", "hide" => true }]
    refute SquareCatalog.apply_extras(listings, extras).any? { |c| c.name.include?("Handle") }
  end

  def test_unmatched_and_blank_extras_are_ignored
    extras = [{ "square_id" => "NOPE" }, { "square_id" => "" }, {}]
    assert_equal listings.map(&:id), SquareCatalog.apply_extras(listings, extras).map(&:id)
  end

  def test_summary_falls_back_to_square_description
    summary = find("BOWLS").summary(60)
    assert summary.start_with?("BOWLS of all sizes!")
    assert summary.end_with?("...")
    assert summary.length <= 63
  end
end
