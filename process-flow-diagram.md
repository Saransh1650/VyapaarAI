# AI Khata — Process Flow Diagrams

> Visual representation of key system flows extracted from ARCHITECTURE.md

---

## 1. User Authentication & Onboarding Flow

```mermaid
flowchart TD
    Start([User Opens App]) --> CheckAuth{Has Valid<br/>Token?}
    
    CheckAuth -->|No| Login[Login/Register Screen]
    Login --> LoginAction{User Action}
    LoginAction -->|Login| LoginAPI[POST /auth/login]
    LoginAction -->|Register| RegisterAPI[POST /auth/register]
    
    LoginAPI --> SaveTokens[Save Tokens to SharedPrefs]
    RegisterAPI --> SaveTokens
    
    SaveTokens --> CheckStore{Has<br/>store_id?}
    
    CheckAuth -->|Yes| CheckStore
    
    CheckStore -->|No| Onboarding1[Store Type Selection]
    Onboarding1 --> Onboarding2[Store Details Entry]
    Onboarding2 --> SetupAPI[POST /stores/setup]
    SetupAPI --> SaveStore[Save store_id to SharedPrefs]
    SaveStore --> Onboarding3[Onboarding Done Screen]
    Onboarding3 --> Dashboard
    
    CheckStore -->|Yes| Dashboard[Dashboard Home Screen]
```

---

## 2. Bill Entry Flow — OCR Path

```mermaid
flowchart TD
    Start([User Taps Scan Bill]) --> Scanner[Bill Scanner Screen]
    Scanner --> PickImage{Choose Source}
    
    PickImage -->|Camera| Camera[Take Photo]
    PickImage -->|Gallery| Gallery[Select Image]
    
    Camera --> Preview[Image Preview]
    Gallery --> Preview
    
    Preview --> UserConfirm{User Confirms?}
    UserConfirm -->|No| Scanner
    UserConfirm -->|Yes| Upload[POST /bills/upload<br/>multipart/form-data]
    
    Upload --> CreateBill[(Create bills record<br/>status: UPLOADED)]
    CreateBill --> SpawnWorker[Dispatch ocrWorker<br/>worker thread]
    
    SpawnWorker --> ReturnToApp[Return Success to App]
    ReturnToApp --> Navigate[Navigate to Bills Screen]
    
    SpawnWorker -.Async.-> OCRProcess[Gemini Vision API<br/>Extract: merchant, date,<br/>total, transactionType,<br/>lineItems with units]
    
    OCRProcess --> OCRSuccess{Success?}
    
    OCRSuccess -->|Yes| BeginTx[BEGIN TRANSACTION]
    BeginTx --> CreateLedger[(Create ledger_entry)]
    CreateLedger --> CreateLineItems[(Create line_items)]
    CreateLineItems --> SyncStock[syncStockAfterBill]
    
    SyncStock --> CheckType{Transaction<br/>Type?}
    CheckType -->|expense| AddStock[(UPDATE stock_items<br/>quantity += qty)]
    CheckType -->|income| SubtractStock[(UPDATE stock_items<br/>quantity -= qty<br/>GREATEST 0)]
    
    AddStock --> CommitTx[COMMIT]
    SubtractStock --> CommitTx
    CommitTx --> UpdateStatus[(Update bills<br/>status: COMPLETED)]
    
    OCRSuccess -->|No| Rollback[ROLLBACK]
    Rollback --> FailStatus[(Update bills<br/>status: FAILED)]
    
    UpdateStatus --> CheckThreshold[checkAndRefreshIfNeeded]
    FailStatus --> End([End])
    CheckThreshold --> End
```

---

## 3. Bill Entry Flow — Manual Path

