# frozen_string_literal: true

module Leads
  # All leads (a stage, an owner, a search), one lead's page, adding one by
  # hand, editing its details, and moving it to the trash.
  class LeadsController < ApplicationController
    requires_capability "leads:read", only: [:index, :show]
    requires_capability "leads:write", only: [:new, :create, :edit, :update]
    requires_capability "leads:delete", only: :destroy

    before_action :set_lead, only: [:show, :edit, :update, :destroy]

    def index
      @stage = params[:stage].presence_in(Lead::STAGES + %w[open all]) || "open"
      @owner = params[:owner].presence
      scope = Lead.includes(:owner)
      scope = scope.matching(search_term) if search_term
      @counts = scope.group(:stage).count
      scope = case @stage
      when "open" then scope.open
      when "all" then scope.not_spam
      else scope.in_stage(@stage)
      end
      scope = filter_by_owner(scope)
      @leads = paginate(scope.recent_first)
      @next_tasks = Task.pending.where(lead_id: @leads.map(&:id)).in_due_order.group_by(&:lead_id).transform_values(&:first)
    end

    def show
      @tasks = @lead.tasks.pending.in_due_order.includes(:assignee)
      @next_task = @tasks.first
      @activities = @lead.activities.includes(:user).limit(100)
      @enrollments = @lead.enrollments.includes(:playbook).newest_first
      @draft = @lead.latest_draft
      Template.seed_defaults!
      @templates = Template.ordered.to_a
    end

    def new
      @lead = Lead.new(source: "manual", owner_id: Current.user.id)
    end

    def create
      playbook = chosen_playbook
      enquiry = Enquiry.from_params(lead_params.except(:owner_id, :stage, :playbook_id))
      @lead = Lead.new(source: "manual", owner_id: lead_params[:owner_id].presence, stage: lead_params[:stage].presence || "new")
      @lead.assign_attributes(enquiry.contact)
      @lead.fields = enquiry.fields
      if @lead.save
        @lead.record_creation(playbook: playbook)
        redirect_to lead_path(@lead), notice: "Added #{@lead.display_name}"
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @lead.revise(lead_params.except(:playbook_id, :message))
        @lead.track_event(:updated, name: @lead.display_name)
        redirect_to lead_path(@lead), notice: "Saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @lead.track_event(:deleted, name: @lead.display_name)
      @lead.discard!
      redirect_to leads_path, notice: "#{@lead.display_name} moved to the trash"
    end

    private

    def set_lead
      @lead = Lead.find(params[:id])
    end

    def lead_params
      params.require(:lead).permit(:name, :email, :phone, :company, :stage, :owner_id, :playbook_id, :message)
    end

    # The playbook "Add new" asked for: "" for the one that matches, "none"
    # for none.
    def chosen_playbook
      case lead_params[:playbook_id].presence
      when nil then nil
      when "none" then false
      else Playbook.find(lead_params[:playbook_id])
      end
    end

    def filter_by_owner(scope)
      case @owner
      when "me" then scope.owned_by(Current.user)
      when "none" then scope.where(owner_id: nil)
      when /\A\d+\z/ then scope.where(owner_id: @owner)
      else scope
      end
    end
  end
end
