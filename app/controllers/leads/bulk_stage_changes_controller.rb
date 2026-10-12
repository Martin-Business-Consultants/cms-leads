# frozen_string_literal: true

module Leads
  # Moving the ticked leads to one stage (All leads' bulk actions).
  class BulkStageChangesController < ApplicationController
    requires_capability "leads:write", only: :create

    def create
      stage = params[:status].presence_in(Lead::STAGES)
      return redirect_back_or_to(leads_path, alert: "Choose a stage") unless stage

      leads = Lead.where(id: Array(params[:ids]))
      moved = leads.count { it.change_stage(stage) }
      redirect_back_or_to leads_path, notice: "Moved #{helpers.pluralize(moved, "lead")} to #{stage.humanize.downcase}"
    end
  end
end
