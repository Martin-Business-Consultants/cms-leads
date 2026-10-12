# frozen_string_literal: true

module Leads
  module Api
    # The plugin's API (/api/leads…, listed in /api/manifest): a 404 while
    # it's off, every action declaring its capability.
    class BaseController < ::Api::BaseController
      include PluginGated
      plugin :leads
      enforce_authorization

      private

      def set_lead
        @lead = Lead.find(params[:api_lead_id] || params[:id])
      end
    end
  end
end
