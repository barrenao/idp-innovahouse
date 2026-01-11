# DocFlow AI - Database Schema

Multi-tenant PostgreSQL database for intelligent document processing SaaS platform.

## Overview

This database supports:
- **Multi-tenancy**: Isolated data per client with flexible configurations
- **Dynamic Processing**: Configurable workflows using client_id, process_type_id, and version
- **Audit Trail**: Immutable logging for compliance and billing
- **Versioned Prompts**: LLM instructions versioned per process type
- **HITL Support**: Human-in-the-Loop review queues

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      TENANT LAYER                            │
├─────────────┬───────────────────────────────────────────────┤
│   clients   │  users                                         │
│  (tenants)  │  (portal access, HITL operators)               │
└─────────────┴───────────────────────────────────────────────┘
                             │
                             │ has many
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   CONFIGURATION LAYER                        │
├──────────────┬────────────────┬─────────────────────────────┤
│process_types │  prompts       │  configurations             │
│(workflow def)│ (LLM versioned)│  (client-specific rules)    │
└──────────────┴────────────────┴─────────────────────────────┘
                             │
                             │ uses
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    PROCESSING LAYER                          │
├──────────────┬──────────────────────────────────────────────┤
│  processes   │  documents                                    │
│ (job/batch)  │  (individual files)                           │
└──────────────┴──────────────────────────────────────────────┘
                             │
                             │ generates
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                  OUTPUT & AUDIT LAYER                        │
├──────────────┬──────────────┬───────────────────────────────┤
│ audit_logs   │output_actions│  notifications                │
│(immutable log)│(email, ERP)  │  (HITL alerts)                │
└──────────────┴──────────────┴───────────────────────────────┘
```

## Tables

### 1. Tenant & Authentication

#### `clients`
Multi-tenant isolation. Each client is a separate organization/tenant.

**Key Fields:**
- `client_id` (UUID, PK): Unique tenant identifier
- `slug` (VARCHAR, UNIQUE): URL-friendly identifier (e.g., "acme-corp")
- `status`: active | suspended | inactive
- `subscription_tier`: basic | professional | enterprise
- `token_balance`: Prepaid LLM tokens for billing

**Relationships:**
- Has many `users`, `processes`, `configurations`, `audit_logs`

#### `users`
Portal users (admins, operators, viewers) with client association.

**Key Fields:**
- `user_id` (UUID, PK)
- `client_id` (UUID, FK → clients)
- `email` (VARCHAR, UNIQUE)
- `role`: admin | operator | viewer
- `status`: active | inactive | pending

**Relationships:**
- Belongs to `clients`
- Can create `prompts`, `configurations`
- Can review `processes` (HITL)

### 2. Configuration & Versioning

#### `process_types`
Workflow definitions (e.g., "payroll_v1", "simple_invoice").

**Key Fields:**
- `process_type_id` (VARCHAR, PK): Human-readable ID
- `display_name`: User-facing name
- `is_active`: Enable/disable workflow
- `default_version`: Default configuration version

**Relationships:**
- Has many `prompts`, `configurations`, `processes`

#### `prompts`
Versioned LLM instructions per process type and stage.

**Key Fields:**
- `prompt_id` (UUID, PK)
- `process_type_id` (VARCHAR, FK → process_types)
- `version` (INTEGER): Configuration version
- `stage`: classification | ocr | validation | summarization
- `prompt_template` (TEXT): LLM instruction with {{variable}} placeholders
- `model_name`: claude-3-5-sonnet, gpt-4, etc.
- `temperature`, `max_tokens`: LLM parameters

**Unique Constraint:**
- (`process_type_id`, `version`, `stage`)

**Relationships:**
- Belongs to `process_types`

#### `configurations`
Client-specific overrides and validation rules.

**Key Fields:**
- `config_id` (UUID, PK)
- `client_id` (UUID, FK → clients)
- `process_type_id` (VARCHAR, FK → process_types)
- `version` (INTEGER): Must match prompt version
- `input_schema`, `output_schema` (JSONB): JSON Schema definitions
- `validation_rules` (JSONB): Business rules for validation stage
- `plugin_name`: Python/Rust plugin to load (e.g., "payroll_standard_validator")
- `enable_fraud_detection`, `enable_hitl`: Feature flags
- `confidence_threshold`: Trigger HITL if below (0.0-1.0)

**Unique Constraint:**
- (`client_id`, `process_type_id`, `version`)

**Relationships:**
- Belongs to `clients`, `process_types`
- Used by `processes`

### 3. Processing Layer

#### `processes`
A single processing job (one or more documents).

**Key Fields:**
- `process_id` (UUID, PK)
- `client_id`, `process_type_id`, `config_version` (FK → configurations)
- `status`: pending | ingested | classifying | extracting | validating | hitl_review | completed | failed | cancelled
- `current_stage`: INGEST | INTELLIGENT_OCR | INTELLIGENT_PROCESS | OUTPUT
- `classification_result`, `extraction_result`, `validation_result`, `final_output` (JSONB): Stage results
- `overall_confidence` (DECIMAL): 0.0-1.0
- `requires_review` (BOOLEAN): Flagged for HITL
- `reviewed_by`, `reviewed_at`: Human review tracking
- `total_tokens_input`, `total_tokens_output`: For billing
- `ingestion_source`: web | whatsapp | telegram | api

**Relationships:**
- Belongs to `clients`, uses `configurations`
- Has many `documents`, `audit_logs`, `output_actions`, `notifications`

#### `documents`
Individual files within a process (1 process can have multiple documents).

**Key Fields:**
- `document_id` (UUID, PK)
- `process_id` (UUID, FK → processes)
- `storage_url` (TEXT): S3/GCS URL
- `storage_provider`: s3 | gcs | local
- `file_name`, `file_size`, `mime_type`
- `status`: pending | processing | completed | failed
- `ocr_text`, `ocr_confidence`, `extracted_data` (JSONB)
- `fraud_score`, `fraud_flags` (JSONB): Fraud detection results

**Relationships:**
- Belongs to `processes`

### 4. Output & Audit

#### `audit_logs`
Immutable event log for compliance and billing (also sent to RabbitMQ Stream).

**Key Fields:**
- `audit_id` (UUID, PK)
- `process_id`, `client_id`, `process_type_id`
- `timestamp` (TIMESTAMP)
- `result`: SUCCESS | FAILED | ERRORS
- `stage_type`: INGEST | INTELLIGENT_OCR | INTELLIGENT_PROCESS | OUTPUT
- `process_plugin_name`: Plugin that executed
- `document_urls` (TEXT[]): Array of document URLs involved
- `payload` (JSONB): Variable data per stage
- `token_usage` (JSONB): {input, output, model}
- `error_message`, `error_stack`: Error details

**Indexes:**
- `(client_id, timestamp DESC)`: Billing queries
- `(process_id)`: Process history
- `(result, stage_type)`: Error analysis

**Note:** Consider partitioning by month for large-scale deployments.

#### `output_actions`
Actions to execute after processing (email, webhook, ERP integration).

**Key Fields:**
- `action_id` (UUID, PK)
- `process_id` (UUID, FK → processes)
- `action_type`: email | webhook | erp_integration | database_insert | file_export
- `target_config` (JSONB): {to, webhook_url, ...}
- `status`: pending | executing | completed | failed | retrying
- `retry_count`, `max_retries`
- `result`, `error_message`

**Relationships:**
- Belongs to `processes`

#### `notifications`
User alerts (HITL required, errors, completions).

**Key Fields:**
- `notification_id` (UUID, PK)
- `client_id`, `process_id`, `user_id`
- `type`: hitl_required | process_failed | low_confidence | fraud_detected | process_completed
- `severity`: info | warning | error | critical
- `title`, `message`
- `is_read`, `read_at`

**Relationships:**
- Belongs to `clients`, optionally `processes`, `users`

## Views

### `v_active_processes`
Currently running processes with client and process type names.

### `v_client_token_usage`
Monthly token usage per client for billing.

### `v_hitl_queue`
Processes requiring human review, ordered by creation date.

## Triggers

### `update_updated_at_column()`
Automatically updates `updated_at` timestamp on row modification.

Applied to: `clients`, `users`, `process_types`, `configurations`, `processes`, `documents`

## Multi-Tenancy Implementation

Data isolation is enforced via:

1. **Database Level**: All queries filter by `client_id`
2. **Application Level**: Middleware validates JWT token and extracts `client_id`
3. **Configuration**: Dynamic loading via (`client_id`, `process_type_id`, `version`)

**Example Query:**
```sql
SELECT * FROM processes
WHERE client_id = '11111111-1111-1111-1111-111111111111'
AND status = 'hitl_review';
```

## Dynamic Configuration Flow

1. **Ingestion**: Process created with `client_id`, `process_type_id`
2. **Configuration Lookup**:
   ```sql
   SELECT * FROM configurations
   WHERE client_id = ? AND process_type_id = ?
   AND is_active = true
   LIMIT 1;
   ```
3. **Prompt Loading**:
   ```sql
   SELECT prompt_template, model_name, temperature, max_tokens
   FROM prompts
   WHERE process_type_id = ? AND version = ? AND stage = 'ocr'
   AND is_active = true;
   ```
4. **Plugin Execution**: Load Python/Rust plugin from `configurations.plugin_name`
5. **Validation**: Apply `validation_rules` JSONB against extracted data

## Migrations

### Prerequisites

This project uses **uv** as the package manager and **asyncio** for all database operations.

Install uv:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Setup

```bash
cd db

