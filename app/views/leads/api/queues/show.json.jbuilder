# frozen_string_literal: true

json.whose @queue.whose
%i[overdue today coming_up].each do |section|
  json.set! section, @queue.public_send(section) do |task|
    json.partial! "leads/api/tasks/task", record: task
    json.lead do
      json.extract! task.lead, :id, :name, :email, :phone, :company, :stage
    end
  end
end
json.without_next_step @queue.without_next_step, partial: "leads/api/leads/lead", as: :record
json.hot @queue.hot, partial: "leads/api/leads/lead", as: :record
