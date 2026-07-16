class Shared::Pill < Bridgetown::Component
  def initialize(text: nil, status: nil, count: nil)
    @text = text
    @status = status
    @count = count
    @pill_classes = classes_for(@status)
  end

  private

  def classes_for(status)
    case status
    when "class-full"
      "bg-red-400 text-white border-red-400 border"
    when "seats-left"
      "bg-red-100 text-red-700 border-red-400 border"
    when "new"
      "bg-indigo-600 text-white border-indigo-600 border"
    when "coming-soon"
      "bg-indigo-600 text-white border-indigo-600 border"
    end
  end
end
