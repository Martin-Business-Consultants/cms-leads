# frozen_string_literal: true

# A playbook step's email as one lead gets it: the placeholders filled in
# (escaped in the HTML), the body's paragraphs as HTML, every http(s) link
# passed through `link` (the mailer's click tracking), and a plain-text part
# from the same words.
class Leads::Step::Email
  # Plain text, with URLs, as paragraphs of HTML.
  def self.paragraphs(text, link: ->(url) { url })
    text.to_s.strip.split(/\n{2,}/).map do |paragraph|
      escaped = ERB::Util.html_escape(paragraph).gsub("\n", "<br>")
      linked = escaped.gsub(%r{https?://[^\s<]+}) { |url| %(<a href="#{ERB::Util.html_escape(link.call(CGI.unescapeHTML(url)))}">#{url}</a>) }
      "<p>#{linked}</p>"
    end.join("\n")
  end

  def initialize(step, lead, sender: nil)
    @step = step
    @personalization = Leads::Personalization.new(lead, sender: sender)
  end

  def subject = @personalization.fill(@step.subject).squish

  def text = @personalization.fill(@step.body.to_s).strip

  # link: ->(url) { the URL to put in its place }, for tracked links.
  def html(link: ->(url) { url }) = self.class.paragraphs(text, link: link)
end
