# Design Document: Retail Analytics AI System (MVP)

## Overview

AI-powered retail analytics platform with Flutter mobile app for bill scanning, automated ledger management, and intelligent business insights. This MVP design prioritizes rapid development and deployment while maintaining scalability potential for future growth.

### MVP Design Principles

1. **Modular Monolith**: Single backend API with clear module boundaries for future extraction
2. **Minimal Infrastructure**: PostgreSQL + optional Redis for async jobs
3. **Async AI**: Background workers for OCR and ML processing
4. **Mobile-First**: Flutter app with native camera integration
5. **Deploy Anywhere**: Docker-based deployment on single server or cloud VM

### Technology Stack (MVP)

**Mobile App:**
- Flutter for cross-platform iOS/Android
- fl_chart for visualizations
- camera plugin for bill scanning
- http/dio for API calls

**Backend (Modular Monolith):**
- Node.js + Express or Fastify (single application with modules)
- PostgreSQL for all data storage
- Redis (optional) for async job queue
- Bull or BullMQ for background workers (if using Redis)
- OR Node.js worker threads (if no Redis)

**AI/ML:**
- Tesseract.js or node-tesseract-ocr for text extraction
- compromise or natural for entity extraction
- Prophet (via Python subprocess) or simple regression for forecasting
- ml.js or TensorFlow.js for analytics

**Infrastructure:**
- Docker + Docker Compose for local/cloud deployment
- AWS S3 or local filesystem for bill images
- Single server deployment (can scale later)

## Architecture

### Simplified System Diagram

```
┌─────────────────────────────────┐
│      Flutter Mobile App         │
│  ┌──────────┐  ┌──────────┐     │
│  │ Camera   │  │ Charts   │     │
│  │ Scanner  │  │ (fl_chart)│    │
│  └──────────┘  └──────────┘     │
└────────┬────────────────────────┘
         │ HTTPS/REST
         │
┌────────▼────────────────────────┐
│   API Backend (Monolith)        │
│                                 | 
│  ┌────────────────────────────┐ │
│  │  Auth Module               │ │
│  │  - JWT tokens              │ │
│  │  - User management         │ │
│  └────────────────────────────┘ │
│                                 │
│  ┌────────────────────────────┐ │
│  │  Bill Module               │ │
│  │  - Upload handling         │ │
│  │  - OCR job creation        │ │
│  └────────────────────────────┘ │
│                                 │
│  ┌────────────────────────────┐ │
│  │  Ledger Module             │ │
│  │  - Entry CRUD              │ │
│  │  - Duplicate detection     │ │
│  └────────────────────────────┘ │
│                                 │
│  ┌────────────────────────────┐ │
│  │  Analytics Module          │ │
│  │  - Sales trends            │ │
│  │  - Product rankings        │ │
│  │  - Customer activity       │ │
│  └────────────────────────────┘ │
│                                 │
│  ┌────────────────────────────┐ │
│  │  AI Module                 │ │
│  │  - Job management          │ │
│  │  - Result storage          │ │
│  └────────────────────────────┘ │
└────────┬────────────────────────┘
         │
    ┌────▼────-┐
    │PostgreSQL│
    └───-┬──-──┘
         │
    ┌────▼────────────────────────┐
    │  Background Workers         │
    │  (Celery or Threading)      │
    │                             │
    │  ┌──────────┐  ┌─────────┐  │
    │  │   OCR    │  │Forecast │  │
    │  │  Worker  │  │ Worker  │  │
    │  └──────────┘  └─────────┘  │
    └─────────────────────────────┘
```

### Data Flow

**Bill Scanning Flow:**
1. User captures bill → Mobile app uploads to `/bills/upload`
2. Backend saves image, creates OCR job record in DB
3. Background worker picks up job, runs Tesseract OCR
4. Worker extracts entities, creates ledger entry
5. Analytics module updates aggregations
6. Mobile app polls `/bills/{id}/status` or receives push notification

**Analytics Query Flow:**
1. Mobile app requests `/analytics/sales-trends`
2. Backend queries PostgreSQL with aggregations
3. Results returned to mobile app
4. Mobile app renders charts using fl_chart

**AI Insights Flow:**
1. User requests forecast → POST `/ai/forecast`
2. Backend creates job record, returns job ID
3. Background worker picks up job, runs Prophet model
4. Worker stores results in DB
5. Mobile app polls `/ai/jobs/{id}` for completion
6. Mobile app fetches results and renders forecast

