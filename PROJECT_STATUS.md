# DocFlow AI - Project Progress & Next Steps

**Last Updated:** 2025-01-11
**Current Phase:** Database Schema & Infrastructure Setup

---

## ✅ Completed Tasks

### 1. Project Foundation (2025-01-11)

#### PR #2: Comprehensive .gitignore
- **Status:** Merged (pending review)
- **Branch:** `feat/add-gitignore`
- **Files:** 224-line .gitignore covering Python, Rust, Node.js, Docker, databases
- **Purpose:** Protect sensitive files (.env, credentials, API keys)

#### PR #3: Database Schema with Async Support
- **Status:** Open (pending review)
- **Branch:** `feat/database-schema-async`
- **Files Added:**
  - `db/schema.sql` - Complete PostgreSQL schema (10 tables + 3 views)
  - `db/pyproject.toml` - UV package manager with async dependencies
  - `db/migrations/env.py` - Alembic with async support
  - `db/migrations/versions/001_initial_schema.py` - Initial migration
  - `db/scripts/migrate.sh` - Migration helper script (uv-based)
  - `db/seeds/001_sample_data.sql` - Sample data (3 clients, 5 process types)
  - `db/README.md` - Complete schema documentation
  - `db/QUICKSTART.md` - 5-minute setup guide
  - `db/.env.example` - Environment template
  - `CLAUDE.md` - Updated with async/uv requirements

**Database Schema Summary:**
- **Tenant Layer:** clients, users
- **Configuration Layer:** process_types, prompts, configurations
- **Processing Layer:** processes, documents
- **Audit Layer:** audit_logs, output_actions, notifications
- **Views:** v_active_processes, v_client_token_usage, v_hitl_queue

**Key Features:**
- Multi-tenant isolation with UUID primary keys
- JSONB for flexible payloads and versioned configurations
- Async/await required for all Python I/O operations
- UV as official Python package manager
- PostgreSQL async driver: `postgresql+psycopg://`

### 2. Architecture Decisions

#### Python Stack (CRITICAL)
- **Package Manager:** UV (Astral) - mandatory for all Python projects
- **Async/Await:** Required for ALL I/O operations
- **Database Driver:** psycopg3 (async) via `postgresql+psycopg://`
- **SQLAlchemy:** AsyncEngine, AsyncSession
- **RabbitMQ:** aio-pika
- **Redis:** redis[asyncio]
- **HTTP Client:** httpx (async)
- **Web Framework:** FastAPI with uvicorn

#### Project Structure
```
/
├── deploy/n8n/              # Orchestration (existing)
├── services/
│   ├── frontend/            # Preact + Tailwind (empty)
│   ├── backend-api/         # API Gateway (empty)
│   ├── worker-ocr/          # Python OCR microservice (empty)
│   ├── worker-processor/    # Rust/Python processor (empty)
│   └── service-audit/       # Audit log consumer (empty)
├── db/                      # Database migrations & schema (NEW)
└── docs/                    # Documentation (empty)
```

---

## 🎯 Current Focus

**Immediate:** Get PR #3 merged to establish database foundation

---

## 📋 Next Steps (Priority Order)

### Phase 1: Database Setup (CURRENT)
- [ ] Review and merge PR #3 (database schema)
- [ ] Test migrations locally
  ```bash
  cd db
  ./scripts/migrate.sh install
  export DATABASE_URL="postgresql+psycopg://n8nuser:n8npassword@localhost:5432/docflow"
  ./scripts/migrate.sh fresh
  ```
- [ ] Verify seed data loads correctly
- [ ] Validate schema with PostgreSQL locally

### Phase 2: Backend API (API Gateway)
**Priority:** HIGH - Required by all other services

**Tasks:**
1. Create `services/backend-api/` with uv project structure
   ```bash
   cd services/backend-api
   uv init
   ```

2. Define project structure:
   ```
   backend-api/
   ├── pyproject.toml          # UV dependencies
   ├── app/
   │   ├── __init__.py
   │   ├── main.py             # FastAPI app (async)
   │   ├── config.py           # Settings (pydantic-settings)
   │   ├── database.py         # Async SQLAlchemy engine/session
   │   ├── models/             # SQLAlchemy models (async)
   │   │   ├── __init__.py
   │   │   ├── client.py
   │   │   ├── user.py
   │   │   ├── process_type.py
   │   │   ├── prompt.py
   │   │   ├── configuration.py
   │   │   └── process.py
   │   ├── schemas/            # Pydantic models (request/response)
   │   ├── routers/            # API endpoints
   │   │   ├── auth.py
   │   │   ├── clients.py
   │   │   ├── processes.py
   │   │   └── configurations.py
   │   ├── services/           # Business logic
   │   ├── middleware/         # Auth, tenant isolation
   │   └── utils/
   ├── tests/
   └── Dockerfile
   ```

