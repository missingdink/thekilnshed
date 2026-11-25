require "date"

# Upcoming events from the CMS, for the announcement banner and the
# Gallery page. An event is upcoming until the end of its last day.
module EventListings
  module_function

  def upcoming(events, today: Date.today)
    Array(events&.values)
      .select { |event| (end_date(event) || start_date(event))&.>=(today) }
      .sort_by { |event| [start_date(event) || Date.new(9999), event["title"].to_s] }
  end

  def start_date(event)
    to_date(event["start_date"])
  end

  def end_date(event)
    to_date(event["end_date"]) || start_date(event)
  end

  # "Sat, Dec 12" or "Dec 12 - 13" or "Dec 30 - Jan 2"
  def date_range(event)
    first, last = start_date(event), end_date(event)
    return "" unless first
    return first.strftime("%a, %b %-d") if last.nil? || last == first
    return "#{first.strftime('%b %-d')} - #{last.strftime('%-d')}" if first.month == last.month && first.year == last.year

    "#{first.strftime('%b %-d')} - #{last.strftime('%b %-d')}"
  end

  def to_date(value)
    case value
    when Date then value.to_date
    when nil, "" then nil
    else Date.parse(value.to_s)
    end
  rescue Date::Error
    nil
  end
end