## Components and Interfaces

### 1. Flutter Mobile App

**Responsibilities:**
- Capture bill images via camera
- Upload bills to backend
- Display analytics charts
- Poll for job status

**Key Screens:**
- Bill Scanner (camera integration)
- Dashboard (sales trends, rankings)
- Insights (forecasts, inventory alerts)
- Settings (auth, store selection)

### 2. Express/Fastify Backend (Modular Monolith)

**Module Structure:**
```
src/
├── index.js               # Express/Fastify app entry point
├── config/
│   └── database.js        # Sequelize/TypeORM setup
├── auth/
│   ├── routes.js          # /auth/* endpoints
│   ├── service.js         # JWT logic
│   └── models.js          # User model
├── bills/
│   ├── routes.js          # /bills/* endpoints
│   ├── service.js         # Upload, OCR job creation
│   └── models.js          # Bill model
├── ledger/
│   ├── routes.js          # /ledger/* endpoints
│   ├── service.js         # CRUD, duplicate detection
│   └── models.js          # LedgerEntry, LineItem models
├── analytics/
│   ├── routes.js          # /analytics/* endpoints
│   ├── service.js         # Aggregation queries
│   └── calculations.js    # Trend, ranking logic
├── ai/
│   ├── routes.js          # /ai/* endpoints
│   ├── service.js         # Job management
│   └── models.js          # AIJob, AIResult models
└── workers/
    ├── ocrWorker.js       # OCR + entity extraction
    ├── forecastWorker.js  # Demand forecasting
    └── inventoryWorker.js # Inventory analysis
```

**API Endpoints:**

```javascript
// Auth
POST   /auth/login
POST   /auth/refresh
POST   /auth/logout

// Bills
POST   /bills/upload
GET    /bills/:id
GET    /bills/:id/status
GET    /bills

// Ledger
POST   /ledger/entries
GET    /ledger/entries
GET    /ledger/entries/:id
PUT    /ledger/entries/:id
DELETE /ledger/entries/:id

// Analytics
GET    /analytics/sales-trends
GET    /analytics/product-rankings
GET    /analytics/customer-activity

// AI
POST   /ai/forecast
POST   /ai/inventory-analysis
POST   /ai/festival-recommendations
GET    /ai/jobs/:id
GET    /ai/jobs/:id/result
```

### 3. Background Workers

**OCR Worker:**
```javascript
async function processOCRJob(billId) {
  // 1. Fetch bill from DB
  const bill = await Bill.findByPk(billId);
  
  // 2. Download image from S3 or filesystem
  const image = await downloadImage(bill.imageUrl);
  
  // 3. Run Tesseract.js OCR
  const { data: { text } } = await Tesseract.recognize(image, 'eng+hin');
  
  // 4. Extract entities using regex/NLP
  const entities = await extractEntities(text);
  
  // 5. Create ledger entry
  const ledgerEntry = await createLedgerEntry(entities, billId);
  
  // 6. Update bill status
  bill.status = 'COMPLETED';
  await bill.save();
}
```

**Forecast Worker:**
```javascript
async function generateForecast(jobId) {
  // 1. Fetch job config
  const job = await AIJob.findByPk(jobId);
  
  // 2. Load historical sales data
  const salesData = await loadSalesData(job.userId, { days: 90 });
  
  // 3. Run forecasting model (simple regression or Prophet via Python subprocess)
  const forecast = await runForecastModel(salesData, job.config.horizon);
  
  // 4. Store results
  await AIResult.create({
    jobId: job.id,
    data: forecast
  });
  
  // 5. Update job status
  job.status = 'COMPLETED';
  await job.save();
}
```

**Inventory Analysis Worker:**
```javascript
async function analyzeInventory(jobId) {
  // 1. Fetch job config
  const job = await AIJob.findByPk(jobId);
  
  // 2. Load sales data
  const sales = await loadProductSales(job.config.productId, { days: 30 });
  
  // 3. Calculate moving average
  const ma7d = movingAverage(sales, 7);
  const ma14d = movingAverage(sales, 14);
  
  // 4. Calculate velocity
  const velocity = mean(sales.slice(-7));
  
  // 5. Estimate exhaustion
  const currentStock = await getCurrentStock(job.config.productId);
  const daysLeft = velocity > 0 ? currentStock / velocity : Infinity;
  
  // 6. Generate alert if needed
  if (daysLeft < 14) {
    await createLowStockAlert({ productId: job.config.productId, daysLeft });
  }
  
  // 7. Store results
  await AIResult.create({
    jobId: job.id,
    data: { ma7d, ma14d, velocity, daysLeft }
  });
  
  job.status = 'COMPLETED';
  await job.save();
}
```

