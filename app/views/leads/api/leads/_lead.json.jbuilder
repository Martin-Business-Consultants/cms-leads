# frozen_string_literal: true

json.extract! record, :id, :name, :email, :phone, :company, :stage, :score, :source, :source_label, :source_form
json.owner record.owner && {id: record.owner.id, name: record.owner.name, email: record.owner.email}
json.hot record.hot?
next_task = record.next_task
json.next_step next_task && {id: next_task.id, kind: next_task.kind, title: next_task.title, due_at: next_task.due_at&.iso8601,
                            overdue: next_task.overdue?, assignee_id: next_task.assignee_id}
json.needs_next_step record.needs_next_step?
json.contacted_at record.contacted_at&.iso8601
json.unsubscribed record.unsubscribed?
json.last_activity_at record.last_activity_at&.iso8601
json.created_at record.created_at.iso8601
json.admin_url lead_url(record)
