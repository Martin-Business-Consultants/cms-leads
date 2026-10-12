# frozen_string_literal: true

json.task do
  json.partial! "leads/api/tasks/task", record: @task
end
