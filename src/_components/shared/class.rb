class Shared::Class < Bridgetown::Component
   def initialize(dates: "", start_time: "", end_time:"", cost: "", class_day: "", link: "https://thekilnshed.square.site/")
    @dates = dates
    @start_time = start_time
    @end_time = end_time
    @cost = cost
    @class_day = class_day
    @link = link
  end
end