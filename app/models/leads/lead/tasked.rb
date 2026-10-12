# frozen_string_literal: true

# A lead's tasks (Leads::Task): what to do, by when, and who does it. Its
# next step is the earliest open one; an open lead without one shows in
# Needs you until someone decides what's next.
module Leads::Lead::Tasked
  extend ActiveSupport::Concern

  included do
    has_many :tasks, class_name: "Leads::Task", dependent: :delete_all, inverse_of: :lead

    # Open leads with nothing planned.
    scope :without_next_step, -> {
      open.where.not(id: Leads::Task.pending.select(:lead_id))
    }
  end

  def next_task = tasks.pending.in_due_order.first

  def needs_next_step? = open? && tasks.pending.none?

  # A task someone (or a playbook) adds. Returns it, saved or with errors.
  # quiet: leave it off the timeline (a playbook notes its plan as one).
  def add_task(attributes, user: Current.user, quiet: false)
    task = tasks.new(attributes)
    task.creator_id ||= user&.id
    task.assignee_id = owner_id unless task.assignee_id || attributes.to_h.stringify_keys.key?("assignee_id")
    if task.save && !quiet
      record_activity(:task_added, summary: "Next: #{task.title}", user: user,
        data: {task_id: task.id, due_at: task.due_at&.iso8601})
    end
    task
  end

  # Drops open tasks together, with one line on the timeline.
  def drop_tasks(tasks, reason:, user: nil)
    tasks = tasks.to_a.select(&:pending?)
    return if tasks.empty?

    tasks.each { it.update!(canceled_at: Time.current) }
    titles = tasks.map(&:title)
    record_activity(:task_canceled, summary: "Dropped #{titles.size == 1 ? "“#{titles.first}”" : "#{titles.size} planned steps"} (#{reason})",
      body: (titles.join("\n") if titles.size > 1), user: user, data: {task_ids: tasks.map(&:id)})
    enrollments.active.each(&:complete_if_done)
  end
end
