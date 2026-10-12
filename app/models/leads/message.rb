# frozen_string_literal: true

module Leads
  # One email a playbook sent a lead. Its links carry signed tokens back to
  # the plugin's public routes (Leads::Mail::…): the open pixel, click
  # tracking and the unsubscribe page. The first open and the first click
  # score (Settings › Leads); every click goes on the timeline.
  class Message < ApplicationRecord
    OPEN_PURPOSE = "leads/open"
    CLICK_PURPOSE = "leads/click"

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :enrollment, class_name: "Leads::Enrollment", optional: true
    belongs_to :step, class_name: "Leads::Step", optional: true

    validates :subject, presence: true

    def self.find_by_open_token(token)
      id = Leads.verifier.verified(token.to_s, purpose: OPEN_PURPOSE)
      id && find_by(id: id)
    end

    # [message, url] for a click token, or nil.
    def self.find_by_click_token(token)
      id, url = Leads.verifier.verified(token.to_s, purpose: CLICK_PURPOSE)
      message = id && find_by(id: id)
      [message, url] if message && url.to_s.match?(%r{\Ahttps?://}i)
    end

    def open_token = Leads.verifier.generate(id, purpose: OPEN_PURPOSE)

    def click_token(url) = Leads.verifier.generate([id, url], purpose: CLICK_PURPOSE)

    def deliver_now
      Leads::LeadMailer.with(message: self).step_email.deliver_now
      update!(sent_at: Time.current)
    end

    # The pixel loaded: the first time only.
    def record_open
      return false if opened_at

      update!(opened_at: Time.current)
      lead.record_activity(:email_opened, summary: "Opened “#{subject}”", data: {message_id: id}, user: nil,
        points: Leads::Settings.current.points_for(:email_open))
      true
    end

    # A tracked link followed. A click is an open too (images are often off).
    def record_click(url)
      record_open
      first = clicked_at.nil?
      update!(clicked_at: Time.current) if first
      lead.record_activity(:email_clicked, summary: "Clicked #{host_of(url)} in “#{subject}”",
        data: {message_id: id, url: url}, user: nil,
        points: first ? Leads::Settings.current.points_for(:email_click) : 0)
    end

    private

    def host_of(url)
      URI.parse(url).host.presence || url
    rescue URI::InvalidURIError
      url
    end
  end
end
