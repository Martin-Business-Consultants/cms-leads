# frozen_string_literal: true

module Leads
  module Api
    # A lead's AI-drafted replies: GET the latest few, POST to ask for new
    # ones (written in the background: poll GET until state is ready).
    class DraftsController < BaseController
      requires_capability "leads:read", only: :index
      requires_capability "leads:write", only: :create

      before_action :set_lead

      def index
        @drafts = @lead.drafts.limit(5)
      end

      def create
        @draft = @lead.draft_replies_later(user: Current.user)
        if @draft
          render :show, status: :accepted
        else
          render json: {error: "unavailable", message: Leads::Draft::Writer.unavailable_reason}, status: :unprocessable_content
        end
      end
    end
  end
end
