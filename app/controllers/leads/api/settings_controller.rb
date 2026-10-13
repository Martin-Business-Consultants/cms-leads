# frozen_string_literal: true

module Leads
  module Api
    # GET and PATCH /api/leads/settings: Settings › Leads. Drafts come from
    # the AI plugin (Settings › AI): ai_available says whether it's set up.
    class SettingsController < BaseController
      requires_capability "settings:read", only: :show
      requires_capability "settings:write", only: :update

      def show
        @settings = Leads::Settings.current
      end

      def update
        @settings = Leads::Settings.update(params.require(:settings).permit(:notify_owner, :digest_hour, :default_owner_id,
          :forms_mode, :hot_threshold, :ai_drafts,
          notify_emails: [], forms: [], points: {}).to_h)
        Event.record("settings.leads_updated")
        render :show
      end
    end
  end
end
