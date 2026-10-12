# frozen_string_literal: true

module Leads
  # Something to send or say: an email, a text message or a call script for
  # a situation ("First reply to a website enquiry"), with its
  # {{placeholders}} filled in for each lead on its page. Starts with a set
  # the team can change (Defaults).
  class Template < ApplicationRecord
    include Defaults

    KINDS = {"email" => "Email", "text" => "Text message", "call" => "Phone call"}.freeze
    # What the body may hold: a template is short, simple HTML.
    TAGS = %w[p br strong b em i u a ul ol li].freeze

    validates :kind, inclusion: {in: KINDS.keys}
    validates :title, presence: true, length: {maximum: 120}
    validates :situation, length: {maximum: 200}
    validates :subject, length: {maximum: 200}

    scope :ordered, -> { in_order_of(:kind, KINDS.keys).order(:position, :id) }
    scope :of_kind, ->(kind) { where(kind: kind) }

    before_create { self.position = (self.class.of_kind(kind).maximum(:position) || -1) + 1 }

    def kind_label = KINDS.fetch(kind, kind.humanize)

    # The subject and body as this lead gets them from this person:
    # [subject, html, text].
    def filled_for(lead, sender: Current.user)
      personalization = Leads::Personalization.new(lead, sender: sender)
      html = personalization.fill(clean_body) { ERB::Util.html_escape(it) }
      [subject.present? ? personalization.fill(subject) : nil, html, self.class.plain_text(html)]
    end

    # Body HTML as plain text, links as "text (url)".
    def self.plain_text(html)
      fragment = Nokogiri::HTML5.fragment(html.to_s)
      fragment.css("a[href]").each { |a| a.replace("#{a.text} (#{a["href"]})") unless a.text == a["href"] }
      fragment.css("br").each { it.replace("\n") }
      fragment.css("p, li").each { it.add_next_sibling("\n\n") }
      fragment.text.gsub(/[ \t]+\n/, "\n").gsub(/\n{3,}/, "\n\n").strip
    end

    private

    def clean_body = Rails::HTML5::SafeListSanitizer.new.sanitize(body.to_s, tags: TAGS, attributes: %w[href])
  end
end
