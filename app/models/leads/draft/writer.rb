# frozen_string_literal: true

# Asks the install's AI (the AI plugin, cms-ai: Ai.structured, with the
# provider and model in Settings › AI) for a lead's replies, as JSON in a
# fixed shape, in the site's voice: the brand brief from Settings › Brand
# context, the site's name, and the lead — who they are, what they sent, its
# timeline.
class Leads::Draft::Writer
  class Error < StandardError; end

  TIMELINE = 15

  SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[summary next_step email text call],
    properties: {
      summary: {type: "string", description: "One or two sentences: who they are and what they want."},
      next_step: {
        type: "object", additionalProperties: false, required: %w[kind title when why],
        properties: {
          kind: {type: "string", enum: Leads::Task::KINDS.keys},
          title: {type: "string", description: "What to do, as a short task title."},
          when: {type: "string", enum: Leads::When::CHOICES.map(&:last)},
          why: {type: "string"}
        }
      },
      email: {
        type: "object", additionalProperties: false, required: %w[subject body],
        properties: {subject: {type: "string"}, body: {type: "string", description: "Plain text, paragraphs separated by blank lines."}}
      },
      text: {type: "string", description: "A text message under 300 characters."},
      call: {
        type: "object", additionalProperties: false, required: %w[opening questions objections],
        properties: {
          opening: {type: "string"},
          questions: {type: "array", items: {type: "string"}},
          objections: {
            type: "array",
            items: {type: "object", additionalProperties: false, required: %w[objection answer],
                    properties: {objection: {type: "string"}, answer: {type: "string"}}}
          }
        }
      }
    }
  }.freeze

  INSTRUCTIONS = <<~TEXT
    You help a small business answer the people who get in touch through its website, quickly and well.
    Given one lead, write what the person who owns it should send or say next: a short email reply, a text
    message, a plan for a phone call (an opening line, the questions worth asking, the objections to expect
    with how to answer them), and the single best next step with when to do it.

    Write as the business, in its voice. Be specific to what this person asked; never invent prices, dates,
    availability or facts about the business that aren't given. Where a detail is needed and unknown, leave a
    short placeholder in square brackets, like [price]. Keep the email under 150 words, warm and plain, with
    one clear question or next step. Sign the email with {{my_name}}.
  TEXT

  # Whether the AI plugin is installed, on, set up and within its limit.
  def self.available? = defined?(::Ai) && ::Ai.respond_to?(:available?) && ::Ai.available?

  def self.unavailable_reason
    return "Drafts come from the AI plugin: install it (Martin-Business-Consultants/cms-ai) and set it up in Settings › AI" unless defined?(::Ai) && ::Ai.respond_to?(:unavailable_reason)

    ::Ai.unavailable_reason
  end

  def initialize(lead, user: nil)
    @lead = lead
    @user = user
  end

  # The drafted replies, as a hash in SCHEMA's shape. Raises Error.
  def write
    raise Error, self.class.unavailable_reason unless self.class.available?

    ::Ai.structured(purpose: "leads_draft", system: system_prompt, prompt: lead_description, schema: SCHEMA, user: @user)
  rescue Error
    raise
  rescue => error
    raise unless defined?(::Ai::Error) && (error.is_a?(::Ai::Error) || error.is_a?(::Ai::Unavailable))

    raise Error, error.message
  end

  private

  def system_prompt
    brand = defined?(::BrandBrief) ? ::BrandBrief.to_h : {}
    about = brand.map { |field, text| "#{field.to_s.humanize}: #{text}" }.join("\n")
    [INSTRUCTIONS, "The business: #{Leads::Personalization.business_name}", about.presence].compact.join("\n\n")
  end

  def lead_description
    lines = ["Lead: #{@lead.display_name}", ("Company: #{@lead.company}" if @lead.company),
      ("Has an email address" if @lead.email), ("Has a phone number" if @lead.phone),
      "Stage: #{@lead.stage}", "Came from: #{@lead.source_text}"]
    sent = @lead.fields.to_h.map { |label, value| "#{label}: #{value}" }
    timeline = @lead.activities.limit(TIMELINE).map { "#{it.created_at.to_date.iso8601} #{it.summary}" }
    [lines.compact.join("\n"), ("What they sent:\n#{sent.join("\n")}" if sent.any?),
      ("Timeline, newest first:\n#{timeline.join("\n")}" if timeline.any?)].compact.join("\n\n")
  end
end
