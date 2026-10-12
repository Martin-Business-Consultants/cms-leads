# frozen_string_literal: true

module Leads
  # One step of a playbook, its delay counted from when the lead started it:
  # a task for whoever owns the lead (call, email, text, meeting, to-do), or
  # an email sent by itself. The title, subject and body may say
  # {{first_name}}, {{name}}, {{company}}, {{email}}, {{phone}},
  # {{my_name}} and {{business}}. A step marked skip_if_reached is dropped
  # once someone reaches the lead — the second call attempt, the "did you
  # get my message?" email.
  class Step < ApplicationRecord
    ACTIONS = {"task" => "A task for a person", "email" => "An email that sends itself"}.freeze
    DELAY_UNITS = %w[minutes hours days weeks].freeze

    belongs_to :playbook, class_name: "Leads::Playbook", inverse_of: :steps
    has_many :tasks, class_name: "Leads::Task", dependent: :nullify

    validates :action, inclusion: {in: ACTIONS.keys}
    validates :task_kind, inclusion: {in: Leads::Task::KINDS.keys}
    validates :title, presence: true, length: {maximum: 200}, if: :task?
    validates :subject, presence: true, length: {maximum: 200}, if: :email?
    validates :body, presence: true, if: :email?
    validates :delay_amount, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than: 1000}
    validates :delay_unit, inclusion: {in: DELAY_UNITS}

    def task? = action == "task"
    def email? = action == "email"

    def delay = delay_amount.to_i.public_send(delay_unit)

    def due_from(start) = start + delay

    # "Right away", "1 hour in", "3 days in".
    def delay_label
      amount = delay_amount.to_i
      amount.zero? ? "Right away" : "#{amount} #{delay_unit.singularize.pluralize(amount)} in"
    end

    def title_for(lead) = Leads::Personalization.new(lead).fill(title.to_s)

    def summary = task? ? "#{Leads::Task::KINDS.fetch(task_kind)}: #{title}" : "Email: #{subject}"

    def email_for(lead, sender: nil) = Leads::Step::Email.new(self, lead, sender: sender)
  end
end
