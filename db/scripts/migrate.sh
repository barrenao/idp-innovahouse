#!/bin/bash
# ========================================
# DocFlow AI - Database Migration Script
# Using UV package manager
# ========================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DATABASE_URL="${DATABASE_URL:-postgresql+psycopg://n8nuser:n8npassword@localhost:5432/docflow}"
ACTION="${1:-help}"

# Change to db directory
cd "$(dirname "$0")/.."

echo -e "${GREEN}DocFlow AI - Database Migration Tool (UV)${NC}"
echo "Database: $DATABASE_URL"
echo ""

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo -e "${RED}Error: 'uv' is not installed.${NC}"
    echo "Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Ensure dependencies are synced
echo -e "${YELLOW}Syncing dependencies with uv...${NC}"
uv sync --quiet

case "$ACTION" in
    "upgrade")
        echo -e "${YELLOW}Applying migrations...${NC}"
        uv run alembic -c alembic.ini upgrade head
        echo -e "${GREEN}✓ Migrations applied successfully${NC}"
        ;;

    "downgrade")
        echo -e "${YELLOW}Rolling back last migration...${NC}"
        uv run alembic -c alembic.ini downgrade -1
        echo -e "${GREEN}✓ Rollback complete${NC}"
        ;;

    "reset")
        echo -e "${RED}WARNING: This will drop all tables!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            echo -e "${YELLOW}Rolling back all migrations...${NC}"
            uv run alembic -c alembic.ini downgrade base
            echo -e "${GREEN}✓ Database reset complete${NC}"
        else
            echo "Cancelled."
        fi
        ;;

    "seed")
        echo -e "${YELLOW}Loading seed data...${NC}"
        psql "$DATABASE_URL" -f seeds/001_sample_data.sql
        echo -e "${GREEN}✓ Seed data loaded${NC}"
        ;;

    "fresh")
        echo -e "${YELLOW}Fresh migration (reset + upgrade + seed)...${NC}"
        echo -e "${RED}WARNING: This will drop all tables and data!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            echo "1/3: Rolling back..."
            uv run alembic -c alembic.ini downgrade base || true
            echo "2/3: Applying migrations..."
            uv run alembic -c alembic.ini upgrade head
            echo "3/3: Loading seed data..."
            psql "$DATABASE_URL" -f seeds/001_sample_data.sql
            echo -e "${GREEN}✓ Fresh database ready${NC}"
        else
            echo "Cancelled."
        fi
        ;;

    "status")
        echo -e "${YELLOW}Migration status:${NC}"
        uv run alembic -c alembic.ini current
        echo ""
        uv run alembic -c alembic.ini history
        ;;

    "new")
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Migration name required${NC}"
            echo "Usage: $0 new \"migration_name\""
            exit 1
        fi
        echo -e "${YELLOW}Creating new migration: $2${NC}"
        uv run alembic -c alembic.ini revision -m "$2"
        echo -e "${GREEN}✓ Migration file created${NC}"
        ;;

    "sync")
        echo -e "${YELLOW}Syncing dependencies...${NC}"
        uv sync
        echo -e "${GREEN}✓ Dependencies synced${NC}"
        ;;

    "install")
        echo -e "${YELLOW}Installing all dependencies (including dev)...${NC}"
        uv sync --all-extras
        echo -e "${GREEN}✓ All dependencies installed${NC}"
        ;;

    "help"|*)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  upgrade     Apply all pending migrations"
        echo "  downgrade   Rollback last migration"
        echo "  reset       Drop all tables (downgrade to base)"
        echo "  seed        Load sample data (for development)"
        echo "  fresh       Reset + Upgrade + Seed (full reset)"
        echo "  status      Show current migration status"
        echo "  new <name>  Create new migration file"
        echo "  sync        Sync dependencies with uv"
        echo "  install     Install all dependencies (including dev)"
        echo "  help        Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  DATABASE_URL    PostgreSQL connection URL (async driver)"
        echo "                  Default: postgresql+psycopg://n8nuser:n8npassword@localhost:5432/docflow"
        echo ""
        echo "Prerequisites:"
        echo "  Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo ""
        echo "Examples:"
        echo "  $0 install          # First time setup"
        echo "  $0 upgrade          # Apply migrations"
        echo "  $0 fresh            # Fresh database"
        echo "  DATABASE_URL=postgresql+psycopg://user:pass@host:5432/db $0 upgrade"
        ;;
esac
