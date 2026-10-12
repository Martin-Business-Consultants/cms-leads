# frozen_string_literal: true

module Leads
  module Mail
    # Leaving a lead's emails (public, signed by the lead's token), even with
    # the plugin off. The page asks with one button; a mail client's one-click
    # unsubscribe (List-Unsubscribe-Post, RFC 8058) posts straight here
    # without a CSRF token. A link scanner fetching the page changes nothing.
    # Not the admin's controller: mail clients and providers aren't modern
    # browsers, and nobody here is signed in.
    class UnsubscribesController < ActionController::Base
      skip_forgery_protection only: :create

      layout "public"

      before_action :set_lead

      def show
      end

      def create
        @lead.unsubscribe
        if params["List-Unsubscribe"].present?
          head :ok
        else
          redirect_to leads_mail_unsubscribe_path(token: params[:token]), status: :see_other
        end
      end

      private

      def set_lead
        @lead = Lead.find_by_unsubscribe_token(params[:token])
        render :invalid, status: :not_found unless @lead
      end
    end
  end
end
