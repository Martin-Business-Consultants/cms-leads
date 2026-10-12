# frozen_string_literal: true

# Needs you: what to do about leads now, for one person or the whole team.
# Overdue tasks first, then today's, then open leads with nothing planned,
# then hot leads (a high score, active this week), then the week ahead.
# A person's own includes unassigned work, which is everyone's until
# someone owns it.
#
#   queue = Leads::Queue.new(user: Current.user, whose: "mine")
#   queue.overdue  # => tasks
class Leads::Queue
  WHOSE = {"mine" => "Mine", "everyone" => "Everyone’s", "unassigned" => "Unassigned"}.freeze
  AHEAD = 7.days
  LIMIT = 50

  attr_reader :user, :whose

  # "mine" for someone who owns leads or has tasks, "everyone" otherwise.
  def self.default_whose(user)
    mine = user && (Leads::Lead.owned_by(user).open.exists? || Leads::Task.pending.assigned_to(user).exists?)
    mine ? "mine" : "everyone"
  end

  def initialize(user:, whose: nil, now: Time.current)
    @user = user
    @whose = WHOSE.key?(whose.to_s) ? whose.to_s : self.class.default_whose(user)
    @now = now
  end

  def overdue = tasks.overdue(@now).in_due_order.limit(LIMIT)

  def today = tasks.between(@now..end_of_today).in_due_order.limit(LIMIT)

  def coming_up = tasks.between(end_of_today..(@now + AHEAD)).in_due_order.limit(LIMIT)

  def without_next_step = leads.without_next_step.recent_first.limit(LIMIT)

  def hot = leads.hot.where.not(id: overdue.select(:lead_id)).order(score: :desc).limit(10)

  # How many need doing now: overdue and due today. The admin bar's count.
  def count = tasks.due_by(end_of_today).count + leads.without_next_step.count

  def empty? = overdue.none? && today.none? && without_next_step.none?

  def to_h
    {whose: whose, overdue: overdue.to_a, today: today.to_a, without_next_step: without_next_step.to_a,
     hot: hot.to_a, coming_up: coming_up.to_a}
  end

  private

  def end_of_today = @now.in_time_zone(Site.time_zone).end_of_day

  def tasks
    scope = Leads::Task.on_kept_leads.merge(Leads::Lead.not_spam).includes(:lead, :assignee)
    case whose
    when "mine" then scope.where(assignee_id: [user&.id, nil])
    when "unassigned" then scope.unassigned
    else scope
    end
  end

  def leads
    scope = Leads::Lead.includes(:owner)
    case whose
    when "mine" then scope.where(owner_id: [user&.id, nil])
    when "unassigned" then scope.where(owner_id: nil)
    else scope
    end
  end
end
