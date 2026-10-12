# frozen_string_literal: true

module Leads
  # A lead following a playbook: started when it came in or by hand, active
  # until every email step has gone (completed), or stopped — by hand, or
  # because the lead closed or unsubscribed. Its tasks were planned when it
  # started; Deliverable sends its emails.
  class Enrollment < ApplicationRecord
    include Deliverable

    STATUSES = %w[active completed stopped].freeze

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :playbook, class_name: "Leads::Playbook"
    has_many :messages, class_name: "Leads::Message", dependent: :nullify

    validates :status, inclusion: {in: STATUSES}

    scope :active, -> { where(status: "active") }
    scope :newest_first, -> { order(created_at: :desc, id: :desc) }

    def active? = status == "active"

    def email_steps = playbook.ordered_steps.select(&:email?)

    # The email step that goes next, or nil when none is left.
    def next_email = email_steps.find { sent_step_ids.exclude?(it.id) }

    # The tasks it planned for its lead.
    def tasks = lead.tasks.where(step_id: playbook.steps.select(:id)).where(created_at: started_at..)

    # "2 of 6 steps done, 1 of 2 emails sent".
    def progress_label
      planned = tasks.to_a
      done = planned.count { !it.pending? }
      emails = email_steps.size
      parts = []
      parts << "#{done} of #{planned.size} #{"step".pluralize(planned.size)} done" if planned.any?
      parts << "#{[sent_step_ids.size, emails].min} of #{emails} #{"email".pluralize(emails)} sent" if emails.positive?
      parts.join(", ").presence || "Nothing planned"
    end

    # Its emails stop; stopped by a person, its open tasks are dropped too.
    def stop(reason: "stopped by hand", user: nil)
      return false unless active?

      lead.drop_tasks(tasks.pending, reason: "stopped “#{playbook.name}”", user: user) if reason.to_s == "stopped by hand"
      update!(status: "stopped", finished_at: Time.current, next_send_at: nil, stop_reason: reason.to_s)
      lead.record_activity(:enrollment_stopped, summary: "Stopped “#{playbook.name}” (#{reason.to_s.humanize(capitalize: false)})",
        data: {playbook_id: playbook_id, reason: reason.to_s}, user: user)
      true
    end

    # Done once every email has gone and every step it planned is finished.
    def complete_if_done
      complete if active? && next_email.nil? && tasks.pending.none?
    end

    def complete
      update!(status: "completed", finished_at: Time.current, next_send_at: nil)
      lead.record_activity(:enrollment_completed, summary: "Finished “#{playbook.name}”", data: {playbook_id: playbook_id}, user: nil)
    end
  end
end
