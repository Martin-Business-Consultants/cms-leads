# frozen_string_literal: true

module Leads
  # Moving the ticked leads to the trash (All leads' bulk actions).
  class BulkDeletionsController < ApplicationController
    requires_capability "leads:delete", only: :create

    def create
      leads = Lead.where(id: Array(params[:ids])).to_a
      leads.each do |lead|
        lead.track_event(:deleted, name: lead.display_name)
        lead.discard!
      end
      redirect_back_or_to leads_path, notice: "#{helpers.pluralize(leads.size, "lead")} moved to the trash"
    end
  end
end
