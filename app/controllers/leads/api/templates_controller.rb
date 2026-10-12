# frozen_string_literal: true

module Leads
  module Api
    # GET /api/leads/templates?kind=email|text|call
    class TemplatesController < BaseController
      requires_capability "leads:read", only: :index

      def index
        Template.seed_defaults!
        @templates = Template.ordered
        @templates = @templates.of_kind(params[:kind]) if params[:kind].present?
      end
    end
  end
end
