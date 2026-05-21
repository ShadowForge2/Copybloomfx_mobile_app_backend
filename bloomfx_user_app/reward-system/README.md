# BloomFX Reward Distribution System

## Overview

A deterministic, capped reward engine where users earn profit based on deposit amount and rank. Total profit is always limited to **5% of deposit over 30 days** — rank only controls claim **frequency**, not total ROI.

---

## 1. Backend Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client App (Flutter)                      │
└───────────────────────────┬─────────────────────────────────────┘
                            │ HTTPS + JWT
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Express API Server (:3001)                     │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Helmet   │  │ RateLimit │  │Auth Guard│  │ Global Error  │  │
│  │ (CORS)   │  │(10/min)   │  │(JWT)     │  │ Handler       │  │
│  └──────────┘  └───────────┘  └──────────┘  └───────────────┘  │
│                          │                                       │
│  ┌────────────────────────────────────────────────────────┐      │
│  │              Reward Engine (Service Layer)              │      │
│  │  createDeposit()  calculateReward()  claimReward()      │      │
│  │  checkCooldown()  checkPayoutCap()   expireDeposits()   │      │
│  └────────────────────────────────────────────────────────┘      │
│                          │                                       │
│  ┌────────────────────────────────────────────────────────┐      │
│  │               MongoDB (Mongoose ODM)                    │      │
│  │  ┌──────────────┐  ┌──────────────┐                     │      │
│  │  │ RewardDeposit│  │  ClaimLog    │                     │      │
│  │  │ (deposits)   │  │ (audit)      │                     │      │
│  │  └──────────────┘  └──────────────┘                     │      │
│  └────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
                    Cron Job (node-cron)
                    Daily: expireDeposits()
                    Midnight auto-sweep
```

---

## 2. Database Schema

### Collection: `rewarddeposits`

| Field               | Type     | Description                                      |
|---------------------|----------|--------------------------------------------------|
| `_id`               | ObjectId | Primary key                                      |
| `userId`            | ObjectId | Ref → User                                       |
| `depositAmount`     | Number   | Original deposit (>= 7)                          |
| `lockedBalance`     | Number   | Currently locked (= depositAmount)               |
| `accumulatedRewards`| Number   | Sum of all claimed rewards (default 0)           |
| `rank`              | Number   | 1–6                                              |
| `lastClaimAt`       | Date     | Last successful claim timestamp                  |
| `totalClaims`       | Number   | Total number of claims made                      |
| `status`            | String   | `active` / `capped` / `expired` / `cancelled`    |
| `payoutCap`         | Number   | `depositAmount × 0.05` (5%)                      |
| `expiresAt`         | Date     | `createdAt + 30 days` (TTL index auto-deletes)   |
| `createdAt`         | Date     | Auto                                              |
| `updatedAt`         | Date     | Auto                                              |

**Indexes:** `{ userId, status }`, `{ expiresAt }` (TTL)

### Collection: `claimlogs`

| Field         | Type     | Description                       |
|---------------|----------|-----------------------------------|
| `_id`         | ObjectId | Primary key                       |
| `depositId`   | ObjectId | Ref → RewardDeposit               |
| `userId`      | ObjectId | Ref → User                        |
| `rank`        | Number   | Rank at time of claim             |
| `claimNumber` | Number   | Sequential claim # for this deposit |
| `amount`      | Number   | Reward amount claimed             |
| `runningTotal`| Number   | Accumulated rewards after claim   |
| `ip`          | String   | Claimant IP (audit)               |
| `userAgent`   | String   | UA string (audit)                 |
| `createdAt`   | Date     | Claim timestamp                   |

**Indexes:** `{ depositId, createdAt }`, `{ userId, createdAt }`

---

## 3. Reward Calculation Logic

### Core formula (immutable)

```
reward_per_claim = (depositAmount × 0.05) / (30 × rank)
```

### Why this works

| Rank | Claims/day | Total claims (30d) | Reward/claim | Total reward | ROI   |
|------|-----------|-------------------|-------------|-------------|-------|
| 1    | 1         | 30                | D×0.05/30   | D×0.05      | **5%** |
| 2    | 2         | 60                | D×0.05/60   | D×0.05      | **5%** |
| 3    | 3         | 90                | D×0.05/90   | D×0.05      | **5%** |
| 4    | 4         | 120               | D×0.05/120  | D×0.05      | **5%** |
| 5    | 5         | 150               | D×0.05/150  | D×0.05      | **5%** |
| 6    | 6         | 180               | D×0.05/180  | D×0.05      | **5%** |

**Total ROI is identical across all ranks — only frequency differs.**

### Example: $100 deposit

| Rank | Per claim | Per day | 30-day total |
|------|----------|---------|-------------|
| 1    | $0.1667  | $0.1667 | **$5.00**   |
| 3    | $0.0556  | $0.1667 | **$5.00**   |
| 6    | $0.0278  | $0.1667 | **$5.00**   |

---

## 4. Example API Endpoints

| Method | Endpoint                          | Description                     |
|--------|-----------------------------------|---------------------------------|
| POST   | `/api/rewards/deposit`            | Create a reward deposit         |
| POST   | `/api/rewards/claim`              | Claim one reward (cooldown-gated) |
| GET    | `/api/rewards/status/:depositId`  | Full deposit status + cooldown  |
| GET    | `/api/rewards/history/:depositId` | Claim history (last 200)        |
| GET    | `/api/rewards/user`               | All deposits for current user   |
| POST   | `/api/rewards/admin/force-cap/:depositId` | Admin: force cap a deposit |
| GET    | `/health`                         | Health check                    |

### Example: Claim flow

```
POST /api/rewards/claim
Authorization: Bearer <token>
Body: { "depositId": "664abc..." }

