# Design Document: Retail Analytics AI System

## Overview

AI-powered retail analytics platform with Flutter mobile app for bill scanning, automated ledger management, and intelligent business insights.

### Core Principles

1. **Stateless APIs**: JWT-based REST endpoints for horizontal scaling
2. **Async AI**: Long-running ML operations via job queue
3. **Mobile-First**: Flutter app with native camera integration
4. **Microservices**: Decoupled services for OCR, analytics, and AI

### Technology Stack

**Mobile App:**
- Flutter for cross-platform iOS/Android
- fl_chart for visualizations
- camera plugin for bill scanning
- http/dio for API calls

**Backend:**
- Python FastAPI for REST APIs
- PostgreSQL for ledger data
- Redis for caching and pub/sub
- RabbitMQ for async job queue

**AI/ML:**
- Tesseract OCR for text extraction
- spaCy for entity extraction
- Prophet for time-series forecasting
- scikit-learn for analytics

**Infrastructure:**
- Docker + Kubernetes
- AWS S3 for bill images
- AWS KMS for encryption keys

## Architecture

```
┌─────────────────────────────────┐
│      Flutter Mobile App         │
│  ┌──────────┐  ┌──────────┐    │
│  │ Camera   │  │ SQLite   │    │
│  │ Scanner  │  │ Queue    │    │
│  └──────────┘  └──────────┘    │
└────────┬────────────────────────┘
         │ HTTPS/REST
         │
┌────────▼────────────────────────┐
│      API Gateway (Nginx)        │
│      JWT Validation             │
└────┬────┬────┬────┬────┬────────┘
     │    │    │    │    │
  ┌──▼─┐┌─▼──┐┌▼──┐┌▼──┐┌▼───┐
  │Auth││Bill││Led││Ana││AI  │
  │Svc ││Svc ││Svc││Svc││Svc │
  └──┬─┘└─┬──┘└┬──┘└┬──┘└┬───┘
     │    │    │    │    │
     └────┴────▼────┴────┘
          PostgreSQL
               │
     ┌─────────┴─────────┐
     │                   │
  ┌──▼──┐          ┌────▼────┐
  │Redis│          │RabbitMQ │
  └─────┘          └────┬────┘
                        │
                   ┌────▼────┐
                   │AI Workers│
                   │OCR/ML   │
                   └─────────┘
```

## Components and Interfaces

### 1. Flutter Mobile App

**Responsibilities:**
- Capture bill images via camera
- Display analytics charts (line, bar, heatmap, forecast)
- Real-time data updates

**Key Interfaces:**

```dart
class BillScanner {
  Future<File> captureBill();
  Future<String> uploadBill(File image);
}

class AnalyticsView {
  Widget renderSalesTrend(SalesTrendData data);
  Widget renderProductRanking(List<Product> products);
  Widget renderForecast(ForecastData forecast);
}
```

### 2. Auth Service

**Responsibilities:**
- Issue/validate JWT tokens
- Handle login/logout
- Enforce rate limiting

**API Endpoints:**
```
POST /auth/login
POST /auth/refresh
POST /auth/logout
```

### 3. Bill Service

**Responsibilities:**
- Accept bill image uploads
- Store in S3 with encryption
- Create OCR jobs

**API Endpoints:**
```
POST /bills/upload
GET /bills/{id}
GET /bills/{id}/status
```

### 4. OCR Worker

**Responsibilities:**
- Extract text from bill images
- Preprocess images (deskew, enhance)
- Return text with confidence scores

**Process:**
1. Fetch image from S3
2. Preprocess (deskew, denoise, contrast)
3. Run Tesseract OCR
4. Return text + confidence

### 5. Entity Extractor

**Responsibilities:**
- Parse OCR text for entities
- Extract products, prices, dates, merchant
- Validate totals

**Logic:**
```python
def extract_entities(ocr_text):
    # Regex patterns for prices, dates
    products = extract_products(ocr_text)
    prices = extract_prices(ocr_text)
    date = extract_date(ocr_text)
    total = extract_total(ocr_text)
    
    # Validate sum of line items = total
    if abs(sum(prices) - total) > 0.01:
        flag_for_review = True
    
    return ExtractedEntities(...)
```

### 6. Ledger Service

**Responsibilities:**
- Create/update/delete ledger entries
- Detect duplicate bills
- Maintain audit logs

**API Endpoints:**
```
POST /ledger/entries
GET /ledger/entries
PUT /ledger/entries/{id}
DELETE /ledger/entries/{id}
GET /ledger/entries/{id}/audit
```

### 7. Analytics Engine

**Responsibilities:**
- Calculate sales trends, rankings, activity
- Cache results in Redis
- Trigger real-time updates

