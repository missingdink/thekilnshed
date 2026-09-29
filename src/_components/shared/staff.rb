class Shared::Staff < Bridgetown::Component
  def initialize(image:, name:, title: nil, instagram: nil, website: nil, bio:)
    @image = image
    @name = name
    @title = title
    @instagram  = instagram
    @website = website
    @bio = bio
  end
end