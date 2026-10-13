# frozen_string_literal: true

# Drafts come from the AI plugin now: Leads keeps no AI key or model of its
# own, so any it saved before goes.
class ForgetLeadsAnthropicKey < ActiveRecord::Migration[8.1]
  def up
    return unless defined?(::Setting) && ::Setting.exists?(key: "leads")

    ::Setting.set_secret("leads", "anthropic_api_key" => "")
    ::Setting.unset("leads", "ai_model")
  end

  def down
  end
end
