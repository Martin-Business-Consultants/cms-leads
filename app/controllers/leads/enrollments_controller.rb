# frozen_string_literal: true

module Leads
  # Starting a playbook on a lead by hand, and stopping one.
  class EnrollmentsController < ApplicationController
    include LeadScoped

    requires_capability "leads:write", only: [:create, :destroy]

    def create
      playbook = Playbook.find(params.require(:enrollment)[:playbook_id])
      if (refusal = @lead.enrollment_refusal(playbook))
        redirect_to lead_path(@lead), alert: refusal
      else
        @lead.enroll(playbook)
        redirect_to lead_path(@lead), notice: "Started “#{playbook.name}”"
      end
    end

    def destroy
      enrollment = @lead.enrollments.find(params[:id])
      enrollment.stop(user: Current.user)
      redirect_to lead_path(@lead), notice: "Stopped “#{enrollment.playbook.name}”"
    end
  end
end
