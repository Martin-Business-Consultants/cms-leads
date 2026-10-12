# frozen_string_literal: true

module Leads
  # Needs you: what to do about leads now (Leads::Queue), mine or everyone's.
  class QueuesController < ApplicationController
    requires_capability "leads:read", only: :show

    def show
      @queue = Queue.new(user: Current.user, whose: params[:whose])
    end
  end
end
