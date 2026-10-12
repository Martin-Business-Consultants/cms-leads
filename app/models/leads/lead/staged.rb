# frozen_string_literal: true

# Where a lead is: new, contacted (someone reached them), qualified (a good
# fit), quoted, then won or lost — or spam. Closing a lead (won, lost, spam)
# cancels its playbook's open tasks and stops its emails; every change goes
# on the timeline and out to webhooks (lead.stage_changed).
module Leads::Lead::Staged
  extend ActiveSupport::Concern

  STAGES = %w[new contacted qualified quoted won lost spam].freeze
  OPEN_STAGES = %w[new contacted qualified quoted].freeze
  CLOSED_STAGES = %w[won lost spam].freeze

  included do
    scope :in_stage, ->(stage) { where(stage: stage) }
    scope :open, -> { where(stage: OPEN_STAGES) }
    scope :not_spam, -> { where.not(stage: "spam") }

    validates :stage, inclusion: {in: STAGES}
  end

  def open? = OPEN_STAGES.include?(stage)
  def closed? = CLOSED_STAGES.include?(stage)
  def spam? = stage == "spam"

  # Returns whether the stage changed.
  def change_stage(to, user: Current.user, reason: nil)
    to = to.to_s
    raise ArgumentError, "Unknown stage #{to.inspect}" unless STAGES.include?(to)
    return false if to == stage

    from = stage
    update!(stage: to, stage_changed_at: Time.current)
    record_activity(:stage_changed, summary: "#{from.humanize} → #{to.humanize}#{": #{reason}" if reason.present?}",
      data: {from: from, to: to, reason: reason}, user: user)
    wind_down(to) if closed?
    track_event(:stage_changed, from: from, to: to) if user
    announce("lead.stage_changed", webhook_payload.merge(previous_stage: from))
    true
  end

  # Someone talked to them (a call answered, a reply): a new lead is
  # contacted, and the playbook steps meant only for someone not yet reached
  # are dropped.
  def mark_reached(user: Current.user)
    update_columns(contacted_at: Time.current, updated_at: Time.current)
    drop_tasks(tasks.pending.from_steps_skipped_once_reached, reason: "reached them", user: user)
    change_stage("contacted", user: user) if stage == "new"
  end

  def mark_spam(user: Current.user) = change_stage("spam", user: user)

  def unmark_spam(user: Current.user) = spam? && change_stage("new", user: user)

  # An edit from the lead's page or the API: its details, and its stage
  # through change_stage. Returns whether it saved; errors are on the lead.
  def revise(attributes, user: Current.user)
    attributes = attributes.to_h.stringify_keys
    stage = attributes.delete("stage").presence
    if stage && STAGES.exclude?(stage)
      errors.add(:stage, "is not one of #{STAGES.join(", ")}")
      return false
    end

    transaction do
      assign_attributes(attributes)
      owner_changed = will_save_change_to_owner_id?
      save!
      reassign_open_tasks(user: user) if owner_changed
      change_stage(stage, user: user) if stage
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  def wind_down(stage)
    stop_enrollments(reason: stage)
    drop_tasks(tasks.pending.from_steps, reason: "the lead is #{stage}")
  end

  # A new owner takes over the open tasks the old one had.
  def reassign_open_tasks(user:)
    tasks.pending.update_all(assignee_id: owner_id, updated_at: Time.current)
    record_activity(:owner_changed, summary: owner ? "Now #{owner.name.presence || owner.email}’s" : "No owner now",
      data: {owner_id: owner_id}, user: user)
  end
end
