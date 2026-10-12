# frozen_string_literal: true

module Leads
  # Templates: emails, texts and call scripts for the situations that come up.
  class TemplatesController < ApplicationController
    requires_capability "leads:read", only: :index
    requires_capability "leads:playbooks", only: [:new, :create, :edit, :update, :destroy]

    before_action :set_template, only: [:edit, :update, :destroy]

    def index
      Template.seed_defaults!
      @templates = Template.ordered.group_by(&:kind)
    end

    def new
      @template = Template.new(kind: params[:kind].presence_in(Template::KINDS.keys) || "email")
    end

    def create
      @template = Template.new(template_params)
      if @template.save
        redirect_to leads_templates_path(anchor: "template_#{@template.id}"), notice: "Template added"
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @template.update(template_params)
        redirect_to leads_templates_path(anchor: "template_#{@template.id}"), notice: "Saved"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @template.destroy!
      redirect_to leads_templates_path, notice: "“#{@template.title}” deleted"
    end

    private

    def set_template
      @template = Template.find(params[:id])
    end

    def template_params
      params.require(:template).permit(:kind, :title, :situation, :subject, :body)
    end
  end
end
