"""
scripts/migrate_phase6.py
Applies Phase 6 database changes to an existing accesco_discovery DB.

Run ONCE from inside the backends/ folder:
  python scripts/migrate_phase6.py

What this does:
  1. Adds new columns to the videos table
     - caption TEXT
     - farmchain_price FLOAT
     - venture_category VARCHAR(100)
     - quality_score FLOAT

  2. Adds new columns to the users table
     - category_affinity JSONB
     - cross_venture_signals JSONB
     - last_active_at TIMESTAMP
     - credits_awarded_this_month INTEGER DEFAULT 0
     - credits_last_reset_at TIMESTAMP

  3. Creates credits_ledger table

Safe to run multiple times — uses IF NOT EXISTS / column existence checks.
"""

import os
import sys

# Make sure we can import models
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

import psycopg2
from urllib.parse import urlparse

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("ERROR: DATABASE_URL not set in .env")
    sys.exit(1)

parsed = urlparse(DATABASE_URL)
conn = psycopg2.connect(
    host=parsed.hostname,
    port=parsed.port or 5432,
    dbname=parsed.path.lstrip("/"),
    user=parsed.username,
    password=parsed.password,
)
conn.autocommit = True
cur = conn.cursor()


def column_exists(table: str, column: str) -> bool:
    cur.execute(
        "SELECT 1 FROM information_schema.columns WHERE table_name=%s AND column_name=%s",
        (table, column),
    )
    return cur.fetchone() is not None


def table_exists(table: str) -> bool:
    cur.execute(
        "SELECT 1 FROM information_schema.tables WHERE table_name=%s",
        (table,),
    )
    return cur.fetchone() is not None


print("Running Phase 6 migrations...")

# ── videos table ──────────────────────────────────────────────────────────
video_cols = [
    ("caption",          "TEXT"),
    ("farmchain_price",  "FLOAT"),
    ("venture_category", "VARCHAR(100)"),
    ("quality_score",    "FLOAT"),
]
for col, dtype in video_cols:
    if not column_exists("videos", col):
        cur.execute(f"ALTER TABLE videos ADD COLUMN {col} {dtype}")
        print(f"  ✓ videos.{col} ({dtype}) added")
    else:
        print(f"  · videos.{col} already exists")

# ── users table ───────────────────────────────────────────────────────────
user_cols = [
    ("category_affinity",          "JSONB DEFAULT '{}'::jsonb"),
    ("cross_venture_signals",      "JSONB DEFAULT '{}'::jsonb"),
    ("last_active_at",             "TIMESTAMP"),
    ("credits_awarded_this_month", "INTEGER DEFAULT 0"),
    ("credits_last_reset_at",      "TIMESTAMP"),
]
for col, dtype in user_cols:
    if not column_exists("users", col):
        cur.execute(f"ALTER TABLE users ADD COLUMN {col} {dtype}")
        print(f"  ✓ users.{col} added")
    else:
        print(f"  · users.{col} already exists")

# ── credits_ledger table ──────────────────────────────────────────────────
if not table_exists("credits_ledger"):
    cur.execute("""
        CREATE TABLE credits_ledger (
            id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id     VARCHAR(100) NOT NULL,
            video_id    VARCHAR(100),
            credit_type VARCHAR(50) NOT NULL,
            amount      INTEGER NOT NULL,
            multiplier  FLOAT DEFAULT 1.0,
            base_amount INTEGER NOT NULL,
            expires_at  TIMESTAMP,
            redeemed_at TIMESTAMP,
            note        TEXT,
            created_at  TIMESTAMP DEFAULT NOW()
        )
    """)
    cur.execute("CREATE INDEX idx_credits_user ON credits_ledger(user_id)")
    cur.execute("CREATE INDEX idx_credits_video ON credits_ledger(video_id)")
    print("  ✓ credits_ledger table created")
else:
    print("  · credits_ledger already exists")

cur.close()
conn.close()
print("\nPhase 6 migration complete.")
