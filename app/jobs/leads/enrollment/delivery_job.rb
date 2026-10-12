# frozen_string_literal: true

# Sends one enrollment's email when it's due, or (with no id, the sweep)
# every enrollment's that is (Leads::Enrollment::Deliverable). Nothing goes
# while the plugin is off.
class Leads::Enrollment::DeliveryJob < ApplicationJob
  queue_as :default

  def perform(enrollment_id = nil)
    return unless Cms::Plugins.enabled?(:leads)

    if enrollment_id
      Leads::Enrollment.find_by(id: enrollment_id)&.deliver_now
    else
      Leads::Enrollment.deliver_due_now
    end
  end
end
