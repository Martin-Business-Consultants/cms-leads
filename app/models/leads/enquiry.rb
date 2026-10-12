# frozen_string_literal: true

# What someone sent when they got in touch, as a lead takes it: who they are
# (email, name, phone, company), what they asked (message), every other answer
# as text (details), and where it came from. Made from a Forms submission's
# webhook payload, a Commerce quote request's, or what someone typed in.
class Leads::Enquiry
  EMAIL_FIELDS = %w[email email_address your_email e_mail].freeze
  NAME_FIELDS = %w[name full_name your_name contact_name customer_name].freeze
  PHONE_FIELDS = %w[phone telephone phone_number mobile tel cell customer_phone].freeze
  COMPANY_FIELDS = %w[company company_name organization organisation business].freeze
  MESSAGE_FIELDS = %w[message comments comment enquiry inquiry details question notes how_can_we_help].freeze
  MAX_DETAILS = 40
  # Fields read into the lead itself, so not repeated among the details.
  KNOWN = (EMAIL_FIELDS + NAME_FIELDS + PHONE_FIELDS + COMPANY_FIELDS + MESSAGE_FIELDS +
    %w[first_name firstname last_name lastname surname website_url redirect_to authenticity_token]).freeze

  attr_reader :email, :name, :phone, :company, :message, :details, :source, :source_label, :source_form, :reference

  # A Forms submission (submission.created): its answers by field name, read
  # with the form's own field types and labels when the form is there.
  def self.from_submission(payload)
    payload = payload.to_h.deep_stringify_keys
    data = payload["data"].to_h
    fields = form_fields(payload["form_slug"])
    typed = ->(type) { fields.select { it["type"] == type }.filter_map { it["name"] } }
    labels = fields.to_h { [it["name"], it["label"].presence || it["name"].to_s.humanize] }

    new(data, email_keys: typed.("email"), phone_keys: typed.("tel"), message_keys: typed.("textarea"), labels: labels,
      source: "form", source_label: payload["form_title"].presence || payload["form_slug"],
      source_form: payload["form_slug"], reference: {"submission_id" => payload["id"], "form_slug" => payload["form_slug"]})
  end

  # A Commerce quote request (quote_request.created).
  def self.from_quote(payload)
    payload = payload.to_h.deep_stringify_keys
    items = Array(payload["items"]).filter_map do |item|
      item = item.is_a?(Hash) ? item : {"name" => item.to_s}
      [item["quantity"].presence && "#{item["quantity"]} ×", item["name"] || item["title"] || item["sku"]].compact.join(" ").presence
    end
    data = {"email" => payload["customer_email"], "name" => payload["customer_name"], "phone" => payload["customer_phone"],
            "company" => payload["company"], "message" => payload["message"], "items" => items.join("\n"),
            "page" => payload["page_url"]}
    new(data, labels: {"items" => "Items", "page" => "Asked from"}, source: "quote", source_label: "Quote request",
      reference: {"quote_request_id" => payload["id"]})
  end

  # What someone typed into "Add new", or an API client sent.
  def self.from_params(params, source: "manual")
    hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    new(hash, source: source)
  end

  def self.form_fields(slug)
    return [] unless slug.present? && defined?(::Form)

    Array(::Form.find_by(slug: slug)&.fields).select { it.is_a?(Hash) }
  rescue ActiveRecord::ActiveRecordError
    []
  end

  def initialize(data, email_keys: [], phone_keys: [], message_keys: [], labels: {}, source: "manual",
    source_label: nil, source_form: nil, reference: {})
    @data = data.to_h.stringify_keys.transform_keys { it.to_s.strip }
    @normalized = @data.transform_keys { normalize(it) }
    @email = find_email(email_keys)
    @name = text(*NAME_FIELDS) || [text("first_name", "firstname"), text("last_name", "lastname", "surname")].compact.join(" ").presence
    @phone = text(*phone_keys, *PHONE_FIELDS)
    @company = text(*COMPANY_FIELDS)
    @message = long_text(*message_keys, *MESSAGE_FIELDS)
    @details = collect_details(labels, used: email_keys + phone_keys + message_keys)
    @source = source
    @source_label = source_label.to_s.truncate(120).presence
    @source_form = source_form.presence
    @reference = reference.compact
  end

  def blank? = [email, name, phone].all?(&:blank?)

  # The lead's details this enquiry gives a value for (it never blanks one).
  def contact = {name: name, email: email, phone: phone, company: company}.compact_blank

  # Everything they sent, as a lead's fields keep it: labelled, message first.
  def fields = ({"Message" => message}.compact_blank).merge(details)

  private

  def normalize(key) = key.to_s.strip.downcase.tr(" -", "__")

  def value(key)
    raw = @data.key?(key.to_s) ? @data[key.to_s] : @normalized[normalize(key)]
    raw = raw.join(", ") if raw.is_a?(Array)
    raw.is_a?(String) || raw.is_a?(Numeric) ? raw.to_s.strip.presence : nil
  end

  def text(*keys) = keys.lazy.map { value(it)&.truncate(200) }.find(&:present?)

  def long_text(*keys) = keys.lazy.map { value(it)&.truncate(5_000) }.find(&:present?)

  def find_email(typed_keys)
    candidates = (typed_keys + EMAIL_FIELDS).filter_map { value(it) }
    candidates += @data.values.grep(String) if candidates.none? { email?(it) }
    candidates.map { it.strip.downcase }.find { email?(it) }
  end

  def email?(string) = string.to_s.strip.match?(URI::MailTo::EMAIL_REGEXP)

  def collect_details(labels, used:)
    skip = (KNOWN + used.map { normalize(it) }).to_set
    @data.filter_map do |key, _|
      next if skip.include?(normalize(key))

      text = value(key)
      next unless text

      [labels[key].presence || key.to_s.humanize, text.truncate(2_000)]
    end.first(MAX_DETAILS).to_h
  end
end
