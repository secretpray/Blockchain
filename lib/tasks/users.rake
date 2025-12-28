namespace :users do
  desc "Cleanup unverified users older than 7 days"
  task cleanup_unverified: :environment do
    count = User.stale_unverified.delete_all

    if count > 0
      puts "✓ Deleted #{count} unverified user(s)"
      Rails.logger.info("Cleanup: Deleted #{count} unverified users")
    else
      puts "✓ No stale unverified users found"
    end
  end

  desc "Rotate stale nonces older than TTL"
  task rotate_stale_nonces: :environment do
    count = 0

    User.with_stale_nonces.find_each do |user|
      user.rotate_nonce!
      count += 1
    end

    if count > 0
      puts "✓ Rotated #{count} stale nonce(s)"
      Rails.logger.info("Security: Rotated #{count} stale nonces")
    else
      puts "✓ No stale nonces found"
    end
  end

  desc "Show user statistics"
  task stats: :environment do
    total = User.count
    verified = User.where(verified: true).count
    unverified = User.where(verified: false).count
    stale = User.stale_unverified.count

    puts "User Statistics:"
    puts "  Total users:           #{total}"
    puts "  Verified:              #{verified}"
    puts "  Unverified:            #{unverified}"
    puts "  Stale (>7 days):       #{stale}"
    puts ""
    puts "Security:"
    puts "  Nonce TTL:             #{User::NONCE_TTL.inspect}"
    puts "  Max auth attempts:     #{User::MAX_AUTH_ATTEMPTS}"
    puts "  Rate limit window:     #{User::RATE_LIMIT_WINDOW.inspect}"
  end
end
