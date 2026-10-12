# frozen_string_literal: true

json.extract! record, :id, :kind, :summary, :body, :points, :user_id
json.data record.data
json.created_at record.created_at.iso8601
