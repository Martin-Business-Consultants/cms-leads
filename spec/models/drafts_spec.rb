# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Drafted replies", type: :model do
  let(:lead) { Leads::Lead.create!(name: "Jordan Reyes", email: "jordan@example.com", fields: {"Message" => "40 units by May"}) }
  let(:answer) do
    {"summary" => "Jordan needs 40 units by May.",
     "next_step" => {"kind" => "call", "title" => "Call Jordan about May delivery", "when" => "1h", "why" => "They're on a deadline"},
     "email" => {"subject" => "Your 40 units", "body" => "Hi Jordan,\n\nWe can help.\n\n{{my_name}}"},
     "text" => "Hi Jordan, can we talk about May?",
     "call" => {"opening" => "Hi Jordan", "questions" => ["Which sites?"], "objections" => [{"objection" => "Price", "answer" => "Value"}]}}
  end

  before do
    switch_plugin :leads, on: true
    switch_plugin :ai, on: true
    Ai::Settings.update("provider" => "opencode", "api_key" => "zen-key")
  end

  it "asks the AI plugin for the replies in a fixed shape and keeps them" do
    asked = nil
    allow(Ai).to receive(:structured) { |**request| asked = request; answer }
    draft = Leads::Draft.create!(lead: lead)

    draft.write_now

    expect(draft.reload).to have_attributes(state: "ready", summary: "Jordan needs 40 units by May.")
    expect(asked).to include(purpose: "leads_draft", schema: Leads::Draft::Writer::SCHEMA)
    expect(asked[:prompt]).to include("40 units by May")
    expect(lead.activities.find_by(kind: "drafted")).to be_present
  end

  it "says why when the provider refuses" do
    allow(Ai).to receive(:structured).and_raise(Ai::Error, "OpenCode Zen didn't accept the key in Settings › AI")
    draft = Leads::Draft.create!(lead: lead)

    draft.write_now

    expect(draft.reload).to have_attributes(state: "failed", error: "OpenCode Zen didn't accept the key in Settings › AI")
  end

  it "isn't offered until the AI plugin is set up" do
    Ai::Settings.update("remove_api_key" => "1")

    expect(Leads::Draft.available?).to be(false)
    expect(Leads::Settings.current.ai_drafts?).to be(false)
    expect(lead.draft_replies_later).to be_nil
    expect(Leads::Draft::Writer.unavailable_reason).to include("Settings › AI")
  end
end
