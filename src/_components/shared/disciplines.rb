# The icon list of what the studio teaches (Pottery, Sculpture, ...).
class Shared::Disciplines < Bridgetown::Component
  ICONS = %w[pottery sculpture glaze mold].freeze

  def initialize(items:, layout: :grid)
    @items = Array(items)
    @layout = layout
  end

  private

  def icon_for(item)
    icon = item["icon"].to_s
    ICONS.include?(icon) ? icon : "pottery"
  end
end