Response:
{
  "success": true,
  "data": {
    "claimed": 0.16,
    "runningTotal": 3.20,
    "isCapped": false
  }
}
```

### Example: Status check

```
GET /api/rewards/status/664abc...

Response:
{
  "success": true,
  "data": {
    "depositAmount": 100,
    "accumulatedRewards": 4.50,
    "rank": 3,
    "totalClaims": 81,
    "rewardPerClaim": 0.0556,
    "payoutCap": 5.00,
    "status": "active",
    "cooldown": {
      "canClaim": true,
      "usedInWindow": 2,
      "limit": 3
    },
    "cap": {
      "isCapped": false,
      "remaining": 0.50
    }
  }
}
```

---

## 5. Secure Anti-Abuse Logic

| Threat                    | Mitigation                                           |
|---------------------------|------------------------------------------------------|
| **Replay attack**         | Server tracks `lastClaimAt` + `totalClaims` — no two same claims possible |
| **Clock manipulation**    | Cooldown uses server time (`Date.now()`) exclusively |
| **Race condition**        | Claims are sequential DB writes (atomic `$inc`) — use MongoDB transactions if needed |
| **Rate abuse**            | `express-rate-limit` (10 req/min per IP) + per-deposit cooldown window |
| **Payout cap bypass**     | `Math.min(rawAmount, remaining)` ensures cap is never exceeded |
| **Expired deposit replay**| `expiresAt` guard + TTL index auto-deletes documents |
| **Unauthorized access**   | JWT auth on every endpoint                           |
| **Frequent claims**       | Cooldown counts claims in sliding 24h window per rank limit |
| **Upgrade/downgrade abuse**| Rank is snapshotted per-deposit at creation — does not change mid-deposit |
| **Admin override**        | `forceCapDeposit()` safety valve                     |

---

## 6. Example Implementation (Node.js/Express)

See the following source files:

```
reward-system/
├── package.json
├── .env.example
├── src/
│   ├── server.js                  # Express app, cron, DB connect
│   ├── models/
│   │   ├── RewardDeposit.js       # Mongoose schema + virtuals
│   │   └── ClaimLog.js            # Audit trail schema
│   ├── services/
│   │   └── rewardEngine.js        # Core: createDeposit, claimReward, etc.
│   ├── routes/
│   │   └── rewards.js             # API endpoints
│   ├── middleware/
│   │   └── auth.js                # JWT guard
│   └── utils/
│       ├── asyncWrap.js           # Async error wrapper
│       └── logger.js              # Winston logger
```

### Key invariants enforced in `rewardEngine.js`:

1. `createDeposit()` → computes `payoutCap = amount × 0.05`, sets `expiresAt = now + 30 days`
2. `calculateReward()` → pure function: `(deposit × 0.05) / (30 × rank)`
3. `claimReward()` → guards (status/expiry/cap) → cooldown check → calculate → cap-floor → save → audit log
4. `checkCooldown()` → counts claims in sliding 24h window per rank limit
5. `checkPayoutCap()` → compares `accumulatedRewards ≥ payoutCap`

---

## 7. Suggested Cron / Automation Flow

```
Midnight (00:00) — node-cron ─────────────────────────────────────┐
                                                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│  expireDeposits()                                                │
