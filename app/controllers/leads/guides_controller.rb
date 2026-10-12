# frozen_string_literal: true

module Leads
  # The Learning Center: short guides on turning an enquiry into a sale.
  class GuidesController < ApplicationController
    requires_capability "leads:read", only: [:index, :show]

    def index
      @guides = Guide.all
    end

    def show
      @guide = Guide.find(params[:id])
    end
  end
end