**Calculations:**
```python
def calculate_sales_trend(user_id, start_date, end_date, aggregation):
    # Query ledger entries
    entries = db.query(LedgerEntry).filter(...)
    
    # Aggregate by day/week/month
    if aggregation == 'daily':
        groups = group_by_day(entries)
    elif aggregation == 'weekly':
        groups = group_by_week(entries)
    else:
        groups = group_by_month(entries)
    
    # Calculate growth rates
    for i in range(1, len(groups)):
        growth = (groups[i] - groups[i-1]) / groups[i-1] * 100
        groups[i].growth = growth
    
    return groups
```

### 8. AI Insights Service

**Responsibilities:**
- Manage async AI jobs
- Coordinate workers
- Store/retrieve results

**API Endpoints:**
```
POST /ai/forecast
POST /ai/inventory-analysis
POST /ai/festival-recommendations
GET /ai/jobs/{id}
GET /ai/jobs/{id}/result
```

### 9. Forecast Worker

**Responsibilities:**
- Run Prophet/LSTM/Regression models
- Generate predictions with confidence intervals
- Evaluate model accuracy

**Process:**
```python
def generate_forecast(historical_data, horizon, model_type):
    if model_type == 'prophet':
        model = Prophet()
        model.fit(historical_data)
        future = model.make_future_dataframe(periods=horizon)
        forecast = model.predict(future)
    elif model_type == 'lstm':
        model = build_lstm_model()
        model.fit(historical_data)
        forecast = model.predict(horizon)
    else:
        model = LinearRegression()
        model.fit(historical_data)
        forecast = model.predict(horizon)
    
    return forecast
```

### 10. Inventory Analysis Worker

**Responsibilities:**
- Calculate moving averages
- Detect low-stock conditions
- Generate reorder recommendations

**Logic:**
```python
def analyze_inventory(product_id, window=7):
    sales = get_sales_data(product_id, days=90)
    
    # Calculate moving average
    ma = moving_average(sales, window)
    
    # Calculate sales velocity
    velocity = mean(sales[-window:])
    
    # Estimate days until exhaustion
    current_stock = get_current_stock(product_id)
    days_left = current_stock / velocity if velocity > 0 else float('inf')
    
    # Generate alert if < threshold
    if days_left < 14:
        alert = True
        reorder_qty = velocity * (lead_time + safety_buffer)
    
    return InventoryInsight(...)
```

## Data Models

### PostgreSQL Schema

```sql
-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY,
  username VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Stores
CREATE TABLE stores (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  name VARCHAR(255) NOT NULL,
  region VARCHAR(100)
);

-- Ledger Entries
CREATE TABLE ledger_entries (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  store_id UUID REFERENCES stores(id),
  bill_id UUID NOT NULL,
  transaction_date TIMESTAMP NOT NULL,
  total_amount DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  edited_manually BOOLEAN DEFAULT FALSE
);

-- Line Items
CREATE TABLE line_items (
  id UUID PRIMARY KEY,
  ledger_entry_id UUID REFERENCES ledger_entries(id),
  product_name VARCHAR(255) NOT NULL,
  quantity DECIMAL(10, 2) NOT NULL,
  unit_price DECIMAL(10, 2) NOT NULL,
  total_price DECIMAL(10, 2) NOT NULL
);

CREATE INDEX idx_ledger_user_date ON ledger_entries(user_id, transaction_date);
CREATE INDEX idx_line_items_product ON line_items(product_name);
```

### SQLite Schema (Mobile App)

```sql
-- Cached Analytics
CREATE TABLE analytics_cache (
  cache_key TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
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
**Validates: Requirements 3.3, 14.4, 15.1, 15.2**

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
- Specific examples and edge cases
- Error conditions
- Integration points
- Mock external dependencies
- Target: 80% code coverage

**Property-Based Tests:**
- Universal properties across all inputs
- Randomized input generation
- 100 iterations per test
- Tag format: **Feature: retail-analytics-ai, Property {N}: {text}**

### Framework Selection
- **Flutter/Dart**: faker for test data generation
- **Python**: Hypothesis for property-based testing
- **Unit tests**: pytest, Flutter test

### Test Layers
1. **Unit**: Component-level, mocked dependencies
2. **Integration**: Component interactions, test DB
3. **Property**: Universal properties, randomized inputs
4. **E2E**: Complete workflows, staging environment
5. **Performance**: Load/stress testing
6. **Security**: Penetration testing, encryption verification

### CI Pipeline
1. Unit tests on every commit
2. Integration tests on PRs
3. Property tests nightly
4. E2E tests before deployment
5. Block merge if tests fail or coverage drops
