class Shared::Staff < Bridgetown::Component
  def initialize(image:, name:, title: nil, instagram: nil, website: nil, bio: nil, needs_review: false)
    @image = image
    @name = name
    @title = title
    @instagram  = instagram
    @website = website
    @bio = bio
    @needs_review = needs_review
  end
end