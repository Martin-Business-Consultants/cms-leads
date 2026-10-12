# frozen_string_literal: true

# Sends the morning digests once their hour has come (Leads::Digest).
class Leads::DigestJob < ApplicationJob
  queue_as :default

  def perform
    return unless Cms::Plugins.enabled?(:leads)

    Leads::Digest.deliver_due_now
  end
end
