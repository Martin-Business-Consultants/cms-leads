# frozen_string_literal: true

# The templates every site starts with: first replies, follow-ups and call
# scripts that work for most businesses, written to be edited. Made once,
# the first time the templates are listed; deleting them doesn't bring them
# back.
module Leads::Template::Defaults
  extend ActiveSupport::Concern

  def self.paragraphs(*lines) = lines.map { "<p>#{it}</p>" }.join

  DEFAULTS = [
    {kind: "email", title: "First reply to a website enquiry", situation: "Within minutes of a new lead coming in",
      subject: "Re: your enquiry, {{first_name}}",
      body: paragraphs("Hi {{first_name}},", "Thanks for getting in touch with {{business}}. I’ve read what you sent and I’d love to help.",
        "To point you in the right direction, could you tell me a little more about what you’re hoping to get done, and roughly when?",
        "If it’s easier to talk, reply with a good time and the best number, and I’ll call you then.", "{{my_name}}")},
    {kind: "email", title: "Couldn’t reach you by phone", situation: "After a call that went to voicemail",
      subject: "Tried to call you, {{first_name}}",
      body: paragraphs("Hi {{first_name}},", "I just tried calling about your enquiry and missed you.",
        "No need to call back if email is easier: just reply with a couple of times that suit you, or answer here and we’ll take it from there.", "{{my_name}}, {{business}}")},
    {kind: "email", title: "Recap after a call", situation: "The same day as a good conversation",
      subject: "Great to talk today, {{first_name}}",
      body: paragraphs("Hi {{first_name}},", "Thanks for your time today. Here’s what I heard:",
        "• What you need: …<br>• What matters most: …<br>• Timing: …",
        "Next step: … I’ll have that to you by …. If I’ve missed anything, just reply and let me know.", "{{my_name}}")},
    {kind: "email", title: "Checking in", situation: "No reply after 3–4 days",
      subject: "Still looking for help with this?",
      body: paragraphs("Hi {{first_name}},", "Following up on my last note in case it got buried. Are you still looking for help with this?",
        "A quick yes or no is perfect: if now isn’t the right time, I’ll leave it there.", "{{my_name}}")},
    {kind: "email", title: "Sending a quote", situation: "With a price or proposal attached",
      subject: "Your quote from {{business}}",
      body: paragraphs("Hi {{first_name}},", "As promised, here’s the quote for what we talked about. In short: ….",
        "It covers …. It doesn’t include …, which we can add if you’d like.",
        "Would a 10-minute call this week help to go through it? Any questions before then, just reply.", "{{my_name}}")},
    {kind: "email", title: "Last try", situation: "After several follow-ups with no reply",
      subject: "Should I close your file?",
      body: paragraphs("Hi {{first_name}},", "I haven’t heard back, so I’m guessing the timing isn’t right, and that’s completely fine.",
        "I’ll close this off for now. If anything changes, reply to this email any time and I’ll pick it straight back up.", "All the best,", "{{my_name}}")},
    {kind: "text", title: "First text after an enquiry", situation: "Within minutes, if they gave a mobile number",
      body: paragraphs("Hi {{first_name}}, it’s {{my_name}} from {{business}}. Thanks for your enquiry! Is now a good time for a quick call, or is there a better time today?")},
    {kind: "text", title: "Missed your call", situation: "Right after a call they missed",
      body: paragraphs("Hi {{first_name}}, {{my_name}} from {{business}} here. Just tried to call about your enquiry. When’s a good time to catch you?")},
    {kind: "text", title: "Confirming a time", situation: "The day before a call or visit",
      body: paragraphs("Hi {{first_name}}, just confirming we’re talking tomorrow at …. Reply here if you need to move it. {{my_name}}, {{business}}")},
    {kind: "text", title: "Gentle nudge", situation: "A few days after sending a quote",
      body: paragraphs("Hi {{first_name}}, {{my_name}} here. Did you get a chance to look at the quote? Happy to answer any questions.")},
    {kind: "call", title: "First call", situation: "Calling a new lead",
      body: paragraphs("<strong>Open:</strong> “Hi {{first_name}}, it’s {{my_name}} from {{business}}. You got in touch about … — is now still a good time?”",
        "<strong>Set the agenda:</strong> “I’d love to ask a few questions so I understand what you need, then I’ll tell you how we could help and what happens next. Sound good?”",
        "<strong>Discover:</strong> “What made you reach out now?” · “What would a great result look like?” · “Have you tried anything already?” · “When do you need it done?” · “Who else is involved in the decision?”",
        "<strong>Play it back:</strong> “So what you need is …, and what matters most is …. Did I get that right?”",
        "<strong>Next step:</strong> “The next step is …. Shall we put … in the diary?” Agree a date before you hang up.")},
    {kind: "call", title: "Voicemail", situation: "When they don’t pick up (keep it under 30 seconds)",
      body: paragraphs("“Hi {{first_name}}, it’s {{my_name}} from {{business}}, calling about your enquiry. I have a couple of ideas for you. You can reach me on … — again, that’s …. I’ll also send you a quick email. Speak soon.”")},
    {kind: "call", title: "“It’s too expensive”", situation: "Handling a price objection",
      body: paragraphs("<strong>Acknowledge:</strong> “That’s fair, it’s a real investment.”",
        "<strong>Explore:</strong> “Can I ask what you’re comparing it with?” or “Is it the total, or how it’s paid?”",
        "<strong>Respond:</strong> Connect the price to what they told you matters: “You said … was the big worry. This takes care of that because ….” If it truly doesn’t fit, offer a smaller first step rather than a discount.",
        "<strong>Check:</strong> “Does that help? What would you need to feel good about going ahead?”")},
    {kind: "call", title: "“I need to think about it”", situation: "When they won’t decide on the call",
      body: paragraphs("<strong>Acknowledge:</strong> “Of course, it’s an important decision.”",
        "<strong>Explore:</strong> “So I can help, what part are you weighing up? Is it the price, the timing, or something else?”",
        "<strong>Next step:</strong> “How about I follow up on Thursday? If you have questions before then, call me directly.” Set it as the next step before you hang up.")}
 ].freeze

  class_methods do
    def seed_defaults!
      return if Leads::Settings.current.templates_seeded?

      transaction do
        DEFAULTS.each { create!(it) }
        Leads::Settings.mark_templates_seeded
      end
    end
  end
end
