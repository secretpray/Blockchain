# Blockchain Auth - SIWE Rails 8 (gem 'siwe')

[![Ruby Version](https://img.shields.io/badge/ruby-3.4.1-red.svg)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/rails-8.1.1-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-9.3+-blue.svg)](https://www.postgresql.org/)
[![PWA](https://img.shields.io/badge/PWA-enabled-orange.svg)](https://web.dev/progressive-web-apps/)
[![SIWE](https://img.shields.io/badge/SIWE-EIP--4361-purple.svg)](https://eips.ethereum.org/EIPS/eip-4361)
[![EIP-191](https://img.shields.io/badge/EIP--191-signatures-purple.svg)](https://eips.ethereum.org/EIPS/eip-191)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A modern Progressive Web Application (PWA) for passwordless user authentication via Ethereum wallets using the Sign-In With Ethereum (SIWE) protocol. It implements advanced cache-based security architecture with offline capabilities and real-time updates.

## What You Get

- **EIP-4361** Sign-In with Ethereum (SIWE) - Passwordless authentication protocol
- **EIP-191** Ethereum Signed Messages - Signature verification with prefix
- **PWA Support** Progressive Web Application with installable app experience
- **Service Worker** Offline caching with cache-first and network-first strategies
- **Web Push Notifications** Real-time notifications via Service Worker API
- **Cache-Based Nonce Management** Stateless nonce handling with auto-expiration (10 min TTL)
- **One-Time Nonce Protection** Prevents replay attacks and concurrent authentication attempts
- **IP-Based Rate Limiting** Multi-layer DDoS protection (10 req/min for auth, 30 req/min for nonce)
- **Turbo Streams** Real-time UI updates without page reloads (WebSocket-based)
- **No Phantom Users** Users created only after successful signature verification
- **Solid Cache/Queue/Cable** Rails 8 built-in PostgreSQL-backed infrastructure
- **EIP-55 Compatible** Normalized Ethereum address handling (lowercase storage)

## Documentation

- [SIWE Authentication Algorithm Documentation](docs/AUTHENTICATION.md) - Detailed explanation of the cache-based authentication flow with diagrams

## Project Description

Blockchain Auth is a modern Ruby on Rails 8 application that demonstrates Web3 authentication without traditional passwords. Users connect their crypto wallet (MetaMask, WalletConnect, etc.), sign a message to prove ownership of an address, and gain access to protected sections of the application.

## Main Features

### Authentication & Security
- User registration and authentication via Ethereum wallets (EIP-4361)
- Cryptographic signature verification using EIP-191
- Nonce generation and validation for secure signature verification
- User session management with secure cookies
- REST API for retrieving user information by Ethereum addresses
- Secure storage of Ethereum addresses with normalization and validation
- Multi-layer security system (cache-based):
  - IP-based rate limiting (10 requests/min for authentication)
  - Nonce endpoint rate limiting (30 requests/min per IP:address)
  - Nonce TTL with auto-expiration (10 minutes)
  - One-time nonce usage protection
  - No phantom users (created only after successful verification)

### Progressive Web App (PWA)
- Installable app experience on desktop and mobile devices
- Offline-first architecture with Service Worker
- Smart caching strategies:
  - Cache-first for static assets (CSS, JS, fonts, images)
  - Network-first for HTML pages with offline fallback
  - API requests bypass cache for real-time data
- Automatic cache versioning and cleanup
- Web Push Notifications support
- App manifest with custom icons and theme
- Works seamlessly offline after first visit

## Technology Stack

### Backend

- **Ruby** 3.4.1
- **Rails** 8.1.1
- **PostgreSQL** - primary database for user data, cache, queue, and cable storage
- **SIWE Gem** - Sign-In With Ethereum library implementing EIP-4361 and EIP-191
- **Puma** - multi-threaded web server
- **Solid Cache** - PostgreSQL-backed cache for nonce management and rate limiting
- **Solid Queue** - database-backed job queue for background processing
- **Solid Cable** - database-backed WebSocket for Turbo Streams

### Frontend & PWA

- **Service Worker** - offline caching, push notifications, and background sync
- **Web App Manifest** - PWA metadata for installable app experience
- **Hotwire** (Turbo Rails + Stimulus) - SPA-like experience with minimal JavaScript
- **Turbo Streams** - real-time partial page updates via WebSocket
- **Tailwind CSS** - utility-first CSS framework
- **Importmap** - modern JavaScript dependency management (no bundler)
- **Propshaft** - Rails 8 asset pipeline with fingerprinting

### Web3 & Ethereum Protocols

- **EIP-4361** - Sign-In with Ethereum message format specification
- **EIP-191** - Signed data standard for signature verification
- **EIP-55** - Checksummed address normalization (lowercase storage)
- **Web3 Provider API** - MetaMask, WalletConnect, and other wallet integrations

### Deployment

- **Kamal** - zero-downtime deployment in Docker containers
- **Thruster** - HTTP/2 caching proxy and compression for Puma

## System Dependencies

### Required

- Ruby 3.4.1 or higher
- PostgreSQL 9.3 or higher
- Node.js (for asset pipeline)
- Yarn or npm

### For macOS (with Homebrew)

```bash
brew install ruby postgresql@17
brew services start postgresql@17
```

### For Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install ruby-full postgresql postgresql-contrib libpq-dev
sudo systemctl start postgresql
```

## Installation and Setup

### 1. Clone the Repository

```bash
git clone https://github.com/secretpray/blockchain-auth.git
cd blockchain-auth
```

### 2. Install Dependencies

```bash
# Install Ruby gems
bundle install

# Install JavaScript dependencies (if any)
bin/setup
```

### 3. Database Setup

```bash
# Create databases
bin/rails db:create

# Run migrations
bin/rails db:migrate
```

For custom PostgreSQL configuration, edit `config/database.yml`:

```yaml
development:
  adapter: postgresql
  database: siwe_rails_development
  username: your_username
  password: your_password
  host: localhost
  port: 5432
```

### 4. Environment Variables Setup

Create a `.env` file in the project root (optional):

```bash
RAILS_ENV=development
DATABASE_URL=postgresql://localhost/siwe_rails_development
```

### 5. Run the Application

```bash
# Using Makefile (recommended)
make dev        # Start development server
make fresh      # Clean caches and start
make help       # Show all available commands

# Or directly
bin/dev
```

The application will be available at: `http://localhost:3000`

### 6. Run Tests (optional)

```bash
bin/rails test
```

## Project Structure

```
app/
├── controllers/
│   ├── sessions_controller.rb       # Session management and SIWE authentication (EIP-4361)
│   ├── wallet_controller.rb         # Wallet dashboard
│   └── api/v1/users_controller.rb   # Nonce generation (cache-based, rate-limited)
├── models/
│   └── user.rb                       # User model with EIP-55 address normalization
├── services/
│   └── siwe_authentication_service.rb # SIWE verification (EIP-4361 + EIP-191)
├── views/
│   ├── root/                         # Home page with wallet login
│   ├── wallet/                       # Wallet dashboard
│   └── pwa/
│       ├── service-worker.js         # PWA Service Worker (offline caching)
│       └── manifest.json.erb         # PWA Web App Manifest
└── javascript/
    └── controllers/
        └── wallet_login_controller.js # Web3 wallet integration (Stimulus)
```

## API Endpoints

### Get Nonce for Ethereum Address

```http
GET /api/v1/users/:eth_address
```

**Parameters:**
- `eth_address` - Ethereum address (0x prefixed, 40 hex characters)

**Response:**
```json
{ "eth_nonce": "a1b2c3d4..." }
```

**Rate limiting:** 30 requests per minute per IP:address combination

Returns a nonce for SIWE authentication. Nonce is stored in cache (not database) with 10 minute TTL and auto-expires.

## Main Routes

- `GET /` - Home page (includes sign-in form for guests)
- `POST /session` - Sign in via SIWE (auto-creates user if needed, using Turbo Streams)
- `DELETE /session` - Sign out
- `GET /wallet` - Wallet dashboard (requires authentication)

## Security

The project includes the following security tools:

- **Brakeman** - static analysis for vulnerabilities
- **Bundler Audit** - checking gems for known security issues
- **RuboCop Rails Omakase** - code linter

Running security checks:

```bash
# Using Makefile (runs all checks)
make pre-pr

# Or manually
bundle exec bundler-audit check --update
bundle exec rubocop
bundle exec brakeman
```

## Deployment

The application is ready for deployment via Kamal in Docker containers:

```bash
kamal setup
kamal deploy
```

## Development

### Useful Commands

```bash
# Rails console
bin/rails console

# View routes
bin/rails routes

# Reset database
bin/rails db:reset

# Generate migration
bin/rails generate migration MigrationName
```

## Cache-Based Architecture

The application uses a **cache-based approach** for nonce management:

- **Nonce Storage**: Rails.cache (Solid Cache in production)
- **Auto-Expiration**: Nonces expire automatically after 10 minutes
- **No Phantom Users**: Users created only after successful verification
- **No Cron Jobs**: All cleanup handled by cache TTL

**Cache Store Configuration:**
- Development: MemoryStore
- Production: Solid Cache (PostgreSQL-backed)

This eliminates the need for database cleanup tasks and scheduled jobs.

## Progressive Web App (PWA) Architecture

The application implements a full-featured PWA with Service Worker technology for offline capabilities:

### Service Worker Features

- **Offline Caching**: Assets and pages cached for offline access
- **Smart Cache Strategies**:
  - **Cache-First**: Static assets (CSS, JS, fonts, images) served from cache for instant loading
  - **Network-First**: HTML pages fetched from network with cache fallback when offline
  - **API Bypass**: API requests always go to network for real-time data
- **Automatic Cache Management**: Old caches automatically cleaned up on version updates
- **Web Push Notifications**: Support for push notifications via Service Worker API
- **Background Sync**: Queued actions can be synced when connection restored

### Installation

Users can install the app to their device:

1. **Desktop**: Click "Install" button in browser address bar (Chrome, Edge)
2. **Mobile**: Tap "Add to Home Screen" from browser menu
3. **Standalone Mode**: App runs in its own window without browser UI

### Offline Functionality

After first visit, the app works offline:
- Static assets load instantly from cache
- Previously visited pages accessible offline
- Offline page shown for new navigation attempts
- Seamless transition when connection restored

### PWA Files

- `app/views/pwa/service-worker.js` - Service Worker implementation
- `app/views/pwa/manifest.json.erb` - Web App Manifest with icons and theme
- `app/assets/images/` - PWA icons (192x192, 512x512, maskable)

## License

MIT License