```mermaid
flowchart TD
    Start([User Taps Type In]) --> ManualScreen[Manual Bill Entry Screen]
    
    ManualScreen --> LoadInventory[GET /stocks?storeId=X]
    LoadInventory --> FormReady[Form Ready]
    
    FormReady --> UserFills[User Fills:<br/>- Transaction Type<br/>- Merchant<br/>- Date<br/>- Line Items]
    
    UserFills --> PickItem{Add Item}
    PickItem -->|From Inventory| SelectExisting[Select from Stock List]
    PickItem -->|New Item| TypeNew[Type New Product Name]
    
    TypeNew --> CheckSale{Is Sale?}
    CheckSale -->|Yes| StockDialog[Show Initial Stock Dialog]
    StockDialog --> UserChoice{User Choice}
    UserChoice -->|Skip| SetZero[initialStock = 0]
    UserChoice -->|Add| SetStock[initialStock = entered value]
    
    CheckSale -->|No| AddToForm
    SetZero --> AddToForm[Add Item to Form]
    SetStock --> AddToForm
    SelectExisting --> AddToForm
    
    AddToForm --> MoreItems{Add More?}
    MoreItems -->|Yes| PickItem
    MoreItems -->|No| Validate{Form Valid?}
    
    Validate -->|No| FormReady
    Validate -->|Yes| CreateNewStock[For each new item with initialStock > 0:<br/>POST /stocks]
    
    CreateNewStock --> SubmitBill[POST /bills/manual]
    
    SubmitBill --> BeginTx[BEGIN TRANSACTION]
    BeginTx --> CreateBillRecord[(Create bills record<br/>source: manual<br/>status: COMPLETED)]
    CreateBillRecord --> CreateLedger[(Create ledger_entry)]
    CreateLedger --> CreateLineItems[(Create line_items)]
    CreateLineItems --> SyncStock[syncStockAfterBill]
    
    SyncStock --> CheckType{Transaction<br/>Type?}
    CheckType -->|expense| AddStock[(UPDATE stock_items<br/>quantity += qty)]
    CheckType -->|income| SubtractStock[(UPDATE stock_items<br/>quantity -= qty)]
    
    AddStock --> CommitTx[COMMIT]
    SubtractStock --> CommitTx
    
    CommitTx --> ShowSuccess[Show SnackBar:<br/>Bill saved & inventory updated]
    ShowSuccess --> Navigate[Navigate to Bills Screen]
    Navigate --> CheckThreshold[checkAndRefreshIfNeeded]
    CheckThreshold --> End([End])
```

---

## 4. AI Insights Generation Flow

```mermaid
flowchart TD
    Start([AI Refresh Trigger]) --> TriggerType{Trigger Type}
    
    TriggerType -->|Scheduler| Schedule[Time-based:<br/>06:00, 14:00, 22:00 UTC]
    TriggerType -->|Activity| Activity[≥20 new ledger entries<br/>since last generation]
    TriggerType -->|First Time| FirstTime[No insights exist yet]
    
    Schedule --> GetStores[Query active stores<br/>max 50]
    Activity --> StartWorker
    FirstTime --> StartWorker
    
    GetStores --> LoopStores[For each store<br/>stagger 10s apart]
    LoopStores --> StartWorker[Spawn refreshInsights.js<br/>worker thread]
    
    StartWorker --> CheckInFlight{Already<br/>refreshing?}
    CheckInFlight -->|Yes| Skip([Skip - deduplicate])
    CheckInFlight -->|No| MarkInFlight[Add to refreshInFlight Set]
    
    MarkInFlight --> UpdateMemory[updateShopMemory<br/>Replay last 7 days]
    
    UpdateMemory --> GatherData[Gather Data in Parallel]
    GatherData --> Inventory[getInventory]
    GatherData --> Sales[getRecentSales<br/>last 28 days]
    GatherData --> Activity2[getShopActivity<br/>this week vs last week]
    GatherData --> Festival[getClosestFestival<br/>within 45 days]
    
    Inventory --> BuildInput[Build Input JSON]
    Sales --> BuildInput
    Activity2 --> BuildInput
    Festival --> BuildInput
    
    BuildInput --> CheckData{Has Data?}
    CheckData -->|No| Fallback[Store fallback info card]
    CheckData -->|Yes| ExperienceEngine[generateExperienceGuidance]
    
    ExperienceEngine --> RAGRetrieval[RAG Memory Retrieval]
    RAGRetrieval --> GetMemory[(Read shop_memory)]
    RAGRetrieval --> GetRelations[(Read product_relationships)]
    RAGRetrieval --> GetInsights[(Read experience_insights)]
    
    GetMemory --> AssembleContext[Assemble Rich Context<br/>Priority 1-4]
    GetRelations --> AssembleContext
    GetInsights --> AssembleContext
    
    AssembleContext --> BuildCards[Build Guidance Cards]
    BuildCards --> Card0[0. stock_check]
    BuildCards --> Card1[1. dead_stock]
    BuildCards --> Card2[2. sales_expansion]
    BuildCards --> Card3[3. momentum_pattern]
    BuildCards --> Card4[4. festival_preparation/<br/>festival_experience]
    BuildCards --> Card5[5. shop_intelligence]
    
    Card0 --> CallGemini[Call Gemini API<br/>with full context]
    Card1 --> CallGemini
    Card2 --> CallGemini
    Card3 --> CallGemini
    Card4 --> CallGemini
    Card5 --> CallGemini
    
    CallGemini --> GeminiSuccess{Success?}
    
    GeminiSuccess -->|Yes| ValidateResponse{Valid<br/>Response?}
    GeminiSuccess -->|No| Fallback
    
    ValidateResponse -->|Yes| DiscoverRelations[discoverProductRelationships<br/>90 days]
    ValidateResponse -->|No| Fallback
    
    DiscoverRelations --> Frequent[Frequent Pairs Analysis]
    DiscoverRelations --> Sequential[Sequential Patterns]
    DiscoverRelations --> Complementary[Complementary Items]
    DiscoverRelations --> Seasonal[Seasonal Pairs]
    
    Frequent --> StoreRelations[(Store to product_relationships)]
    Sequential --> StoreRelations
    Complementary --> StoreRelations
    Seasonal --> StoreRelations
    
    StoreRelations --> UpsertInsight[upsertInsight<br/>type: guidance]
    Fallback --> UpsertInsight
    
    UpsertInsight --> CheckValid{Data Valid?}
    CheckValid -->|Yes| SaveToDB[(INSERT ... ON CONFLICT<br/>DO UPDATE ai_insights)]
    CheckValid -->|No| KeepOld[Preserve existing cache]
    
    SaveToDB --> Cleanup[Delete legacy rows:<br/>forecast, festival, inventory]
    KeepOld --> Cleanup
    
    Cleanup --> RemoveInFlight[Remove from refreshInFlight Set]
    RemoveInFlight --> End([End])
```

