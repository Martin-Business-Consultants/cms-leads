# frozen_string_literal: true

module Leads
  # One thing on a lead's timeline: getting in touch, a task planned, done
  # or dropped, an email sent, opened or clicked, a stage, owner or score
  # changed, a note, a playbook started or finished. Made by the lead's
  # verbs (Lead#record_activity), never edited.
  class Activity < ApplicationRecord
    KINDS = %w[
      created captured returned
      task_added task_done task_canceled
      email_sent email_opened email_clicked unsubscribed resubscribed
      stage_changed owner_changed score_changed note
      enrolled enrollment_stopped enrollment_completed
      drafted
    ].freeze

    belongs_to :lead, class_name: "Leads::Lead", inverse_of: :activities
    belongs_to :user, class_name: "::User", optional: true

    validates :kind, inclusion: {in: KINDS}
    validates :summary, presence: true

    def note? = kind == "note"

    # The Forms submission or Commerce quote request it came from, as
    # [label, route name, args] for a link, when it names one.
    def source_link
      if data["submission_id"] && data["form_slug"]
        ["Open the submission", :form_submission_path, [data["form_slug"], data["submission_id"]]]
      elsif data["quote_request_id"]
        ["Open the quote request", :quote_request_path, [data["quote_request_id"]]]
      end
    end
  end
end
