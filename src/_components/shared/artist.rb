# A studio artist card for the Gallery page, styled like the staff bios
# on the About page: featured work photo, two smaller samples, then text.
class Shared::Artist < Bridgetown::Component
  def initialize(artist:)
    @artist = artist
    works = Array(artist["works"]).select { |work| work["image"].present? }
    @featured = works.first || portrait_as_work
    @samples = works.drop(1).first(2)
  end

  private

  def portrait_as_work
    return if @artist["portrait"].blank?

    { "image" => @artist["portrait"], "alt" => @artist["name"] }
  end

  def links
    [
      ["Instagram", @artist["instagram"], "/images/icons/instagram-blue.svg"],
      ["Website", @artist["website"], "/images/icons/website-blue.svg"],
      ["Shop", @artist["shop"], "/images/icons/website-blue.svg"],
    ].select { |_, url, _| url.present? }
  end

  def alt_for(work)
    work["alt"].presence || work["title"].presence || "Work by #{@artist['name']}"
  end
end
