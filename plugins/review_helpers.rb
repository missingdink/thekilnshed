# Shared check for CMS entries marked as placeholder drafts.
module ReviewHelpers
  module_function

  def needs_review?(item)
    item.is_a?(Hash) && item["needs_review"] == true
  end
end
