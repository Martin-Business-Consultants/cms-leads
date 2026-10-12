# Leads, a Libre Publish plugin — guide for AI agents

This repository is a plugin for the Libre Publish CMS: a Rails engine loaded
into an install from `plugins/leads`. It isn't an app on its own. Read the
core's `docs/plugins.md` (the contract) and `STYLE.md` (how code is written)
first; this code follows both.

- Tables are `leads_*` and point at the core's users by id. Never change a
  core table.
- Register everything in `lib/leads/engine.rb`'s `config.to_prepare`.
  Admin controllers inherit `Leads::ApplicationController` (a 404 while the
  plugin is off), API ones `Leads::Api::BaseController`; every action
  declares its capability.
- Behaviour lives on the models: `Leads::Lead` and its concerns
  (`app/models/leads/lead/`) hold the verbs — `capture`, `arrive`,
  `come_back`, `add_task`, `drop_tasks`, `change_stage`, `mark_reached`,
  `enroll`, `unsubscribe`, `draft_replies_later`. Plain objects:
  `Leads::Enquiry` (what someone sent), `Leads::Queue` (Needs you),
  `Leads::Task::Completion` (done, and what's next), `Leads::When`,
  `Leads::Personalization`, `Leads::Settings`, `Leads::Digest`,
  `Leads::Draft::Writer` (the Messages API over Net::HTTP: a plugin may use
  only gems the core bundles).
- Views use the admin's CSS vocabulary; what's the plugin's alone is a
  `leads-*` class in `app/assets/stylesheets/leads/leads.css`. Editors start
  with their title field (`title-input`), with the sidebar beside it — no
  "Edit …" page heading. Herb flags a form inside a block helper it doesn't
  know (`postbox`), so a box holding a form is written as the postbox's
  `<details>` markup.
- Public routes (`/leads-mail/:token/…`) inherit `ActionController::Base`:
  mail clients and providers aren't modern browsers.

Check: `bin/rspec plugins/leads/spec`, `bundle exec herb lint
plugins/leads/app/views`, `bin/rubocop plugins/leads`, and
`bin/rspec spec/architecture` (it reads plugins too), all from the core.
