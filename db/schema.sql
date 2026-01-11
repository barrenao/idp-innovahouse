-- ========================================
-- DocFlow AI - Database Schema
-- Multi-tenant SaaS Document Processing
-- PostgreSQL 13+
-- ========================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ========================================
-- 1. TENANTS & AUTHENTICATION
-- ========================================

-- Clients table (Multi-tenant isolation)
CREATE TABLE clients (
    client_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL, -- URL-friendly identifier
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'inactive')),

    -- Subscription & Billing
    subscription_tier VARCHAR(50) DEFAULT 'basic' CHECK (subscription_tier IN ('basic', 'professional', 'enterprise')),
    token_balance INTEGER DEFAULT 0, -- For prepaid token usage

    -- Contact & Metadata
    contact_email VARCHAR(255),
    metadata JSONB DEFAULT '{}', -- Flexible additional data

    -- Audit timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL -- Soft delete
);

CREATE INDEX idx_clients_slug ON clients(slug);
CREATE INDEX idx_clients_status ON clients(status) WHERE deleted_at IS NULL;

-- Users table (Portal access, HITL operators)
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,

    -- Authentication
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- bcrypt/argon2

    -- Profile
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'operator' CHECK (role IN ('admin', 'operator', 'viewer')),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending')),

    -- Security
    last_login_at TIMESTAMP NULL,
    failed_login_attempts INTEGER DEFAULT 0,

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_client_id ON users(client_id);
CREATE INDEX idx_users_email ON users(email);

-- ========================================
-- 2. CONFIGURATION & VERSIONING
-- ========================================

-- Process Types (e.g., "Payroll_V1", "Simple_Invoice", "ID_Card_Extraction")
CREATE TABLE process_types (
    process_type_id VARCHAR(100) PRIMARY KEY, -- Human-readable ID
    display_name VARCHAR(255) NOT NULL,
    description TEXT,

    -- Configuration
    is_active BOOLEAN DEFAULT true,
    default_version INTEGER DEFAULT 1,

    -- Metadata
    metadata JSONB DEFAULT '{}',

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_process_types_active ON process_types(is_active);

-- LLM Prompts (Versioned per process type)
CREATE TABLE prompts (
    prompt_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    process_type_id VARCHAR(100) NOT NULL REFERENCES process_types(process_type_id) ON DELETE CASCADE,
    version INTEGER NOT NULL,

    -- Prompt Content
    stage VARCHAR(50) NOT NULL CHECK (stage IN ('classification', 'ocr', 'validation', 'summarization')),
    prompt_template TEXT NOT NULL, -- Can contain {{variable}} placeholders

    -- LLM Configuration
    model_name VARCHAR(100) DEFAULT 'claude-3-5-sonnet',
    temperature DECIMAL(3,2) DEFAULT 0.0,
    max_tokens INTEGER DEFAULT 4000,

    -- Metadata
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}',

    -- Audit
    created_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(process_type_id, version, stage)
);

CREATE INDEX idx_prompts_process_type ON prompts(process_type_id, version);
CREATE INDEX idx_prompts_active ON prompts(is_active);

-- Configurations (Client-specific overrides and schemas)
CREATE TABLE configurations (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    process_type_id VARCHAR(100) NOT NULL REFERENCES process_types(process_type_id) ON DELETE CASCADE,
    version INTEGER NOT NULL,

    -- JSON Schemas for validation
    input_schema JSONB NOT NULL, -- Expected document structure
    output_schema JSONB NOT NULL, -- Expected extraction result
    validation_rules JSONB DEFAULT '{}', -- Custom business rules

    -- Processing Configuration
    enable_fraud_detection BOOLEAN DEFAULT true,
    enable_hitl BOOLEAN DEFAULT true, -- Human-in-the-Loop
    confidence_threshold DECIMAL(3,2) DEFAULT 0.85, -- Trigger HITL if below

    -- Plugin Configuration
    plugin_name VARCHAR(255) NOT NULL, -- e.g., "payroll_standard_validator"
    plugin_config JSONB DEFAULT '{}', -- Plugin-specific settings

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Audit
    created_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(client_id, process_type_id, version)
);

CREATE INDEX idx_configurations_client ON configurations(client_id, process_type_id);
CREATE INDEX idx_configurations_active ON configurations(is_active);

