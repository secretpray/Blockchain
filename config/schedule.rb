# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# Set environment path
set :output, "log/cron.log"
set :environment, ENV.fetch("RAILS_ENV", "development")

# Cleanup stale unverified users (once per day at 2 AM)
# Removes users who requested nonce but never authenticated (>7 days old)
every 1.day, at: "2:00 am" do
  rake "users:cleanup_unverified"
end

# Rotate expired nonces (every 10 minutes)
# Ensures nonces older than TTL are refreshed
every 10.minutes do
  rake "users:rotate_stale_nonces"
end

# Optional: Weekly statistics report (Sundays at midnight)
# Uncomment to enable weekly security stats logging
# every :sunday, at: "12:00 am" do
#   rake "users:stats"
# end
