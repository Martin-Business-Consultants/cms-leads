# frozen_string_literal: true

# Finishing a task the way the lead's page and the API do it: how it went,
# then what's next — another task, a new stage, or both — so the lead goes
# on with a next step, or is closed knowingly.
#
#   Leads::Task::Completion.new(task, result: "no_answer", outcome: "Voicemail",
#     next_kind: "text", next_title: "Text them", next_when: "4h").save
class Leads::Task::Completion
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :result, :string
  attribute :outcome, :string
  attribute :next_kind, :string
  attribute :next_title, :string
  attribute :next_when, :string
  attribute :next_due_at, :datetime
  attribute :stage, :string

  attr_reader :task, :next_task

  validate :next_task_valid

  def initialize(task, attributes = {})
    @task = task
    super(attributes.to_h.symbolize_keys.slice(*self.class.attribute_names.map(&:to_sym)))
  end

  def save(user: Current.user)
    return false unless valid?

    Leads::Task.transaction do
      task.complete(result: result, outcome: outcome, user: user)
      @next_task = task.lead.add_task(next_task_attributes, user: user) if next_step?
      task.lead.change_stage(stage, user: user) if stage.present? && stage != task.lead.stage
    end
    true
  end

  def next_step? = next_title.present?

  private

  def next_task_attributes
    {kind: next_kind.presence || "call", title: next_title, due_at: next_due_at || Leads::When.parse(next_when)}
  end

  def next_task_valid
    errors.add(:stage, "is not a stage") if stage.present? && Leads::Lead::STAGES.exclude?(stage)
    return unless next_step?

    errors.add(:next_kind, "is not a kind of task") if next_kind.present? && Leads::Task::KINDS.exclude?(next_kind)
  end
end