-- ========================================
-- 3. DOCUMENT PROCESSING
-- ========================================

-- Processes (A single processing job/batch)
CREATE TABLE processes (
    process_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    process_type_id VARCHAR(100) NOT NULL REFERENCES process_types(process_type_id) ON DELETE CASCADE,
    config_version INTEGER NOT NULL,

    -- Status Tracking
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN (
        'pending', 'ingested', 'classifying', 'extracting',
        'validating', 'hitl_review', 'completed', 'failed', 'cancelled'
    )),
    current_stage VARCHAR(50) DEFAULT 'INGEST' CHECK (current_stage IN (
        'INGEST', 'INTELLIGENT_OCR', 'INTELLIGENT_PROCESS', 'OUTPUT'
    )),

    -- Results
    classification_result JSONB NULL, -- Document type, confidence
    extraction_result JSONB NULL, -- Extracted data
    validation_result JSONB NULL, -- Validation errors/warnings
    final_output JSONB NULL, -- Final processed data

    -- Confidence & Quality
    overall_confidence DECIMAL(3,2) NULL,
    requires_review BOOLEAN DEFAULT false,
    reviewed_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP NULL,

    -- Token Usage (for billing)
    total_tokens_input INTEGER DEFAULT 0,
    total_tokens_output INTEGER DEFAULT 0,

    -- Metadata
    ingestion_source VARCHAR(50), -- 'web', 'whatsapp', 'telegram', 'api'
    metadata JSONB DEFAULT '{}',

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,

    FOREIGN KEY (client_id, process_type_id, config_version)
        REFERENCES configurations(client_id, process_type_id, version)
);

CREATE INDEX idx_processes_client ON processes(client_id);
CREATE INDEX idx_processes_status ON processes(status, created_at DESC);
CREATE INDEX idx_processes_review ON processes(requires_review) WHERE requires_review = true;
CREATE INDEX idx_processes_stage ON processes(current_stage);

-- Documents (Individual files within a process)
CREATE TABLE documents (
    document_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    process_id UUID NOT NULL REFERENCES processes(process_id) ON DELETE CASCADE,

    -- Storage
    storage_url TEXT NOT NULL, -- S3/GCS URL
    storage_provider VARCHAR(50) DEFAULT 's3', -- 's3', 'gcs', 'local'
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT, -- bytes
    mime_type VARCHAR(100),

    -- Processing Status
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN (
        'pending', 'processing', 'completed', 'failed'
    )),

    -- OCR Results
    ocr_text TEXT NULL,
    ocr_confidence DECIMAL(3,2) NULL,
    extracted_data JSONB NULL,

    -- Fraud Detection
    fraud_score DECIMAL(3,2) NULL,
    fraud_flags JSONB DEFAULT '[]',

    -- Metadata
    page_count INTEGER,
    metadata JSONB DEFAULT '{}',

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_documents_process ON documents(process_id);
CREATE INDEX idx_documents_status ON documents(status);

-- ========================================
-- 4. AUDIT & LOGGING
-- ========================================

-- Audit Logs (Immutable event log - also sent to RabbitMQ Stream)
CREATE TABLE audit_logs (
    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Context
    process_id UUID REFERENCES processes(process_id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    process_type_id VARCHAR(100) REFERENCES process_types(process_type_id) ON DELETE SET NULL,

    -- Event Details
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    result VARCHAR(50) NOT NULL CHECK (result IN ('SUCCESS', 'FAILED', 'ERRORS')),
    stage_type VARCHAR(50) NOT NULL CHECK (stage_type IN (
        'INGEST', 'INTELLIGENT_OCR', 'INTELLIGENT_PROCESS', 'OUTPUT'
    )),
    process_plugin_name VARCHAR(255),

    -- Documents involved
    document_urls TEXT[], -- Array of S3/GCS URLs

    -- Payload
    payload JSONB NOT NULL, -- Variable data per stage

    -- Token Usage (for billing)
    token_usage JSONB DEFAULT NULL, -- {input: 150, output: 50, model: "claude-3-5-sonnet"}

    -- Error tracking
    error_message TEXT NULL,
    error_stack TEXT NULL
);

-- Partitioning by month for performance (example for large-scale)
-- CREATE TABLE audit_logs_2024_01 PARTITION OF audit_logs FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE INDEX idx_audit_logs_process ON audit_logs(process_id);
CREATE INDEX idx_audit_logs_client ON audit_logs(client_id, timestamp DESC);
CREATE INDEX idx_audit_logs_result ON audit_logs(result, stage_type);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp DESC);

