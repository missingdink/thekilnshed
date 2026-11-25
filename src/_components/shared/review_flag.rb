# Marks placeholder content during development. Renders nothing elsewhere.
class Shared::ReviewFlag < Bridgetown::Component
  def initialize(item:)
    @item = item
  end

  def render?
    Bridgetown.env.development? && ReviewHelpers.needs_review?(@item)
  end
end
