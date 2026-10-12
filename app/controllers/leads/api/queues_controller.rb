# frozen_string_literal: true

module Leads
  module Api
    # GET /api/leads/needs-you?whose=mine|everyone|unassigned
    class QueuesController < BaseController
      requires_capability "leads:read", only: :show

      def show
        @queue = Queue.new(user: Current.user, whose: params[:whose])
      end
    end
  end
end
