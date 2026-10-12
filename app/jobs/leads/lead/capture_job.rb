# frozen_string_literal: true

# Makes or updates the lead a form submission or quote request names, so the
# visitor's request never waits on it (Leads::Lead::Capturable).
class Leads::Lead::CaptureJob < ApplicationJob
  queue_as :default

  def perform(kind, payload)
    return unless Cms::Plugins.enabled?(:leads)

    Leads::Lead.capture_now(kind, payload)
  end
end
