# DocFlow AI - Database Quick Start

Get the database up and running in 5 minutes.

## Prerequisites

1. **Install uv** (Python package manager):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

2. **PostgreSQL running** (via Docker or local):
   ```bash
   # Already running in docker-compose (deploy/n8n/docker-compose.yml)
   # Or start just Postgres:
   docker run -d \
     --name docflow-postgres \
     -e POSTGRES_USER=n8nuser \
     -e POSTGRES_PASSWORD=n8npassword \
     -e POSTGRES_DB=docflow \
     -p 5432:5432 \
     postgres:16
   ```

## Quick Setup

```bash
cd db

# 1. Install dependencies
./scripts/migrate.sh install

# 2. Set database URL (async driver)
export DATABASE_URL="postgresql+psycopg://n8nuser:n8npassword@localhost:5432/docflow"

# 3. Apply migrations (create all tables)
./scripts/migrate.sh upgrade

# 4. Load sample data (optional, for development)
./scripts/migrate.sh seed
```

## Verify Setup

```bash
# Check migration status
./scripts/migrate.sh status

# Connect to database and verify tables
psql postgresql://n8nuser:n8npassword@localhost:5432/docflow -c "\dt"
```

You should see tables like: `clients`, `users`, `process_types`, `prompts`, `configurations`, `processes`, `documents`, `audit_logs`, etc.

## What's Next?

- Read [README.md](./README.md) for detailed schema documentation
- Explore seed data with sample clients and configurations
- Start building backend-api service to interact with the database

## Troubleshooting

**Issue: "uv: command not found"**
```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Reload shell
source ~/.bashrc  # or ~/.zshrc
```

**Issue: "connection refused to localhost:5432"**
```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Or check local PostgreSQL
sudo systemctl status postgresql
```

**Issue: "database does not exist"**
```bash
# Create database manually
psql postgresql://n8nuser:n8npassword@localhost:5432/postgres -c "CREATE DATABASE docflow;"
```

## Commands Reference

```bash
./scripts/migrate.sh install     # Install dependencies
./scripts/migrate.sh upgrade     # Apply migrations
./scripts/migrate.sh downgrade   # Rollback last migration
./scripts/migrate.sh reset       # Drop all tables
./scripts/migrate.sh fresh       # Drop all + migrate + seed
./scripts/migrate.sh seed        # Load sample data
./scripts/migrate.sh status      # Show migration status
./scripts/migrate.sh new "name"  # Create new migration
```

## Environment Variables

```bash
# Required: Database URL (async driver)
export DATABASE_URL="postgresql+psycopg://user:pass@host:5432/dbname"

# Optional
export ENVIRONMENT=development
export LOG_LEVEL=INFO
```

Copy `.env.example` to `.env` and customize:
```bash
cp .env.example .env
# Edit .env with your values
```
