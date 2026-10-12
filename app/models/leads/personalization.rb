# frozen_string_literal: true

# The {{placeholders}} a playbook's step or a template may say, filled in
# for one lead, as written by one person (or the site, when nobody is).
#
#   Leads::Personalization.new(lead, sender: user).fill("Hi {{first_name}}")  # => "Hi Jordan"
class Leads::Personalization
  PLACEHOLDERS = %w[first_name name company email phone my_name business].freeze
  PATTERN = /\{\{\s*(\w+)\s*\}\}/

  def self.business_name = Setting.get("general")["title"].presence || Site.key.to_s.humanize

  def initialize(lead, sender: nil)
    @lead = lead
    @sender = sender
  end

  # source with each known placeholder replaced by the block's answer for its
  # value (its escaped HTML, say); unknown ones stay as written.
  def fill(source, &escape)
    escape ||= ->(value) { value }
    source.to_s.gsub(PATTERN) do
      key = Regexp.last_match(1)
      PLACEHOLDERS.include?(key) ? escape.call(value_for(key)) : Regexp.last_match(0)
    end
  end

  def value_for(key)
    case key
    when "first_name" then @lead.first_name || "there"
    when "name" then @lead.name.presence || "there"
    when "company" then @lead.company.to_s
    when "email" then @lead.email.to_s
    when "phone" then @lead.phone.to_s
    when "my_name" then @sender&.name.to_s.split.first.presence || self.class.business_name
    when "business" then self.class.business_name
    end
  end
end
