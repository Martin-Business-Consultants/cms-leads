# frozen_string_literal: true

json.extract! record, :id, :name, :active, :trigger, :trigger_form, :owner_id
json.trigger_label record.trigger_label
json.steps record.ordered_steps do |step|
  json.extract! step, :id, :action, :task_kind, :title, :subject, :body, :delay_amount, :delay_unit, :skip_if_reached
  json.when step.delay_label
end
