# frozen_string_literal: true

module Leads
  # Putting a lead that unsubscribed back on the emails, because it asked.
  class SubscriptionsController < ApplicationController
    include LeadScoped

    requires_capability "leads:write", only: :create

    def create
      @lead.resubscribe
      redirect_to lead_path(@lead), notice: "#{@lead.display_name} gets emails again"
    end
  end
end
