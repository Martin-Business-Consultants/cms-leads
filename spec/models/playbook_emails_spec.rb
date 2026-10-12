# frozen_string_literal: true

require "rails_helper"

RSpec.describe "A playbook's emails", type: :model do
  include ActionMailer::TestHelper

  let(:playbook) { Leads::Playbook.create!(name: "Nurture", trigger: "manual") }
  let(:lead) { Leads::Lead.create!(name: "Jordan Reyes", email: "jordan@example.com") }

  before do
    switch_plugin :leads, on: true
    playbook.steps.create!(action: "email", subject: "Hi {{first_name}}", body: "Thanks for asking.\n\nMore at https://example.com/guide",
      delay_amount: 0, delay_unit: "hours")
    playbook.steps.create!(action: "email", subject: "Still there?", body: "Checking in.", delay_amount: 2, delay_unit: "days")
  end

  it "sends each email at its moment, once, with tracked links and an unsubscribe link" do
    enrollment = lead.enroll(playbook)

    expect(enrollment.deliver_now).to be(true)
    expect(enrollment.deliver_now).to be(false)
    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to eq("Hi Jordan")
    expect(mail["List-Unsubscribe-Post"].to_s).to eq("List-Unsubscribe=One-Click")
    html = mail.html_part.body.to_s
    expect(html).to include("/leads-mail/").and(include("Unsubscribe"))
    expect(html).not_to include('href="https://example.com/guide"')
    expect(enrollment.reload.next_send_at).to be_within(1.minute).of(enrollment.started_at + 2.days)
    expect(lead.activities.find_by(kind: "email_sent").summary).to eq("Sent “Hi Jordan”")
  end

  it "skips an email meant for someone not reached, once they have been" do
    enrollment = lead.enroll(playbook)
    enrollment.deliver_now
    lead.mark_reached

    travel 3.days do
      expect { enrollment.reload.deliver_now }.not_to change { ActionMailer::Base.deliveries.size }
      expect(enrollment.reload.status).to eq("completed")
    end
  end

  it "stops when the lead unsubscribes" do
    enrollment = lead.enroll(playbook)
    lead.unsubscribe

    expect(enrollment.reload.status).to eq("stopped")
    expect(enrollment.deliver_now).to be(false)
  end

  it "counts opens and clicks once each, and only goes where the email said" do
    enrollment = lead.enroll(playbook)
    enrollment.deliver_now
    message = lead.messages.last

    message.record_click("https://example.com/guide")
    message.record_open
    expect(lead.reload.score).to eq(4)
    expect(Leads::Message.find_by_click_token(message.click_token("https://example.com/guide")).last).to eq("https://example.com/guide")
    expect(Leads::Message.find_by_click_token("forged")).to be_nil
  end

  it "sends someone on the team every email as a test, changing no lead" do
    user = create(:user, name: "Sam Seller")

    expect(playbook.send_test(to: user)).to eq(2)
    perform_enqueued_jobs
    expect(ActionMailer::Base.deliveries.map(&:subject)).to include("[Test] Hi Sam")
    expect(Leads::Message.count).to eq(0)
  end
end
