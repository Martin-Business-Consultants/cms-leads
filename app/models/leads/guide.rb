# frozen_string_literal: true

# The Learning Center's guides: short, practical lessons on turning an
# enquiry into a sale, for people who market more than they sell. Each is an
# article (leads/guides/articles/_<key>), with the stages it helps most at,
# so a lead's page can point to the right one.
class Leads::Guide
  Entry = Struct.new(:key, :title, :summary, :minutes, :stages, keyword_init: true) do
    def to_param = key
    def partial = "leads/guides/articles/#{key.tr("-", "_")}"
  end

  ENTRIES = [
    Entry.new(key: "speed-to-lead", title: "Answer in minutes, not hours", minutes: 3, stages: %w[new],
      summary: "Why the first reply matters most, and how to make it fast without making it sloppy."),
    Entry.new(key: "first-call", title: "The first call", minutes: 5, stages: %w[new contacted],
      summary: "A simple shape for the first conversation: open, set the agenda, listen, play it back, agree the next step."),
    Entry.new(key: "discovery-questions", title: "Questions that uncover what they need", minutes: 4, stages: %w[new contacted qualified],
      summary: "The questions to ask, and why talking less wins more."),
    Entry.new(key: "qualifying", title: "Is this a good fit?", minutes: 3, stages: %w[contacted qualified],
      summary: "Need, timing, who decides and budget: knowing early saves everyone time."),
    Entry.new(key: "objections", title: "Handling objections", minutes: 5, stages: %w[qualified quoted],
      summary: "Listen, acknowledge, explore, respond: what to say to “too expensive”, “not now” and “let me think about it”."),
    Entry.new(key: "follow-up", title: "Following up without being pushy", minutes: 4, stages: %w[contacted qualified quoted],
      summary: "How often, on which channel, and what to say so every follow-up is worth reading."),
    Entry.new(key: "writing", title: "Emails and texts that get replies", minutes: 3, stages: %w[new contacted qualified],
      summary: "Short, personal, one question, a clear next step. Plus texting manners."),
    Entry.new(key: "closing", title: "Asking for the business", minutes: 4, stages: %w[qualified quoted],
      summary: "Recognising when they’re ready, summarising, and asking plainly for a yes.")
  ].freeze

  # What to do now, for a lead at each stage (its page).
  STAGE_TIPS = {
    "new" => "Reply now: the first business to answer usually wins. Call if you have a number, then send the first reply by email or text.",
    "contacted" => "You’ve talked. Find out what they need and whether it’s a fit, and end every conversation with an agreed next step.",
    "qualified" => "They’re a good fit. Recap what they need, deal with what’s holding them back, and get them a price.",
    "quoted" => "They have a price. Follow up within a couple of days, answer what’s in the way, and ask for the business.",
    "won" => "They said yes. Thank them, confirm what happens next in writing, and ask who else they know.",
    "lost" => "Ask what tipped the decision (it’s the cheapest lesson there is), then leave the door open.",
    "spam" => "Nothing to do. If this was a real person, mark it as not spam."
  }.freeze

  def self.all = ENTRIES
  def self.find(key) = ENTRIES.find { it.key == key.to_s } || raise(ActiveRecord::RecordNotFound, "No guide #{key}")
  def self.for_stage(stage, limit: 2) = ENTRIES.select { it.stages.include?(stage.to_s) }.first(limit)
end
