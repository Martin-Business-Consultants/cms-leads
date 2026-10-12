# frozen_string_literal: true

module Leads
  # Something to do for a lead — call, email, text, meet, or anything else —
  # by when, and who does it. A playbook plans them (step), people add them.
  # Finishing one says how it went: reaching them moves a new lead on
  # (Lead#mark_reached), and the person says what's next in the same breath
  # (Completion), so a lead is never left without a next step by accident.
  class Task < ApplicationRecord
    KINDS = {"call" => "Call", "email" => "Email", "text" => "Text", "meeting" => "Meeting", "todo" => "To-do"}.freeze
    # The kinds that try to reach the lead.
    CONTACT_KINDS = %w[call email text meeting].freeze
    RESULTS = {"reached" => "Reached them", "no_answer" => "No answer / left a message", "done" => "Done"}.freeze

    belongs_to :lead, class_name: "Leads::Lead", inverse_of: :tasks
    belongs_to :step, class_name: "Leads::Step", optional: true
    belongs_to :assignee, class_name: "::User", optional: true
    belongs_to :completed_by, class_name: "::User", optional: true

    validates :title, presence: true, length: {maximum: 200}
    validates :kind, inclusion: {in: KINDS.keys}
    validates :result, inclusion: {in: RESULTS.keys}, allow_nil: true

    scope :pending, -> { where(completed_at: nil, canceled_at: nil) }
    scope :completed, -> { where.not(completed_at: nil) }
    scope :from_steps, -> { where.not(step_id: nil) }
    scope :from_steps_skipped_once_reached, -> { joins(:step).where(leads_steps: {skip_if_reached: true}) }
    scope :assigned_to, ->(user) { where(assignee_id: user&.id) }
    scope :unassigned, -> { where(assignee_id: nil) }
    scope :overdue, ->(now = Time.current) { pending.where(due_at: ...now) }
    scope :due_by, ->(time) { pending.where(due_at: ..time) }
    scope :between, ->(range) { pending.where(due_at: range) }
    # Earliest due first, undated last, then the oldest.
    scope :in_due_order, -> { order(Arel.sql("CASE WHEN leads_tasks.due_at IS NULL THEN 1 ELSE 0 END"), :due_at, :created_at, :id) }
    # Tasks on leads that are still around.
    scope :on_kept_leads, -> { joins(:lead).merge(Leads::Lead.kept) }

    def pending? = completed_at.nil? && canceled_at.nil?
    def completed? = completed_at.present?
    def canceled? = canceled_at.present?
    def overdue?(now = Time.current) = pending? && due_at.present? && due_at < now
    def contact? = CONTACT_KINDS.include?(kind)
    def kind_label = KINDS.fetch(kind, kind.humanize)
    def result_label = RESULTS[result]

    # Done, and how it went. result: one of RESULTS (a contact task that
    # isn't told counts as reached; anything else as done). Returns false
    # when it was already finished.
    def complete(result: nil, outcome: nil, user: Current.user)
      return false unless pending?

      result = result.presence || (contact? ? "reached" : "done")
      update!(completed_at: Time.current, completed_by_id: user&.id, result: result, outcome: outcome.to_s.strip.presence)
      lead.record_activity(:task_done, summary: "#{title}: #{result_label.downcase}", body: outcome.presence, user: user,
        data: {task_id: id, kind: kind, result: result})
      lead.mark_reached(user: user) if result == "reached" && contact?
      lead.enrollments.active.each(&:complete_if_done)
      true
    end

    def cancel(reason: nil, user: nil)
      return false unless pending?

      update!(canceled_at: Time.current)
      lead.record_activity(:task_canceled, summary: "Dropped: #{title}#{" (#{reason})" if reason}", user: user, data: {task_id: id})
      true
    end

    def reopen
      return false if pending?

      update!(completed_at: nil, completed_by_id: nil, canceled_at: nil, result: nil)
    end
  end
end
