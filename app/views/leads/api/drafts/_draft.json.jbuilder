# frozen_string_literal: true

json.extract! record, :id, :lead_id, :state, :error
json.drafts record.payload
json.created_at record.created_at.iso8601
json.updated_at record.updated_at.iso8601