│  UPDATE rewarddeposits SET status='expired'                      │
│  WHERE expiresAt < NOW() AND status = 'active'                   │
│                                                                  │
│  MongoDB TTL index on expiresAt auto-cleans after expiry         │
└──────────────────────────────────────────────────────────────────┘

Startup ──────────────────────────────────────────────────────────┐
                                                                    ▼
┌──────────────────────────────────────────────────────────────────┐
│  expireDeposits() runs once on server boot                       │
│  (catches any missed sweeps during downtime)                     │
└──────────────────────────────────────────────────────────────────┘
```

No complex cron chains needed — `expireDeposits()` is idempotent and safe to run redundantly.

---

## 8. Edge-Case Handling

| Scenario                              | Behavior                                                      |
|---------------------------------------|---------------------------------------------------------------|
| Deposit < $7                          | Rejected with `Minimum deposit is $7`                        |
| Claim after 30 days                   | `expiresAt` guard → status='expired', reward blocked          |
| Claim when `accumulatedRewards == cap`| status='capped', reward blocked                               |
| Claim when `accumulatedRewards ≈ cap` | Final claim takes `Math.min` so it never exceeds cap          |
| Rank changes mid-deposit              | Rank is per-deposit immutable — new deposits use new rank     |
| Server restart during claim           | Transaction safety — use MongoDB sessions for atomicity       |
| Network failure after DB write        | ClaimLog written atomically with deposit save                 |
| Multiple rapid claims (race)          | MongoDB `$inc` is atomic — use `findOneAndUpdate` for strict  |
| Zero-balance deposit                  | Not possible — `min: 7` on schema level                       |
| Deposit after 30 days expired         | User creates a new deposit (new 30-day window)               |

---

## 9. Platform Sustainability Recommendations

### Economic safety

1. **5% hard cap is non-negotiable** — never change `MAX_PROFIT_PCT` per-deposit; each deposit's cap is computed at creation and stored immutably
2. **No compounding** — rewards go to withdrawable balance, not locked; prevents exponential growth
3. **Per-deposit isolation** — each deposit has its own cap; multiple deposits = multiple independent caps
4. **No reinvestment loop** — user must make a new deposit to earn more

### Operational

5. **Rate limit API** — 10 claims/min per IP prevents scripted abuse
6. **Audit trail** — `ClaimLog` gives full forensic visibility into every reward event
7. **Admin kill switch** — `forceCapDeposit()` lets admins halt any deposit immediately
8. **Monitor** — alert on:
   - Claims rejected due to cap (legitimate users hitting limit)
   - Failed cooldown checks (potential abuse attempts)
   - Deposit creation spikes (sybil attack detection)

### Scaling

9. **Stateless API** — reward engine is pure logic + DB; scale horizontally behind a load balancer
10. **MongoDB TTL index** — auto-cleans expired documents, no manual cleanup needed
11. **Read replicas** — `/status` and `/history` endpoints can use secondary reads
12. **Idempotency key** — optional `Idempotency-Key` header on `/claim` for safe retries

### Code maintainability

13. All protocol constants in one place (`rewardEngine.js` top section)
14. Pure `calculateReward()` is unit-testable with zero dependencies
15. Comprehensive test suite (Jest) recommended for all guard conditions