# Install dependencies with uv
./scripts/migrate.sh install

# Or manually
uv sync --all-extras
```

### Apply Migrations

**IMPORTANT:** Database URL must use `postgresql+psycopg://` (async driver):

```bash
# Set database URL (async driver)
export DATABASE_URL="postgresql+psycopg://n8nuser:n8npassword@localhost:5432/docflow"

# Apply all migrations
./scripts/migrate.sh upgrade

# Or manually with uv
uv run alembic -c alembic.ini upgrade head
```

### Other Migration Commands

```bash
# Check migration status
./scripts/migrate.sh status

# Rollback last migration
./scripts/migrate.sh downgrade

# Fresh database (drop all + migrate + seed)
./scripts/migrate.sh fresh

# Load sample data
./scripts/migrate.sh seed
```

### Create New Migration

```bash
./scripts/migrate.sh new "add new table"

# Or manually
uv run alembic -c alembic.ini revision -m "add new table"
```

### Async Database Access

All database operations use asyncio with psycopg3:

```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

# Create async engine
engine = create_async_engine(
    "postgresql+psycopg://user:pass@localhost:5432/docflow",
    echo=True,
    pool_size=10,
    max_overflow=20,
)

# Create async session factory
async_session = sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)

# Use in async context
async with async_session() as session:
    result = await session.execute(select(Client))
    clients = result.scalars().all()
```

