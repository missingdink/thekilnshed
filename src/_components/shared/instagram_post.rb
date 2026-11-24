class Shared::InstagramPost < Bridgetown::Component
  def initialize(image_src:, permalink:, caption: nil, posted_at: nil)
    @image_src = image_src
    @permalink = permalink
    @caption = caption
    @posted_at = posted_at
  end
end
