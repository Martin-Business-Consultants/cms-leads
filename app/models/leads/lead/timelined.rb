# frozen_string_literal: true

# A lead's timeline: everything that happened to it, newest first
# (Leads::Activity). Recording an activity is how the lead's other verbs
# leave a trace: it adds the activity's points to the score (Scored) and
# marks the lead active now.
module Leads::Lead::Timelined
  extend ActiveSupport::Concern

  included do
    has_many :activities, -> { order(created_at: :desc, id: :desc) }, class_name: "Leads::Activity",
      dependent: :delete_all, inverse_of: :lead
  end

  # kind: one of Leads::Activity::KINDS. points: added to the score (0: none).
  def record_activity(kind, summary:, body: nil, points: 0, data: {}, user: Current.user)
    activity = activities.create!(kind: kind.to_s, summary: summary.to_s.truncate(250), body: body,
      points: points.to_i, data: data, user_id: user&.id)
    update_columns(last_activity_at: activity.created_at, updated_at: Time.current)
    add_points(points) unless points.to_i.zero?
    activity
  end

  # A note someone wrote on the lead.
  def add_note(body, user: Current.user)
    text = body.to_s.strip
    raise ArgumentError, "A note needs some text" if text.blank?

    record_activity(:note, summary: text.squish.truncate(120), body: text, user: user,
      points: Leads::Settings.current.points_for(:note))
  end
end
