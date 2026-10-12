# frozen_string_literal: true

# Leaving a playbook's emails: every one carries a link with the lead's
# signed token to a public page that records it in one click and stops the
# lead's emails. Its tasks stay: someone may still call.
module Leads::Lead::Subscribable
  extend ActiveSupport::Concern

  TOKEN_PURPOSE = "leads/unsubscribe"

  class_methods do
    def find_by_unsubscribe_token(token)
      id = Leads.verifier.verified(token.to_s, purpose: TOKEN_PURPOSE)
      id && with_discarded.find_by(id: id)
    end
  end

  def unsubscribed? = unsubscribed_at.present?

  def unsubscribe_token = Leads.verifier.generate(id, purpose: TOKEN_PURPOSE)

  # Returns false when the lead had already left.
  def unsubscribe
    return false if unsubscribed?

    update!(unsubscribed_at: Time.current)
    record_activity(:unsubscribed, summary: "Unsubscribed from emails", user: nil)
    stop_enrollments(reason: "unsubscribed")
    true
  end

  # Someone putting a lead back on the list, because it asked to be.
  def resubscribe(user: Current.user)
    return false unless unsubscribed?

    update!(unsubscribed_at: nil)
    record_activity(:resubscribed, summary: "Subscribed to emails again", user: user)
    true
  end
end
