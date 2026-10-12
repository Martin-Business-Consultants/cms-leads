# frozen_string_literal: true

module Leads
  # "Send me the emails": a playbook's email steps to the person asking, now.
  class PlaybookTestsController < ApplicationController
    requires_capability "leads:playbooks", only: :create

    def create
      playbook = Playbook.find(params[:playbook_id])
      sent = playbook.send_test(to: Current.user)
      notice = sent.zero? ? "“#{playbook.name}” has no emails to send" : "Sent #{helpers.pluralize(sent, "email")} to #{Current.user.email}"
      redirect_to edit_leads_playbook_path(playbook), notice: notice
    end
  end
end
