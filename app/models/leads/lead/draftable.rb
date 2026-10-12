# frozen_string_literal: true

# Replies drafted for a lead by AI (Leads::Draft): an email, a text, a call
# plan and the best next step, in the site's voice (Settings › Brand
# context). Only while an Anthropic key is set in Settings › Leads.
module Leads::Lead::Draftable
  extend ActiveSupport::Concern

  included do
    has_many :drafts, -> { order(created_at: :desc, id: :desc) }, class_name: "Leads::Draft", dependent: :delete_all
  end

  # Returns the draft being written, or nil when AI isn't set up or the lead
  # is spam.
  def draft_replies_later(user: nil)
    return if spam? || !Leads::Draft.available?

    Leads::Draft.write_later(self, user: user)
  end

  def latest_draft = drafts.first
end
