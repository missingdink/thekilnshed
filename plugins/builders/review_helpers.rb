# Template helpers for placeholder content that still needs owner review.
#
# Any CMS entry with needs_review: true is shown with a Draft label in
# development and left off every other build (test and production), so
# made-up copy never reaches the live site by accident.
class Builders::ReviewHelpers < SiteBuilder
  def build
    helper :needs_review? do |item|
      ReviewHelpers.needs_review?(item)
    end

    helper :show_content? do |item|
      !ReviewHelpers.needs_review?(item) || Bridgetown.env.development?
    end

    helper :paragraphs do |text|
      text.to_s.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
    end
  end
end