## Seed Data

Load sample data for development:

```bash
psql $DATABASE_URL -f seeds/001_sample_data.sql
```

**Sample Credentials (for testing only):**
- Email: `admin@acme.com`
- Password: `password123` (hash: `$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIBx5QH8u2`)

## Schema Validation

### Input Schema Example (JSONB)
```json
{
  "type": "object",
  "required": ["document_url", "file_type"],
  "properties": {
    "document_url": {"type": "string", "format": "uri"},
    "file_type": {"type": "string", "enum": ["pdf", "png", "jpg"]}
  }
}
```

### Validation Rules Example (JSONB)
```json
{
  "validation_rules": [
    {
      "field": "pay_period_start",
      "rule": "date_before",
      "compare_to": "pay_period_end"
    },
    {
      "field": "total_net",
      "rule": "less_than_or_equal",
      "compare_to": "total_gross"
    }
  ]
}
```

## Performance Considerations

1. **Indexes**: Critical indexes on `client_id`, `status`, `created_at`, `process_id`
2. **Partitioning**: Consider partitioning `audit_logs` by month for large datasets
3. **JSONB Queries**: Use GIN indexes for JSONB columns if querying nested fields:
   ```sql
   CREATE INDEX idx_processes_extraction_gin ON processes USING GIN (extraction_result);
   ```
4. **Connection Pooling**: Use PgBouncer for high concurrency

## Backup Strategy

- **Daily Full Backup**: pg_dump with compression
- **Continuous WAL Archiving**: For point-in-time recovery
- **Audit Logs**: Also stored in RabbitMQ Stream (redundancy)

## Security

1. **Row-Level Security (RLS)**: Optional for additional tenant isolation
   ```sql
   ALTER TABLE processes ENABLE ROW LEVEL SECURITY;
   CREATE POLICY tenant_isolation ON processes
   USING (client_id = current_setting('app.current_client_id')::uuid);
   ```
2. **Encryption**: Enable at-rest encryption (PostgreSQL TDE or cloud provider)
3. **Secrets**: Never store API keys in database; use environment variables

## Testing

Run integration tests with Testcontainers:

```python
# Example with testcontainers
from testcontainers.postgres import PostgresContainer

with PostgresContainer("postgres:16") as postgres:
    conn_url = postgres.get_connection_url()
    # Run migrations
    # Run tests
```

## Troubleshooting

### Check Active Connections
```sql
SELECT pid, usename, application_name, client_addr, state
FROM pg_stat_activity
WHERE datname = 'docflow';
```

### Slow Query Analysis
```sql
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

### Table Sizes
```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Next Steps

1. Implement backend-api service with Alembic integration
2. Create Python/Rust plugins for validation (`payroll_standard_validator`, etc.)
3. Set up RabbitMQ Stream consumer for audit logs
4. Implement Row-Level Security for additional tenant isolation
5. Configure automated backups and monitoring

## References

- [PostgreSQL JSONB](https://www.postgresql.org/docs/current/datatype-json.html)
- [Alembic Documentation](https://alembic.sqlalchemy.org/)
- [Multi-Tenancy Patterns](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
