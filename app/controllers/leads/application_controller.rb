# frozen_string_literal: true

module Leads
  # The plugin's admin pages: a 404 while it's off, in the core's layout.
  class ApplicationController < ::ApplicationController
    include PluginGated
    plugin :leads

    helper Leads::LeadsHelper
  end
end
