"""Initial database schema

Revision ID: 001
Revises: None
Create Date: 2025-01-11

"""
from typing import Sequence, Union
import os

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Apply initial schema from schema.sql"""
    # Read and execute schema.sql
    schema_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
        'schema.sql'
    )

    with open(schema_path, 'r') as f:
        schema_sql = f.read()

    # Execute the schema (split by semicolons for individual statements)
    conn = op.get_bind()

    # Execute as raw SQL
    # Note: This is a simplified approach. For production, consider
    # breaking down into individual statements if needed.
    statements = [stmt.strip() for stmt in schema_sql.split(';') if stmt.strip()]

    for statement in statements:
        if statement:
            conn.execute(sa.text(statement))


def downgrade() -> None:
    """Drop all tables and extensions"""
    # Drop views
    op.execute("DROP VIEW IF EXISTS v_hitl_queue CASCADE")
    op.execute("DROP VIEW IF EXISTS v_client_token_usage CASCADE")
    op.execute("DROP VIEW IF EXISTS v_active_processes CASCADE")

    # Drop tables in reverse order of dependencies
    op.drop_table('notifications')
    op.drop_table('output_actions')
    op.drop_table('audit_logs')
    op.drop_table('documents')
    op.drop_table('processes')
    op.drop_table('configurations')
    op.drop_table('prompts')
    op.drop_table('process_types')
    op.drop_table('users')
    op.drop_table('clients')

    # Drop functions
    op.execute("DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE")

    # Drop extension
    op.execute("DROP EXTENSION IF EXISTS \"uuid-ossp\" CASCADE")
