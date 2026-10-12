# frozen_string_literal: true

module Leads
  # A lead's tasks: adding the next step (/leads/:lead_id/tasks), and
  # changing or deleting one (/leads/tasks/:id).
  class TasksController < ApplicationController
    requires_capability "leads:write", only: [:create, :edit, :update, :destroy]

    before_action :set_task, only: [:edit, :update, :destroy]

    def create
      @lead = Lead.find(params[:lead_id])
      task = @lead.add_task(task_attributes)
      if task.persisted?
        redirect_to lead_path(@lead), notice: "Next step: #{task.title}"
      else
        redirect_to lead_path(@lead), alert: task.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    def update
      if @task.update(task_attributes)
        redirect_to lead_path(@task.lead), notice: "Saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @task.lead.drop_tasks([@task], reason: "deleted", user: Current.user)
      redirect_to lead_path(@task.lead), notice: "Dropped “#{@task.title}”"
    end

    private

    def set_task
      @task = Task.joins(:lead).merge(Lead.kept).find(params[:id])
    end

    def task_attributes
      attributes = params.require(:task).permit(:kind, :title, :notes, :due_at, :when, :assignee_id)
      choice = attributes.delete(:when)
      attributes[:due_at] = When.parse(choice) if attributes[:due_at].blank? && choice.present?
      attributes[:assignee_id] = attributes[:assignee_id].presence
      attributes
    end
  end
end
