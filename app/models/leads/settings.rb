# frozen_string_literal: true

# Settings › Leads, kept in the core's Setting "leads": who hears about new leads, the morning digest's hour,
# who owns a lead no playbook assigns, which forms make leads, the points
# things are worth and the score that makes a lead hot, and the AI drafts.
class Leads::Settings
  KEY = "leads"
  DEFAULT_POINTS = {"captured" => 10, "returned" => 15, "email_open" => 1, "email_click" => 3, "note" => 0}.freeze
  POINT_LABELS = {"captured" => "Getting in touch", "returned" => "Getting in touch again", "email_open" => "Opening an email",
                  "email_click" => "Clicking a link in one", "note" => "A note"}.freeze
  DIGEST_HOURS = (5..11).to_a.freeze

  def self.current = new(Setting.get(KEY))

  def initialize(data)
    @data = data.to_h.stringify_keys
  end

  # Addresses told about every new lead, besides its owner.
  def notify_emails = Array(@data["notify_emails"]).map(&:to_s).compact_blank

  def notify_owner? = @data.fetch("notify_owner", true) == true

  # Who's told about this lead getting in touch.
  def alert_recipients(lead)
    owner_email = lead.owner&.email if notify_owner?
    ([owner_email] + notify_emails).compact_blank.map(&:downcase).uniq
  end

  # The hour (site time) the daily digest goes, or nil when it's off.
  def digest_hour
    hour = @data.fetch("digest_hour", 8)
    hour.nil? || hour.to_s == "" ? nil : hour.to_i
  end

  def default_owner_id = @data["default_owner_id"].presence&.to_i

  # "all", or only the forms named in `forms`.
  def forms_mode = @data["forms_mode"] == "chosen" ? "chosen" : "all"

  def forms = Array(@data["forms"]).map(&:to_s)

  def captures_form?(slug) = forms_mode == "all" || forms.include?(slug.to_s)

  def points = DEFAULT_POINTS.merge(@data["points"].to_h.transform_values(&:to_i))

  def points_for(kind) = points.fetch(kind.to_s, 0)

  def hot_threshold = (@data["hot_threshold"].presence || 25).to_i

  # Drafting replies for every new lead: switched on here, and the AI plugin set up (Settings › AI).
  def ai_drafts? = @data.fetch("ai_drafts", true) == true && Leads::Draft.available?



  def templates_seeded? = @data["templates_seeded"] == true

  # From Settings › Leads' form or the API's PATCH: only what was sent
  # changes.
  def self.update(params)
    params = params.to_h.stringify_keys
    boolean = ActiveModel::Type::Boolean.new
    readers = {
      "notify_emails" => ->(value) { Array(value).join(" ").split(/[\s,;]+/).select { it.match?(URI::MailTo::EMAIL_REGEXP) }.map(&:downcase).uniq },
      "notify_owner" => ->(value) { boolean.cast(value) || false },
      "digest_hour" => ->(value) { value.presence&.to_i },
      "default_owner_id" => ->(value) { value.presence&.to_i },
      "forms_mode" => ->(value) { value == "chosen" ? "chosen" : "all" },
      "forms" => ->(value) { Array(value).compact_blank.map(&:to_s) },
      "points" => ->(value) { DEFAULT_POINTS.keys.index_with { (value.to_h.stringify_keys[it].presence || DEFAULT_POINTS[it]).to_i } },
      "hot_threshold" => ->(value) { [(value.presence || 25).to_i, 1].max },
      "ai_drafts" => ->(value) { boolean.cast(value) || false }
    }
    data = readers.filter_map { |name, read| [name, read.call(params[name])] if params.key?(name) }.to_h
    Setting.set(KEY, data) if data.any?
    current
  end

  def self.mark_templates_seeded = Setting.set(KEY, "templates_seeded" => true)

  def to_h
    {notify_emails: notify_emails, notify_owner: notify_owner?, digest_hour: digest_hour, default_owner_id: default_owner_id,
     forms_mode: forms_mode, forms: forms, points: points, hot_threshold: hot_threshold,
     ai_drafts: @data.fetch("ai_drafts", true) == true, ai_available: Leads::Draft.available?}
  end
end