-- ========================================
-- 5. NOTIFICATIONS & OUTPUT ROUTING
-- ========================================

-- Output Actions (Email, ERP, Webhook)
CREATE TABLE output_actions (
    action_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    process_id UUID NOT NULL REFERENCES processes(process_id) ON DELETE CASCADE,

    -- Action Type
    action_type VARCHAR(50) NOT NULL CHECK (action_type IN (
        'email', 'webhook', 'erp_integration', 'database_insert', 'file_export'
    )),

    -- Target Configuration
    target_config JSONB NOT NULL, -- {to: "email@example.com", webhook_url: "https://...",...}

    -- Status
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN (
        'pending', 'executing', 'completed', 'failed', 'retrying'
    )),
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,

    -- Result
    result JSONB NULL,
    error_message TEXT NULL,

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    executed_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL
);

CREATE INDEX idx_output_actions_process ON output_actions(process_id);
CREATE INDEX idx_output_actions_status ON output_actions(status);

-- Notifications (HITL alerts, errors)
CREATE TABLE notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    process_id UUID REFERENCES processes(process_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,

    -- Notification Details
    type VARCHAR(50) NOT NULL CHECK (type IN (
        'hitl_required', 'process_failed', 'low_confidence', 'fraud_detected', 'process_completed'
    )),
    severity VARCHAR(50) DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,

    -- Metadata
    metadata JSONB DEFAULT '{}',

    -- Status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP NULL,

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_client ON notifications(client_id, created_at DESC);
CREATE INDEX idx_notifications_process ON notifications(process_id);

-- ========================================
-- 6. TRIGGERS & FUNCTIONS
-- ========================================

-- Update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to relevant tables
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON clients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_process_types_updated_at BEFORE UPDATE ON process_types
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_configurations_updated_at BEFORE UPDATE ON configurations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_processes_updated_at BEFORE UPDATE ON processes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- 7. VIEWS (Convenience queries)
-- ========================================

-- Active processes with client info
CREATE VIEW v_active_processes AS
SELECT
    p.process_id,
    p.status,
    p.current_stage,
    p.requires_review,
    p.overall_confidence,
    c.name AS client_name,
    c.slug AS client_slug,
    pt.display_name AS process_type_name,
    p.created_at,
    p.updated_at
FROM processes p
JOIN clients c ON p.client_id = c.client_id
JOIN process_types pt ON p.process_type_id = pt.process_type_id
WHERE p.status NOT IN ('completed', 'cancelled', 'failed')
ORDER BY p.created_at DESC;

-- Token usage per client (for billing)
CREATE VIEW v_client_token_usage AS
SELECT
    c.client_id,
    c.name AS client_name,
    DATE_TRUNC('month', p.created_at) AS billing_month,
    SUM(p.total_tokens_input) AS total_input_tokens,
    SUM(p.total_tokens_output) AS total_output_tokens,
    SUM(p.total_tokens_input + p.total_tokens_output) AS total_tokens,
    COUNT(p.process_id) AS total_processes
FROM clients c
LEFT JOIN processes p ON c.client_id = p.client_id
GROUP BY c.client_id, c.name, DATE_TRUNC('month', p.created_at)
ORDER BY billing_month DESC, total_tokens DESC;

-- HITL Review Queue
CREATE VIEW v_hitl_queue AS
SELECT
    p.process_id,
    p.status,
    c.name AS client_name,
    pt.display_name AS process_type,
    p.overall_confidence,
    COUNT(d.document_id) AS document_count,
    p.created_at,
    p.updated_at
FROM processes p
JOIN clients c ON p.client_id = c.client_id
JOIN process_types pt ON p.process_type_id = pt.process_type_id
LEFT JOIN documents d ON p.process_id = d.process_id
WHERE p.requires_review = true AND p.reviewed_at IS NULL
GROUP BY p.process_id, p.status, c.name, pt.display_name, p.overall_confidence, p.created_at, p.updated_at
ORDER BY p.created_at ASC;

-- ========================================
-- END OF SCHEMA
-- ========================================
