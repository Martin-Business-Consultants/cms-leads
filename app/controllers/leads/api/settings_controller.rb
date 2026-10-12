# frozen_string_literal: true

module Leads
  module Api
    # GET and PATCH /api/leads/settings: Settings › Leads. The Anthropic key
    # is write-only: it reads back as ai_key_set.
    class SettingsController < BaseController
      requires_capability "settings:read", only: :show
      requires_capability "settings:write", only: :update

      def show
        @settings = Leads::Settings.current
      end

      def update
        @settings = Leads::Settings.update(params.require(:settings).permit(:notify_owner, :digest_hour, :default_owner_id,
          :forms_mode, :hot_threshold, :ai_drafts, :ai_model, :anthropic_api_key, :remove_ai_key,
          notify_emails: [], forms: [], points: {}).to_h)
        Event.record("settings.leads_updated")
        render :show
      end
    end
  end
end
