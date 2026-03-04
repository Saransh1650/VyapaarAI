# AI Khata Architecture Diagram

## Simplified Complete System Architecture

```mermaid
graph TB
    subgraph APP["📱 Flutter Mobile App"]
        UI["3 Main Tabs:<br/>Home | Advice | Inventory"]
        State["State Management<br/>AuthService + OrderListProvider"]
        API["API Client<br/>Dio + JWT Auth"]
        
        UI --> State
        State --> API
    end
    
    API -->|"REST API<br/>(HTTPS)"| Backend
    
    subgraph Backend["⚙️ Node.js Backend"]
        Routes["8 API Modules<br/>Auth | Bills | Ledger | Stocks<br/>Orders | Analytics | Stores | AI"]
        
        subgraph Workers["Background Workers"]
            OCR["OCR Worker<br/>📷 Gemini Vision"]
            Refresh["Refresh Worker<br/>🤖 AI Guidance"]
            Discover["Relationship<br/>Discovery"]
        end
        
        Scheduler["⏰ AI Scheduler<br/>3x daily"]
        
        Routes --> OCR
        Scheduler --> Refresh
        Refresh --> Discover
    end
    
    Backend --> DB
    
    subgraph DB["🗄️ PostgreSQL Database"]
        Core["Core Tables<br/>users | stores | bills<br/>ledger_entries | line_items<br/>stock_items | order_items<br/>ai_insights (cache)"]
        
        RAG["RAG Memory System<br/>shop_memory<br/>product_relationships<br/>experience_insights"]
    end
    
    subgraph AI["🧠 External AI"]
        Gemini["Google Gemini<br/>Vision + Text"]
        Groq["Groq Llama<br/>Fallback"]
    end
    
    OCR -->|Vision API| Gemini
    Refresh -->|Text Gen| Gemini
    Refresh -.->|Fallback| Groq
    
    Workers --> Core
    Workers --> RAG
    Routes --> Core
    Routes --> RAG
    
    style APP fill:#E3F2FD
    style Backend fill:#FFF3E0
    style DB fill:#E8F5E9
    style AI fill:#F3E5F5
    style OCR fill:#9C27B0
    style Refresh fill:#9C27B0
    style Scheduler fill:#FF9800
```

## Core Data Flows

### 1️⃣ Bill Entry Flow
```mermaid
sequenceDiagram
    participant User
    participant App
    participant Backend
    participant OCR as OCR Worker
    participant DB
    participant RAG
    participant Gemini

    User->>App: Scan/Type Bill
    App->>Backend: POST /bills/upload
    Backend->>DB: Create bill (UPLOADED)
    Backend->>OCR: Dispatch worker
    OCR->>Gemini: Extract data
    Gemini-->>OCR: merchant, items, total
    OCR->>DB: Create ledger + line_items
    OCR->>DB: Sync stock (atomic)
    OCR->>RAG: Learn patterns (async)
    OCR->>DB: Update bill (COMPLETED)
    Backend-->>App: Success
```

### 2️⃣ AI Guidance Flow
```mermaid
sequenceDiagram
    participant Scheduler
    participant Worker as Refresh Worker
    participant RAG
    participant DB
    participant Gemini
    participant App

    Scheduler->>Worker: Trigger (3x daily OR 20 new entries)
    Worker->>RAG: Replay last 7 days
    Worker->>DB: Get inventory + sales + activity
    Worker->>RAG: Read shop_memory + relationships
    Worker->>Gemini: Generate guidance (with RAG context)
    Gemini-->>Worker: 6 card types
    Worker->>DB: Cache in ai_insights
    App->>DB: GET /ai/insights (read-only)
    DB-->>App: Return cached guidance
```

### 3️⃣ RAG Learning Flow
```mermaid
flowchart LR
    A[New Transaction] --> B[Learn Product<br/>Behavior]
    A --> C[Learn Product<br/>Relationships]
    A --> D[Learn Operational<br/>Rhythm]
    
    B --> E[shop_memory<br/>confidence +0.05]
    C --> F[product_relationships<br/>strength updated]
    D --> E
    
    E --> G{Milestone?<br/>20/50/100/200/500}
    G -->|Yes| H[Deep Analysis]
    H --> I[Discover<br/>Relationships]
    H --> J[Generate<br/>Insights]
```

## Key Architecture Principles

| Principle | Description |
|-----------|-------------|
| **Read-Only AI** | App only reads from `ai_insights` cache via GET. Workers write asynchronously. |
| **JWT Auth** | Access token (short) + Refresh token (long). Silent refresh on 401. |
| **RAG Memory** | 3 tables learn shop patterns: behavior, relationships, insights. Confidence grows +0.05/observation. |
| **AI Triggers** | Runs 3x daily (06:00, 14:00, 22:00 UTC) OR every 20 new transactions. |
| **Stock Sync** | Atomic transactions. Purchase: `qty += n`. Sale: `qty = max(0, qty - n)`. |
| **State Management** | AuthService (top-level) → OrderListProvider (proxy). Optimistic updates. |

## Tech Stack Summary

| Layer | Technology |
|-------|------------|
| **Mobile** | Flutter + Material 3 + Provider |
| **Navigation** | go_router v2 (ShellRoute) |
| **HTTP** | Dio + JWT interceptor |
| **Backend** | Node.js + Express |
| **Database** | PostgreSQL |
| **AI** | Google Gemini (primary), Groq/Llama (fallback) |
| **Workers** | Node.js worker_threads |
| **Container** | Docker Compose |

## 6 AI Guidance Card Types

1. **stock_check** - Stock status (GOOD/WATCH/LOW)
2. **dead_stock** - Non-moving items + swap suggestions
3. **sales_expansion** - Cross-sell opportunities
4. **momentum_pattern** - Rising/opportunity products
5. **festival_preparation/experience** - Festival-specific guidance (≤10 days)
6. **shop_intelligence** - Memory maturity summary

---

*Simplified architecture diagram - March 2026*
