class Shared::GalleryImage < Bridgetown::Component
  def initialize(image_src:, title: nil, message: nil)
    @image_src = image_src
    @title = title
    @message = message
  end
end