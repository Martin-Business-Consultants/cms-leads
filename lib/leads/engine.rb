# frozen_string_literal: true

module Leads
  # A CMS plugin (docs/plugins.md): it extends the core only through
  # Cms::Plugins and "<event>.cms" notifications, and the core never names it.
  class Engine < ::Rails::Engine
    initializer "leads.migrations" do |app|
      config.paths["db/migrate"].expanded.each { |path| app.config.paths["db/migrate"] << path }
    end

    initializer "leads.routes" do |app|
      app.routes.append do
        admin = proc do
          # Before `resources :leads`, so /leads/playbooks isn't read as a lead.
          scope "leads", module: "leads", as: "leads" do
            resource :queue, path: "needs-you", only: :show
            resources :playbooks, except: :show do
              resources :steps, only: [:new, :create, :edit, :update, :destroy]
              resource :test, only: :create, controller: "playbook_tests"
            end
            resources :templates, except: :show
            resources :guides, only: [:index, :show]
            resources :tasks, only: [:edit, :update, :destroy] do
              resource :completion, only: [:create, :destroy], controller: "task_completions"
            end
            resources :bulk_stage_changes, only: :create
            resources :bulk_deletions, only: :create
          end

          resources :leads, module: "leads", constraints: {id: /\d+/} do
            resources :notes, only: :create
            resources :tasks, only: :create
            resources :score_adjustments, only: :create
            resources :enrollments, only: [:create, :destroy]
            resources :drafts, only: :create
            resource :subscription, only: :create
          end

          scope "settings", as: "settings" do
            resource :leads, only: [:show, :update], controller: "leads/settings"
          end
        end
        defined?(Cms::PATH) ? scope(path: Cms::PATH, &admin) : admin.call

        # What a playbook's email links to: public, signed, at the root.
        scope "leads-mail/:token", module: "leads/mail", as: "leads_mail" do
          resource :open, only: :show
          resource :click, only: :show
          resource :unsubscribe, only: [:show, :create]
        end

        scope "api", defaults: {format: :json} do
          scope "leads", module: "leads/api", as: "api_leads" do
            resource :queue, path: "needs-you", only: :show
            resources :tasks, only: [:index, :update] do
              resource :completion, only: :create, controller: "task_completions"
            end
            resources :playbooks, only: [:index, :show]
            resources :templates, only: :index
            resource :settings, only: [:show, :update]
          end
          resources :leads, module: "leads/api", as: "api_leads", only: [:index, :show, :create, :update, :destroy],
            constraints: {id: /\d+/} do
            resources :notes, only: :create
            resources :tasks, only: :create
            resources :enrollments, only: :create
            resources :drafts, only: [:index, :create]
          end
        end
      end
    end

    # A form submission or a quote request becomes (or comes back to) its
    # lead, in a job so the visitor's request never waits on it; an invoice
    # sent or paid moves the lead it was for.
    initializer "leads.events" do
      {"submission.created.cms" => "submission", "quote_request.created.cms" => "quote_request"}.each do |event, kind|
        ActiveSupport::Notifications.subscribe(event) do |notification|
          next unless Cms::Plugins.enabled?(:leads)

          Leads::Lead.capture_later(kind, notification.payload[:data])
        end
      end

      {"invoice.sent.cms" => "quoted", "invoice.paid.cms" => "won"}.each do |event, stage|
        ActiveSupport::Notifications.subscribe(event) do |notification|
          next unless Cms::Plugins.enabled?(:leads)

          Leads::Lead.follow_invoice_later(notification.payload[:data], stage)
        end
      end
    end

    config.to_prepare do
      Cms::Plugins.register :leads, name: "Leads", version: Leads::VERSION, author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 1.30", homepage: "https://github.com/Martin-Business-Consultants/cms-leads",
        description: "Every enquiry from a form or a quote request becomes a lead with an owner and a next step. " \
                     "Playbooks plan the first steps, Needs you lists what's due, and replies, templates and " \
                     "follow-up emails help with the rest."

      Cms::Plugins.menu :leads, :leads, label: "Leads", icon: "person", group: "Content", after: [:forms, :globals],
        path: -> { leads_queue_path }, capability: "leads:read"
      Cms::Plugins.submenu :leads, :leads, label: "Needs you", path: -> { leads_queue_path }, capability: "leads:read"
      Cms::Plugins.submenu :leads, :leads, label: "All leads", path: -> { leads_path }, capability: "leads:read", after: "Needs you"
      Cms::Plugins.submenu :leads, :leads, label: "Add new", path: -> { new_lead_path }, capability: "leads:write", after: "All leads"
      Cms::Plugins.submenu :leads, :leads, label: "Playbooks", path: -> { leads_playbooks_path }, capability: "leads:playbooks", after: "Add new"
      Cms::Plugins.submenu :leads, :leads, label: "Templates", path: -> { leads_templates_path }, capability: "leads:read", after: "Playbooks"
      Cms::Plugins.submenu :leads, :leads, label: "Learning Center", path: -> { leads_guides_path }, capability: "leads:read", after: "Templates"
      Cms::Plugins.new_item :leads, label: "Lead", path: -> { new_lead_path }, capability: "leads:write"

      Cms::Plugins.permissions :leads, "Leads", %w[leads:read leads:write leads:delete leads:playbooks],
        after: ["Commerce", "Forms", "Globals"],
        defaults: {editor: %w[leads:read leads:write leads:delete leads:playbooks], author: %w[leads:read leads:write],
                   agent: %w[leads:read leads:write]}
      Cms::Plugins.settings :leads, "Leads", -> { settings_leads_path },
        description: "Who hears about new leads, the morning digest, which forms make leads, scoring and AI drafts.",
        capability: "settings:read"

      Cms::Plugins.slot :dashboard, :leads, "leads/slots/dashboard"
      Cms::Plugins.slot :nav_actions, :leads, "leads/slots/nav_actions"
      Cms::Plugins.stylesheet :leads, "leads/leads"

      Cms::Plugins.trashable :leads, "lead", "Leads::Lead", label: "Leads", meta: ->(lead) { {name: lead.display_name, stage: lead.stage} }
      Cms::Plugins.counts :leads, leads: -> { Leads::Lead.count }
      Cms::Plugins.webhook_events :leads, "Leads", %w[lead.created lead.stage_changed]

      Cms::Plugins.minutely :leads, :emails, -> { Leads::Enrollment.deliver_due_later }, every: 5
      Cms::Plugins.minutely :leads, :digest, -> { Leads::Digest.deliver_due_later }, every: 15
      Cms::Plugins.bootstrap :leads, -> { Leads::Playbook.seed_defaults! }

      Cms::Plugins.api :leads, "/api/leads/needs-you",
        description: "What's due now: overdue and today's tasks, open leads with no next step, hot leads (?whose=mine|everyone|unassigned)."
      Cms::Plugins.api :leads, "/api/leads",
        description: "Leads: list (?stage, ?q, ?owner), show with tasks and timeline, create, update (details, stage, owner), delete."
      Cms::Plugins.api :leads, "/api/leads/:id/tasks",
        description: "Add a next step to a lead: kind (call, email, text, meeting, todo), title, due_at or when (1h, 4h, 1d, 2d, 3d, 7d, 14d, 30d)."
      Cms::Plugins.api :leads, "/api/leads/tasks/:id/completion",
        description: "Finish a task: result (reached, no_answer, done), outcome, and the next step (next_kind, next_title, next_when) or a stage."
      Cms::Plugins.api :leads, "/api/leads/:id/notes", description: "Add a note to a lead's timeline."
      Cms::Plugins.api :leads, "/api/leads/:id/drafts", description: "AI-drafted replies for a lead: list them, or ask for new ones."
      Cms::Plugins.api :leads, "/api/leads/playbooks", description: "The playbooks and their steps; start one on a lead at /api/leads/:id/enrollments."
      Cms::Plugins.api :leads, "/api/leads/templates", description: "Email, text and call templates."
      Cms::Plugins.api :leads, "/api/leads/settings", description: "Settings › Leads (read with settings:read, change with settings:write)."
    end
  end
end
