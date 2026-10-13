# frozen_string_literal: true

module Leads
  module Api
    # The plugin's API (/api/leads…, listed in /api/manifest): a 404 while
    # it's off, every action declaring its capability.
    class BaseController < ::Api::BaseController
      include PluginGated
      plugin :leads
      enforce_authorization

      # Every controller under this one says who may call it, on any core:
      # cores before 1.32.3 turned that off for a plugin's controllers.
      def self.inherited(subclass)
        super
        subclass._skip_authorization = false
      end

      private

      def set_lead
        @lead = Lead.find(params[:api_lead_id] || params[:id])
      end
    end
  end
end
