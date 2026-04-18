# Virtual Discovery — AI-Powered Product Discovery Feed
**Accesco Living Pvt. Ltd. | AI/ML Backend | Phase 6 Complete**

Virtual Discovery is the real-time, AI-ranked short-form video feed embedded across Grokly, Swadisht and InstaStyle within the Accesco Living ecosystem. Every video is shoppable. Every frame is ranked by household relevance — not by what brands paid most.

---

## Table of Contents
- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup & Installation](#setup--installation)
- [Running the Server](#running-the-server)
- [API Endpoints](#api-endpoints)
- [Environment Variables](#environment-variables)
- [Database Schema](#database-schema)
- [Phases Delivered](#phases-delivered)
- [Known Bugs Fixed](#known-bugs-fixed)
- [Testing Guide](#testing-guide)

---

## Overview

Virtual Discovery replaces the traditional product browse grid with a full-screen, vertically scrollable short-form video feed. The backend serves 26 endpoints across 7 feature groups, all powered by a real-time AI ranking and personalisation engine.

**Key capabilities:**
- AI-ranked video feed with real-time personalisation
- UGC upload, automated moderation pipeline, and Creator Quality Score (CQS)
- Real-time inventory sync and stock-gate (removes videos with < 3 units)
- Brand ads auction engine with sponsored video insertion
- Discovery Credits ledger for creators
- Household embedding model with cross-venture signals
- GDPR-compliant data deletion

---

## Tech Stack

| Layer | Technology |
|---|---|
| API Framework | FastAPI (Python) |
| ORM | SQLAlchemy |
| Database | PostgreSQL |
| Cache / Feature Store | Redis |
| Event Streaming | Apache Kafka |
| Server | Uvicorn (ASGI) |
| Package Manager | pip |

---

## Project Structure

```
backends/
├── main.py                     # App entry point, router registration
├── .env                        # Environment variables
├── api/
│   ├── events.py               # POST /event — interaction tracking
│   ├── brand.py                # Brand campaign & analytics endpoints
│   ├── cart.py                 # Cart & inventory endpoints
│   ├── moderation.py           # Moderation queue & review endpoints
│   ├── personalisation.py      # Profile, credits, CQS, embedding endpoints
│   └── ugc.py                  # UGC upload endpoint
├── models/
│   ├── database.py             # DB session setup
│   ├── video.py                # Video model
│   ├── user.py                 # User/household model
│   └── inventory.py            # Inventory model
├── ranking/
│   ├── feature_store.py        # Redis feature store, interaction counters
│   └── ranker.py               # Feed ranking logic, sponsored insertion
├── personalisation/
│   └── embedding.py            # Household embedding vectors
├── services/
│   └── ad_auction.py           # Brand ad auction engine
├── moderation/                 # Moderation pipeline
├── scripts/
│   └── migrate_phase6.py       # DB migration script
└── frontend/                   # (Reference only)
```

---

## Prerequisites

Make sure the following are installed and running before starting:

- Python 3.10+
- PostgreSQL (running as Windows service or local server)
- Redis (running as Windows service)
- Apache Kafka (running locally on port 9092)
- pip packages: `fastapi`, `uvicorn`, `sqlalchemy`, `psycopg2-binary`, `redis`, `kafka-python`

---

## Setup & Installation

### 1. Clone the repo and navigate to backends

```bash
cd "C:\Users\USER\Desktop\Virtual Discovery\backends"
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure environment variables

Copy `.env.example` to `.env` and fill in your values:

```env
DATABASE_URL=postgresql://postgres:password@localhost:5432/accesso_discovery
REDIS_URL=redis://localhost:6379
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
ENVIRONMENT=development
```

### 4. Run the database migration (one time only)

```bash
python scripts/migrate_phase6.py
```

This creates all required tables and columns including `credits_ledger`, `caption`, `farmchain_price`, `quality_score`, `category_affinity`.

### 5. Seed test data (optional, for development)

Run this SQL in pgAdmin on the `accesso_discovery` database:

```sql
INSERT INTO inventory (id, sku_id, dark_store_id, units_available, price_current, farmchain_price, delivery_eta_mins, freshness_score)
VALUES (gen_random_uuid(), 'SKU-TOMATO-001', 'store_001', 50, 45.00, 30.00, 20, 0.95);

INSERT INTO videos (id, title, hls_url, thumbnail_url, duration_seconds, venture, sku_id, product_name, price_current, farmchain_price, units_available, delivery_eta_mins, freshness_score, moderation_status, ranking_score, view_count, cart_add_count, is_sponsored)
VALUES
  (gen_random_uuid(), 'Fresh Tomatoes from Karnataka', 'https://test.com/t1.m3u8', 'https://test.com/t1.jpg', 45, 'grokly', 'SKU-TOMATO-001', 'Farm Tomatoes', 45.00, 30.00, 50, 20, 0.95, 'approved', 0.8, 120, 15, false);
```

---

## Running the Server

### Terminal 1 — Start Kafka (CMD, not PowerShell)

```cmd
C:\kafka\bin\windows\kafka-server-start.bat C:\kafka\config\server.properties
```

### Terminal 2 — Start the API server

```bash
cd "C:\Users\USER\Desktop\Virtual Discovery\backends"
python -m uvicorn main:app --reload
```

Redis and PostgreSQL start automatically as Windows services.

### Verify startup

- Swagger UI: http://127.0.0.1:8000/docs — should show 26 endpoints
- Health check: http://127.0.0.1:8000/ — should return `"version": "3.0.0"` with all 6 phases

---

## API Endpoints

### Health
| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | Version check, phases complete |
| GET | `/health` | Database, Redis, Kafka status |

### Discovery Feed
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/v1/discovery/feed` | AI-ranked video feed |
| POST | `/api/v1/discovery/upload` | UGC video upload |
| POST | `/event` | Track user interaction event |

### Cart & Inventory
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/v1/cart/` | Get household cart |
| POST | `/api/v1/cart/add` | Add item to cart |
| DELETE | `/api/v1/cart/remove/{sku_id}` | Remove item from cart |
| GET | `/api/v1/cart/inventory/{sku_id}` | Live inventory check |

### Moderation
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/v1/moderation/status/{video_id}` | Poll moderation result |
| GET | `/api/v1/moderation/queue` | Human review queue (internal) |
| POST | `/api/v1/moderation/review/{video_id}` | Submit reviewer decision (internal) |

### Brand / Ads
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/v1/brand/campaign` | Create sponsored campaign |
| GET | `/api/v1/brand/analytics/{brand_id}` | Real-time campaign stats |
| GET | `/api/v1/brand/ugc-library` | Browse UGC for brand boost |
| POST | `/api/v1/brand/ab-test` | A/B test two video variants |
| POST | `/api/v1/brand/pacing` | Set budget pacing & blackout windows |
| DELETE | `/api/v1/brand/campaign/{brand_id}/{video_id}` | Pause campaign |
| GET | `/api/v1/brand/spend/{brand_id}` | Today's spend |

### Personalisation
| Method | Endpoint | Description |
|---|---|---|
| PUT | `/api/v1/personalisation/profile/{household_id}` | Create/update My Home Profile |
| GET | `/api/v1/personalisation/profile/{household_id}` | Read profile |
| GET | `/api/v1/personalisation/embedding/{household_id}` | Live embedding snapshot |
| GET | `/api/v1/personalisation/credits/{household_id}` | Credits balance & history |
| GET | `/api/v1/personalisation/leaderboard` | Top creators this month |
| GET | `/api/v1/personalisation/cqs/{household_id}` | CQS score breakdown |
| DELETE | `/api/v1/personalisation/data/{household_id}` | GDPR data deletion |

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql://...` | PostgreSQL connection string |
| `REDIS_URL` | `redis://localhost:6379` | Redis connection URL |
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` | Kafka broker address |
| `ENVIRONMENT` | `development` | Set to `production` to strip debug fields |

---

## Database Schema

Core tables:

- **videos** — video metadata, moderation status, ranking scores
- **inventory** — live stock levels per dark store per SKU
- **users** — household profiles, CQS scores, credit balances
- **credits_ledger** — full audit trail of credit awards and expirations

---

## Phases Delivered

| Phase | Feature | Status |
|---|---|---|
| Phase 1 | Video feed, basic ranking | ✅ Complete |
| Phase 2 | Cart & inventory sync | ✅ Complete |
| Phase 3 | UGC upload & moderation pipeline | ✅ Complete |
| Phase 4 | AI ranking & personalisation engine | ✅ Complete |
| Phase 5 | Brand ads auction & analytics | ✅ Complete |
| Phase 6 | Full personalisation model, credits, CQS, GDPR | ✅ Complete |

---

## Known Bugs Fixed

### Bug 1 — Feed filtering NULL `is_sponsored` (`feed.py`)
**Problem:** `Video.is_sponsored == False` drops rows where the column is NULL.
**Fix:** Changed to `Video.is_sponsored.isnot(True)`

### Bug 2 — Interaction counter never incremented (`events.py`)
**Problem:** The `/event` endpoint updated embeddings and Kafka but never called `increment_interaction`, so `personalisation_level` was always `cold_start`.
**Fix:** Added `increment_interaction(event.household_id)` call before Kafka push.

### Bug 3 — Cold-start hardcoded interaction count (`ranking/feature_store.py`)
**Problem:** `_cold_start_user_features()` returned `"interaction_count": 0` hardcoded, ignoring the actual Redis counter.
**Fix:** Changed to `"interaction_count": _get_interaction_count(household_id)`

---

## Testing Guide

### Required headers for feed requests
```
X-Household-ID: household_test_001
X-Session-ID: 550e8400-e29b-41d4-a716-446655440000
```

### Internal API keys (change in production)
```
x-internal-key: dev-internal-key-change-in-prod
x-brand-key: dev-brand-key-change-in-prod
```

### Personalisation levels
- `cold_start` — fewer than 10 interactions
- `partial` — 10 to 49 interactions
- `full` — 50+ interactions

Fire `POST /event` with `event_type: view_complete` to accumulate interactions.

### Redis debug commands
```bash
redis-cli get "session:interactions:household_test_001"   # interaction count
redis-cli keys "session:*"                                # all session keys
redis-cli flushall                                        # reset all (dev only)
```

---

*Accesco Living Pvt. Ltd. | AI/ML Engineering | Confidential*
