# frozen_string_literal: true

# A lead's score: points for what it does (getting in touch, coming back,
# opening a playbook's email, clicking a link in one; Settings › Leads) and
# adjustments by hand. A lead at or over the threshold is hot: Needs you
# lists it while it's open and has been active this week.
module Leads::Lead::Scored
  extend ActiveSupport::Concern

  HOT_WITHIN = 7.days

  included do
    scope :hot, -> {
      open.where(score: Leads::Settings.current.hot_threshold..).where(last_activity_at: HOT_WITHIN.ago..)
    }
  end

  # A change to the score by hand, with the reason on the timeline.
  def adjust_score(points, reason:, user: Current.user)
    points = Integer(points.to_s, exception: false)
    raise ArgumentError, "Give a number of points other than 0" if points.nil? || points.zero?

    reason = reason.to_s.strip
    record_activity(:score_changed, summary: "Score #{"+" if points.positive?}#{points}#{": #{reason}" if reason.present?}",
      points: points, user: user, data: {reason: reason})
  end

  def add_points(points)
    update_columns(score: score + points.to_i, updated_at: Time.current)
  end

  def hot? = open? && score >= Leads::Settings.current.hot_threshold
end
