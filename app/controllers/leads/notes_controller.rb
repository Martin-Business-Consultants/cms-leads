# frozen_string_literal: true

module Leads
  # A note on a lead's timeline.
  class NotesController < ApplicationController
    include LeadScoped

    requires_capability "leads:write", only: :create

    def create
      @lead.add_note(params.require(:note)[:body])
      redirect_to lead_path(@lead, anchor: "timeline"), notice: "Note added"
    rescue ArgumentError => error
      redirect_to lead_path(@lead, anchor: "timeline"), alert: error.message
    end
  end
end
