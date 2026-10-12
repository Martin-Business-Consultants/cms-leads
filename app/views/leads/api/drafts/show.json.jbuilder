# frozen_string_literal: true

json.draft do
  json.partial! "leads/api/drafts/draft", record: @draft
end