---

## 5. RAG Memory Learning Flow

```mermaid
flowchart TD
    Start([New Transaction Created]) --> RealTime[learnFromNewTransaction<br/>fire-and-forget async]
    
    RealTime --> FetchTx[(Fetch transaction<br/>+ line_items)]
    FetchTx --> LearnProduct[learnProductBehavior]
    FetchTx --> LearnRelations[learnProductRelationships]
    FetchTx --> LearnRhythm[learnOperationalRhythm]
    
    LearnProduct --> ForEachItem[For each line item]
    ForEachItem --> CalcMetrics[Calculate:<br/>- avgQty<br/>- avgPrice<br/>- dayOfWeek<br/>- performanceIndicator]
    CalcMetrics --> UpsertProduct[(UPSERT shop_memory<br/>type: product_behavior<br/>context: productName)]
    
    UpsertProduct --> UpdateConf1[confidence += 0.05<br/>frequency += 1]
    
    LearnRelations --> ForEachPair[For every pair of items<br/>in transaction]
    ForEachPair --> UpdatePairAB[(updateRelationshipStrength<br/>A → B, frequently_together)]
    ForEachPair --> UpdatePairBA[(updateRelationshipStrength<br/>B → A, frequently_together)]
    
    UpdatePairAB --> UpsertRelation[(UPSERT product_relationships)]
    UpdatePairBA --> UpsertRelation
    UpsertRelation --> UpdateConf2[strength += increment<br/>occurrences += 1]
    
    LearnRhythm --> CalcRhythm[Calculate:<br/>- dayOfWeek<br/>- timeOfDay<br/>- peak indicator]
    CalcRhythm --> UpsertRhythm[(UPSERT shop_memory<br/>type: operational_rhythm<br/>context: Monday_morning)]
    
    UpsertRhythm --> UpdateConf3[confidence += 0.05<br/>frequency += 1]
    
    UpdateConf1 --> CheckMilestone{Transaction<br/>Count Milestone?}
    UpdateConf2 --> CheckMilestone
    UpdateConf3 --> CheckMilestone
    
    CheckMilestone -->|20, 50, 100,<br/>200, 500| DeepLearning[setImmediate<br/>Deep Learning]
    CheckMilestone -->|No| End([End])
    
    DeepLearning --> DiscoverRelations[discoverProductRelationships<br/>90 days]
    DeepLearning --> GenerateInsights[generateExperienceInsights]
    
    DiscoverRelations --> SQLAnalysis[Run 4 SQL analyses:<br/>1. Frequent Pairs<br/>2. Sequential<br/>3. Complementary<br/>4. Seasonal]
    
    SQLAnalysis --> StoreResults[(Store to product_relationships)]
    
    GenerateInsights --> AnalyzePatterns[Analyze shop_memory<br/>+ product_relationships]
    AnalyzePatterns --> CreateInsights[(Create experience_insights:<br/>- shop_identity<br/>- strength_product<br/>- opportunity_gap)]
    
    StoreResults --> End
    CreateInsights --> End
```

