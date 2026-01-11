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


### Software Architecture Patterns

**CRITICAL: All microservices MUST follow Hexagonal Architecture (Ports & Adapters) and SOLID Principles.**

#### Hexagonal Architecture (Ports & Adapters)

Hexagonal Architecture, also known as Ports and Adapters, isolates the core business logic from external concerns (databases, APIs, message queues). This pattern ensures that the domain logic remains independent of infrastructure details, making the system more testable, maintainable, and adaptable to change.

**Core Layers:**

1. **Domain Layer (Core/Center):**
   - Contains pure business logic, entities, and domain services
   - No dependencies on external frameworks or infrastructure
   - Technology-agnostic
   - Examples: `ProcessValidator`, `DocumentClassifier`, `FraudDetector`

2. **Application Layer (Use Cases):**
   - Orchestrates domain logic to fulfill specific use cases
   - Defines input/output ports (interfaces)
   - Examples: `ClassifyDocumentUseCase`, `ExtractDataUseCase`, `ValidateProcessUseCase`

3. **Adapters Layer (Infrastructure):**
   - **Primary/Driving Adapters (Input):** Trigger application use cases
     - REST API controllers (FastAPI routers)
     - RabbitMQ message consumers
     - CLI commands
   - **Secondary/Driven Adapters (Output):** Implement ports defined by the application
     - Database repositories (PostgreSQL via SQLAlchemy)
     - External API clients (LLM providers, S3)
     - Message publishers (RabbitMQ)
     - Cache implementations (Redis)

**Hexagonal Architecture in Practice:**

```
services/backend-api/
├── app/
│   ├── domain/                    # Domain Layer (Pure Business Logic)
│   │   ├── entities/              # Domain entities (Client, Process, Document)
│   │   ├── value_objects/         # Immutable values (ProcessStatus, StageType)
│   │   ├── services/              # Domain services (business rules)
│   │   └── exceptions/            # Domain-specific exceptions
│   ├── application/               # Application Layer (Use Cases)
│   │   ├── use_cases/             # Business workflows
│   │   │   ├── create_process.py
│   │   │   ├── update_configuration.py
│   │   │   └── retrieve_hitl_queue.py
│   │   └── ports/                 # Interfaces (contracts)
│   │       ├── repositories/      # Repository interfaces
│   │       ├── services/          # External service interfaces
│   │       └── publishers/        # Message publisher interfaces
│   └── infrastructure/            # Adapters Layer (Infrastructure)
│       ├── api/                   # Primary Adapter: REST API
│       │   ├── routers/           # FastAPI routers
│       │   ├── dependencies.py    # Dependency injection
│       │   └── middleware/
│       ├── persistence/           # Secondary Adapter: Database
│       │   ├── models.py          # SQLAlchemy models
│       │   └── repositories/      # Repository implementations
│       ├── messaging/             # Secondary Adapter: RabbitMQ
│       │   ├── publishers.py
│       │   └── consumers.py
│       ├── external/              # Secondary Adapter: External APIs
│       │   ├── llm_client.py
│       │   └── storage_client.py
│       └── cache/                 # Secondary Adapter: Redis
│           └── redis_cache.py
```

**Example: OCR Worker with Hexagonal Architecture**