## Data Models

### PostgreSQL Schema

```sql
-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Stores
CREATE TABLE stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  name VARCHAR(255) NOT NULL,
  region VARCHAR(100)
);

-- Bills
CREATE TABLE bills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  store_id UUID REFERENCES stores(id),
  image_url TEXT NOT NULL,
  ocr_text TEXT,
  status VARCHAR(50) DEFAULT 'UPLOADED',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Ledger Entries
CREATE TABLE ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  store_id UUID REFERENCES stores(id),
  bill_id UUID REFERENCES bills(id),
  transaction_date TIMESTAMP NOT NULL,
  total_amount DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Line Items
CREATE TABLE line_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_entry_id UUID REFERENCES ledger_entries(id) ON DELETE CASCADE,
  product_name VARCHAR(255) NOT NULL,
  quantity DECIMAL(10, 2) NOT NULL,
  unit_price DECIMAL(10, 2) NOT NULL,
  total_price DECIMAL(10, 2) NOT NULL
);

-- AI Jobs
CREATE TABLE ai_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  job_type VARCHAR(50) NOT NULL,
  config JSONB NOT NULL,
  status VARCHAR(50) DEFAULT 'QUEUED',
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
);

-- AI Results
CREATE TABLE ai_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID REFERENCES ai_jobs(id),
  data JSONB NOT NULL,
  confidence DECIMAL(3, 2),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_ledger_user_date ON ledger_entries(user_id, transaction_date);
CREATE INDEX idx_line_items_product ON line_items(product_name);
CREATE INDEX idx_bills_user_status ON bills(user_id, status);
CREATE INDEX idx_ai_jobs_status ON ai_jobs(status);
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: OCR Accuracy Threshold
*For any* bill image with printed text, OCR extraction accuracy should meet or exceed 85%.
**Validates: Requirements 1.1**

### Property 2: OCR Error Handling
*For any* blurry/corrupted image, OCR_Service should return descriptive error.
**Validates: Requirements 1.3**

### Property 3: Multi-Language OCR
*For any* bill with English/Hindi text, OCR should extract both languages.
**Validates: Requirements 1.4**

### Property 4: Image Format Validation
*For any* image file, JPEG/PNG/HEIC under 10MB should be accepted, others rejected.
**Validates: Requirements 1.5**

### Property 5: Complete Entity Extraction
*For any* OCR text, Entity_Extractor should identify all present entities (products, prices, dates, merchant).
**Validates: Requirements 2.1**

### Property 6: Currency Format Recognition
*For any* price text with ₹/$ symbols, Entity_Extractor should parse correctly.
**Validates: Requirements 2.2**

### Property 7: Date Format Parsing
*For any* date in DD/MM/YYYY, MM-DD-YYYY, or DD-MMM-YYYY format, parser should convert to Date object.
**Validates: Requirements 2.3**

### Property 8: Low Confidence Flagging
*For any* extraction with confidence <70%, system should flag for manual review.
**Validates: Requirements 2.4**

### Property 9: Line Item Separation
*For any* bill with N products, Entity_Extractor should create N separate line item records.
**Validates: Requirements 2.5**

### Property 10: Bill Total Validation (Invariant)
*For any* extracted bill, sum of line item totals should equal bill total (within 0.01 tolerance).
**Validates: Requirements 2.6**

### Property 11: Ledger Entry Creation
*For any* successful extraction, Ledger_Manager should create entry with all details.
**Validates: Requirements 3.1**

### Property 12: Unique Transaction IDs
*For any* set of ledger entries, all transaction IDs should be unique.
**Validates: Requirements 3.2**

### Property 13: Data Encryption
*For any* sensitive data (bills, ledger, prices), Storage_Service should encrypt with AES-256.
**Validates: Requirements 3.3, 13.4, 14.1, 14.2**

### Property 14: Duplicate Bill Detection
*For any* previously scanned bill, re-scanning should be detected and not create duplicate entry.
**Validates: Requirements 3.4**

### Property 15: Bill-Ledger Referential Integrity
*For any* ledger entry, corresponding bill record should exist.
**Validates: Requirements 3.5**

### Property 16: Audit Log Creation
*For any* ledger edit, system should create audit log with timestamp, user, action, changes.
**Validates: Requirements 3.6**

### Property 17: Sales Aggregation Correctness
*For any* time period, calculated sales totals should equal sum of transaction totals in that period.
**Validates: Requirements 4.1**

### Property 18: Growth Rate Calculation
*For any* two consecutive periods, growth rate = ((current - previous) / previous) * 100.
**Validates: Requirements 4.2**

### Property 19: Analytics Filtering
*For any* query with filters, all results should satisfy filter criteria.
**Validates: Requirements 4.4**

### Property 20: Product Ranking Correctness
*For any* product set, ranking by metric should order products in descending order by that metric.
**Validates: Requirements 5.1**

### Property 21: Product Metrics Calculation
*For any* product, units_sold = sum(quantities), revenue = sum(totals), avg = revenue / transaction_count.
**Validates: Requirements 5.2**

### Property 22: Time-Period Ranking
*For any* ranking query with time period, only transactions in that window should be included.
**Validates: Requirements 5.4**

### Property 23: Percentage Contribution
*For any* product ranking, sum of all percentage contributions should equal 100% (±0.01%).
**Validates: Requirements 5.5**

### Property 24: Peak Time Detection
*For any* transaction set, identified peaks should correspond to highest transaction count periods.
**Validates: Requirements 6.1**

### Property 25: Customer Activity Metrics
*For any* transaction set, avg_transaction_value = total_revenue / count, avg_basket_size = total_items / count.
**Validates: Requirements 6.2**

### Property 26: Anomaly Detection
*For any* time series, spikes/drops exceeding 2 standard deviations from moving average should be flagged.
**Validates: Requirements 6.4**

### Property 27: Privacy Through Aggregation
*For any* customer activity display, individual transactions should not be identifiable.
**Validates: Requirements 6.5**

### Property 28: Moving Average Calculation
*For any* product sales, moving average over window W should equal mean of values in that window.
**Validates: Requirements 7.1**

### Property 29: Low-Stock Alert Generation
*For any* product where (current_stock / velocity) < threshold, system should generate alert.
**Validates: Requirements 7.2**

### Property 30: Confidence Score Validity
*For any* AI prediction, confidence score should be in [0.0, 1.0].
**Validates: Requirements 7.4**

### Property 31: Reorder Quantity Calculation
*For any* low-stock alert, reorder_qty = (velocity * (lead_time + buffer)) - current_stock, always ≥ 0.
**Validates: Requirements 7.5**

### Property 32: Festival Recommendation Formatting
*For any* festival recommendation, output should include product, recommended stock, percentage increase, baseline.
**Validates: Requirements 8.3**

### Property 33: Insufficient Data Fallback
*For any* AI request with <30 days data, system should use industry benchmarks as fallback.
**Validates: Requirements 8.5**

### Property 34: Forecast Horizon Support
*For any* forecast request, system should generate predictions for all requested horizons (30/60/90 days).
**Validates: Requirements 9.2**

### Property 35: Forecast Accuracy Monitoring
*For any* model with accuracy <75%, system should alert admin and trigger retraining.
**Validates: Requirements 9.5**

### Property 36: Feature Importance Validity
*For any* forecast with feature importance, sum should equal 1.0 (±0.01), all values in [0.0, 1.0].
**Validates: Requirements 9.6**

### Property 37: Stateless Request Handling
*For any* API request, it should be processable by any server instance without server-side session state.
**Validates: Requirements 11.2, 11.4**

### Property 38: JWT Token Validation
*For any* API request with JWT, system should validate signature, expiration, payload, rejecting invalid tokens.
**Validates: Requirements 11.3, 13.2**

### Property 39: Stateless Pagination
*For any* paginated response, cursor should be stateless and work on any server instance.
**Validates: Requirements 11.5**

### Property 40: Asynchronous Job Creation
*For any* AI request, API should return job ID immediately (<1s), processing asynchronously.
**Validates: Requirements 12.1**

### Property 41: Job Completion Notification
*For any* async job, system should notify client when complete (success/failure).
**Validates: Requirements 12.2**

### Property 42: Queue Depth Time Estimation
*For any* queued job, estimated_time = (queue_position * avg_duration) + current_time.
**Validates: Requirements 12.3**

### Property 43: Concurrent Job Processing
*For any* job set, up to N jobs (worker pool size) should process concurrently.
**Validates: Requirements 12.4**

### Property 44: Job Retry with Exponential Backoff
*For any* failed job, system should retry up to 3 times with exponential backoff (1s, 2s, 4s) before permanent failure.
**Validates: Requirements 12.5**

### Property 45: JWT Token Issuance
*For any* successful login, Auth_Service should issue JWT with 24h expiration and refresh token.
**Validates: Requirements 13.1**

### Property 46: Rate Limiting Enforcement
*For any* user, system should enforce 100 requests/minute limit, rejecting excess with 429 status.
**Validates: Requirements 13.5**

### Property 47: Account Lockout on Failed Logins
*For any* user with 5 failed logins in 15 minutes, account should be locked and user notified.
**Validates: Requirements 13.6**

### Property 48: Encryption Key Separation
*For any* encrypted data, encryption keys should be stored in separate KMS, not with data.
**Validates: Requirements 14.3**

### Property 49: Backup Encryption and Integrity
*For any* backup, file should be encrypted and integrity verified before completion.
**Validates: Requirements 14.4**

### Property 50: Data Retention Policy
*For any* data older than retention threshold, it should be automatically deleted.
**Validates: Requirements 14.5**

### Property 51: Distributed Cache Consistency
*For any* cached data in Redis, all server instances should access same shared cache.
**Validates: Requirements 15.2**

### Property 52: Job Distribution Across Workers
*For any* AI workload, jobs should be distributed evenly across worker nodes.
**Validates: Requirements 15.3**

### Property 53: Read Replica Load Distribution
*For any* analytics query (read), it should route to read replicas; writes to primary.
**Validates: Requirements 15.4**

### Property 54: Analytics Event Logging
*For any* user interaction (page view, feature use, error), event should log to Firebase Analytics.
**Validates: Requirements 16.1**

### Property 55: Error Context Capture
*For any* critical error, details should include stack trace, user context, timestamp, system state.
**Validates: Requirements 16.2**

### Property 56: Metrics Tracking
*For any* operation, key metrics (DAU, bills scanned, API latency) should be tracked in real-time.
**Validates: Requirements 16.3**

### Property 57: PII Anonymization in Logs
*For any* log entry, PII (names, emails, phones, addresses) should be anonymized.
**Validates: Requirements 16.4**

### Property 58: Large Dataset Optimization
*For any* chart with >1000 points, Mobile_App should apply aggregation/sampling before rendering.
**Validates: Requirements 17.5**

### Property 59: Multi-Store Ledger Association
*For any* ledger entry in multi-store mode, it should be associated with specific store ID.
**Validates: Requirements 18.1**

### Property 60: Multi-Store Comparative Analytics
*For any* analytics query in multi-store mode, per-store metrics should be comparable across stores.
**Validates: Requirements 18.2**

### Property 61: Store-Based Filtering
*For any* query filtered by store ID, only data for that store should be returned.
**Validates: Requirements 18.3**

### Property 62: Store-Specific AI Recommendations
*For any* AI request in multi-store mode, recommendations should use store-specific historical patterns.
**Validates: Requirements 18.4**

### Property 63: Chain-Wide Aggregation
*For any* chain-wide query, aggregated values should equal sum of individual store metrics.
**Validates: Requirements 18.5**

### Property 64: Regional Model Selection
*For any* AI request with regional models, system should select model based on store location/user preference.
**Validates: Requirements 19.1**

### Property 65: Regional Festival Calendar
*For any* festival recommendation with regional models, system should use region-appropriate calendar.
**Validates: Requirements 19.2**

### Property 66: Regional Training Data
*For any* forecast with regional models, system should use region-specific training data.
**Validates: Requirements 19.3**

### Property 67: Multi-Language Product Support
*For any* product in regional mode, system should support storage/display in multiple languages.
**Validates: Requirements 19.4**

### Property 68: Regional Configuration
*For any* region, admins should configure region-specific parameters (currency, tax, hours), applied to all operations.
**Validates: Requirements 19.5**

## Error Handling

**OCR Errors:**
- Blurry image → Return error with "retake photo" suggestion
- Corrupted file → Return format validation error
- Low confidence → Flag for manual review

**Entity Extraction Errors:**
- Missing fields → Prompt user for manual entry
- Invalid totals → Alert user, allow correction
- Low confidence (<70%) → Flag for review

**API Errors:**
- 401: Invalid/expired token → Refresh token
- 403: Account locked → Show lockout reason
- 429: Rate limit → Show retry-after time
- 400: Validation error → Show field errors

**AI Processing Errors:**
- Model failure → Retry with different version
- Timeout → Cancel job, offer retry
- Insufficient data → Use fallback benchmarks

## Testing Strategy

### Dual Testing Approach

**Unit Tests:**
- Module-level tests for each backend module
- Mock database and external dependencies
- Test specific examples and edge cases
- Target: 80% code coverage

**Property-Based Tests:**
- Universal properties across all inputs
- Randomized input generation
- 100 iterations per test
- Tag format: **Feature: retail-analytics-ai, Property {N}: {text}**

### Framework Selection
- **Flutter/Dart**: faker for test data generation
- **Node.js**: fast-check for property-based testing, Jest/Mocha for unit tests

### Test Layers
1. **Unit**: Module-level, mocked dependencies
2. **Integration**: Module interactions, test DB
3. **Property**: Universal properties, randomized inputs
4. **E2E**: Complete workflows, staging environment

### CI Pipeline
1. Unit tests on every commit
2. Integration tests on PRs
3. Property tests nightly
4. E2E tests before deployment

## Deployment

### MVP Deployment (Single Server)

**Docker Compose Setup:**
```yaml
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/retail_analytics
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
  
  worker:
    build: ./backend
    command: node src/workers/index.js
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/retail_analytics
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
  
  db:
    image: postgres:15
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=retail_analytics
  
  redis:
    image: redis:7
    