---

## 6. App Data Loading Flow — Dashboard Home

```mermaid
flowchart TD
    Start([User Opens Dashboard]) --> InitState[initState]
    
    InitState --> LoadStats[_loadStats]
    InitState --> LoadAlerts[_loadUrgentAlerts]
    
    LoadStats --> SalesTrends[GET /analytics/sales-trends?days=30]
    LoadStats --> ProductRank[GET /analytics/product-rankings?days=30&limit=1]
    
    SalesTrends --> ParseStats[Parse:<br/>- Today total<br/>- Yesterday total<br/>- Monthly total]
    ProductRank --> ParseStats
    
    ParseStats --> UpdateStatsUI[Update Stats UI]
    
    LoadAlerts --> GetInsights[GET /ai/insights]
    GetInsights --> BackgroundCheck[checkAndRefreshIfNeeded<br/>runs in background]
    
    BackgroundCheck --> CheckStale{Data Stale?}
    CheckStale -->|≥20 new entries| TriggerRefresh[Trigger AI refresh<br/>non-blocking]
    CheckStale -->|No| ReturnCache
    
    TriggerRefresh --> ReturnCache[Return cached data]
    ReturnCache --> ParseAlerts[Parse guidance array]
    
    ParseAlerts --> ExtractHigh[Extract high urgency<br/>inventory alerts]
    ParseAlerts --> ExtractMedium[Extract medium urgency<br/>inventory alerts]
    ParseAlerts --> ExtractFestival[Extract festival[0]<br/>if exists]
    
    ExtractHigh --> BuildSuggestions[Build _suggestions list]
    ExtractMedium --> BuildSuggestions
    ExtractFestival --> BuildSuggestions
    
    BuildSuggestions --> UpdateAlertsUI[Update Action Center UI]
    
    UpdateStatsUI --> RenderHome[Render Home Screen:<br/>1. Urgent Banner<br/>2. Add Bill Card<br/>3. Performance Card<br/>4. Action Center<br/>5. Quick Health<br/>6. Medium Alerts<br/>7. Records Row]
    UpdateAlertsUI --> RenderHome
    
    RenderHome --> End([End])
```

---

## 7. Order List Management Flow

```mermaid
flowchart TD
    Start([User Action on Order List]) --> Action{Action Type}
    
    Action -->|Add Item| AddFlow[add method]
    Action -->|Remove Item| RemoveFlow[remove method]
    Action -->|Update Qty| UpdateQtyFlow[updateQty method]
    Action -->|Update Unit| UpdateUnitFlow[updateUnit method]
    Action -->|Mark All Ordered| MarkOrderedFlow[markAllOrdered method]
    Action -->|Ordered + Update Stock| UpdateStockFlow[Ordered — Update Stock button]
    
    AddFlow --> CheckExists{Item exists<br/>in list?}
    CheckExists -->|Yes| NoOp([No-op - already in list])
    CheckExists -->|No| AddLocal[Add to local list<br/>optimistic update]
    AddLocal --> AddAPI[POST /order-items]
    AddAPI --> AddSuccess{Success?}
    AddSuccess -->|Yes| ReplaceLocal[Replace local item<br/>with server version<br/>has UUID now]
    AddSuccess -->|No| RevertAdd[Revert local add]
    ReplaceLocal --> NotifyAdd[notifyListeners]
    RevertAdd --> NotifyAdd
    
    RemoveFlow --> RemoveLocal[Remove from local list<br/>optimistic update]
    RemoveLocal --> RemoveAPI[DELETE /order-items/:id]
    RemoveAPI --> RemoveSuccess{Success?}
    RemoveSuccess -->|Yes| NotifyRemove[notifyListeners]
    RemoveSuccess -->|No| RevertRemove[Revert local remove]
    RevertRemove --> NotifyRemove
    
    UpdateQtyFlow --> CheckQty{qty <= 0?}
    CheckQty -->|Yes| RemoveFlow
    CheckQty -->|No| UpdateQtyLocal[Update qty locally]
    UpdateQtyLocal --> UpdateQtyAPI[PATCH /order-items/:id {qty}]
    UpdateQtyAPI --> QtySuccess{Success?}
    QtySuccess -->|Yes| NotifyQty[notifyListeners]
    QtySuccess -->|No| RevertQty[Revert local qty]
    RevertQty --> NotifyQty
    
    UpdateUnitFlow --> UpdateUnitLocal[Update unit locally]
    UpdateUnitLocal --> UpdateUnitAPI[PATCH /order-items/:id {unit}]
    UpdateUnitAPI --> UnitSuccess{Success?}
    UnitSuccess -->|Yes| NotifyUnit[notifyListeners]
    UnitSuccess -->|No| RevertUnit[Revert local unit]
    RevertUnit --> NotifyUnit
    
    MarkOrderedFlow --> ClearLocal[Clear local list]
    ClearLocal --> ClearAPI[DELETE /order-items?storeId=X]
    ClearAPI --> ClearSuccess{Success?}
    ClearSuccess -->|Yes| NotifyClear[notifyListeners]
    ClearSuccess -->|No| RevertClear[Revert local clear]
    RevertClear --> NotifyClear
    
    UpdateStockFlow --> LoopItems[For each order item]
    LoopItems --> FindStock[Find matching stock item<br/>by name case-insensitive]
    FindStock --> StockExists{Stock<br/>exists?}
    StockExists -->|Yes| UpdateStock[PUT /stocks/:id<br/>quantity = current + orderQty]
    StockExists -->|No| CreateStock[POST /stocks<br/>quantity = orderQty]
    UpdateStock --> NextItem{More items?}
    CreateStock --> NextItem
    NextItem -->|Yes| LoopItems
    NextItem -->|No| ClearAfterUpdate[markAllOrdered]
    ClearAfterUpdate --> ShowSnackBar[Show SnackBar:<br/>Stock updated! X items added]
    ShowSnackBar --> EndFlow([End])
    
    NotifyAdd --> EndFlow
    NotifyRemove --> EndFlow
    NotifyQty --> EndFlow
    NotifyUnit --> EndFlow
    NotifyClear --> EndFlow
    NoOp --> EndFlow
```

