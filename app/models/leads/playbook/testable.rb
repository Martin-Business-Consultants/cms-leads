# frozen_string_literal: true

# "Send me the emails": every email step of the playbook to someone on the
# team, at once, as a lead with their name and address would get it — links
# untracked, the subject marked as a test.
module Leads::Playbook::Testable
  extend ActiveSupport::Concern

  # Returns how many went.
  def send_test(to:)
    emails = ordered_steps.select(&:email?)
    emails.each { Leads::LeadMailer.with(step: it, to: to).test_email.deliver_later }
    emails.size
  end
end