volumes:
  postgres_data:
```

**Deployment Options:**
- Local: `docker-compose up`
- Cloud VM: AWS EC2, DigitalOcean Droplet, Google Compute Engine
- Platform: Railway, Render, Fly.io

## What Was Removed and Why

### Removed Components
1. **Kubernetes** → Overkill for MVP, Docker Compose sufficient
2. **Microservices** → Converted to modular monolith for simplicity
3. **API Gateway (Nginx)** → Express/Fastify handles routing, can add later
4. **MongoDB** → PostgreSQL handles all data, JSONB for flexible schemas
5. **RabbitMQ** → Optional Redis + Bull/BullMQ, or Node.js worker threads
6. **WebSocket real-time updates** → Polling sufficient for MVP
7. **Read replicas** → Single DB instance, can add later
8. **Distributed caching** → Optional Redis, or in-memory cache
9. **Auto-scaling** → Manual scaling sufficient for MVP
10. **Firebase Analytics** → Can add later, focus on core features

### Why These Changes
- **Faster development**: Single codebase, fewer moving parts
- **Lower costs**: Single server deployment
- **Easier debugging**: All code in one place
- **Simpler deployment**: Docker Compose vs Kubernetes
- **Maintainable**: Small team can manage monolith

## Phase 2: Scaling Plan

### When to Scale (Indicators)
- 1000+ concurrent users
- 10,000+ bills processed per day
- API response times > 500ms
- Database queries > 1s
- Worker queue backlog > 1 hour

### Scaling Path

**Step 1: Vertical Scaling**
- Upgrade server CPU/RAM
- Add database indexes
- Enable Redis caching
- Optimize slow queries

**Step 2: Horizontal Scaling (Stateless API)**
- Deploy multiple backend instances
- Add load balancer (Nginx)
- Use Redis for shared cache
- Ensure JWT-based stateless auth

**Step 3: Database Scaling**
- Add read replicas for analytics queries
- Partition large tables by user_id or date
- Consider TimescaleDB for time-series data

**Step 4: Microservices Extraction**
- Extract AI module → Separate AI service
- Extract Analytics module → Separate Analytics service
- Keep Auth, Bills, Ledger in monolith

**Step 5: Advanced Infrastructure**
- Kubernetes for orchestration
- Message queue (RabbitMQ/SQS) for reliability
- CDN for bill images
- Monitoring (Prometheus, Grafana)

### Future Enhancements
- Real-time WebSocket updates
- On-device ML inference (TensorFlow Lite)
- Multi-region deployment
- Advanced caching strategies
- Event-driven architecture
