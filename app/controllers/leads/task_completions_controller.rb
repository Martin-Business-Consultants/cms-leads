# frozen_string_literal: true

module Leads
  # Marking a task done — how it went and what's next (Task::Completion) —
  # and undoing it.
  class TaskCompletionsController < ApplicationController
    requires_capability "leads:write", only: [:create, :destroy]

    before_action :set_task

    def create
      completion = Task::Completion.new(@task, completion_params)
      if completion.save
        notice = completion.next_task ? "Done. Next: #{completion.next_task.title}" : "Done"
        redirect_to back_path, notice: notice
      else
        redirect_to back_path, alert: completion.errors.full_messages.to_sentence
      end
    end

    def destroy
      @task.reopen
      redirect_to back_path, notice: "“#{@task.title}” is open again"
    end

    private

    def set_task
      @task = Task.joins(:lead).merge(Lead.kept).find(params[:task_id])
    end

    def completion_params
      params.fetch(:completion, {}).permit(:result, :outcome, :next_kind, :next_title, :next_when, :next_due_at, :stage)
    end

    # Back to Needs you when it was done from there, else the lead.
    def back_path = params[:from] == "queue" ? leads_queue_path(whose: params[:whose].presence) : lead_path(@task.lead)
  end
end
