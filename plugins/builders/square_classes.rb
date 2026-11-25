# Exposes Square classes to templates as site.data.square_classes, with
# any CMS-managed class extras from src/_data/class_extras applied.
class Builders::SquareClasses < SiteBuilder
  def build
    hook :site, :post_read do |site|
      extras = (site.data[:class_extras] || {}).values
      site.data[:square_classes] = SquareCatalog.apply_extras(SquareCatalog.classes, extras)
    end
  end
end
