# frozen_string_literal: true

# The team's emails about leads: one got in touch (new, or again), and the
# morning digest of what's due (Leads::Digest).
class Leads::AlertMailer < ::ApplicationMailer
  helper Leads::LeadsHelper

  def alert
    @lead = params[:lead]
    @event = params[:event]
    @next_task = @lead.next_task
    recipients = Leads::Settings.current.alert_recipients(@lead)
    return if recipients.empty?

    verb = @event == "returned" ? "got in touch again" : "new lead"
    subject = @event == "returned" ? "#{@lead.display_name} got in touch again" : "New lead: #{@lead.display_name}"
    @heading = verb
    mail to: recipients, subject: "#{subject} (#{@lead.source_text})"
  end

  def digest
    @tasks = Leads::Task.where(id: params[:task_ids]).includes(:lead).in_due_order.to_a
    @leads = Leads::Lead.where(id: params[:lead_ids]).to_a
    @now = Time.current.in_time_zone(Site.time_zone)
    count = @tasks.size + @leads.size
    mail to: params[:email], subject: "Leads today: #{count} #{count == 1 ? "thing" : "things"} to do"
  end
end
