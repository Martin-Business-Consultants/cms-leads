# frozen_string_literal: true

require_relative "lib/leads/version"

Gem::Specification.new do |spec|
  spec.name = "leads"
  spec.version = Leads::VERSION
  spec.summary = "Lead nurturing for Libre Publish: every enquiry gets an owner and a next step, and nothing is left waiting"
  spec.authors = ["Martin Business Consultants"]
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
