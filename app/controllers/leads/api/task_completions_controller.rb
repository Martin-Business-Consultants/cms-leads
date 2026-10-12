# frozen_string_literal: true

module Leads
  module Api
    # POST /api/leads/tasks/:task_id/completion {"completion": {"result":
    # "reached|no_answer|done", "outcome": "…", "next_kind": "call",
    # "next_title": "…", "next_when": "2d", "stage": "qualified"}}
    class TaskCompletionsController < BaseController
      requires_capability "leads:write", only: :create

      def create
        @task = Task.on_kept_leads.find(params[:task_id])
        return render(json: {error: "already_finished", message: "That task is already done or dropped"}, status: :conflict) unless @task.pending?

        completion = Task::Completion.new(@task, params.fetch(:completion, {}).permit(:result, :outcome, :next_kind, :next_title,
          :next_when, :next_due_at, :stage).to_h)
        if completion.save
          @lead = @task.lead.reload
          render "leads/api/leads/show", status: :created
        else
          render json: {error: "invalid", errors: completion.errors.as_json}, status: :unprocessable_content
        end
      end
    end
  end
end
