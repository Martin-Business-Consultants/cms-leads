# frozen_string_literal: true

require "net/http"

# Asks Claude (the Messages API, with the key and model in Settings › Leads)
# for a lead's replies, as JSON in a fixed shape (structured output), in the
# site's voice: the brand brief from Settings › Brand context, the site's
# name, and the lead — who they are, what they sent, its timeline. Plain
# Net::HTTP: a plugin may use only the gems the core bundles.
class Leads::Draft::Writer
  class Error < StandardError; end

  ENDPOINT = URI("https://api.anthropic.com/v1/messages")
  TIMEOUT = 120
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

  def initialize(lead)
    @lead = lead
    @settings = Leads::Settings.current
  end

  # The drafted replies, as a hash in SCHEMA's shape. Raises Error.
  def write
    raise Error, "No Anthropic API key is set in Settings › Leads" if @settings.ai_key.blank?

    response = post(request_body)
    body = JSON.parse(response.body) rescue {}
    raise Error, failure_message(response, body) unless response.is_a?(Net::HTTPSuccess)

    case body["stop_reason"]
    when "refusal" then raise Error, "Claude declined to draft replies for this lead"
    when "max_tokens" then raise Error, "The drafts ran too long; try again"
    end

    text = Array(body["content"]).select { it["type"] == "text" }.map { it["text"] }.join
    JSON.parse(text)
  rescue JSON::ParserError
    raise Error, "Claude's answer wasn't in the expected shape; try again"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
    raise Error, "Couldn't reach Anthropic: #{error.class.name.demodulize}"
  end

  def request_body
    {
      model: @settings.ai_model,
      max_tokens: 16_000,
      output_config: {effort: "medium", format: {type: "json_schema", schema: SCHEMA}},
      fallbacks: "default",
      system: system_prompt,
      messages: [{role: "user", content: lead_description}]
    }
  end

  private

  def post(body)
    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = TIMEOUT
    request = Net::HTTP::Post.new(ENDPOINT.request_uri)
    request["content-type"] = "application/json"
    request["x-api-key"] = @settings.ai_key
    request["anthropic-version"] = "2023-06-01"
    request["anthropic-beta"] = "server-side-fallback-2026-07-01"
    request.body = JSON.generate(body)
    http.request(request)
  end

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

  def failure_message(response, body)
    detail = body.dig("error", "message").presence
    case response.code.to_i
    when 401 then "Anthropic didn't accept the API key in Settings › Leads"
    when 429 then "Anthropic is rate limiting this key; try again shortly"
    else "Anthropic answered #{response.code}#{": #{detail}" if detail}"
    end
  end
end
