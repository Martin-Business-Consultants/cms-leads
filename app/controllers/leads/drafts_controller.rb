# frozen_string_literal: true

module Leads
  # Asking Claude for a lead's replies (Leads::Draft), written in the
  # background; the lead's page shows them when they're ready.
  class DraftsController < ApplicationController
    include LeadScoped

    requires_capability "leads:write", only: :create

    def create
      if @lead.draft_replies_later(user: Current.user)
        redirect_to lead_path(@lead, anchor: "replies"), notice: "Drafting replies: they’ll be here in a moment"
      else
        redirect_to lead_path(@lead, anchor: "replies"), alert: "Add an Anthropic API key in Settings › Leads to draft replies"
      end
    end
  end
end
