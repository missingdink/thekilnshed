class Shared::Workshop < Bridgetown::Component
   def initialize(image_src: "", alt_text: "", title:"", description: "", start_date: "", end_date:"", start_time:"", end_time:"", cost: "", message: "")
    @image_src = image_src
    @alt_text = alt_text
    @title = title 
    @description = description
    @start_date = start_date
    @end_date = end_date
    @start_time = start_time
    @end_time = end_time
    @cost = cost
    @message = message
  end
end