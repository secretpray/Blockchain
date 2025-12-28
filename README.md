# Blockchain Auth - SIWE Rails 8

[![Ruby Version](https://img.shields.io/badge/ruby-3.4.1-red.svg)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/rails-8.1.1-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-9.3+-blue.svg)](https://www.postgresql.org/)
[![SIWE](https://img.shields.io/badge/SIWE-EIP--4361-purple.svg)](https://eips.ethereum.org/EIPS/eip-4361)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Web application for user authentication via Ethereum wallets using the Sign-In With Ethereum (SIWE) protocol.

## Documentation

- [SIWE Authentication Algorithm Documentation](docs/AUTHENTICATION.md) - Detailed explanation of the authentication flow with diagrams
- [Scheduled Tasks Setup](docs/WHENEVER_SETUP.md) - Cron jobs configuration using whenever gem

## Project Description

Blockchain Auth is a modern Ruby on Rails 8 application that demonstrates Web3 authentication without traditional passwords. Users connect their crypto wallet (MetaMask, WalletConnect, etc.), sign a message to prove ownership of an address, and gain access to protected sections of the application.

## Main Features

- User registration and authentication via Ethereum wallets
- Nonce generation and validation for secure signature verification
- User session management
- REST API for retrieving user information by Ethereum addresses
- Secure storage of Ethereum addresses with normalization and validation
- Multi-layer security system:
  - IP-based rate limiting (10 requests/min)
  - Per-user rate limiting (3 attempts/min)
  - Nonce TTL validation (10 minutes)
  - One-time nonce usage protection
  - Automated cleanup of stale data

## Technology Stack

### Backend

- **Ruby** 3.4.1
- **Rails** 8.1.1
- **PostgreSQL** - primary database
- **SIWE** (Sign-In With Ethereum) - authentication protocol
- **Puma** - web server
- **Solid Cache/Queue/Cable** - Rails 8 built-in solutions for caching, job queues, and WebSocket
- **Whenever** - cron job management for scheduled tasks

### Frontend

- **Hotwire** (Turbo Rails + Stimulus) - for SPA-like experience
- **Tailwind CSS** - for styling
- **Importmap** - JavaScript dependency management
- **Propshaft** - modern asset pipeline

### Deployment

- **Kamal** - deployment in Docker containers
- **Thruster** - HTTP caching and compression for Puma

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
# For development environment
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
│   ├── sessions_controller.rb       # Session management and SIWE authentication
│   ├── users_controller.rb          # User registration
│   └── api/v1/users_controller.rb   # REST API
├── models/
│   ├── concerns/
│   │   └── authenticatable.rb       # Security methods (rate limiting, nonce management)
│   └── user.rb                       # User model with Ethereum address
├── services/
│   └── siwe_authentication_service.rb # SIWE verification logic
└── views/
    ├── home/                         # Home page
    ├── sessions/                     # Sign-in pages
    └── users/                        # Registration pages

config/
└── schedule.rb                       # Cron jobs schedule (whenever)

lib/tasks/
└── users.rake                        # Maintenance tasks
```

## API Endpoints

### Get List of Users

```http
GET /api/v1/users
```

### Get User by Ethereum Address

```http
GET /api/v1/users/:eth_address
```

## Main Routes

- `GET /` - Home page
- `GET /users/new` - New user registration
- `POST /users` - Create user
- `GET /session/new` - Sign-in page
- `POST /session` - Sign in via SIWE
- `DELETE /session` - Sign out

## Security

The project includes the following security tools:

- **Brakeman** - static analysis for vulnerabilities
- **Bundler Audit** - checking gems for known security issues
- **RuboCop Rails Omakase** - code linter

Running security checks:

```bash
bundle exec brakeman
bundle exec bundler-audit check --update
bundle exec rubocop
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

## Scheduled Tasks

The application uses **whenever** gem for automated maintenance tasks:

### Available Tasks

```bash
# Manual execution
bin/rails users:cleanup_unverified  # Remove stale unverified users (>7 days)
bin/rails users:rotate_stale_nonces # Rotate expired nonces
bin/rails users:stats                # Show user statistics
```

### Cron Schedule

```bash
# Preview cron jobs
bundle exec whenever

# Install to crontab (production)
bundle exec whenever --update-crontab
```

**Default schedule:**
- Daily cleanup at 2:00 AM
- Nonce rotation every 10 minutes

For detailed setup instructions, see [Scheduled Tasks Documentation](docs/WHENEVER_SETUP.md).

## License

MIT License