3. Core Features to Implement:
   - [ ] Async SQLAlchemy models matching db/schema.sql
   - [ ] JWT authentication
   - [ ] Multi-tenant middleware (extract client_id from JWT)
   - [ ] CRUD endpoints for clients, users, configurations
   - [ ] Configuration loader (by client_id, process_type_id, version)
   - [ ] Prompt retrieval endpoints (versioned)
   - [ ] Process creation and status endpoints
   - [ ] HITL review queue endpoint
   - [ ] Token usage tracking endpoint

4. Dependencies:
   - FastAPI, uvicorn
   - SQLAlchemy[asyncio], psycopg[binary]
   - Pydantic, pydantic-settings
   - python-jose (JWT)
   - passlib (password hashing)
   - redis[asyncio] (caching)
   - httpx (external API calls)

5. Testing:
   - pytest-asyncio
   - httpx (test client)
   - testcontainers (PostgreSQL for integration tests)

### Phase 3: Worker OCR (Python Microservice)
**Priority:** HIGH - Core business logic

**Tasks:**
1. Create `services/worker-ocr/` with uv
2. Implement:
   - [ ] RabbitMQ consumer (aio-pika) listening to `docflow.events`
   - [ ] Document classification logic
   - [ ] LLM integration (Claude API via httpx)
   - [ ] OCR processing with LLM Vision
   - [ ] Fraud detection module
   - [ ] Confidence scoring
   - [ ] Result publishing to RabbitMQ
   - [ ] Audit log emission

3. Dynamic Configuration:
   - Load prompts from backend-api by (process_type_id, version)
   - Load client-specific rules from configurations table
   - Plugin system for custom validators

4. Dependencies:
   - aio-pika (RabbitMQ)
   - anthropic (Claude API async)
   - httpx (API calls)
   - aiofiles (file operations)
   - Pillow (image processing)

### Phase 4: Service Audit (Log Consumer)
**Priority:** MEDIUM - Can run in parallel with worker-ocr

**Tasks:**
1. Create `services/service-audit/`
2. Implement:
   - [ ] RabbitMQ Stream consumer (aio-pika)
   - [ ] Async PostgreSQL writer (insert into audit_logs)
   - [ ] Batch insert optimization
   - [ ] Error handling and retry logic
   - [ ] Monitoring metrics (Prometheus)

### Phase 5: Worker Processor (Business Logic)
**Priority:** MEDIUM - After OCR is working

**Decision:** Python or Rust?
- Python: Easier integration, faster development
- Rust: Better performance for high-volume processing

**Tasks:**
1. Create `services/worker-processor/`
2. Implement:
   - [ ] RabbitMQ consumer
   - [ ] Cross-validation logic
   - [ ] Business rule execution (from configurations.validation_rules)
   - [ ] Data summarization
   - [ ] HITL flagging logic
   - [ ] Result publishing

### Phase 6: Frontend (User Portal)
**Priority:** LOW - Can be developed in parallel after backend-api

**Tasks:**
1. Create `services/frontend/` with Preact + Vite
2. Implement:
   - [ ] Login/authentication
   - [ ] Dashboard (active processes)
   - [ ] Document upload interface
   - [ ] Process monitoring
   - [ ] HITL review interface
   - [ ] Configuration management (prompts, rules)
   - [ ] Token usage reports

### Phase 7: n8n Workflows
**Priority:** MEDIUM - After backend-api is ready

**Tasks:**
1. Create n8n workflows:
   - [ ] WhatsApp bot integration
   - [ ] Telegram bot integration
   - [ ] Web webhook handler
   - [ ] Document upload to S3/GCS
   - [ ] Process creation via backend-api
   - [ ] Email notifications
   - [ ] ERP integrations

### Phase 8: Docker Compose Integration
**Priority:** HIGH - After core services are ready

**Tasks:**
1. Update `deploy/n8n/docker-compose.yml`:
   - [ ] Add backend-api service
   - [ ] Add worker-ocr service
   - [ ] Add worker-processor service
   - [ ] Add service-audit service
   - [ ] Add frontend service
   - [ ] Add Redis service
   - [ ] Configure networking
   - [ ] Add health checks
   - [ ] Add Prometheus + Grafana

### Phase 9: Testing & CI/CD
**Priority:** HIGH - Throughout development

**Tasks:**
1. Unit tests for each service
2. Integration tests with testcontainers
3. E2E tests with Playwright
4. GitHub Actions CI/CD pipeline
5. Docker image builds
6. Automated migrations on deployment

---

## 🔑 Key Architecture Patterns

