# frozen_string_literal: true

# A controller nested under a lead (/leads/:lead_id/…) loads it first.
module Leads::LeadScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_lead
  end

  private

  def set_lead
    @lead = Leads::Lead.find(params[:lead_id])
  end
end
