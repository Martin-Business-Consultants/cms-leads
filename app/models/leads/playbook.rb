# frozen_string_literal: true

module Leads
  # What happens when a kind of lead comes in: who owns it, and the steps
  # from that moment — tasks for a person ("Call within the hour") and
  # emails that send themselves ("Checking in", after a week). One playbook
  # starts for each new lead, the most specific that matches: its form's,
  # then any form's or quote requests', then every lead's. It can be started
  # by hand on any lead too.
  class Playbook < ApplicationRecord
    include Testable
    include Defaults

    TRIGGERS = {
      "any" => "Every new lead", "any_form" => "A lead from any form", "form" => "A lead from one form",
      "quote" => "A quote request", "manual" => "Only when someone starts it"
    }.freeze

    belongs_to :owner, class_name: "::User", optional: true
    has_many :steps, class_name: "Leads::Step", inverse_of: :playbook, dependent: :destroy
    has_many :enrollments, class_name: "Leads::Enrollment", dependent: :delete_all

    normalizes :trigger_form, with: -> { it.strip.presence }

    validates :name, presence: true, length: {maximum: 120}
    validates :trigger, inclusion: {in: TRIGGERS.keys}
    validates :trigger_form, presence: {message: "must be chosen for a form's playbook"}, if: -> { trigger == "form" }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:name, :id) }

    before_validation { self.trigger_form = nil unless trigger == "form" }
    after_update_commit -> { Leads::Enrollment.deliver_due_later }, if: -> { saved_change_to_active?(to: true) }

    # The playbook a new lead starts: its form's, then its kind's, then
    # every lead's; nil when none is on.
    def self.for_lead(lead)
      candidates = active.where(trigger: %w[any any_form form quote]).to_a
      by_form = candidates.find { it.trigger == "form" && lead.source == "form" && it.trigger_form == lead.source_form }
      by_kind = candidates.find { (it.trigger == "any_form" && lead.source == "form") || (it.trigger == "quote" && lead.source == "quote") }
      by_form || by_kind || candidates.find { it.trigger == "any" }
    end

    # Steps in the order they happen.
    def ordered_steps = steps.sort_by { [it.delay.to_i, it.id.to_i] }

    def trigger_label
      trigger == "form" ? "A lead from #{form_title || trigger_form}" : TRIGGERS.fetch(trigger)
    end

    def form_title
      defined?(::Form) ? ::Form.find_by(slug: trigger_form)&.title : nil
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    def status_label = active? ? "On" : "Off"
  end
end
