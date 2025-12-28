# SIWE Authentication Algorithm Documentation

## Table of Contents
1. [Overview](#overview)
2. [Traditional Rails Authentication](#traditional-rails-authentication)
3. [SIWE Authentication Flow](#siwe-authentication-flow)
4. [Detailed Algorithm Description](#detailed-algorithm-description)
5. [Multi-Layer Security System](#multi-layer-security-system)
6. [Security Considerations](#security-considerations)
7. [Comparison Table](#comparison-table)

## Overview

This document describes the Sign-In With Ethereum (SIWE) authentication mechanism implemented in this Rails application. SIWE is a passwordless authentication protocol that uses cryptographic signatures from Ethereum wallets to verify user identity.

**Key Concept**: Instead of storing and validating passwords, we verify that users own the private key associated with their Ethereum address by asking them to sign a challenge message.

## Traditional Rails Authentication

For context, here's how traditional password-based authentication works in Rails:

```mermaid
sequenceDiagram
    participant User
    participant Browser
    participant Rails
    participant Database

    Note over User,Database: Registration Flow
    User->>Browser: Fill registration form (email, password)
    Browser->>Rails: POST /users (email, password)
    Rails->>Rails: Hash password with bcrypt
    Rails->>Database: Store user (email, password_digest)
    Database-->>Rails: User created
    Rails-->>Browser: Redirect to login

    Note over User,Database: Login Flow
    User->>Browser: Enter email & password
    Browser->>Rails: POST /session (email, password)
    Rails->>Database: Find user by email
    Database-->>Rails: User record
    Rails->>Rails: Compare password with bcrypt
    alt Password matches
        Rails->>Rails: Set session[:user_id]
        Rails-->>Browser: Redirect to dashboard
    else Password incorrect
        Rails-->>Browser: Show error
    end
```

**Problems with password-based auth:**
- Users must remember passwords
- Passwords can be weak or reused
- Risk of database breaches exposing password hashes
- Need password reset mechanisms
- Requires secure password storage (bcrypt, etc.)

## SIWE Authentication Flow

SIWE eliminates passwords entirely by leveraging Ethereum's public-key cryptography:

```mermaid
sequenceDiagram
    participant User
    participant Browser
    participant Wallet
    participant Rails
    participant Database

    Note over User,Database: Initial Connection
    User->>Browser: Click "Connect Wallet"
    Browser->>Wallet: Request account access
    Wallet-->>Browser: Ethereum address (0x123...)
    Browser->>Rails: Request nonce for address
    Rails->>Database: Find or create user by eth_address
    Database-->>Rails: User with eth_nonce
    Rails-->>Browser: Return nonce

    Note over User,Database: Authentication Challenge
    Browser->>Browser: Build SIWE message with nonce
    Browser->>Wallet: Request signature of SIWE message
    User->>Wallet: Approve signature
    Wallet->>Wallet: Sign message with private key
    Wallet-->>Browser: Cryptographic signature

    Note over User,Database: Verification
    Browser->>Rails: POST /session (address, message, signature)
    Rails->>Rails: Parse SIWE message
    Rails->>Rails: Verify message format
    Rails->>Rails: Check domain matches
    Rails->>Database: Get user's nonce
    Database-->>Rails: eth_nonce
    Rails->>Rails: Verify nonce matches
    Rails->>Rails: Check timestamp validity
    Rails->>Rails: Verify signature cryptographically

    alt All checks pass
        Rails->>Rails: Set session[:user_id]
        Rails->>Database: Rotate nonce (prevent replay)
        Rails-->>Browser: Authentication successful
        Browser-->>User: Redirect to dashboard
    else Any check fails
        Rails-->>Browser: Authentication failed
        Browser-->>User: Show error
    end
```

## Detailed Algorithm Description

### Phase 1: Wallet Connection & Nonce Generation

**Client Side (JavaScript):**
```javascript
// 1. Request wallet connection
const accounts = await ethereum.request({
  method: 'eth_requestAccounts'
});
const address = accounts[0]; // e.g., "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
```

**Server Side (Rails):**
```ruby
# SessionsController#create - load_user callback
def load_user
  @address = params[:eth_address].to_s.downcase

  # Find existing user or create new one
  @user = User.find_or_create_by(eth_address: @address) do |u|
    u.eth_nonce = Siwe::Util.generate_nonce  # Random 8+ character string
  end
end
```

**Why nonce?**
- Prevents replay attacks (same signature can't be reused)
- Unique for each authentication attempt
- Rotated after successful login

### Phase 2: SIWE Message Construction

The SIWE message follows [EIP-4361 specification](https://eips.ethereum.org/EIPS/eip-4361):

```
example.com wants you to sign in with your Ethereum account:
0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb

Sign in to Example App

URI: https://example.com
Version: 1
Chain ID: 1
Nonce: YqnKjNL8pREgNv8s
Issued At: 2025-12-27T10:30:00Z
Expiration Time: 2025-12-27T11:30:00Z
```

**Client Side:**
```javascript
// 2. Build SIWE message
const message = new SiweMessage({
  domain: window.location.host,
  address: address,
  statement: "Sign in to Blockchain Auth",
  uri: window.location.origin,
  version: '1',
  chainId: 1,
  nonce: nonceFromServer,  // Received from Rails
  issuedAt: new Date().toISOString(),
  expirationTime: new Date(Date.now() + 3600000).toISOString() // 1 hour
});

const messageString = message.prepareMessage();
```

### Phase 3: Cryptographic Signature

**Client Side:**
```javascript
// 3. Request signature from wallet
const signature = await ethereum.request({
  method: 'personal_sign',
  params: [messageString, address]
});
// signature: "0x1a2b3c4d..." (130 characters, ECDSA signature)
```

**What happens in the wallet:**
1. User sees human-readable message
2. User clicks "Sign" (not a blockchain transaction - gas-free!)
3. Wallet uses private key to create ECDSA signature
4. Signature proves: "The owner of this address signed this exact message"

### Phase 4: Security Checks & Verification

Before cryptographic verification, multiple security layers are checked:

**Server Side (Rails - SiweAuthenticationService):**
```ruby
# Security checks BEFORE signature verification
def perform_security_checks
  # 1. Per-user rate limiting (3 attempts per minute)
  unless user.can_attempt_auth?
    @errors << "Too many authentication attempts. Please wait 1 minute."
    return false
  end

  # 2. Nonce TTL validation (10 minutes)
  unless user.nonce_valid?
    user.rotate_nonce!
    @errors << "Nonce expired. Please refresh and try again."
    return false
  end

  # 3. One-time nonce usage check (cache-based)
  if user.nonce_used?
    @errors << "Nonce already used. Please request a new one."
    return false
  end

  # Record attempt for rate limiting
  user.record_auth_attempt!
  true
end

# Cryptographic signature verification
def verify_signature
  # Parse the SIWE message string into structured data
  siwe = Siwe::Message.from_message(message)

  # 1. Verify address matches
  return false unless siwe.address.to_s.downcase == user.eth_address

  # 2. Comprehensive SIWE verification (throws exceptions on failure)
  siwe.verify(
    signature,
    request.host_with_port,  # Domain binding
    Time.current.utc.iso8601,  # Timestamp validation
    user.eth_nonce  # Nonce matching
  )
  # This method checks:
  # - Signature is cryptographically valid (ECDSA recovery)
  # - Domain matches current host
  # - Nonce matches user's stored nonce
  # - Timestamp is within valid range (not expired, not future)
  # - Message format follows EIP-4361 spec

  true
rescue Siwe::ExpiredMessage
  @errors << "Signature expired. Please sign a new message."
  false
rescue Siwe::InvalidSignature
  @errors << "Invalid signature. Please try signing again."
  false
rescue Siwe::NonceMismatch
  @errors << "Invalid nonce. Please refresh and request a new nonce."
  false
rescue Siwe::DomainMismatch
  @errors << "Domain mismatch. Please refresh and try again."
  false
# ... handle other exceptions
end
```

**Cryptographic Verification Details:**

The `siwe.verify` method performs ECDSA signature verification:

```ruby
# Pseudocode of what happens inside the siwe gem:
def verify(signature, domain, timestamp, nonce)
  # 1. Recover public key from signature
  public_key = recover_public_key_from_signature(signature, message)

  # 2. Derive Ethereum address from public key
  derived_address = keccak256(public_key)[12..31]  # Last 20 bytes

  # 3. Compare with claimed address
  raise InvalidSignature unless derived_address == self.address

  # 4. Verify domain, nonce, timestamp
  raise DomainMismatch unless self.domain == domain
  raise NonceMismatch unless self.nonce == nonce
  raise ExpiredMessage if Time.parse(self.expirationTime) < timestamp
  # ... more checks
end
```

### Phase 5: Session Creation & Nonce Rotation

**Server Side:**
```ruby
def sign_in_user(user)
  # 1. Create session (standard Rails session)
  session[:user_id] = user.id

  # 2. CRITICAL: Rotate nonce to prevent replay attacks
  user.rotate_nonce!
  # This generates a NEW random nonce and saves it
  # Old signature is now invalid for future login attempts

  redirect_to root_path, notice: "Signed in"
end
```

**Why rotate nonce?**
- Without rotation, an attacker who intercepts the signature could reuse it
- Each nonce is single-use only
- Even if old signatures leak, they're useless

## Multi-Layer Security System

The application implements a comprehensive defense-in-depth strategy with five security layers working together:

### Layer 1: IP-Based Rate Limiting

**Purpose**: Prevent brute-force attacks and DoS attempts at the network level

**Implementation**:
```ruby
# SessionsController
rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, only: :create
```

**Details**:
- Limit: 10 authentication requests per minute per IP address
- Scope: IP-level (protects against distributed attacks)
- Technology: Rails 8 built-in rate limiter
- Action: Rejects requests with HTTP 429 (Too Many Requests)

**Why this matters**: SIWE signature verification is cryptographically expensive. This prevents attackers from overwhelming the server with verification requests.

### Layer 2: Per-User Rate Limiting

**Purpose**: Prevent targeted attacks on specific accounts

**Implementation**:
```ruby
# app/models/concerns/authenticatable.rb
RATE_LIMIT_WINDOW = 1.minute
MAX_AUTH_ATTEMPTS = 3

def can_attempt_auth?
  return true if last_auth_attempt_at.nil?
  return true if last_auth_attempt_at < RATE_LIMIT_WINDOW.ago

  auth_attempts_count < MAX_AUTH_ATTEMPTS
end

def record_auth_attempt!
  if last_auth_attempt_at && last_auth_attempt_at > RATE_LIMIT_WINDOW.ago
    increment!(:auth_attempts_count)
  else
    update!(auth_attempts_count: 1, last_auth_attempt_at: Time.current)
  end
end
```

**Details**:
- Limit: 3 failed attempts per minute per user
- Tracking: Database fields `auth_attempts_count` and `last_auth_attempt_at`
- Reset: Counter resets after 1 minute window expires
- Scope: User-level (even if attacker uses different IPs)

**Database Schema**:
```ruby
t.integer :auth_attempts_count, default: 0, null: false
t.datetime :last_auth_attempt_at
t.index :last_auth_attempt_at
```

### Layer 3: Nonce TTL (Time-To-Live)

**Purpose**: Limit the time window for replay attacks

**Implementation**:
```ruby
# app/models/concerns/authenticatable.rb
NONCE_TTL = 10.minutes

def nonce_valid?
  nonce_issued_at && nonce_issued_at > NONCE_TTL.ago
end
```

**Details**:
- TTL: 10 minutes from nonce issuance
- Tracking: `nonce_issued_at` timestamp in database
- Behavior: Expired nonces trigger automatic rotation
- Cleanup: Automated task rotates stale nonces every 10 minutes

**Database Schema**:
```ruby
t.datetime :nonce_issued_at
t.index :nonce_issued_at
```

**Security benefit**: Even if an attacker intercepts a valid signature, they only have a 10-minute window to use it (and only once - see Layer 4).

### Layer 4: One-Time Nonce Usage

**Purpose**: Prevent replay attacks by ensuring each nonce is used only once

**Implementation**:
```ruby
# app/models/concerns/authenticatable.rb
def nonce_used?
  Rails.cache.read(nonce_used_cache_key).present?
rescue
  false  # Graceful degradation if cache unavailable
end

def mark_nonce_as_used!
  Rails.cache.write(nonce_used_cache_key, true, expires_in: NONCE_TTL)
rescue => e
  Rails.logger.warn("Cache unavailable for nonce marking: #{e.message}")
end

private

def nonce_used_cache_key
  "nonce_used:#{eth_address}:#{eth_nonce}"
end
```

**Details**:
- Storage: Rails cache (Solid Cache - PostgreSQL-backed)
- Cache key: `"nonce_used:{eth_address}:{nonce}"`
- Expiration: Automatically expires after NONCE_TTL (10 minutes)
- Fallback: Graceful degradation if cache is unavailable
- Post-auth: Nonce rotation provides additional protection

**Attack scenario prevented**:
1. Attacker intercepts valid signature
2. Legitimate user successfully authenticates (nonce marked as used + rotated)
3. Attacker attempts to use intercepted signature
4. Layer 4 detects nonce was already used → reject
5. Even if Layer 4 fails, nonce rotation (Layer 5) ensures rejection

### Layer 5: Nonce Rotation After Authentication

**Purpose**: Invalidate old signatures immediately after successful authentication

**Implementation**:
```ruby
# app/controllers/sessions_controller.rb
def sign_in_user(user)
  session[:user_id] = user.id
  user.rotate_nonce!  # CRITICAL: Prevents signature reuse
  redirect_to wallet_path, notice: "Successfully signed in"
end

# app/models/concerns/authenticatable.rb
def rotate_nonce!
  update!(
    eth_nonce: Siwe::Util.generate_nonce,
    nonce_issued_at: Time.current,
    auth_attempts_count: 0,
    last_auth_attempt_at: nil
  )
end
```

**Details**:
- Trigger: Immediately after successful authentication
- Action: Generate new cryptographically random nonce
- Side effects: Reset rate limit counters, update timestamp
- Security: Old signature becomes permanently invalid

**Why this is critical**: Even if an attacker bypasses cache-based checks, the rotated nonce ensures the old signature will fail `NonceMismatch` validation.

### Layer 6: Automated Cleanup

**Purpose**: Remove stale data and maintain security hygiene

**Implementation**:
```ruby
# config/schedule.rb (whenever gem)
every 1.day, at: "2:00 am" do
  rake "users:cleanup_unverified"
end

every 10.minutes do
  rake "users:rotate_stale_nonces"
end

# lib/tasks/users.rake
task cleanup_unverified: :environment do
  count = User.stale_unverified.delete_all
  Rails.logger.info("Cleanup: Deleted #{count} unverified users")
end

task rotate_stale_nonces: :environment do
  User.with_stale_nonces.find_each { |user| user.rotate_nonce! }
end
```

**Details**:
- **Daily cleanup** (2:00 AM): Remove users who requested nonce but never authenticated (>7 days old)
- **10-minute rotation**: Proactively rotate nonces older than TTL
- **Benefits**: Reduces attack surface, cleans zombie accounts, prevents nonce staleness

**Database Scopes**:
```ruby
scope :unverified, -> { where(verified: false) }
scope :stale_unverified, -> { unverified.where("created_at < ?", 7.days.ago) }
scope :with_stale_nonces, -> { where("nonce_issued_at < ? OR nonce_issued_at IS NULL", NONCE_TTL.ago) }
```

### Security Layers Interaction

```mermaid
graph TD
    A[Authentication Request] --> B{Layer 1: IP Rate Limit?}
    B -->|Exceeded| FAIL1[HTTP 429: Too Many Requests]
    B -->|OK| C{Layer 2: User Rate Limit?}

    C -->|Exceeded| FAIL2[Error: Too many attempts]
    C -->|OK| D{Layer 3: Nonce TTL Valid?}

    D -->|Expired| E[Auto-rotate nonce]
    E --> FAIL3[Error: Nonce expired]
    D -->|Valid| F{Layer 4: Nonce Used Before?}

    F -->|Yes| FAIL4[Error: Nonce already used]
    F -->|No| G[Record attempt + Mark nonce as used]

    G --> H[Cryptographic Verification]
    H --> I{Signature Valid?}

    I -->|No| FAIL5[Error: Invalid signature]
    I -->|Yes| J[Layer 5: Rotate Nonce]

    J --> K[Create Session]
    K --> SUCCESS[Authentication Complete]

    style SUCCESS fill:#90EE90
    style FAIL1 fill:#FFB6C6
    style FAIL2 fill:#FFB6C6
    style FAIL3 fill:#FFB6C6
    style FAIL4 fill:#FFB6C6
    style FAIL5 fill:#FFB6C6
```

### Security Configuration Constants

All security parameters are centralized in `app/models/concerns/authenticatable.rb`:

```ruby
module Authenticatable
  NONCE_TTL = 10.minutes          # Layer 3: Nonce expiration
  MAX_AUTH_ATTEMPTS = 3            # Layer 2: Max failed attempts
  RATE_LIMIT_WINDOW = 1.minute    # Layer 2: Rate limit window
end
```

And in `app/controllers/sessions_controller.rb`:
```ruby
rate_limit to: 10, within: 1.minute  # Layer 1: IP-based limit
```

### Attack Scenarios & Mitigations

| Attack Scenario | Without Protection | With Multi-Layer Security |
|----------------|-------------------|--------------------------|
| **Brute Force** | Attacker tries thousands of signatures | Layer 1 (IP) + Layer 2 (user) block after 3-10 attempts |
| **Replay Attack** | Old signature works forever | Layer 4 (one-time use) + Layer 5 (rotation) prevent reuse |
| **Time-based Replay** | Signature valid indefinitely | Layer 3 (TTL) limits window to 10 minutes |
| **Distributed Attack** | Different IPs bypass IP limit | Layer 2 (per-user limit) protects individual accounts |
| **DoS via Crypto** | Expensive ECDSA operations overwhelm server | Layer 1 (IP limit) prevents before reaching crypto code |
| **Zombie Accounts** | Abandoned registrations accumulate | Layer 6 (cleanup) removes stale unverified users |

## Security Considerations

### 1. **Replay Attack Prevention**
- **Problem**: Attacker intercepts valid signature and tries to reuse it
- **Solution**: Nonce rotation after each successful login
- **Implementation**: `user.rotate_nonce!` in `sign_in_user`

### 2. **Man-in-the-Middle (MITM) Protection**
- **Problem**: Attacker modifies SIWE message in transit
- **Solution**: Message is signed; any modification invalidates signature
- **Implementation**: Cryptographic signature verification

### 3. **Domain Binding**
- **Problem**: Signature from site A used on site B (cross-site attack)
- **Solution**: Domain is part of signed message
- **Implementation**: `expected_domain = request.host_with_port` check

### 4. **Time-based Attacks**
- **Problem**: Old signatures used days/weeks later
- **Solution**: Expiration time in SIWE message
- **Implementation**: `ExpiredMessage` exception handling

### 5. **Nonce Prediction**
- **Problem**: Attacker predicts next nonce
- **Solution**: Cryptographically random nonce generation
- **Implementation**: `Siwe::Util.generate_nonce` (random 8+ chars)

### 6. **Address Case Sensitivity**
- **Problem**: Ethereum addresses are case-insensitive, but string comparison isn't
- **Solution**: Normalize to lowercase before comparison
- **Implementation**: `eth_address.downcase` everywhere

## Comparison Table

| Aspect | Traditional Password Auth | SIWE Authentication |
|--------|---------------------------|---------------------|
| **User Secret** | Password (memorized) | Private key (in wallet) |
| **Server Stores** | Password hash (bcrypt) | Ethereum address + nonce |
| **Authentication** | Compare password hash | Verify cryptographic signature |
| **Credentials** | Username + Password | Ethereum address + Signature |
| **Password Reset** | Email recovery needed | Not applicable (no password) |
| **Phishing Risk** | High (users enter password) | Low (signature is site-specific) |
| **Database Breach Impact** | Hashes can be cracked | Addresses are public anyway |
| **User Experience** | Type password each time | One click in wallet |
| **Registration** | Email + Password form | Connect wallet (instant) |
| **Multi-factor** | Needs separate setup | Wallet itself is 2FA |
| **Lost Credentials** | Password reset flow | Lose wallet = lose access* |
| **Crypto Knowledge** | Not required | Must have wallet |

\* *Users should backup their wallet seed phrase*

## Flow Diagrams

### Complete Authentication Sequence

```mermaid
graph TD
    A[User Visits Site] --> B{Has Wallet?}
    B -->|No| C[Install MetaMask/WalletConnect]
    B -->|Yes| D[Click Connect Wallet]
    C --> D

    D --> E[Wallet Shows Accounts]
    E --> F[User Selects Account]
    F --> G[Frontend Gets Address]

    G --> H[Request Nonce from Server]
    H --> I{User Exists?}
    I -->|No| J[Create User with Random Nonce]
    I -->|Yes| K[Return Existing Nonce]
    J --> L[Return Nonce to Frontend]
    K --> L

    L --> M[Build SIWE Message]
    M --> N[Request Signature from Wallet]
    N --> O[User Approves in Wallet]
    O --> P[Wallet Signs with Private Key]
    P --> Q[Return Signature to Frontend]

    Q --> R[Send Address + Message + Signature to Server]
    R --> R1{IP Rate Limit OK?}
    R1 -->|No| Z1[HTTP 429: Too Many Requests]
    R1 -->|Yes| S[Parse SIWE Message]

    S --> S1{User Rate Limit OK?}
    S1 -->|No| Z[Reject: Too many attempts]
    S1 -->|Yes| S2{Nonce TTL Valid?}
    S2 -->|No| Z
    S2 -->|Yes| S3{Nonce Not Used?}
    S3 -->|No| Z
    S3 -->|Yes| S4[Record Attempt + Mark Nonce Used]

    S4 --> T{Verify Address Match?}
    T -->|No| Z
    T -->|Yes| U{Verify Domain?}
    U -->|No| Z
    U -->|Yes| V{Verify Nonce?}
    V -->|No| Z
    V -->|Yes| W{Verify Signature?}
    W -->|No| Z
    W -->|Yes| X{Check Expiration?}
    X -->|Expired| Z
    X -->|Valid| Y[Create Session + Rotate Nonce]

    Y --> AA[User Authenticated]
    Z --> AB[Show Error to User]
    Z1 --> AB
```

### Verification Process Detail

```mermaid
flowchart LR
    A[Receive Signature] --> SEC1{IP Rate Limit OK?}
    SEC1 -->|No| FAIL0[HTTP 429: Too Many Requests]
    SEC1 -->|Yes| SEC2{User Rate Limit OK?}

    SEC2 -->|No| FAIL_SEC1[Reject: Too many attempts]
    SEC2 -->|Yes| SEC3{Nonce TTL Valid?}

    SEC3 -->|No| FAIL_SEC2[Reject: Nonce expired]
    SEC3 -->|Yes| SEC4{Nonce Not Used?}

    SEC4 -->|No| FAIL_SEC3[Reject: Nonce already used]
    SEC4 -->|Yes| SEC5[Record Attempt + Mark Nonce Used]

    SEC5 --> B[Parse SIWE Message]
    B --> C{Format Valid?}
    C -->|No| FAIL1[Reject: Invalid Format]
    C -->|Yes| D[Extract Components]

    D --> E{Address Matches Claim?}
    E -->|No| FAIL2[Reject: Address Mismatch]
    E -->|Yes| F{Domain Matches Server?}

    F -->|No| FAIL3[Reject: Domain Mismatch]
    F -->|Yes| G[Get User's Nonce from DB]

    G --> H{Nonce Matches Message?}
    H -->|No| FAIL4[Reject: Invalid/Reused Nonce]
    H -->|Yes| I[Check Timestamp]

    I --> J{Not Expired?}
    J -->|No| FAIL5[Reject: Expired]
    J -->|Yes| K{Not Future?}

    K -->|No| FAIL6[Reject: Not Valid Yet]
    K -->|Yes| L[Verify ECDSA Signature]

    L --> M{Signature Valid?}
    M -->|No| FAIL7[Reject: Invalid Signature]
    M -->|Yes| N[All Checks Passed]

    N --> O[Create Session]
    O --> P[Rotate Nonce]
    P --> SUCCESS[Authentication Complete]

    style SUCCESS fill:#90EE90
    style FAIL0 fill:#FFB6C6
    style FAIL_SEC1 fill:#FFB6C6
    style FAIL_SEC2 fill:#FFB6C6
    style FAIL_SEC3 fill:#FFB6C6
    style FAIL1 fill:#FFB6C6
    style FAIL2 fill:#FFB6C6
    style FAIL3 fill:#FFB6C6
    style FAIL4 fill:#FFB6C6
    style FAIL5 fill:#FFB6C6
    style FAIL6 fill:#FFB6C6
    style FAIL7 fill:#FFB6C6
```

## Code References

Key files implementing this algorithm:

- **SessionsController** (`app/controllers/sessions_controller.rb`): Main authentication logic, IP-based rate limiting
- **SiweAuthenticationService** (`app/services/siwe_authentication_service.rb`): Security checks and SIWE verification
- **Authenticatable Concern** (`app/models/concerns/authenticatable.rb`): Multi-layer security implementation (rate limiting, TTL, nonce management)
- **User Model** (`app/models/user.rb`): Nonce management and address validation
- **Application Controller** (`app/controllers/application_controller.rb`): Session helpers
- **Maintenance Tasks** (`lib/tasks/users.rake`): Automated cleanup and security tasks
- **Cron Schedule** (`config/schedule.rb`): Scheduled security maintenance
- **Routes** (`config/routes.rb`): Authentication endpoints

## Additional Resources

- [EIP-4361: Sign-In with Ethereum](https://eips.ethereum.org/EIPS/eip-4361)
- [SIWE Ruby Gem Documentation](https://github.com/spruceid/siwe-ruby)
- [Ethereum Signature Verification](https://docs.ethers.org/v5/api/signer/#Signer-signMessage)
- [ECDSA Signatures Explained](https://cryptobook.nakov.com/digital-signatures/ecdsa-sign-verify-messages)

---

**Last Updated**: December 28, 2025
**Version**: 2.0 - Added Multi-Layer Security System documentation
