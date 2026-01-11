-- ========================================
-- DocFlow AI - Sample Seed Data
-- Use for development and testing only
-- ========================================

-- ========================================
-- 1. Sample Clients (Tenants)
-- ========================================

INSERT INTO clients (client_id, name, slug, status, subscription_tier, token_balance, contact_email, metadata)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'Acme Corporation', 'acme-corp', 'active', 'enterprise', 100000, 'admin@acme.com', '{"industry": "technology", "employees": 500}'),
    ('22222222-2222-2222-2222-222222222222', 'Global Logistics Inc', 'global-logistics', 'active', 'professional', 50000, 'contact@globallogistics.com', '{"industry": "logistics", "employees": 200}'),
    ('33333333-3333-3333-3333-333333333333', 'SmallBiz Retail', 'smallbiz-retail', 'active', 'basic', 10000, 'owner@smallbiz.com', '{"industry": "retail", "employees": 10}');

-- ========================================
-- 2. Sample Users
-- ========================================

-- Password: 'password123' (hashed with bcrypt - this is just a sample hash)
-- In production, use proper bcrypt hashing
INSERT INTO users (user_id, client_id, email, password_hash, full_name, role, status)
VALUES
    -- Acme Corporation users
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin@acme.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIBx5QH8u2', 'John Admin', 'admin', 'active'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'operator@acme.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIBx5QH8u2', 'Jane Operator', 'operator', 'active'),

    -- Global Logistics users
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', 'admin@globallogistics.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIBx5QH8u2', 'Mike Manager', 'admin', 'active'),

    -- SmallBiz Retail users
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '33333333-3333-3333-3333-333333333333', 'owner@smallbiz.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIBx5QH8u2', 'Sarah Owner', 'admin', 'active');

-- ========================================
-- 3. Process Types
-- ========================================

INSERT INTO process_types (process_type_id, display_name, description, is_active, default_version, metadata)
VALUES
    ('payroll_v1', 'Payroll Processing V1', 'Standard payroll document processing with employee data extraction', true, 1, '{"category": "finance", "complexity": "medium"}'),
    ('simple_invoice', 'Simple Invoice', 'Basic invoice data extraction (vendor, amount, date, items)', true, 1, '{"category": "accounting", "complexity": "low"}'),
    ('id_card_extraction', 'ID Card Extraction', 'Government ID card OCR and validation', true, 1, '{"category": "identity", "complexity": "high"}'),
    ('receipt_scanner', 'Receipt Scanner', 'Retail receipt parsing for expense tracking', true, 1, '{"category": "expenses", "complexity": "low"}'),
    ('contract_analyzer', 'Contract Analyzer', 'Legal contract parsing and clause extraction', true, 1, '{"category": "legal", "complexity": "high"}');

-- ========================================
-- 4. Sample Prompts (LLM Instructions)
-- ========================================

