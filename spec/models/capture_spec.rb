# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Capturing leads", type: :model do
  include ActiveJob::TestHelper

  let(:owner) { create(:user, name: "Sam Seller", email: "sam@example.com") }
  let(:playbook) { Leads::Playbook.create!(name: "Enquiries", trigger: "any", owner: owner) }

  def submission(id: 1, slug: "contact", data: {})
    {"id" => id, "form_slug" => slug, "form_title" => "Contact us",
     "data" => {"name" => "Jordan Reyes", "email" => "Jordan@Example.com", "phone" => "(555) 123-4567",
                "company" => "Acme", "message" => "40 units by May", "fleet_size" => "40"}.merge(data)}
  end

  before do
    switch_plugin :leads, on: true
    Leads::Playbook.destroy_all # the ones switching it on made
    playbook.steps.create!(action: "task", task_kind: "call", title: "Call {{first_name}}", delay_amount: 15, delay_unit: "minutes", skip_if_reached: false)
    playbook.steps.create!(action: "task", task_kind: "call", title: "Second call", delay_amount: 1, delay_unit: "days")
  end

  it "makes a lead from a form submission, owned and planned by its playbook" do
    lead = nil
    freeze_time do
      lead = Leads::Lead.capture_now("submission", submission)
    end

    expect(lead).to have_attributes(name: "Jordan Reyes", email: "jordan@example.com", phone_key: "5551234567", company: "Acme",
      stage: "new", source: "form", source_form: "contact", owner: owner, score: 10)
    expect(lead.fields).to eq("Message" => "40 units by May", "Fleet size" => "40")
    expect(lead.tasks.pending.in_due_order.map { [it.title, it.assignee_id] }).to eq([["Call Jordan", owner.id], ["Second call", owner.id]])
    expect(lead.next_task.due_at).to eq(lead.created_at + 15.minutes)
    expect(lead.activities.pluck(:kind)).to include("captured", "enrolled")
  end

  it "comes back to the same lead, by email or by phone, with a reply due" do
    lead = Leads::Lead.capture_now("submission", submission)
    again = Leads::Lead.capture_now("submission", submission(id: 2, data: {"email" => "", "phone" => "555.123.4567", "message" => "Any update?"}))

    expect(again).to eq(lead)
    expect(Leads::Lead.count).to eq(1)
    expect(lead.reload.score).to eq(25)
    expect(lead.tasks.pending.pluck(:title)).to include("Reply to their new message")
    expect(lead.fields["Message"]).to eq("Any update?")
  end

  it "opens a lost lead again, and keeps spam out of sight" do
    lead = Leads::Lead.capture_now("submission", submission)
    lead.change_stage("lost")
    Leads::Lead.capture_now("submission", submission(id: 2))
    expect(lead.reload.stage).to eq("new")

    lead.mark_spam
    expect { Leads::Lead.capture_now("submission", submission(id: 3)) }.not_to change { lead.reload.activities.count }
  end

  it "makes leads only from the chosen forms" do
    Leads::Settings.update("forms_mode" => "chosen", "forms" => ["quote-form"])

    expect(Leads::Lead.capture_now("submission", submission)).to be_nil
    expect(Leads::Lead.capture_now("submission", submission(slug: "quote-form"))).to be_present
  end

  it "ignores a submission that names nobody" do
    expect(Leads::Lead.capture_now("submission", submission(data: {"name" => "", "email" => "", "phone" => ""}))).to be_nil
  end

  it "makes a lead from a quote request, and moves it on with its invoice" do
    quotes = Leads::Playbook.create!(name: "Quotes", trigger: "quote")
    quotes.steps.create!(action: "task", task_kind: "email", title: "Send the quote", delay_amount: 1, delay_unit: "days")

    lead = Leads::Lead.capture_now("quote_request", {"id" => 7, "customer_name" => "Pat Buyer", "customer_email" => "pat@example.com",
      "items" => [{"name" => "Pallet racking", "quantity" => 4}], "message" => "Delivered to Ohio?"})

    expect(lead).to have_attributes(source: "quote", name: "Pat Buyer")
    expect(lead.fields).to include("Message" => "Delivered to Ohio?", "Items" => "4 × Pallet racking")
    expect(lead.tasks.pending.pluck(:title)).to eq(["Send the quote"])

    Leads::Lead.capture_now("invoice_quoted", {"customer_email" => "PAT@example.com", "number" => "INV-1"})
    expect(lead.reload.stage).to eq("quoted")
    Leads::Lead.capture_now("invoice_won", {"customer_email" => "pat@example.com", "number" => "INV-1"})
    expect(lead.reload.stage).to eq("won")
    expect(lead.tasks.pending).to be_empty
  end

  it "hears form submissions through the core's event, in a job" do
    expect {
      ActiveSupport::Notifications.instrument("submission.created.cms", event: "submission.created", data: submission.deep_symbolize_keys)
    }.to have_enqueued_job(Leads::Lead::CaptureJob).with("submission", hash_including("form_slug" => "contact"))
  end

  it "tells the owner and the addresses in Settings" do
    Leads::Settings.update("notify_emails" => "team@example.com")

    expect { Leads::Lead.capture_now("submission", submission) }
      .to have_enqueued_mail(Leads::AlertMailer, :alert)
    mail = Leads::AlertMailer.with(lead: Leads::Lead.last, event: "new").alert
    expect(mail.to).to contain_exactly("sam@example.com", "team@example.com")
    expect(mail.subject).to eq("New lead: Jordan Reyes (Contact us)")
    expect(mail.html_part&.body&.to_s || mail.body.to_s).to include("Call Jordan")
  end
end
