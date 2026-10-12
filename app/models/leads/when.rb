# frozen_string_literal: true

# When a next step is due, from the choices the lead's page offers ("in an
# hour", "tomorrow", "next week"): a day away or more lands at 9 in the
# morning in the site's time zone, an hour or two from now lands then.
module Leads::When
  CHOICES = [
    ["In an hour", "1h"], ["Later today", "4h"], ["Tomorrow", "1d"], ["In 2 days", "2d"],
    ["In 3 days", "3d"], ["Next week", "7d"], ["In 2 weeks", "14d"], ["In a month", "30d"]
  ].freeze
  MORNING = 9

  module_function

  # The time a choice means, or nil (no due date) for a blank or unknown one.
  def parse(choice, now: Time.current)
    amount, unit = choice.to_s.match(/\A(\d+)([hd])\z/)&.captures
    return unless amount

    if unit == "h"
      now + amount.to_i.hours
    else
      (now.in_time_zone(Site.time_zone) + amount.to_i.days).change(hour: MORNING)
    end
  end
end
