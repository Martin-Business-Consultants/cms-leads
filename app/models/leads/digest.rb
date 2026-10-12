# frozen_string_literal: true

# The morning email: each person's overdue and due-today lead tasks, and the
# open leads they own with nothing planned, once a day at the hour Settings ›
# Leads names (site time). Unassigned work goes to the addresses told about
# new leads. Nobody with nothing to do gets one.
module Leads::Digest
  SENT_ON = "digest_sent_on"

  module_function

  def deliver_due_later = Leads::DigestJob.perform_later

  # Sends today's digests once the hour has come. Returns how many went.
  def deliver_due_now(now = Time.current)
    settings = Leads::Settings.current
    local = now.in_time_zone(Site.time_zone)
    return 0 if settings.digest_hour.nil? || local.hour < settings.digest_hour
    return 0 if Setting.get(Leads::Settings::KEY)[SENT_ON] == local.to_date.iso8601

    Setting.set(Leads::Settings::KEY, SENT_ON => local.to_date.iso8601)
    recipients(local.end_of_day).count do |email, work|
      Leads::AlertMailer.with(email: email, **work).digest.deliver_later
    end
  end

  # {email => {tasks:, leads:}} for everyone with something to do.
  def recipients(end_of_day)
    tasks = Leads::Task.on_kept_leads.merge(Leads::Lead.not_spam).due_by(end_of_day).includes(:lead).in_due_order.to_a
    leads = Leads::Lead.without_next_step.to_a
    people = ::User.where(id: (tasks.map(&:assignee_id) + leads.map(&:owner_id)).compact.uniq).index_by(&:id)
    unassigned_to = Leads::Settings.current.notify_emails

    work = Hash.new { |hash, email| hash[email] = {task_ids: [], lead_ids: []} }
    tasks.each { |task| emails_for(task.assignee_id, people, unassigned_to).each { work[it][:task_ids] << task.id } }
    leads.each { |lead| emails_for(lead.owner_id, people, unassigned_to).each { work[it][:lead_ids] << lead.id } }
    work
  end

  def emails_for(user_id, people, unassigned_to)
    person = people[user_id]
    person ? [person.email] : unassigned_to
  end
end
