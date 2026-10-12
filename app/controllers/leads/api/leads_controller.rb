# frozen_string_literal: true

module Leads
  module Api
    # /api/leads: list (?stage=open|all|<stage>, ?q, ?owner=me|none|<id>),
    # show (with its tasks, enrollments and timeline), create (a playbook
    # starts as for a lead from a form, unless playbook_id names another or
    # is false), update (details, stage, owner) and delete (to the trash).
    class LeadsController < BaseController
      requires_capability "leads:read", only: [:index, :show]
      requires_capability "leads:write", only: [:create, :update]
      requires_capability "leads:delete", only: :destroy

      before_action :set_lead, only: [:show, :update, :destroy]

      LIMIT = 100

      def index
        stage = params[:stage].presence_in(Lead::STAGES + %w[open all]) || "open"
        scope = Lead.includes(:owner)
        scope = scope.matching(params[:q]) if params[:q].present?
        scope = case stage
        when "open" then scope.open
        when "all" then scope.not_spam
        else scope.in_stage(stage)
        end
        scope = case params[:owner]
        when "me" then scope.owned_by(Current.user)
        when "none" then scope.where(owner_id: nil)
        when /\A\d+\z/ then scope.where(owner_id: params[:owner])
        else scope
        end
        @leads = scope.recent_first.limit(LIMIT)
      end

      def show
      end

      def create
        playbook = case params[:playbook_id]
        when nil, "" then nil
        when false, "false", "none" then false
        else Playbook.find(params[:playbook_id])
        end
        enquiry = Enquiry.from_params(lead_params.except(:owner_id, :stage), source: "api")
        @lead = Lead.new(source: "api", owner_id: lead_params[:owner_id].presence || Current.user&.id, stage: lead_params[:stage].presence || "new")
        @lead.assign_attributes(enquiry.contact)
        @lead.fields = enquiry.fields
        @lead.save!
        @lead.record_creation(playbook: playbook)
        render :show, status: :created
      end

      def update
        if @lead.revise(lead_params.except(:message))
          @lead.track_event(:updated, name: @lead.display_name)
          render :show
        else
          render json: {error: "invalid", errors: @lead.errors.as_json}, status: :unprocessable_content
        end
      end

      def destroy
        @lead.track_event(:deleted, name: @lead.display_name)
        @lead.discard!
        head :no_content
      end

      private

      def lead_params
        params.require(:lead).permit(:name, :email, :phone, :company, :stage, :owner_id, :message, fields: {})
      end
    end
  end
end
