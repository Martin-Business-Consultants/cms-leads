# frozen_string_literal: true

# Writes a lead's drafted replies (Leads::Draft#write_now).
class Leads::Draft::WriteJob < ApplicationJob
  queue_as :default

  def perform(draft_id)
    Leads::Draft.find_by(id: draft_id)&.write_now
  end
end