```python
# domain/services/document_classifier.py (Domain Layer)
from typing import Protocol
from app.domain.entities.document import Document
from app.domain.value_objects.classification_result import ClassificationResult

class DocumentClassifier:
    """Pure business logic for document classification."""

    def classify(self, document: Document, rules: dict) -> ClassificationResult:
        # Pure domain logic, no I/O
        if self._is_fraud_pattern(document.content, rules):
            return ClassificationResult(
                document_type="FRAUD_DETECTED",
                confidence=0.95,
                fraud_detected=True
            )
        return ClassificationResult(
            document_type=self._infer_type(document.content),
            confidence=0.85,
            fraud_detected=False
        )

# application/ports/repositories/prompt_repository.py (Port - Interface)
from typing import Protocol
from app.domain.entities.prompt import Prompt

class PromptRepository(Protocol):
    """Port: Interface for prompt retrieval."""

    async def get_by_process_type(
        self,
        process_type_id: str,
        version: int,
        stage: str
    ) -> Prompt:
        ...

# application/use_cases/classify_document.py (Application Layer)
from app.application.ports.repositories.prompt_repository import PromptRepository
from app.application.ports.services.llm_service import LLMService
from app.domain.services.document_classifier import DocumentClassifier

class ClassifyDocumentUseCase:
    """Use case: Orchestrates document classification."""

    def __init__(
        self,
        classifier: DocumentClassifier,
        prompt_repo: PromptRepository,
        llm_service: LLMService
    ):
        self._classifier = classifier
        self._prompt_repo = prompt_repo
        self._llm_service = llm_service

    async def execute(
        self,
        document_url: str,
        process_type_id: str
    ) -> ClassificationResult:
        # Orchestrate domain logic with infrastructure
        prompt = await self._prompt_repo.get_by_process_type(
            process_type_id=process_type_id,
            version=1,
            stage="classification"
        )

        llm_response = await self._llm_service.analyze(
            document_url=document_url,
            prompt=prompt.content
        )

        # Delegate to domain service
        return self._classifier.classify(
            document=llm_response.document,
            rules=prompt.rules
        )

# infrastructure/persistence/repositories/prompt_repository_impl.py (Adapter)
from sqlalchemy.ext.asyncio import AsyncSession
from app.application.ports.repositories.prompt_repository import PromptRepository
from app.infrastructure.persistence.models import PromptModel

class PromptRepositoryImpl(PromptRepository):
    """Adapter: PostgreSQL implementation of PromptRepository."""

    def __init__(self, session: AsyncSession):
        self._session = session

    async def get_by_process_type(
        self,
        process_type_id: str,
        version: int,
        stage: str
    ) -> Prompt:
        result = await self._session.execute(
            select(PromptModel)
            .where(PromptModel.process_type_id == process_type_id)
            .where(PromptModel.version == version)
            .where(PromptModel.stage == stage)
        )
        model = result.scalar_one()
        return Prompt.from_orm(model)  # Convert to domain entity

# infrastructure/api/routers/ocr.py (Primary Adapter - REST API)
from fastapi import APIRouter, Depends
from app.application.use_cases.classify_document import ClassifyDocumentUseCase

router = APIRouter()

@router.post("/classify")
async def classify_document(
    request: ClassifyRequest,
    use_case: ClassifyDocumentUseCase = Depends(get_classify_use_case)
):
    """REST endpoint triggers use case."""
    result = await use_case.execute(
        document_url=request.document_url,
        process_type_id=request.process_type_id
    )
    return {"classification": result.document_type, "confidence": result.confidence}
```

**Benefits:**
- **Testability:** Domain logic can be tested without databases or external APIs
- **Flexibility:** Easy to swap PostgreSQL for MongoDB, or Claude API for GPT-4
- **Maintainability:** Changes to infrastructure don't affect business logic
- **Clear Boundaries:** Each layer has a single responsibility

#### SOLID Principles

All code must adhere to SOLID principles to ensure maintainability, scalability, and testability.

**S - Single Responsibility Principle (SRP)**

Each class/module should have one, and only one, reason to change.

```python
# BAD: Multiple responsibilities
class DocumentProcessor:
    async def process(self, document_url: str):
        # Responsibility 1: Download document
        content = await self._download(document_url)

        # Responsibility 2: Classify document
        classification = await self._classify(content)

        # Responsibility 3: Save to database
        await self._save_to_db(classification)

        # Responsibility 4: Send notification
        await self._send_email(classification)

# GOOD: Separated responsibilities
class DocumentDownloader:
    async def download(self, url: str) -> bytes:
        """Single responsibility: Download documents."""
        ...

class DocumentClassifier:
    def classify(self, content: bytes) -> ClassificationResult:
        """Single responsibility: Classify documents."""
        ...

class ClassificationRepository:
    async def save(self, classification: ClassificationResult):
        """Single responsibility: Persist classifications."""
        ...

class NotificationService:
    async def notify(self, classification: ClassificationResult):
        """Single responsibility: Send notifications."""
        ...
```

**O - Open/Closed Principle (OCP)**

Classes should be open for extension but closed for modification.

```python
# BAD: Hard to extend without modifying
class ValidationService:
    async def validate(self, process_type: str, data: dict):
        if process_type == "payroll":
            # Validate payroll
            ...
        elif process_type == "invoice":
            # Validate invoice
            ...
        # Adding new type requires modifying this class

# GOOD: Open for extension via Strategy Pattern
from abc import ABC, abstractmethod

class Validator(ABC):
    """Base validator interface."""

    @abstractmethod
    async def validate(self, data: dict) -> ValidationResult:
        pass

class PayrollValidator(Validator):
    async def validate(self, data: dict) -> ValidationResult:
        # Payroll-specific validation
        ...

class InvoiceValidator(Validator):
    async def validate(self, data: dict) -> ValidationResult:
        # Invoice-specific validation
        ...

class ValidationService:
    def __init__(self):
        self._validators: dict[str, Validator] = {}

    def register_validator(self, process_type: str, validator: Validator):
        """Register new validators without modifying core logic."""
        self._validators[process_type] = validator

    async def validate(self, process_type: str, data: dict):
        validator = self._validators.get(process_type)
        if not validator:
            raise ValueError(f"No validator for {process_type}")
        return await validator.validate(data)
```

