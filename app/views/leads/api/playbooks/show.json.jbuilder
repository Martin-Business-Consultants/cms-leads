# frozen_string_literal: true

json.playbook do
  json.partial! "leads/api/playbooks/playbook", record: @playbook
end
