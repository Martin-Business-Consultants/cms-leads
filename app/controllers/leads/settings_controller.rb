# frozen_string_literal: true

module Leads
  # Settings › Leads (Leads::Settings).
  class SettingsController < ::Settings::BaseController
    include PluginGated
    plugin :leads

    requires_capability "settings:read", only: :show
    requires_capability "settings:write", only: :update

    def show
      @settings = Leads::Settings.current
      @forms = defined?(::Form) ? ::Form.order(:title).to_a : []
      @people = ::User.order(:name).to_a
    end

    def update
      Leads::Settings.update(params.require(:leads).permit(:notify_emails, :notify_owner, :digest_hour, :default_owner_id,
        :forms_mode, :hot_threshold, :ai_drafts, :ai_model, :anthropic_api_key, :remove_ai_key, forms: [], points: {}))
      Event.record("settings.leads_updated")
      redirect_to settings_leads_path, notice: "Saved"
    end
  end
end
