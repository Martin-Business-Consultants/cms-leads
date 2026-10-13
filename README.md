# Leads

A plugin for the CMS (see `docs/plugins.md` in [Libre Publish](https://github.com/Martin-Business-Consultants/libre-publish)).

Everyone who gets in touch through the site becomes a **lead** with an owner
and a **next step**, so the right thing happens next and nobody waits on a
reply. A Forms submission with a name, an email address or a phone number
makes one (Settings › Leads can narrow it to chosen forms), and so does a
Commerce quote request; the same person writing again comes back to the lead
they already are — by email, or by phone number — with a reply due within
the hour. A lead can be added by hand, or over the API.

**Playbooks** say what happens when each kind of lead comes in: who owns it,
and its first steps, counted from the moment it arrives — tasks for a person
("Call {{first_name}} back", 15 minutes in) and emails that send themselves
("Checking in", a week in). One playbook starts for each new lead, the most
specific that matches: its form's, then any form's or quote requests', then
every lead's. A step can be marked to be dropped once someone reaches the
lead — the second call attempt, the "did you get my message?" email. Two
playbooks come with it, tasks only: nothing emails a lead until someone adds
an email step.

**Needs you** (Leads in the admin menu) lists what to do now, for you or the
whole team: overdue steps, today's, open leads with nothing planned, hot
leads, and the week ahead. The admin bar says how many need you; the
dashboard has the same at a glance; a morning digest emails each person their
day. Finishing a step asks how it went — reached them, no answer, done — and
what's next, in one form: reaching a new lead makes it contacted and drops
the steps meant for someone not reached yet.

A **lead's page** has its next steps, what they sent, replies to send, its
timeline, and its owner, stage, playbooks and score beside them. Stages are
new, contacted, qualified, quoted, won, lost and spam; a Commerce invoice sent
makes its lead quoted, and paid makes it won. Closing a lead drops its
playbook's open steps and stops its emails.

**Replies**: a tip for the lead's stage with the guides that help, the
**templates** (emails, texts and call scripts, filled in for the lead, to copy
or open in your email or messages app), and — with the
[AI plugin](https://github.com/Martin-Business-Consultants/cms-ai) set up in Settings › AI —
replies **drafted by the AI** in the site's voice
(Settings › Brand context): a summary, the best next step to plan in one
click, an email, a text and a call plan with the questions to ask and the
objections to expect. Nothing is ever sent by itself.

The **Learning Center** has short guides on turning an enquiry into a sale:
answering fast, the first call, discovery questions, qualifying, objections,
following up, writing replies, asking for the business.

Playbook emails go from the site's sender, with a one-click unsubscribe link
(and `List-Unsubscribe` headers, RFC 8058), an open pixel and tracked links,
at `/leads-mail/:token/…`. Opens and clicks score; a lead at the threshold,
active this week, is hot.

**For agents**, through `cms get|post|patch` (listed in `/api/manifest`):

    GET   /api/leads/needs-you?whose=mine|everyone|unassigned
    GET   /api/leads?stage=open&q=…&owner=me
    POST  /api/leads                       {"lead": {"name": …, "email": …, "message": …}}
    GET   /api/leads/:id                   tasks, playbooks, timeline, guides
    PATCH /api/leads/:id                   {"lead": {"stage": "qualified", "owner_id": 2}}
    POST  /api/leads/:id/tasks             {"task": {"kind": "call", "title": …, "when": "1d"}}
    POST  /api/leads/tasks/:id/completion  {"completion": {"result": "reached", "next_title": …, "next_when": "2d"}}
    POST  /api/leads/:id/notes             {"note": {"body": …}}
    GET|POST /api/leads/:id/drafts
    POST  /api/leads/:id/enrollments       {"enrollment": {"playbook_id": 1}}
    GET   /api/leads/playbooks, /api/leads/templates, /api/leads/tasks?due=overdue|today|week
    GET|PATCH /api/leads/settings

Webhooks can subscribe to `lead.created` and `lead.stage_changed`.

Capabilities: `leads:read`, `leads:write`, `leads:delete`, and
`leads:playbooks` (playbooks and templates). Editors start with all four,
authors and the Agent role with read and write. Settings › Leads takes
`settings:read` and `settings:write`. Deleting a lead moves it to the trash;
purging it there removes its tasks, timeline, emails and drafts.

Install it into a CMS checkout (core 1.30 or newer):

    bin/rails "plugins:install[https://github.com/Martin-Business-Consultants/cms-leads]"

or add it from Settings › Plugins, or, on a Docker install, add the URL to the
`CMS_PLUGINS` builder secret. Then switch it on in Settings › Plugins.

Its specs run inside the CMS, with the plugin in `plugins/leads`:

    bin/rspec plugins/leads/spec

To release, bump `lib/leads/version.rb`, commit, and tag `vX.Y.Z`.
