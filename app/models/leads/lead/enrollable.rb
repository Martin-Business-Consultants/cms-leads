# frozen_string_literal: true

# A lead's playbooks (Leads::Enrollment). Starting one plans its steps from
# now: each task step becomes a task due its delay from now, and each email
# step is sent at its moment unless the lead has been reached (for a step
# meant only for someone not reached yet), closed or unsubscribed.
module Leads::Lead::Enrollable
  extend ActiveSupport::Concern

  included do
    has_many :enrollments, class_name: "Leads::Enrollment", dependent: :delete_all
    has_many :messages, class_name: "Leads::Message", dependent: :delete_all
  end

  # Whether a playbook's email may go to the lead at all.
  def sendable? = email.present? && !unsubscribed? && open?

  # Why the lead can't start `playbook` now, or nil when it can.
  def enrollment_refusal(playbook)
    if closed? then "#{display_name} is #{stage}."
    elsif playbook.steps.empty? then "“#{playbook.name}” has no steps yet."
    elsif enrollments.active.exists?(playbook: playbook) then "#{display_name} is already following “#{playbook.name}”."
    end
  end

  # Returns the enrollment, or nil when it can't start (enrollment_refusal).
  def enroll(playbook, user: Current.user)
    return if enrollment_refusal(playbook)

    now = Time.current
    enrollment = enrollments.create!(playbook: playbook, started_at: now)
    steps = playbook.ordered_steps
    steps.select(&:task?).each do |step|
      add_task({kind: step.task_kind, title: step.title_for(self), notes: step.body.presence, due_at: step.due_from(now), step: step},
        user: user, quiet: true)
    end
    enrollment.plan_next_email
    record_activity(:enrolled, summary: "Started the “#{playbook.name}” playbook: #{steps.size} #{"step".pluralize(steps.size)} planned",
      body: steps.map { "#{it.delay_label}: #{it.summary}" }.join("\n"), data: {playbook_id: playbook.id}, user: user)
    enrollment
  end

  def stop_enrollments(reason:)
    enrollments.active.includes(:playbook).each { it.stop(reason: reason) }
  end
end
