# frozen_string_literal: true

# Sending a playbook's emails. Each time an enrollment's next email is
# planned, a job is queued for that moment (plan_next_email); every few
# minutes a sweep sends any that are due and weren't (a playbook switched
# back on, a failed send, a restart). Sending one is a Leads::Message, an
# "email sent" activity, and the next one planned — or the enrollment done
# when it was the last. A step for someone not reached yet is skipped once
# they have been.
module Leads::Enrollment::Deliverable
  extend ActiveSupport::Concern

  # When an email that failed to send is tried again.
  RETRY_AFTER = 15.minutes

  included do
    # Active, due, in a playbook that's on.
    scope :due, ->(now = Time.current) { active.where(next_send_at: ..now).joins(:playbook).merge(Leads::Playbook.active) }
  end

  class_methods do
    def deliver_due_later = Leads::Enrollment::DeliveryJob.perform_later

    # Returns how many emails went. One that fails is logged, tried again
    # later, and doesn't stop the others.
    def deliver_due_now(now = Time.current)
      due(now).includes(:lead, playbook: :steps).find_each.count do |enrollment|
        enrollment.deliver_now(now)
      rescue => error
        Rails.logger.error("[leads] enrollment #{enrollment.id}: #{error.class}: #{error.message}")
        false
      end
    end
  end

  # Sets when the next email goes and queues it; completes an enrollment
  # with nothing left to send and no tasks of its own still open.
  def plan_next_email
    step = next_email
    if step
      update!(next_send_at: step.due_from(started_at))
      Leads::Enrollment::DeliveryJob.set(wait_until: next_send_at).perform_later(id)
    else
      update!(next_send_at: nil)
      complete_if_done
    end
  end

  # Sends the due email, once: a run first claims it (clearing next_send_at
  # where it's still due), so two at once can't both send it. Returns
  # whether an email went.
  def deliver_now(now = Time.current)
    return false unless playbook.active? && claim(now)

    step = next_email
    if step.nil?
      complete_if_done
      false
    elsif !lead.sendable?
      stop(reason: lead.unsubscribed? ? "unsubscribed" : (lead.email.blank? ? "no email address" : lead.stage))
      false
    elsif step.skip_if_reached? && lead.contacted_at && lead.contacted_at >= started_at
      skip(step)
      false
    else
      send_step(step, now)
      true
    end
  end

  private

  def claim(now)
    claimed = self.class.active.where(id: id, next_send_at: ..now).update_all(next_send_at: nil, updated_at: now)
    reload if claimed == 1
    claimed == 1
  end

  def skip(step)
    update!(sent_step_ids: sent_step_ids + [step.id])
    plan_next_email
  end

  def send_step(step, now)
    message = lead.messages.create!(enrollment: self, step: step, subject: step.email_for(lead, sender: playbook.owner || lead.owner).subject)
    begin
      message.deliver_now
    rescue
      message.destroy!
      update!(next_send_at: now + RETRY_AFTER)
      raise
    end
    lead.record_activity(:email_sent, summary: "Sent “#{message.subject}”", user: nil,
      data: {message_id: message.id, playbook_id: playbook_id, step_id: step.id})
    update!(sent_step_ids: sent_step_ids + [step.id])
    plan_next_email
  end
end
