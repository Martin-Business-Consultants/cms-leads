# frozen_string_literal: true

json.activity do
  json.partial! "leads/api/notes/activity", record: @activity
end
