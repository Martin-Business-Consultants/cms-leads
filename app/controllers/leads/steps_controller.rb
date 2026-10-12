# frozen_string_literal: true

module Leads
  # A playbook's steps: a task for a person, or an email that sends itself.
  class StepsController < ApplicationController
    requires_capability "leads:playbooks", only: [:new, :create, :edit, :update, :destroy]

    before_action :set_playbook
    before_action :set_step, only: [:edit, :update, :destroy]

    def new
      @step = @playbook.steps.new(action: params[:step_action].presence_in(Step::ACTIONS.keys) || "task", delay_amount: 1, delay_unit: "days")
    end

    def create
      @step = @playbook.steps.new(step_params)
      if @step.save
        redirect_to edit_leads_playbook_path(@playbook), notice: "Step added"
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @step.update(step_params)
        redirect_to edit_leads_playbook_path(@playbook), notice: "Step saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @step.destroy!
      redirect_to edit_leads_playbook_path(@playbook), notice: "Step deleted"
    end

    private

    def set_playbook
      @playbook = Playbook.find(params[:playbook_id])
    end

    def set_step
      @step = @playbook.steps.find(params[:id])
    end

    def step_params
      params.require(:step).permit(:action, :task_kind, :title, :subject, :body, :delay_amount, :delay_unit, :skip_if_reached)
    end
  end
end