**L - Liskov Substitution Principle (LSP)**

Derived classes must be substitutable for their base classes without breaking functionality.

```python
# BAD: Violates LSP - child changes expected behavior
class BaseRepository:
    async def save(self, entity: Entity) -> None:
        # Expected to always save
        await self._db.insert(entity)

class CachedRepository(BaseRepository):
    async def save(self, entity: Entity) -> None:
        # Violates LSP: doesn't actually save to DB immediately
        await self._cache.set(entity.id, entity)
        # Missing DB persistence!

# GOOD: Respects LSP
class BaseRepository(ABC):
    @abstractmethod
    async def save(self, entity: Entity) -> None:
        pass

class DatabaseRepository(BaseRepository):
    async def save(self, entity: Entity) -> None:
        await self._db.insert(entity)

class CachedRepository(BaseRepository):
    def __init__(self, db_repo: DatabaseRepository, cache: Cache):
        self._db_repo = db_repo
        self._cache = cache

    async def save(self, entity: Entity) -> None:
        # Maintains contract: entity is persisted
        await self._db_repo.save(entity)
        await self._cache.set(entity.id, entity)
```

**I - Interface Segregation Principle (ISP)**

Clients should not be forced to depend on interfaces they don't use.

```python
# BAD: Fat interface forces unnecessary dependencies
class DataService(Protocol):
    async def read(self, id: str) -> Data: ...
    async def write(self, data: Data) -> None: ...
    async def delete(self, id: str) -> None: ...
    async def export_to_csv(self, ids: list[str]) -> bytes: ...
    async def import_from_json(self, file: bytes) -> None: ...

class ReadOnlyClient:
    def __init__(self, service: DataService):
        # Forced to depend on write/delete/export/import even though it only reads
        self._service = service

# GOOD: Segregated interfaces
class Readable(Protocol):
    async def read(self, id: str) -> Data: ...

class Writable(Protocol):
    async def write(self, data: Data) -> None: ...

class Deletable(Protocol):
    async def delete(self, id: str) -> None: ...

class ReadOnlyClient:
    def __init__(self, service: Readable):
        # Only depends on what it needs
        self._service = service

class AdminClient:
    def __init__(self, readable: Readable, writable: Writable, deletable: Deletable):
        # Composes only required interfaces
        self._readable = readable
        self._writable = writable
        self._deletable = deletable
```

**D - Dependency Inversion Principle (DIP)**

High-level modules should not depend on low-level modules. Both should depend on abstractions.

```python
# BAD: High-level module depends on low-level implementation
from infrastructure.persistence.postgresql_repo import PostgreSQLProcessRepository

class ProcessService:
    def __init__(self):
        # Tightly coupled to PostgreSQL
        self._repo = PostgreSQLProcessRepository()

    async def create_process(self, data: dict):
        await self._repo.save(data)

# GOOD: Both depend on abstraction
from abc import ABC, abstractmethod

# Abstraction (Port)
class ProcessRepository(ABC):
    @abstractmethod
    async def save(self, process: Process) -> None:
        pass

# High-level module depends on abstraction
class ProcessService:
    def __init__(self, repo: ProcessRepository):
        # Depends on interface, not implementation
        self._repo = repo

    async def create_process(self, data: dict):
        process = Process.from_dict(data)
        await self._repo.save(process)

# Low-level module implements abstraction
class PostgreSQLProcessRepository(ProcessRepository):
    async def save(self, process: Process) -> None:
        await self._db.insert(process.to_dict())

# Dependency injection at composition root
def create_process_service() -> ProcessService:
    repo = PostgreSQLProcessRepository(db_session)
    return ProcessService(repo)
```

**SOLID Benefits in DocFlow AI:**
- **S:** Each validator, classifier, and processor has a single, well-defined purpose
- **O:** New document types can be added without modifying existing code
- **L:** All repository implementations are interchangeable
- **I:** OCR workers don't depend on audit logging interfaces
- **D:** Business logic is independent of PostgreSQL, Redis, or RabbitMQ implementations

#### Dependency Injection

All dependencies must be injected via constructors or FastAPI's `Depends()`, never instantiated inside classes.

```python
# FastAPI dependency injection example
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db_session() -> AsyncSession:
    async with async_session_maker() as session:
        yield session

async def get_process_repository(
    session: AsyncSession = Depends(get_db_session)
) -> ProcessRepository:
    return PostgreSQLProcessRepository(session)

async def get_process_service(
    repo: ProcessRepository = Depends(get_process_repository)
) -> ProcessService:
    return ProcessService(repo)

@router.post("/processes")
async def create_process(
    request: CreateProcessRequest,
    service: ProcessService = Depends(get_process_service)
):
    return await service.create_process(request.dict())
```

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

### General

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
