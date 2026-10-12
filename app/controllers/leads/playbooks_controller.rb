# frozen_string_literal: true

module Leads
  # Playbooks: what happens when each kind of lead comes in.
  class PlaybooksController < ApplicationController
    requires_capability "leads:read", only: :index
    requires_capability "leads:playbooks", only: [:new, :create, :edit, :update, :destroy]

    before_action :set_playbook, only: [:edit, :update, :destroy]

    def index
      @playbooks = Playbook.includes(:steps, :owner).ordered
      @active_counts = Enrollment.active.group(:playbook_id).count
    end

    def new
      @playbook = Playbook.new(trigger: "any_form")
    end

    def create
      @playbook = Playbook.new(playbook_params)
      if @playbook.save
        redirect_to edit_leads_playbook_path(@playbook), notice: "Playbook added: now give it its steps"
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @playbook.update(playbook_params)
        redirect_to edit_leads_playbook_path(@playbook), notice: "Saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @playbook.destroy!
      redirect_to leads_playbooks_path, notice: "“#{@playbook.name}” deleted"
    end

    private

    def set_playbook
      @playbook = Playbook.find(params[:id])
    end

    def playbook_params
      params.require(:playbook).permit(:name, :active, :trigger, :trigger_form, :owner_id)
    end
  end
end
