# frozen_string_literal: true

json.lead do
  json.partial! "leads/api/leads/lead", record: @lead
  json.fields @lead.fields
  json.tasks @lead.tasks.pending.in_due_order, partial: "leads/api/tasks/task", as: :record
  json.playbooks @lead.enrollments.includes(:playbook).newest_first do |enrollment|
    json.extract! enrollment, :id, :status, :stop_reason
    json.playbook_id enrollment.playbook_id
    json.playbook_name enrollment.playbook.name
    json.progress enrollment.progress_label
    json.started_at enrollment.started_at.iso8601
  end
  json.timeline @lead.activities.limit(50), partial: "leads/api/notes/activity", as: :record
  json.guides Leads::Guide.for_stage(@lead.stage).map { {title: it.title, url: leads_guide_url(it)} }
  json.tip Leads::Guide::STAGE_TIPS[@lead.stage]
end
