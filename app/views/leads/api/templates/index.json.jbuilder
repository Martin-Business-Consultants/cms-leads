# frozen_string_literal: true

json.templates @templates do |template|
  json.extract! template, :id, :kind, :title, :situation, :subject, :body
  json.placeholders Leads::Personalization::PLACEHOLDERS
end