---

## 8. JWT Token Refresh Flow

```mermaid
flowchart TD
    Start([App Makes API Request]) --> SendRequest[Dio sends request<br/>with Authorization header]
    
    SendRequest --> Response{Response<br/>Status}
    
    Response -->|200-299| Success([Return response to app])
    Response -->|401| CheckRefreshing{_isRefreshing?}
    
    CheckRefreshing -->|Yes| QueueRequest[Add request to queue<br/>wait for refresh to complete]
    CheckRefreshing -->|No| SetRefreshing[_isRefreshing = true]
    
    SetRefreshing --> GetRefreshToken[Read refresh_token<br/>from SharedPrefs]
    GetRefreshToken --> RefreshAPI[POST /auth/refresh<br/>using _refreshDio<br/>no interceptors]
    
    RefreshAPI --> RefreshSuccess{Success?}
    
    RefreshSuccess -->|Yes| SaveNewTokens[Save new access_token<br/>+ refresh_token<br/>to SharedPrefs]
    SaveNewTokens --> RetryOriginal[Retry original request<br/>with new token]
    RetryOriginal --> ResetFlag[_isRefreshing = false]
    ResetFlag --> ProcessQueue[Process queued requests<br/>with new token]
    ProcessQueue --> Success
    
    RefreshSuccess -->|No| ClearSession[Clear SharedPrefs<br/>all auth data]
    ClearSession --> NotifyAuth[AuthService.notifyListeners]
    NotifyAuth --> Redirect[go_router redirect<br/>to /login]
    Redirect --> ResetFlag2[_isRefreshing = false]
    ResetFlag2 --> Fail([Return 401 to app])
    
    QueueRequest --> WaitForRefresh[Wait for refresh to complete]
    WaitForRefresh --> RefreshDone{Refresh<br/>succeeded?}
    RefreshDone -->|Yes| RetryQueued[Retry queued request<br/>with new token]
    RefreshDone -->|No| Fail
    RetryQueued --> Success
```

---

## 9. Stock Sync After Bill Flow

```mermaid
flowchart TD
    Start([syncStockAfterBill called<br/>inside DB transaction]) --> Input[Input:<br/>- transactionType<br/>- lineItems array]
    
    Input --> CheckType{Transaction<br/>Type?}
    
    CheckType -->|expense<br/>Purchase| PurchaseLoop[For each line item]
    CheckType -->|income<br/>Sale| SaleLoop[For each line item]
    
    PurchaseLoop --> UpsertPurchase[(INSERT stock_items<br/>quantity = qty<br/>ON CONFLICT<br/>DO UPDATE<br/>quantity += qty)]
    
    UpsertPurchase --> NextPurchase{More items?}
    NextPurchase -->|Yes| PurchaseLoop
    NextPurchase -->|No| End([Return - stock updated])
    
    SaleLoop --> EnsureExists[(INSERT stock_items<br/>quantity = 0<br/>ON CONFLICT<br/>DO NOTHING)]
    
    EnsureExists --> DecrementStock[(UPDATE stock_items<br/>SET quantity =<br/>GREATEST 0, quantity - qty)]
    
    DecrementStock --> NextSale{More items?}
    NextSale -->|Yes| SaleLoop
    NextSale -->|No| End
```

