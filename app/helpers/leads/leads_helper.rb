# frozen_string_literal: true

# The Leads screens' words and small pieces: when something is due, a
# stage's badge, the links that reach a lead, and the choices forms offer.
module Leads::LeadsHelper
  STAGE_BADGE_CLASSES = {
    "new" => "badge badge--info", "contacted" => "badge badge--warning", "qualified" => "badge badge--warning",
    "quoted" => "badge badge--warning", "won" => "badge badge--success", "lost" => "badge", "spam" => "badge badge--danger"
  }.freeze

  # "overdue by 2 hours", "in 40 minutes", "today at 3:00 pm", "tomorrow at
  # 9:00 am", "Thu 16 Oct at 9:00 am", in the site's time zone.
  def lead_due_words(time, now: Time.current)
    return "no date" unless time

    zone = Site.time_zone
    local = time.in_time_zone(zone)
    today = now.in_time_zone(zone).to_date
    clock = local.strftime("%-l:%M %P")
    if time < now
      "overdue by #{distance_of_time_in_words(time, now)}"
    elsif time < now + 1.hour
      "in #{distance_of_time_in_words(now, time)}"
    elsif local.to_date == today
      "today at #{clock}"
    elsif local.to_date == today + 1
      "tomorrow at #{clock}"
    else
      "#{local.strftime("%a %-d %b")} at #{clock}"
    end
  end

  def lead_due_tag(task)
    tag.span lead_due_words(task.due_at), class: class_names("nowrap text-small", task.overdue? ? "text-danger" : "text-muted"),
      title: task.due_at&.in_time_zone(Site.time_zone)&.to_fs(:long)
  end

  def lead_stage_tag(stage)
    tag.span stage.to_s.humanize, class: STAGE_BADGE_CLASSES.fetch(stage.to_s, "badge")
  end

  def lead_task_kind_tag(task_or_kind)
    kind = task_or_kind.respond_to?(:kind) ? task_or_kind.kind : task_or_kind.to_s
    tag.span Leads::Task::KINDS.fetch(kind, kind.humanize), class: "badge leads-kind"
  end

  # [[label, href], …]: call, text and email the lead, for what it gave.
  def lead_contact_links(lead)
    [
      (["Call", "tel:#{lead.phone.gsub(/[^\d+]/, "")}"] if lead.phone.present?),
      (["Text", "sms:#{lead.phone.gsub(/[^\d+]/, "")}"] if lead.phone.present?),
      (["Email", "mailto:#{lead.email}"] if lead.email.present?)
    ].compact
  end

  # A mailto: link with the subject and body filled in.
  def lead_mailto(lead, subject:, body:)
    "mailto:#{lead.email}?#{{subject: subject.to_s, body: body.to_s}.to_query.gsub("+", "%20")}"
  end

  def lead_sms(lead, body:) = "sms:#{lead.phone.to_s.gsub(/[^\d+]/, "")}?&body=#{ERB::Util.url_encode(body.to_s)}"

  def lead_people_options = ::User.order(:name, :email).map { [it.name.presence || it.email, it.id] }

  def lead_person_name(user) = user ? (user.name.presence || user.email) : "Nobody"

  def lead_stage_options = Leads::Lead::STAGES.map { [it.humanize, it] }

  def lead_task_kind_options = Leads::Task::KINDS.map { |key, label| [label, key] }

  def lead_when_options = Leads::When::CHOICES

  def lead_form_options = defined?(::Form) ? ::Form.order(:title).map { [it.title, it.slug] } : []

  # The link to the Forms submission or Commerce quote request an activity
  # came from, when that plugin's route is there.
  def lead_activity_source_link(activity)
    label, route, args = activity.source_link
    return unless route && respond_to?(route)

    link_to label, public_send(route, *args), class: "link text-small"
  rescue ActionController::UrlGenerationError
    nil
  end

  def lead_queue_whose_options(counts = {})
    Leads::Queue::WHOSE.map { |key, label| [label, key, counts[key]] }
  end
end
