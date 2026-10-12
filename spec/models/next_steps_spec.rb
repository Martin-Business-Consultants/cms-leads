# frozen_string_literal: true

require "rails_helper"

RSpec.describe "A lead's next steps", type: :model do
  let(:user) { create(:user) }
  let(:playbook) { Leads::Playbook.create!(name: "Enquiries", trigger: "any") }
  let(:lead) { Leads::Lead.create!(name: "Jordan Reyes", email: "jordan@example.com", owner: user) }

  before do
    switch_plugin :leads, on: true
    Leads::Playbook.destroy_all # the ones switching it on made
    playbook.steps.create!(action: "task", task_kind: "call", title: "Call {{first_name}}", delay_amount: 15, delay_unit: "minutes", skip_if_reached: false)
    playbook.steps.create!(action: "task", task_kind: "call", title: "Second call", delay_amount: 1, delay_unit: "days")
    playbook.steps.create!(action: "task", task_kind: "todo", title: "Decide", delay_amount: 14, delay_unit: "days", skip_if_reached: false)
    lead.enroll(playbook, user: user)
  end

  it "plans the playbook's steps as one entry on the timeline" do
    expect(lead.tasks.pending.count).to eq(3)
    expect(lead.activities.where(kind: "task_added")).to be_empty
    expect(lead.activities.find_by(kind: "enrolled").summary).to eq("Started the “Enquiries” playbook: 3 steps planned")
  end

  it "moves a new lead on when someone reaches them, dropping the steps for someone not reached" do
    completion = Leads::Task::Completion.new(lead.next_task, result: "reached", outcome: "Wants a quote",
      next_kind: "email", next_title: "Send the quote", next_when: "1d")

    expect(completion.save(user: user)).to be(true)
    lead.reload
    expect(lead.stage).to eq("contacted")
    expect(lead.contacted_at).to be_present
    expect(lead.tasks.pending.in_due_order.pluck(:title)).to eq(["Send the quote", "Decide"])
    expect(lead.activities.find_by(kind: "task_canceled").summary).to eq("Dropped “Second call” (reached them)")
  end

  it "keeps a lead new after no answer" do
    Leads::Task::Completion.new(lead.next_task, result: "no_answer").save(user: user)

    expect(lead.reload.stage).to eq("new")
    expect(lead.tasks.pending.pluck(:title)).to include("Second call")
  end

  it "shows an open lead with nothing planned, until it's closed" do
    lead.tasks.pending.each { it.complete(result: "no_answer") }
    expect(lead.needs_next_step?).to be(true)
    expect(Leads::Lead.without_next_step).to include(lead)

    lead.change_stage("lost", user: user)
    expect(Leads::Lead.without_next_step).not_to include(lead)
  end

  it "drops a playbook's steps, but not a person's, when the lead is won" do
    lead.add_task({kind: "meeting", title: "Kick-off", due_at: 3.days.from_now}, user: user)
    lead.change_stage("won", user: user)

    expect(lead.tasks.pending.pluck(:title)).to eq(["Kick-off"])
    expect(lead.enrollments.first.status).to eq("stopped")
  end

  it "hands open steps to a new owner" do
    other = create(:user, email: "other@example.com")
    lead.revise({"owner_id" => other.id}, user: user)

    expect(lead.tasks.pending.pluck(:assignee_id).uniq).to eq([other.id])
  end

  it "reads when a step is due from the page's choices, mornings in the site's zone" do
    travel_to Time.zone.parse("2026-10-12 15:00 UTC") do
      expect(Leads::When.parse("1h")).to eq(Time.zone.parse("2026-10-12 16:00 UTC"))
      expect(Leads::When.parse("1d").in_time_zone(Site.time_zone).hour).to eq(9)
      expect(Leads::When.parse("whenever")).to be_nil
    end
  end

  it "lists what needs doing, overdue first" do
    travel 2.days do
      queue = Leads::Queue.new(user: user, whose: "mine")
      expect(queue.overdue.map(&:title)).to eq(["Call Jordan", "Second call"])
      expect(queue.count).to eq(2)
    end
  end
end
