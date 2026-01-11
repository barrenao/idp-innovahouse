# Project Context: SaaS Document Processing (DocFlow AI)

This file contains essential information, architecture, conventions, and commands for the development of the SaaS intelligent document processing project.

## 1. Project Summary

Multi-tenant SaaS system for ingestion, classification, intelligent OCR (LLM Vision), and document processing. The system is document-type agnostic, utilizing a configurable plugin architecture based on client_id, process_type_id, and version.

Main Flow

Ingest: Web (Preact), WhatsApp/Telegram (n8n Bots).

Upload: Cloud Storage (S3/Drive).

Classification & OCR (Microservice): Fraud detection, data extraction to JSON using LLMs (Claude 4.5, GPT-5, Gemini).

Intelligent Processing (Microservice): Cross-validation, business logic, summarization, auditing.

Output: Action Router (Email, ERP, DB).

## 2. Technical Architecture

### Tech Stack

Frontend (Portal): Preact, TailwindCSS.

Backend / Microservices: Python (FastAPI) for AI logic / Rust (Axum) for high performance.

Python Package Manager: uv (fast Rust-based package manager by Astral).

Orchestration / Chatbots: n8n (Webhooks, Messaging Triggers).

Messaging (Async): RabbitMQ.

Standard Queues: Inter-process communication.

Streams: High-volume audit logs.

Database: PostgreSQL (Relational + JSONB for variable payloads).

Cache: Redis (volatile data or large object sharing).

Monitoring: Prometheus.

Folder Structure

/
├── deploy/
│   ├── n8n/
│   │   ├── docker-compose.yml       # Orchestration (Postgres, n8n, RabbitMQ, Services)
│   │   ├── n8n-runners/             # Custom n8n runner images
│   │   └── scripts/                 # Init DB, seeds
├── services/
│   ├── frontend/                    # User Portal (Preact + Tailwind)
│   ├── backend-api/                 # API Gateway / User & Config Management
│   ├── worker-ocr/                  # OCR & Classification Microservice (Python/LLM)
│   ├── worker-processor/            # Business Logic & Validation Microservice
│   └── service-audit/               # RabbitMQ Stream Consumer -> DB Logs
└── docs/                            # Additional documentation


## 3. Design Principles & Business Logic

### Dynamic Configuration (Strategy Pattern)

OCR and Processing microservices do not have hardcoded logic for a single client. They must load configuration (prompts, validation schemas, plugins) based on:

client_id: Tenant identifier.

process_type_id: Flow type (e.g., "Payroll_V1", "Simple_Invoice").

version: Configuration/prompt version.

Note: LLM Prompts are versionable and stored in the DB.

### Audit System (Critical)

Every step generates an immutable log sent to RabbitMQ Stream.
Log Schema (JSON):

{
  "timestamp": "ISO8601",
  "results": "SUCCESS" | "FAILED" | "ERRORS",
  "stage_type": "INGEST" | "INTELIGENT_OCR" | "INTELIGENT_PROCESS" | "OUTPUT",
  "process_plugin_name": "string (e.g., payroll_standard_validator)",
  "process_id": "uuid",
  "documents": ["url_s3_doc1", "url_s3_doc2"],
  "client_id": "uuid",
  "process_type_id": "string",
  "payload": { ... }, // Variable data depending on stage
  "token_usage": { // For billing
     "input": 150,
     "output": 50,
     "model": "claude-3-5-sonnet"
  }
}

### Human-in-the-Loop (HITL)

If results == "ERRORS" or LLM confidence is low:

The process is paused or flagged for review.

Notification is sent to the User Portal.

An operator corrects extracted data or adjusts the prompt.

## 4. Code Conventions

###General

Language: Comments and documentation in English (user business rule). Code (variables, functions) in English.

Formatting: Prettier for JS/TS/JSON. Black for Python. Rustfmt for Rust.

Backend (Python - AI Workers)

**CRITICAL: All Python code MUST use async/await (asyncio).**

Use asyncio for all I/O operations (database, HTTP, file operations).

All database operations MUST use async drivers:
- PostgreSQL: psycopg (v3+) with asyncio support
- SQLAlchemy: async engine and sessions (AsyncEngine, AsyncSession)
- Redis: aioredis or redis[asyncio]
- RabbitMQ: aio-pika
- HTTP clients: httpx (async) or aiohttp

Use Pydantic for all input/output validation and LLM schemas.

Type Hints mandatory (including async functions: async def foo() -> ReturnType).

Error Handling: Always capture LLM API exceptions and wrap them in structured audit logs before failing the worker.

NO hardcoded API keys. Use environment variables.

Frontend (Preact)

Functional components.

Lightweight state management (Signals or Context).

Mobile-First design mandatory (Tailwind classes sm:, md:).

Avoid heavy libraries unless necessary.

n8n

Use "HTTP Request" nodes to communicate with internal microservices.

Do not put complex business logic in n8n (only orchestration and light transformation). Heavy logic belongs in microservices.

## 5. Testing Strategy (Mandatory)

All components must be thoroughly tested before deployment.

### Unit Tests

Scope: Individual functions, classes, validators, and data parsers.

Mocking: External services (LLM APIs, S3, Database) must be mocked.

Requirement: High coverage for complex business logic plugins.

### Integration Tests

Scope: Interaction between microservices, Database, Redis, and RabbitMQ.

Environment: Use a transient Docker environment (Testcontainers) to spin up dependencies.

Focus: Verify that messages sent to docflow.events are correctly consumed and processed.

### End-to-End (E2E) Tests
Scope: Full user flows from Ingestion (Web/Bot) to Output.

Tools: Playwright/Cypress for Frontend. Scripted scenarios for API/Bot flows.

Critical Path: Upload Document -> OCR Classification -> Data Extraction -> Validation -> Final Output.

## 6. Common Commands

### Local Deployment

** Start full infrastructure
docker-compose -f deploy/n8n/docker-compose.yml up -d

** View logs for a specific service
docker logs -f service-worker-ocr


### Python Package Management (UV)

**All Python projects MUST use uv as the package manager.**

Installation:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Project setup:
- Define dependencies in `pyproject.toml`
- Use `uv sync` to install dependencies
- Use `uv run <command>` to run commands with the project environment
- Use `uv add <package>` to add new dependencies

Do NOT use pip, poetry, or conda. Use uv exclusively.

### Database

Migrations are handled with Alembic (Python) or sqlx (Rust).

Database URL must use async drivers: `postgresql+psycopg://` for PostgreSQL.

Do not modify audit_logs table schemas without a strict migration.

## 7. RabbitMQ Integration

Exchange: docflow.events (Topic).

Routing Keys: ingest.created, ocr.completed, process.validated.

Stream: audit.logs.stream (Append Only).

## 8. Extraction Modules (Examples)

When creating new processors, always define:

Output JSON Schema: Expected fields.

Validation Rules: (e.g., date_of_birth < current_date).

LLM Prompt: Versioned.

Reminder: When generating code, prioritize modularity. A change in "Payroll" logic must not break "Invoice" processing.