### Multi-Tenancy
- All queries filter by `client_id` (extracted from JWT)
- Row-level security (optional, for defense-in-depth)
- Configuration isolation per client

### Dynamic Configuration Strategy
```python
# Pseudo-code
async def get_configuration(client_id: UUID, process_type_id: str) -> Configuration:
    config = await session.execute(
        select(Configuration)
        .where(Configuration.client_id == client_id)
        .where(Configuration.process_type_id == process_type_id)
        .where(Configuration.is_active == True)
        .order_by(Configuration.version.desc())
        .limit(1)
    )
    return config.scalar_one()

async def get_prompt(process_type_id: str, version: int, stage: str) -> Prompt:
    prompt = await session.execute(
        select(Prompt)
        .where(Prompt.process_type_id == process_type_id)
        .where(Prompt.version == version)
        .where(Prompt.stage == stage)
        .where(Prompt.is_active == True)
    )
    return prompt.scalar_one()
```

### Audit Trail
```python
async def emit_audit_log(
    process_id: UUID,
    client_id: UUID,
    stage_type: str,
    result: str,
    payload: dict,
    token_usage: dict = None
):
    audit_log = {
        "timestamp": datetime.utcnow().isoformat(),
        "process_id": str(process_id),
        "client_id": str(client_id),
        "stage_type": stage_type,
        "result": result,
        "payload": payload,
        "token_usage": token_usage,
    }

    # Send to RabbitMQ Stream
    await rabbitmq_channel.basic_publish(
        exchange="docflow.events",
        routing_key=f"audit.{stage_type.lower()}",
        body=json.dumps(audit_log),
    )
```

### HITL (Human-in-the-Loop)
```python
async def check_hitl_required(
    process: Process,
    overall_confidence: float,
    config: Configuration
) -> bool:
    if overall_confidence < config.confidence_threshold:
        return True

    if process.classification_result.get("fraud_detected"):
        return True

    return False

async def flag_for_review(process_id: UUID, user_id: UUID = None):
    await session.execute(
        update(Process)
        .where(Process.process_id == process_id)
        .values(requires_review=True, status="hitl_review")
    )

    # Send notification
    await create_notification(
        client_id=process.client_id,
        process_id=process_id,
        type="hitl_required",
        severity="warning",
        title="Review Required",
        message=f"Process {process_id} requires human review",
    )
```

---

## 📚 Documentation to Create

1. **API Documentation**
   - OpenAPI/Swagger (auto-generated by FastAPI)
   - Authentication guide
   - Multi-tenant usage guide

2. **Developer Guide**
   - Setup instructions per service
   - Testing guide
   - Deployment guide

3. **Architecture Decision Records (ADRs)**
   - Why async/await?
   - Why UV instead of pip/poetry?
   - Why psycopg3 instead of psycopg2?

4. **Plugin Development Guide**
   - How to create custom validators
   - How to add new process types
   - How to version prompts

---

## 🚧 Known Blockers

None currently. Database schema is ready for review.

---

## 💡 Future Enhancements

1. **Observability**
   - OpenTelemetry tracing
   - Structured logging (JSON)
   - APM integration (Datadog, New Relic)

2. **Scalability**
   - Horizontal scaling of workers
   - Read replicas for PostgreSQL
   - Caching layer optimization

3. **Security**
   - OAuth2 integration
   - API rate limiting
   - WAF integration
   - Secrets management (Vault, AWS Secrets Manager)

4. **Advanced Features**
   - Workflow versioning and A/B testing
   - Real-time process updates (WebSockets)
   - Advanced analytics dashboard
   - ML-based confidence tuning

---

## 📞 Questions to Answer

1. **Storage Provider:** AWS S3, Google Cloud Storage, or local filesystem?
2. **LLM Provider Mix:** Primary Claude, fallback to GPT-4? Or single provider?
3. **Deployment Target:** Self-hosted, AWS, GCP, Azure?
4. **Monitoring:** Prometheus + Grafana, or cloud-native (CloudWatch, GCP Monitoring)?
5. **Frontend Hosting:** Static site (Vercel, Netlify) or bundled with backend?

---

## 🎓 Learning Resources

- [UV Documentation](https://docs.astral.sh/uv/)
- [FastAPI Async SQL](https://fastapi.tiangolo.com/advanced/async-sql-databases/)
- [SQLAlchemy Async](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html)
- [aio-pika Documentation](https://aio-pika.readthedocs.io/)
- [Alembic with Async](https://alembic.sqlalchemy.org/en/latest/cookbook.html#using-asyncio-with-alembic)

---

**Notes:**
- All async/await patterns are non-negotiable per CLAUDE.md
- UV is the only approved package manager
- Database URL must always use `postgresql+psycopg://`
- HITL is critical for business model (human verification)
- Token tracking is critical for billing