---

## 10. Smart Advice Screen Data Flow

```mermaid
flowchart TD
    Start([User Opens Smart Advice Tab]) --> InitState[initState]
    
    InitState --> LoadInsights[_loadInsights]
    LoadInsights --> GetAPI[GET /ai/insights?storeId=X&storeType=Y]
    
    GetAPI --> BackgroundCheck[checkAndRefreshIfNeeded<br/>runs in background]
    BackgroundCheck --> ReturnCache[Return cached guidance]
    
    ReturnCache --> ParseResponse[Parse response:<br/>- mode<br/>- guidance array<br/>- generatedAt]
    
    ParseResponse --> CheckMode{Mode?}
    
    CheckMode -->|EXPERIENCE_EVENT| ShowBanner[Show Festival Mode Banner<br/>with urgency counts]
    CheckMode -->|EXPERIENCE_NORMAL| HideBanner[No festival banner]
    
    ShowBanner --> RenderCards[Render guidance cards<br/>in order]
    HideBanner --> RenderCards
    
    RenderCards --> CardLoop[For each card in guidance]
    
    CardLoop --> CardType{Card Type?}
    
    CardType -->|stock_check| StockCard[_StockCheckCard<br/>- Status badges<br/>- Product rows<br/>- Reason + action]
    
    CardType -->|dead_stock| DeadCard[_DeadStockCard<br/>- Dead items list<br/>- Swap ideas]
    
    CardType -->|sales_expansion| ExpansionCard[_SalesExpansionCard<br/>- Cross-sell suggestions<br/>- Missing items]
    
    CardType -->|momentum_pattern| MomentumCard[_MomentumPatternCard<br/>- Rising products<br/>- Action tip]
    
    CardType -->|festival_preparation<br/>or festival_experience| FestivalCard[_EventContextCard<br/>- Urgency-sorted items<br/>- Demand notes<br/>- Order buttons]
    
    CardType -->|shop_intelligence| IntelligenceCard[_ShopIntelligenceCard<br/>- Memory strength<br/>- Business momentum<br/>- Next actions]
    
    CardType -->|info| InfoCard[_GuidanceInfoCard<br/>- General tip]
    
    StockCard --> NextCard{More cards?}
    DeadCard --> NextCard
    ExpansionCard --> NextCard
    MomentumCard --> NextCard
    FestivalCard --> NextCard
    IntelligenceCard --> NextCard
    InfoCard --> NextCard
    
    NextCard -->|Yes| CardLoop
    NextCard -->|No| ShowTimestamp[Show generatedAt<br/>Updated Xm/h ago]
    
    ShowTimestamp --> UserAction{User Action}
    
    UserAction -->|Pull to Refresh| LoadInsights
    UserAction -->|Tap Order Button| AddToOrder[OrderListProvider.add]
    UserAction -->|Tap View CTA| Navigate[Navigate to relevant screen]
    
    AddToOrder --> UpdateButton[Button shows:<br/>✓ Added / In list]
    Navigate --> End([End])
    UpdateButton --> End
```

---

## Legend

```mermaid
flowchart LR
    A[Process Step] --> B{Decision Point}
    B -->|Yes| C[(Database Operation)]
    B -->|No| D([End Point])
    C -.Async.-> E[Background Process]
    E --> F[API Call]
```

- **Rectangle**: Process step or action
- **Diamond**: Decision point or conditional
- **Cylinder**: Database operation
- **Rounded rectangle**: Start/End point
- **Dashed arrow**: Asynchronous or background operation
- **Solid arrow**: Synchronous flow

---

## Notes

1. All flows are extracted from the ARCHITECTURE.md document
2. Error handling paths are included where critical
3. Background/async operations are marked with dashed lines
4. Database transactions are shown with cylinder shapes
5. User interactions are marked with rounded rectangles

These diagrams can be rendered using any Mermaid-compatible viewer (GitHub, VS Code with Mermaid extension, mermaid.live, etc.)
