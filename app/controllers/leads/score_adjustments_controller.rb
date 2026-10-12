# frozen_string_literal: true

module Leads
  # Points added to or taken from a lead's score by hand, with a reason.
  class ScoreAdjustmentsController < ApplicationController
    include LeadScoped

    requires_capability "leads:write", only: :create

    def create
      adjustment = params.require(:score_adjustment)
      @lead.adjust_score(adjustment[:points], reason: adjustment[:reason])
      redirect_to lead_path(@lead), notice: "Score is #{@lead.reload.score}"
    rescue ArgumentError => error
      redirect_to lead_path(@lead), alert: error.message
    end
  end
end
