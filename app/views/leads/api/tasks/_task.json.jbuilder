# frozen_string_literal: true

json.extract! record, :id, :lead_id, :kind, :title, :notes, :assignee_id, :result, :outcome
json.due_at record.due_at&.iso8601
json.overdue record.overdue?
json.from_playbook record.step_id.present?
json.completed_at record.completed_at&.iso8601
json.canceled_at record.canceled_at&.iso8601
