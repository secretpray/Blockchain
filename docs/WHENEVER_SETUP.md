# Whenever Cron Jobs Setup

## Overview

Automated scheduled tasks for security maintenance using `whenever` gem.

## Scheduled Tasks

### 1. Daily Cleanup (2:00 AM)
```ruby
every 1.day, at: "2:00 am" do
  rake "users:cleanup_unverified"
end
```
**What it does:**
- Removes unverified users older than 7 days
- Prevents database bloat from abandoned signups

### 2. Nonce Rotation (Every 10 minutes)
```ruby
every 10.minutes do
  rake "users:rotate_stale_nonces"
end
```
**What it does:**
- Rotates nonces older than TTL (10 minutes)
- Ensures security of authentication flow

## Setup Instructions

### Development

**Preview schedule (without installing):**
```bash
bundle exec whenever
```

**Install to crontab:**
```bash
bundle exec whenever --update-crontab
```

**Remove from crontab:**
```bash
bundle exec whenever --clear-crontab
```

### Production

**1. Manual Setup**

SSH to server and run:
```bash
cd /path/to/app
RAILS_ENV=production bundle exec whenever --update-crontab
```

**2. With Capistrano**

Add to `Capfile`:
```ruby
require 'whenever/capistrano'
```

Jobs will auto-update on each deploy!

**3. With Docker**

Add to `Dockerfile`:
```dockerfile
# Install cron
RUN apt-get update && apt-get install -y cron

# Copy whenever schedule
COPY config/schedule.rb /app/config/

# Setup cron on container start
RUN bundle exec whenever --update-crontab --set environment=production
```

## Configuration

### Environment-specific schedules

Edit `config/schedule.rb`:

```ruby
set :environment, ENV.fetch("RAILS_ENV", "production")

case @environment
when "production"
  # Production schedule
  every 1.day, at: "2:00 am" do
    rake "users:cleanup_unverified"
  end

when "staging"
  # More frequent for testing
  every 1.hour do
    rake "users:cleanup_unverified"
  end

when "development"
  # Disabled in development
  # (or use very long intervals)
end
```

### Custom log location

```ruby
set :output, "log/cron.log"  # Default
# or
set :output, "/var/log/app/cron.log"  # Custom path
```

### Email notifications on errors

```ruby
set :output, { error: "error.log", standard: "cron.log" }

# With email (requires mail setup)
set :output, {
  error: "/path/to/error.log",
  standard: "/path/to/cron.log"
}
```

## Monitoring

### Check cron log

```bash
tail -f log/cron.log
```

### Verify crontab

```bash
crontab -l | grep rake
```

Should see:
```
0 2 * * * /bin/bash -l -c 'cd /app && RAILS_ENV=production bundle exec rake users:cleanup_unverified...'
0,10,20,30,40,50 * * * * /bin/bash -l -c 'cd /app && RAILS_ENV=production bundle exec rake users:rotate_stale_nonces...'
```

### Test tasks manually

```bash
# Test cleanup
RAILS_ENV=production bundle exec rake users:cleanup_unverified

# Test rotation
RAILS_ENV=production bundle exec rake users:rotate_stale_nonces

# Check stats
RAILS_ENV=production bundle exec rake users:stats
```

## Troubleshooting

### Jobs not running?

1. **Check crontab is installed:**
   ```bash
   crontab -l
   ```

2. **Check cron service is running:**
   ```bash
   sudo service cron status  # Ubuntu/Debian
   sudo systemctl status crond  # CentOS/RHEL
   ```

3. **Check log permissions:**
   ```bash
   ls -la log/cron.log
   chmod 664 log/cron.log
   ```

4. **Check Rails environment:**
   ```bash
   # Add to schedule.rb for debugging
   set :output, { error: "log/cron_error.log", standard: "log/cron.log" }
   ```

### Database connection errors?

Ensure database.yml has correct production settings:
```yaml
production:
  adapter: postgresql
  pool: 5
  timeout: 5000
  # ... other settings
```

### Bundler issues?

Specify bundler path in schedule.rb:
```ruby
set :bundle_command, "/usr/local/bin/bundle"
# or
job_type :rake, "cd :path && RAILS_ENV=:environment /usr/local/bin/bundle exec rake :task :output"
```

## Best Practices

### 1. Use whenever only in production

`Gemfile`:
```ruby
gem "whenever", require: false
```

### 2. Version control schedule.rb

Always commit `config/schedule.rb` to git.

### 3. Monitor execution

Add logging to rake tasks:
```ruby
task cleanup_unverified: :environment do
  Rails.logger.info("[CRON] Starting cleanup_unverified")
  count = User.stale_unverified.delete_all
  Rails.logger.info("[CRON] Deleted #{count} users")
end
```

### 4. Test before deploying

Always run `bundle exec whenever` locally to verify syntax.

### 5. Use separate log file

Keep cron logs separate from application logs for easier debugging.

## Alternative: Solid Queue (Rails 8)

If you want more control, consider using **Solid Queue** (built-in Rails 8):

```ruby
# app/jobs/cleanup_unverified_users_job.rb
class CleanupUnverifiedUsersJob < ApplicationJob
  queue_as :default

  self.queue_adapter = :solid_queue

  # Run daily at 2 AM
  repeats every: 1.day, at: "02:00"

  def perform
    User.stale_unverified.delete_all
  end
end
```

**Pros:**
- Built-in Rails 8
- Uses database (no separate cron daemon)
- Better monitoring/retry logic

**Cons:**
- Requires Solid Queue setup
- More complex than whenever for simple tasks

## Comparison

| Feature | Whenever | Solid Queue | System Cron |
|---------|----------|-------------|-------------|
| Setup | Easy | Medium | Easy |
| Version Control | ✅ | ✅ | ❌ |
| Monitoring | Logs | Dashboard | Logs |
| Retry Logic | ❌ | ✅ | ❌ |
| Dependencies | cron daemon | Database | cron daemon |
| Best for | Simple tasks | Complex jobs | Minimal setup |

## Recommendation

For this project: **Whenever is perfect** ✅

- Simple setup
- Version controlled
- No additional infrastructure
- Production-proven
- Easy to maintain

---

**Status**: ✅ Configured and ready to use
**Next step**: Deploy and run `whenever --update-crontab` on server
