# frozen_string_literal: true

require "leads/version"
require "leads/engine"

# Leads: everyone who gets in touch through the site — a form, a quote
# request — becomes a lead with an owner and a next step, so nobody waits on
# a reply. Playbooks set the first steps for each kind of enquiry, Needs you
# lists what's due, and the timeline, scores, templates, AI drafts and email
# follow-ups help with the rest. Installed from its own repository; off by
# default.
module Leads
  # Plugin tables are prefixed with the plugin's key.
  def self.table_name_prefix = "leads_"

  # Signs what an email's links carry (Leads::Message, Leads::Lead's
  # unsubscribe token): URL-safe, so a token sits in a path segment as it is.
  def self.verifier
    @verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("leads/mail", 32), url_safe: true, serializer: JSON
    )
  end
end
