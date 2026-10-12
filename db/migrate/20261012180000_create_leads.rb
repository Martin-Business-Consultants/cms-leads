# frozen_string_literal: true

# The Leads plugin's tables, prefixed with its key. Users are the core's,
# pointed at by id; a lead's tasks, timeline, emails and drafts go with it
# when it's purged from the trash (that's how someone is forgotten).
class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads_leads do |t|
      t.string :name
      t.string :email, index: true
      t.string :phone
      t.string :phone_key, index: true
      t.string :company
      t.string :stage, null: false, default: "new", index: true
      t.string :source, null: false, default: "manual"
      t.string :source_label
      t.string :source_form
      t.integer :owner_id, index: true
      t.integer :score, null: false, default: 0
      t.json :fields, null: false, default: {}
      t.datetime :contacted_at
      t.datetime :stage_changed_at
      t.datetime :last_activity_at, index: true
      t.datetime :unsubscribed_at
      t.datetime :deleted_at, index: true
      t.timestamps
    end

    create_table :leads_playbooks do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.string :trigger, null: false, default: "any"
      t.string :trigger_form
      t.integer :owner_id
      t.timestamps
    end

    create_table :leads_steps do |t|
      t.references :playbook, null: false, foreign_key: {to_table: :leads_playbooks, on_delete: :cascade}
      t.string :action, null: false, default: "task"
      t.string :task_kind, null: false, default: "call"
      t.string :title
      t.string :subject
      t.text :body
      t.integer :delay_amount, null: false, default: 0
      t.string :delay_unit, null: false, default: "hours"
      t.boolean :skip_if_reached, null: false, default: true
      t.timestamps
    end

    create_table :leads_enrollments do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.references :playbook, null: false, foreign_key: {to_table: :leads_playbooks, on_delete: :cascade}
      t.string :status, null: false, default: "active"
      t.datetime :started_at, null: false
      t.datetime :next_send_at
      t.json :sent_step_ids, null: false, default: []
      t.datetime :finished_at
      t.string :stop_reason
      t.timestamps
      t.index [:status, :next_send_at]
    end

    create_table :leads_tasks do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.references :step, foreign_key: {to_table: :leads_steps, on_delete: :nullify}
      t.string :kind, null: false, default: "call"
      t.string :title, null: false
      t.text :notes
      t.datetime :due_at
      t.integer :assignee_id, index: true
      t.integer :creator_id
      t.datetime :completed_at
      t.integer :completed_by_id
      t.string :result
      t.text :outcome
      t.datetime :canceled_at
      t.timestamps
      t.index [:completed_at, :canceled_at, :due_at]
    end

    create_table :leads_messages do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.references :enrollment, foreign_key: {to_table: :leads_enrollments, on_delete: :nullify}
      t.references :step, foreign_key: {to_table: :leads_steps, on_delete: :nullify}
      t.string :subject, null: false
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.timestamps
    end

    create_table :leads_activities do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.string :kind, null: false
      t.string :summary, null: false
      t.text :body
      t.integer :points, null: false, default: 0
      t.json :data, null: false, default: {}
      t.integer :user_id
      t.datetime :created_at, null: false
      t.index [:lead_id, :created_at]
    end

    create_table :leads_templates do |t|
      t.string :kind, null: false, index: true
      t.string :title, null: false
      t.string :situation
      t.string :subject
      t.text :body
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :leads_drafts do |t|
      t.references :lead, null: false, foreign_key: {to_table: :leads_leads, on_delete: :cascade}
      t.integer :user_id
      t.string :state, null: false, default: "working"
      t.json :payload, null: false, default: {}
      t.text :error
      t.timestamps
    end
  end
end
