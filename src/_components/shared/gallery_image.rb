class Shared::GalleryImage < Bridgetown::Component
  def initialize(image_src:, title: nil, message: nil, alt: nil, show_caption: true)
    @image_src = image_src
    @title = title
    @message = message
    @alt = alt
    @show_caption = show_caption
  end
end
