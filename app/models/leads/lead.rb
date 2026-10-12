# frozen_string_literal: true

module Leads
  # Someone who might buy: one per email address (or phone number, for
  # someone who only gave that), made when they get in touch through the
  # site (Capturable) or added by hand or over the API. A lead has an owner,
  # moves through stages (Staged), always has a next step — its earliest
  # open task (Tasked) — keeps a timeline of everything (Timelined), earns a
  # score from what it does (Scored), follows a playbook's steps
  # (Enrollable) until it unsubscribes (Subscribable), and can have replies
  # drafted for it (Draftable).
  class Lead < ApplicationRecord
    include SoftDeletable
    include Eventable
    include Timelined
    include Scored
    include Staged
    include Tasked
    include Enrollable
    include Subscribable
    include Capturable
    include Draftable

    SOURCES = %w[form quote manual api].freeze

    belongs_to :owner, class_name: "::User", optional: true

    normalizes :email, with: -> { it.to_s.strip.downcase.presence }
    normalizes :name, :company, :phone, with: -> { it.to_s.strip.presence }

    before_validation { self.phone_key = self.class.phone_key_for(phone) }

    # Someone who rang may have no email address: a name or a number is enough.
    validates :email, format: {with: URI::MailTo::EMAIL_REGEXP}, allow_nil: true
    validate { errors.add(:base, "Give a name, an email address or a phone number") if [name, email, phone].all?(&:blank?) }
    validate :email_not_taken
    validates :source, inclusion: {in: SOURCES}

    scope :recent_first, -> { order(Arel.sql("COALESCE(leads_leads.last_activity_at, leads_leads.created_at) DESC"), id: :desc) }
    scope :owned_by, ->(user) { where(owner_id: user&.id) }
    scope :matching, ->(terms) {
      pattern = "%#{sanitize_sql_like(terms.to_s.strip.downcase)}%"
      where("LOWER(COALESCE(leads_leads.email, '')) LIKE :p OR LOWER(COALESCE(leads_leads.name, '')) LIKE :p " \
            "OR LOWER(COALESCE(leads_leads.company, '')) LIKE :p OR COALESCE(leads_leads.phone_key, '') LIKE :p", p: pattern)
    }

    def self.eventable_prefix = "lead"

    # The digits of a phone number, to match the same number written two
    # ways; nil for fewer than 6.
    def self.phone_key_for(phone)
      digits = phone.to_s.gsub(/\D/, "")
      digits.length >= 6 ? digits.last(10) : nil
    end

    # The kept lead an email address or phone number belongs to.
    def self.find_for(email: nil, phone: nil)
      email = email.to_s.strip.downcase.presence
      key = phone_key_for(phone)
      (email && find_by(email: email)) || (key && find_by(phone_key: key))
    end

    def display_name = name.presence || email.presence || phone.presence || "Lead #{id}"
    def first_name = name.to_s.split.first.presence

    def source_text
      case source
      when "form" then source_label.presence || "A form"
      when "quote" then "A quote request"
      when "api" then "Added over the API"
      else "Added by hand"
      end
    end

    # What a webhook receives (lead.created, lead.stage_changed): a contract,
    # so add to it, never change it.
    def webhook_payload
      {id: id, name: name, email: email, phone: phone, company: company, stage: stage, score: score,
       source: source, source_label: source_label, owner_email: owner&.email,
       next_step: next_task&.then { {kind: it.kind, title: it.title, due_at: it.due_at&.iso8601} },
       created_at: created_at&.iso8601}
    end

    # A lead someone added by hand or over the API: its first activity, its
    # owner and its playbook, as a lead from a form gets. playbook: nil for
    # the one that matches, false for none.
    def record_creation(user: Current.user, playbook: nil)
      record_activity(:created, summary: "Added by #{user&.name.presence || user&.email || "the API"}", user: user)
      arrive(playbook: playbook.nil? ? Leads::Playbook.for_lead(self) : playbook.presence, user: user)
      track_event(:created, name: display_name)
    end

    private

    def email_not_taken
      return if email.blank? || !will_save_change_to_email?

      errors.add(:email, "belongs to another lead") if self.class.where(email: email).where.not(id: id).exists?
    end
  end
end
