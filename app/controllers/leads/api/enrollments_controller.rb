# frozen_string_literal: true

module Leads
  module Api
    # POST /api/leads/:lead_id/enrollments {"enrollment": {"playbook_id": 1}}
    class EnrollmentsController < BaseController
      requires_capability "leads:write", only: :create

      before_action :set_lead

      def create
        playbook = Playbook.find(params.require(:enrollment)[:playbook_id])
        if (refusal = @lead.enrollment_refusal(playbook))
          render json: {error: "refused", message: refusal}, status: :unprocessable_content
        else
          @lead.enroll(playbook)
          @lead.reload
          render "leads/api/leads/show", status: :created
        end
      end
    end
  end
end
