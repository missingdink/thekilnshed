class Shared::Faq < Bridgetown::Component
  def initialize(question:, answer:, button_text: nil, link: nil)
    @question = question
    @answer  = answer
    @button_text = button_text
    @link = link
  end
end