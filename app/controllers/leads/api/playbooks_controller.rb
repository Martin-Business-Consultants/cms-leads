# frozen_string_literal: true

module Leads
  module Api
    # GET /api/leads/playbooks and /api/leads/playbooks/:id, with their steps.
    class PlaybooksController < BaseController
      requires_capability "leads:read", only: [:index, :show]

      def index
        @playbooks = Playbook.includes(:steps).ordered
      end

      def show
        @playbook = Playbook.find(params[:id])
      end
    end
  end
end
