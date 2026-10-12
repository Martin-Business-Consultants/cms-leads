# frozen_string_literal: true

module Leads
  module Api
    # POST /api/leads/:lead_id/notes {"note": {"body": "…"}}
    class NotesController < BaseController
      requires_capability "leads:write", only: :create

      before_action :set_lead

      def create
        @activity = @lead.add_note(params.require(:note)[:body])
        render :create, status: :created
      rescue ArgumentError => error
        render json: {error: "invalid", message: error.message}, status: :unprocessable_content
      end
    end
  end
end
