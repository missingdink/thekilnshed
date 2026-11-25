require_relative "test_helper"
require_relative "../plugins/event_listings"

class EventListingsTest < Minitest::Test
  TODAY = Date.new(2026, 12, 1)

  def events(*list)
    list.each_with_index.to_h { |event, i| ["event#{i}", event] }
  end

  def test_keeps_upcoming_and_ongoing_events_sorted_by_start
    result = EventListings.upcoming(events(
      { "title" => "Later", "start_date" => Date.new(2026, 12, 20) },
      { "title" => "Ongoing", "start_date" => Date.new(2026, 11, 28), "end_date" => Date.new(2026, 12, 2) },
      { "title" => "Past", "start_date" => Date.new(2026, 11, 1) },
    ), today: TODAY)
    assert_equal %w[Ongoing Later], result.map { |e| e["title"] }
  end

  def test_accepts_string_dates_from_the_cms
    result = EventListings.upcoming(events({ "title" => "Sale", "start_date" => "2026-12-12" }), today: TODAY)
    assert_equal ["Sale"], result.map { |e| e["title"] }
  end

  def test_formats_date_ranges
    assert_equal "Sat, Dec 12", EventListings.date_range({ "start_date" => Date.new(2026, 12, 12) })
    assert_equal "Dec 12 - 13", EventListings.date_range({ "start_date" => Date.new(2026, 12, 12), "end_date" => Date.new(2026, 12, 13) })
    assert_equal "Dec 30 - Jan 2", EventListings.date_range({ "start_date" => Date.new(2026, 12, 30), "end_date" => Date.new(2027, 1, 2) })
  end

  def test_ignores_events_without_dates
    assert_empty EventListings.upcoming(events({ "title" => "No date" }), today: TODAY)
  end
end
