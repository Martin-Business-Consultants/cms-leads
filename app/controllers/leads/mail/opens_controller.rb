# frozen_string_literal: true

module Leads
  module Mail
    # The open pixel in a playbook's email (public, signed). Always the same
    # transparent GIF.
    class OpensController < ActionController::Base
      PIXEL = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7").freeze

      def show
        Message.find_by_open_token(params[:token])&.record_open if Cms::Plugins.enabled?(:leads)
        response.set_header("Cache-Control", "no-store")
        send_data PIXEL, type: "image/gif", disposition: "inline"
      end
    end
  end
end
