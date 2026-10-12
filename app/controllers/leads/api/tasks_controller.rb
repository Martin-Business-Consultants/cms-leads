# frozen_string_literal: true

module Leads
  module Api
    # Tasks: what's open across leads (GET /api/leads/tasks?whose=…&due=
    # overdue|today|week), a lead's next step (POST /api/leads/:lead_id/tasks,
    # with due_at or when: 1h, 4h, 1d, 2d, 3d, 7d, 14d, 30d), and changing
    # one (PATCH /api/leads/tasks/:id). Finishing one is its completion.
    class TasksController < BaseController
      requires_capability "leads:read", only: :index
      requires_capability "leads:write", only: [:create, :update]

      before_action :set_lead, only: :create
      before_action :set_task, only: :update

      def index
        queue = Queue.new(user: Current.user, whose: params[:whose].presence || "everyone")
        @tasks = case params[:due]
        when "overdue" then queue.overdue
        when "today" then queue.today
        when "week" then queue.coming_up
        else Task.on_kept_leads.pending.includes(:lead, :assignee).in_due_order.limit(Queue::LIMIT)
        end
      end

      def create
        @task = @lead.add_task(task_attributes)
        if @task.persisted?
          render :show, status: :created
        else
          render json: {error: "invalid", errors: @task.errors.as_json}, status: :unprocessable_content
        end
      end

      def update
        if @task.update(task_attributes)
          render :show
        else
          render json: {error: "invalid", errors: @task.errors.as_json}, status: :unprocessable_content
        end
      end

      private

      def set_task
        @task = Task.on_kept_leads.find(params[:id])
      end

      def task_attributes
        attributes = params.require(:task).permit(:kind, :title, :notes, :due_at, :when, :assignee_id)
        choice = attributes.delete(:when)
        attributes[:due_at] = When.parse(choice) if attributes[:due_at].blank? && choice.present?
        attributes
      end
    end
  end
end
