# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Leads", type: :request do
  let(:admin) { create(:user, name: "Sam Seller") }
  let!(:lead) { Leads::Lead.create!(name: "Jordan Reyes", email: "jordan@example.com", phone: "555 123 4567", owner: admin) }
  let!(:task) { lead.add_task({kind: "call", title: "Call Jordan", due_at: 1.hour.ago}, user: admin) }

  def api_headers(user) = {"Authorization" => "Bearer #{user.api_token!.token}", "Accept" => "application/json"}

  before { switch_plugin :leads, on: true }

  it "is a 404 while the plugin is off" do
    switch_plugin :leads, on: false
    sign_in_as admin

    get leads_queue_path
    expect(response).to have_http_status(:not_found)
  end

  describe "the admin" do
    before { sign_in_as admin }

    it "shows every screen" do
      playbook = Leads::Playbook.first
      [leads_queue_path, leads_path, lead_path(lead), new_lead_path, edit_lead_path(lead), edit_leads_task_path(task),
        leads_playbooks_path, edit_leads_playbook_path(playbook), new_leads_playbook_step_path(playbook, step_action: "email"),
        leads_templates_path, new_leads_template_path, leads_guides_path, leads_guide_path("first-call"), settings_leads_path,
        dashboard_path].each do |path|
        get path
        expect(response).to have_http_status(:ok), "#{path}: #{response.status}"
      end
    end

    it "lists what's overdue in Needs you, and counts it in the admin bar" do
      get leads_queue_path(whose: "mine")

      expect(response.body).to include("Overdue").and(include("Call Jordan")).and(include("1 lead needs you"))
    end

    it "starts the editor with the lead's name, not an Edit heading" do
      get edit_lead_path(lead)

      expect(response.body).to include('class="title-input"')
      expect(response.body).not_to include("Edit Lead")
    end

    it "finishes a task with how it went and what's next" do
      post leads_task_completion_path(task, from: "queue"), params: {completion: {result: "reached", outcome: "Wants a quote",
        next_kind: "email", next_title: "Send the quote", next_when: "1d"}}

      expect(response).to redirect_to(leads_queue_path)
      expect(lead.reload.stage).to eq("contacted")
      expect(lead.next_task.title).to eq("Send the quote")
    end

    it "adds a lead by hand, with the playbook that matches" do
      expect {
        post leads_path, params: {lead: {name: "Pat Buyer", email: "pat@example.com", message: "Called about racking",
                                         owner_id: admin.id, stage: "new", playbook_id: ""}}
      }.to change(Leads::Lead, :count).by(1)

      added = Leads::Lead.find_by(email: "pat@example.com")
      expect(response).to redirect_to(lead_path(added))
      expect(added.fields).to eq("Message" => "Called about racking")
      expect(added.tasks.pending).not_to be_empty
    end

    it "moves leads to a stage, and to the trash, in bulk" do
      post leads_bulk_stage_changes_path, params: {ids: [lead.id], status: "qualified"}
      expect(lead.reload.stage).to eq("qualified")

      post leads_bulk_deletions_path, params: {ids: [lead.id]}
      expect(Leads::Lead.find_by(id: lead.id)).to be_nil
      expect(Leads::Lead.with_discarded.find(lead.id)).to be_discarded
    end

    it "saves Settings › Leads" do
      patch settings_leads_path, params: {leads: {notify_emails: "a@example.com, nope", notify_owner: "0", digest_hour: "",
                                                  forms_mode: "all", hot_threshold: "40"}}

      settings = Leads::Settings.current
      expect(settings).to have_attributes(notify_emails: ["a@example.com"], notify_owner?: false, digest_hour: nil, hot_threshold: 40)
    end

    it "refuses a role without the capability" do
      reader = create(:user, admin: false, role: create(:role, name: "Reader", permissions: %w[leads:read]))
      sign_in_as reader

      expect { post lead_notes_path(lead), params: {note: {body: "Hi"}} }.not_to change { lead.activities.count }
      expect(flash[:alert]).to eq("You don't have permission to do that.")
    end
  end

  describe "the API" do
    it "lists what needs doing" do
      get api_leads_queue_path(whose: "everyone"), headers: api_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["overdue"].first).to include("title" => "Call Jordan", "overdue" => true)
    end

    it "creates a lead, gives it a next step and finishes it" do
      post api_leads_path, params: {lead: {name: "Pat Buyer", email: "pat@example.com", message: "Needs racking"}, playbook_id: false},
        headers: api_headers(admin), as: :json
      expect(response).to have_http_status(:created)
      id = response.parsed_body.dig("lead", "id")
      expect(response.parsed_body.dig("lead", "needs_next_step")).to be(true)

      post api_lead_tasks_path(id), params: {task: {kind: "call", title: "Call Pat", when: "1h"}}, headers: api_headers(admin), as: :json
      expect(response).to have_http_status(:created)
      task_id = response.parsed_body.dig("task", "id")

      post api_leads_task_completion_path(task_id), params: {completion: {result: "reached", stage: "qualified"}},
        headers: api_headers(admin), as: :json
      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("lead", "stage")).to eq("qualified")
    end

    it "updates a lead's stage and adds a note" do
      patch api_lead_path(lead), params: {lead: {stage: "quoted"}}, headers: api_headers(admin), as: :json
      expect(response.parsed_body.dig("lead", "stage")).to eq("quoted")

      post api_lead_notes_path(lead), params: {note: {body: "Sent the PDF"}}, headers: api_headers(admin), as: :json
      expect(response).to have_http_status(:created)
    end

    it "is listed in the manifest for agents" do
      get "/api/manifest", headers: api_headers(admin)

      endpoints = response.parsed_body["plugins"].find { it["key"] == "leads" }["endpoints"].map { it["path"] }
      expect(endpoints).to include("/api/leads/needs-you", "/api/leads")
    end
  end

  describe "an email's links" do
    it "unsubscribes in one click, from a mail client too" do
      token = lead.unsubscribe_token

      get leads_mail_unsubscribe_path(token: token)
      expect(response).to have_http_status(:ok)
      post leads_mail_unsubscribe_path(token: token), params: {"List-Unsubscribe" => "One-Click"}
      expect(response).to have_http_status(:ok)
      expect(lead.reload).to be_unsubscribed
    end

    it "turns a forged token away" do
      get leads_mail_unsubscribe_path(token: "forged")
      expect(response).to have_http_status(:not_found)

      get leads_mail_click_path(token: "forged")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the morning digest" do
    it "goes once a day, after its hour, to whoever has something due" do
      Leads::Settings.update("digest_hour" => "8")

      travel_to Site.time_zone.parse("#{Date.tomorrow} 07:30") do
        expect(Leads::Digest.deliver_due_now).to eq(0)
      end
      travel_to Site.time_zone.parse("#{Date.tomorrow} 08:05") do
        expect(Leads::Digest.deliver_due_now).to eq(1)
        expect(Leads::Digest.deliver_due_now).to eq(0)
      end
    end
  end
end
