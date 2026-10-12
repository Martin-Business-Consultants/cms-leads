# frozen_string_literal: true

# Leads from the site: a Forms submission or a Commerce quote request
# (Leads::Enquiry) becomes a lead, or comes back to the one it already is.
#
# A new lead arrives: an owner (its playbook's, else Settings › Leads'
# default), its playbook's steps planned as tasks and emails, the team told
# (Leads::AlertMailer), replies drafted when AI is on, and lead.created
# announced. A lead that writes again gets a reply due within the hour on top
# of whatever was planned; a lost one opens again. Spam stays out of sight.
module Leads::Lead::Capturable
  extend ActiveSupport::Concern

  # How soon a reply is due to someone who wrote again.
  REPLY_WITHIN = 1.hour

  class_methods do
    def capture_later(kind, payload)
      Leads::Lead::CaptureJob.perform_later(kind.to_s, payload.to_h.deep_stringify_keys)
    end

    # kind: "submission" or "quote_request". Returns the lead, or nil when
    # the enquiry names nobody or its form doesn't make leads.
    def capture_now(kind, payload)
      return follow_invoice(payload, kind.delete_prefix("invoice_")) if kind.to_s.start_with?("invoice_")

      enquiry = kind.to_s == "quote_request" ? Leads::Enquiry.from_quote(payload) : Leads::Enquiry.from_submission(payload)
      return if enquiry.source == "form" && !Leads::Settings.current.captures_form?(enquiry.source_form)

      capture(enquiry)
    end

    # A Commerce invoice sent (the lead is quoted) or paid (won), for the
    # lead with its customer's email address. A lead never moves back.
    def follow_invoice_later(payload, stage)
      Leads::Lead::CaptureJob.perform_later("invoice_#{stage}", payload.to_h.deep_stringify_keys)
    end

    def follow_invoice(payload, stage)
      lead = find_for(email: payload.to_h.stringify_keys["customer_email"])
      return if lead.nil? || lead.spam? || lead.stage == "won" || lead.stage == stage

      number = payload.to_h.stringify_keys["number"]
      lead.change_stage(stage, user: nil, reason: stage == "won" ? "invoice #{number} paid" : "invoice #{number} sent")
      lead
    end

    def capture(enquiry)
      return if enquiry.blank?

      lead = find_for(email: enquiry.email, phone: enquiry.phone)
      return lead if lead&.spam?

      if lead
        lead.absorb(enquiry)
        lead.come_back(enquiry)
      else
        lead = new(source: enquiry.source, source_label: enquiry.source_label, source_form: enquiry.source_form)
        lead.absorb(enquiry)
        lead.record_activity(:captured, summary: "Got in touch: #{lead.source_text}", body: enquiry.message, user: nil,
          points: Leads::Settings.current.points_for(:captured), data: {fields: enquiry.fields}.merge(enquiry.reference))
        lead.arrive(playbook: Leads::Playbook.for_lead(lead), user: nil)
      end
      lead
    end
  end

  # Fills in what the enquiry says and the lead doesn't know yet, and keeps
  # every answer. Saves.
  def absorb(enquiry)
    enquiry.contact.each { |attribute, value| self[attribute] = value if self[attribute].blank? }
    self.fields = fields.to_h.merge(enquiry.fields)
    save!
  end

  # A new lead's start: its owner, its playbook, the team told.
  def arrive(playbook:, user:)
    update!(owner_id: playbook&.owner_id || Leads::Settings.current.default_owner_id) if owner_id.nil?
    enroll(playbook, user: user) if playbook
    Leads::AlertMailer.with(lead: self, event: "new").alert.deliver_later if Leads::Settings.current.alert_recipients(self).any?
    draft_replies_later if Leads::Settings.current.ai_drafts?
    announce("lead.created")
  end

  # The same person got in touch again: on the timeline, a reply due, the
  # team told.
  def come_back(enquiry)
    record_activity(:returned, summary: "Got in touch again: #{enquiry.source_label || source_text}", body: enquiry.message,
      user: nil, points: Leads::Settings.current.points_for(:returned), data: {fields: enquiry.fields}.merge(enquiry.reference))
    change_stage("new", user: nil, reason: "got in touch again") if stage == "lost"
    unless tasks.pending.where(kind: "email", step_id: nil).where("title LIKE ?", "Reply to%").exists?
      add_task({kind: "email", title: "Reply to their new message", due_at: REPLY_WITHIN.from_now}, user: nil)
    end
    Leads::AlertMailer.with(lead: self, event: "returned").alert.deliver_later if Leads::Settings.current.alert_recipients(self).any?
  end
end
