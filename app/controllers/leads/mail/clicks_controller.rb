# frozen_string_literal: true

module Leads
  module Mail
    # A tracked link in a playbook's email (public, signed): noted on the
    # lead's timeline, then on to where it pointed. The URL is in the signed
    # token, so this never redirects anywhere else.
    class ClicksController < ActionController::Base
      def show
        message, url = Message.find_by_click_token(params[:token])
        return head(:not_found) unless url

        message.record_click(url) if Cms::Plugins.enabled?(:leads)
        redirect_to url, allow_other_host: true
      end
    end
  end
end
