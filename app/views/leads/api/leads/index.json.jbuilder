# frozen_string_literal: true

json.leads @leads, partial: "leads/api/leads/lead", as: :record
