# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an n8n workflow automation deployment project using Docker Compose. It deploys n8n (v2.2.5) with PostgreSQL backend and custom task runners for JavaScript and Python code execution.

## Commands

All commands should be run from `deploy/n8n/`:

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Rebuild custom runners image after modifying Dockerfile or dependencies
docker-compose build task-runners

# View logs
docker-compose logs -f n8n
docker-compose logs -f task-runners

# Access n8n UI
# http://localhost:5678
```

## Architecture

```
deploy/n8n/
├── docker-compose.yml       # Main orchestration (postgres, n8n, task-runners)
├── n8niorunners/
│   ├── Dockerfile           # Custom runners image with additional packages
│   └── n8n-task-runners.json # Runner configuration (ports, allowed modules)
├── scripts/
│   └── init-data.sh         # PostgreSQL user initialization
├── services/
│   ├── frontend/            # Frontend service  preact app (if any) 
│   │
│   └── backend/             # Backend service (if any)
```

### Services

1. **postgres** - PostgreSQL 18 database for n8n persistence
2. **n8n** - Main n8n instance (port 5678) with external runners enabled
3. **task-runners** - Custom image (`n8nio/runners:custom`) with JavaScript and Python runners
4. **frontend** - Frontend service for custom UI
5. **backend** -  Backend service for custom APIs

### Task Runners Configuration

JavaScript runner (port 5681):
- Allowed external packages: `moment`, `uuid`
- Allowed builtin: `crypto`

Python runner (port 5682):
- Allowed external packages: `numpy`, `pandas`
- Allowed stdlib: `json`

### Adding New Dependencies

To add packages to task runners, modify `deploy/n8n/n8niorunners/Dockerfile`:
- JavaScript: Add to the `pnpm add` command
- Python: Add to the `uv pip install` command

Then update allowed modules in `n8n-task-runners.json` under `env-overrides`.