-- Payroll V1 - Classification
INSERT INTO prompts (prompt_id, process_type_id, version, stage, prompt_template, model_name, temperature, max_tokens, is_active, created_by)
VALUES
    ('91111111-1111-1111-1111-111111111111', 'payroll_v1', 1, 'classification',
    'You are a document classifier. Analyze the provided document and determine if it is a valid payroll document.
Return a JSON object with:
{
  "document_type": "payroll" | "not_payroll",
  "confidence": 0.0-1.0,
  "reasoning": "brief explanation"
}',
    'claude-3-5-sonnet', 0.0, 500, true, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Payroll V1 - OCR
INSERT INTO prompts (prompt_id, process_type_id, version, stage, prompt_template, model_name, temperature, max_tokens, is_active, created_by)
VALUES
    ('92222222-2222-2222-2222-222222222222', 'payroll_v1', 1, 'ocr',
    'Extract payroll information from this document. Return JSON with the following structure:
{
  "company_name": "string",
  "pay_period_start": "YYYY-MM-DD",
  "pay_period_end": "YYYY-MM-DD",
  "employees": [
    {
      "employee_id": "string",
      "full_name": "string",
      "gross_pay": number,
      "deductions": number,
      "net_pay": number,
      "payment_date": "YYYY-MM-DD"
    }
  ],
  "total_gross": number,
  "total_net": number
}',
    'claude-3-5-sonnet', 0.0, 4000, true, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Simple Invoice - Classification
INSERT INTO prompts (prompt_id, process_type_id, version, stage, prompt_template, model_name, temperature, max_tokens, is_active, created_by)
VALUES
    ('93333333-3333-3333-3333-333333333333', 'simple_invoice', 1, 'classification',
    'Classify if this document is an invoice. Return JSON:
{
  "document_type": "invoice" | "not_invoice",
  "confidence": 0.0-1.0,
  "reasoning": "explanation"
}',
    'claude-3-5-sonnet', 0.0, 500, true, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Simple Invoice - OCR
INSERT INTO prompts (prompt_id, process_type_id, version, stage, prompt_template, model_name, temperature, max_tokens, is_active, created_by)
VALUES
    ('94444444-4444-4444-4444-444444444444', 'simple_invoice', 1, 'ocr',
    'Extract invoice data. Return JSON:
{
  "invoice_number": "string",
  "invoice_date": "YYYY-MM-DD",
  "due_date": "YYYY-MM-DD",
  "vendor_name": "string",
  "vendor_address": "string",
  "subtotal": number,
  "tax": number,
  "total": number,
  "currency": "string",
  "line_items": [
    {
      "description": "string",
      "quantity": number,
      "unit_price": number,
      "total": number
    }
  ]
}',
    'claude-3-5-sonnet', 0.0, 4000, true, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- ========================================
-- 5. Sample Configurations (Client-specific)
-- ========================================

-- Acme Corporation - Payroll Configuration
INSERT INTO configurations (config_id, client_id, process_type_id, version, input_schema, output_schema, validation_rules, enable_fraud_detection, enable_hitl, confidence_threshold, plugin_name, plugin_config, is_active, created_by)
VALUES
    ('c1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'payroll_v1',
    1,
    '{"type": "object", "required": ["document_url", "file_type"]}',
    '{"type": "object", "required": ["employees", "total_gross", "total_net"]}',
    '{
      "validation_rules": [
        {"field": "pay_period_start", "rule": "date_before", "compare_to": "pay_period_end"},
        {"field": "total_net", "rule": "less_than_or_equal", "compare_to": "total_gross"},
        {"field": "employees[].net_pay", "rule": "greater_than", "value": 0}
      ]
    }',
    true,
    true,
    0.85,
    'payroll_standard_validator',
    '{"min_net_pay": 100, "max_net_pay": 50000}',
    true,
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Global Logistics - Simple Invoice Configuration
INSERT INTO configurations (config_id, client_id, process_type_id, version, input_schema, output_schema, validation_rules, enable_fraud_detection, enable_hitl, confidence_threshold, plugin_name, plugin_config, is_active, created_by)
VALUES
    ('c2222222-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    'simple_invoice',
    1,
    '{"type": "object", "required": ["document_url"]}',
    '{"type": "object", "required": ["invoice_number", "total", "vendor_name"]}',
    '{
      "validation_rules": [
        {"field": "invoice_date", "rule": "date_not_future"},
        {"field": "total", "rule": "greater_than", "value": 0},
        {"field": "total", "rule": "matches_sum", "compare_to": "subtotal + tax"}
      ]
    }',
    true,
    true,
    0.80,
    'invoice_standard_validator',
    '{"currency": "USD", "require_line_items": true}',
    true,
    'cccccccc-cccc-cccc-cccc-cccccccccccc');

-- SmallBiz Retail - Receipt Scanner Configuration
INSERT INTO configurations (config_id, client_id, process_type_id, version, input_schema, output_schema, validation_rules, enable_fraud_detection, enable_hitl, confidence_threshold, plugin_name, plugin_config, is_active, created_by)
VALUES
    ('c3333333-3333-3333-3333-333333333333',
    '33333333-3333-3333-3333-333333333333',
    'receipt_scanner',
    1,
    '{"type": "object", "required": ["document_url"]}',
    '{"type": "object", "required": ["merchant", "total", "date"]}',
    '{
      "validation_rules": [
        {"field": "total", "rule": "greater_than", "value": 0},
        {"field": "date", "rule": "date_not_future"}
      ]
    }',
    false,
    false,
    0.70,
    'receipt_basic_extractor',
    '{"auto_categorize": true}',
    true,
    'dddddddd-dddd-dddd-dddd-dddddddddddd');

-- ========================================
-- 6. Sample Process (for testing)
-- ========================================

INSERT INTO processes (process_id, client_id, process_type_id, config_version, status, current_stage, classification_result, overall_confidence, requires_review, ingestion_source, metadata)
VALUES
    ('p1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'payroll_v1',
    1,
    'pending',
    'INGEST',
    NULL,
    NULL,
    false,
    'web',
    '{"uploaded_by": "admin@acme.com", "source_ip": "192.168.1.100"}');

-- Sample Documents for the process
INSERT INTO documents (document_id, process_id, storage_url, storage_provider, file_name, file_size, mime_type, status)
VALUES
    ('d1111111-1111-1111-1111-111111111111',
    'p1111111-1111-1111-1111-111111111111',
    's3://docflow-documents/acme/2024/01/payroll_jan.pdf',
    's3',
    'payroll_january_2024.pdf',
    524288,
    'application/pdf',
    'pending');

-- ========================================
-- END OF SEED DATA
-- ========================================
