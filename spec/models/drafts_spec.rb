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

  def respond_with(status, body)
    response = Net::HTTPResponse::CODE_TO_OBJ[status.to_s].new("1.1", status.to_s, "")
    allow(response).to receive(:body).and_return(JSON.generate(body))
    allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, request|
      @request = request
      response
    end
  end

  before do
    switch_plugin :leads, on: true
    Leads::Settings.update("anthropic_api_key" => "sk-ant-test")
  end

  it "asks Claude for the replies in a fixed shape and keeps them" do
    respond_with(200, {"stop_reason" => "end_turn", "content" => [{"type" => "text", "text" => JSON.generate(answer)}]})
    draft = Leads::Draft.create!(lead: lead)

    draft.write_now

    expect(draft.reload).to have_attributes(state: "ready", summary: "Jordan needs 40 units by May.")
    body = JSON.parse(@request.body)
    expect(body).to include("model" => "claude-opus-5-5", "fallbacks" => "default")
    expect(body.dig("output_config", "format", "type")).to eq("json_schema")
    expect(body.dig("messages", 0, "content")).to include("40 units by May")
    expect(@request["x-api-key"]).to eq("sk-ant-test")
    expect(lead.activities.find_by(kind: "drafted")).to be_present
  end

  it "says why when Anthropic refuses the key" do
    respond_with(401, {"error" => {"message" => "invalid x-api-key"}})
    draft = Leads::Draft.create!(lead: lead)

    draft.write_now

    expect(draft.reload).to have_attributes(state: "failed", error: "Anthropic didn't accept the API key in Settings › Leads")
  end

  it "isn't offered without a key" do
    Leads::Settings.update("remove_ai_key" => "1")

    expect(Leads::Draft.available?).to be(false)
    expect(lead.draft_replies_later).to be_nil
  end
end
