# frozen_string_literal: true

json.tasks @tasks do |task|
  json.partial! "leads/api/tasks/task", record: task
  json.lead do
    json.extract! task.lead, :id, :name, :email, :phone, :company, :stage
  end
end
