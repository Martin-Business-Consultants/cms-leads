# frozen_string_literal: true

module Leads
  # Replies drafted for a lead by the AI plugin (Leads::Draft::Writer): a short
  # read of what they want, the best next step, an email, a text and a call
  # plan with the questions to ask and the objections to expect. Written in
  # the background — "working" until it's "ready" or "failed" — and never
  # sent by itself: a person copies, edits and sends.
  class Draft < ApplicationRecord
    STATES = %w[working ready failed].freeze

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :user, class_name: "::User", optional: true

    validates :state, inclusion: {in: STATES}

    def self.available? = Leads::Draft::Writer.available?

    def self.write_later(lead, user: nil)
      draft = lead.drafts.create!(user_id: user&.id)
      Leads::Draft::WriteJob.perform_later(draft.id)
      draft
    end

    def working? = state == "working"
    def ready? = state == "ready"
    def failed? = state == "failed"

    def write_now
      update!(payload: Leads::Draft::Writer.new(lead, user: user).write, state: "ready", error: nil)
      lead.record_activity(:drafted, summary: "Replies drafted", user: user, data: {draft_id: id})
    rescue Leads::Draft::Writer::Error => error
      update!(state: "failed", error: error.message)
    end

    def summary = payload["summary"].to_s
    def next_step = payload["next_step"].to_h
    def email = payload["email"].to_h
    def text_message = payload["text"].to_s
    def call = payload["call"].to_h
  end
end
