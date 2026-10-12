# frozen_string_literal: true

# The playbooks a site starts with when Leads is switched on: one for every
# enquiry and one for quote requests, tasks only — nothing emails a lead
# until someone adds an email step. Made once, while there are none.
module Leads::Playbook::Defaults
  extend ActiveSupport::Concern

  DEFAULTS = [
    {name: "Every new enquiry", trigger: "any", steps: [
      {task_kind: "call", title: "Call {{first_name}} back", delay_amount: 15, delay_unit: "minutes",
       body: "Answer fast: the first business to reply usually wins. No answer? Leave a short voicemail and send the text.", skip_if_reached: false},
      {task_kind: "text", title: "Text {{first_name}} if the call didn’t connect", delay_amount: 30, delay_unit: "minutes",
       body: "Use the “First text after an enquiry” or “Missed your call” template."},
      {task_kind: "email", title: "Email {{first_name}} a personal reply", delay_amount: 2, delay_unit: "hours",
       body: "Use “Couldn’t reach you by phone”, or the drafted reply, and change one line so it’s about them."},
      {task_kind: "call", title: "Second call attempt", delay_amount: 1, delay_unit: "days"},
      {task_kind: "email", title: "Check in with {{first_name}}", delay_amount: 4, delay_unit: "days",
       body: "Use “Checking in”: one short question they can answer yes or no."},
      {task_kind: "todo", title: "Last try, then decide: keep going or mark lost", delay_amount: 14, delay_unit: "days",
       body: "Send “Last try”. If there’s still no reply, mark the lead lost so it stops asking for attention."}
    ]},
    {name: "Quote requests", trigger: "quote", steps: [
      {task_kind: "call", title: "Call {{first_name}} about their quote", delay_amount: 1, delay_unit: "hours",
       body: "Check what they need before you price it: quantities, timing, delivery.", skip_if_reached: false},
      {task_kind: "email", title: "Send {{first_name}} the quote", delay_amount: 1, delay_unit: "days", skip_if_reached: false,
       body: "Use “Sending a quote”. Draft the invoice from the quote request if they’re ready."},
      {task_kind: "call", title: "Follow up on the quote", delay_amount: 3, delay_unit: "days", skip_if_reached: false,
       body: "Ask whether they’ve had a chance to look, and what’s in the way of a yes."},
      {task_kind: "text", title: "Nudge about the quote", delay_amount: 7, delay_unit: "days", skip_if_reached: false,
       body: "Use “Gentle nudge”."}
    ]}
  ].freeze

  class_methods do
    def seed_defaults!
      return if exists?

      transaction do
        DEFAULTS.each do |playbook|
          record = create!(playbook.except(:steps))
          playbook[:steps].each { record.steps.create!({action: "task", skip_if_reached: true}.merge(it)) }
        end
      end
    end
  end
end
