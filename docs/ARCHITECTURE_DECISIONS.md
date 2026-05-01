# Architecture Decision Records (ADR) - Wangku Fase 3

---

## ADR-001: Offline-First Architecture with Hive + Supabase

**Status**: ACCEPTED  
**Date**: April 26, 2026  
**Participants**: Dev Team, Product Owner

### Decision
Use **Offline-First** pattern with Hive as primary cache and Supabase as sync source.

### Context
- Users may lose connectivity while recording transactions
- Mobile users expect instant UI feedback
- Data integrity is critical (financial app)
- No backend infrastructure (using BaaS)

### Consequences

#### Pros
✅ App works offline without any server
✅ Instant optimistic UI updates (user sees data immediately)
✅ Graceful degradation when offline
✅ Reduced API calls (cache-first)
✅ Better UX on poor connections

#### Cons
❌ More complex state management
❌ Potential sync conflicts if user edits same transaction on 2 devices
❌ Storage overhead (local + cloud)
❌ Sync strategy needed (last-write-wins for now)

### Implementation
- **HiveManager**: Single-responsibility for Hive operations
- **TransactionRepository**: Handles try-Supabase-then-Hive logic
- **Client-side IDs**: UUID generation for instant optimistic updates
- **Pending sync flag**: Mark transactions that need sync (future)

### Related Decisions
- **ADR-002**: Client-side ID generation
- **ADR-003**: Provider Pattern for state management

---

## ADR-002: Client-Side ID Generation (UUID)

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Generate transaction IDs on client using `uuid` package instead of waiting for server-generated IDs.

### Context
- Offline-first approach requires immediate IDs
- Server-generated IDs require round-trip to DB
- UX requires instant feedback (see transaction immediately)

### Consequences

#### Pros
✅ Instant UI updates with real IDs
✅ Works completely offline
✅ No wait for server response
✅ UUID is standard & globally unique

#### Cons
❌ Extra dependency (uuid package)
❌ More complex transaction sync (need to track ID mapping)
❌ Potential for ID conflicts if not careful (mitigation: use v4 UUID)

### Implementation
```dart
// In transaction_repository.dart
final newTx = transaction.copyWith(
  id: const Uuid().v4(),
);
```

### Alternatives Considered
1. **Server-generated IDs** → Slower UX, requires server
2. **Timestamp-based IDs** → Not globally unique, collision risk
3. **Database sequences** → Requires server connection

---

## ADR-003: Provider Pattern for State Management

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Use `provider` package for state management (ChangeNotifierProvider).

### Context
- Need reactive state that triggers UI rebuilds
- Multiple providers need to share data (TransactionProvider → DashboardProvider)
- Keep code simple and maintainable
- Avoid boilerplate (not Redux, not Riverpod)

### Consequences

#### Pros
✅ Simple learning curve
✅ Lightweight (no heavy framework)
✅ Good community support
✅ Easy to test (just call methods)
✅ Flexible composition with ChangeNotifierProxyProvider

#### Cons
❌ Manual notifyListeners() calls
❌ Can lead to performance issues if not careful (rebuild whole subtree)
❌ Less powerful than Riverpod/Redux for complex state

### Implementation
```dart
class TransactionProvider extends ChangeNotifier {
  // State
  List<TransactionModel> _transactions = [];
  
  // Public getter
  List<TransactionModel> get transactions => _transactions;
  
  // Public method
  Future<void> addTransaction(...) async {
    // ... logic ...
    notifyListeners(); // Trigger rebuild
  }
}

// In UI
Consumer<TransactionProvider>(
  builder: (context, provider, child) {
    return ListView(
      children: provider.transactions.map(...).toList()
    );
  }
)
```

### Alternatives Considered
1. **Riverpod** → More powerful, but overkill for this app
2. **Redux** → Strict unidirectional flow, but too much boilerplate
3. **GetX** → Quick but less maintainable, breaks SOLID
4. **Bloc** → Good for complex flows, but overhead for this app

### Dependencies
- Depends on ADR-001 (Offline-First) to reduce complexity

---

## ADR-004: Hive for Local Storage

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Use **Hive** NoSQL database for local storage instead of SQLite.

### Context
- Need fast key-value storage for offline support
- Don't need complex queries (simple reads/writes)
- Data structure is already modeled (TransactionModel, CategoryModel)
- Performance critical on mobile

### Consequences

#### Pros
✅ Fast & lightweight (pure Dart)
✅ No SQL needed (JSON-like)
✅ Works with our freezed models
✅ Minimal boilerplate
✅ Good for caching
✅ Supports multiple boxes (transactions, categories, user, etc.)

#### Cons
❌ Limited query capabilities (no SQL joins)
❌ Not suitable for very complex data (but not needed here)
❌ Smaller community than SQLite
❌ Not as battle-tested as SQLite

### Implementation
```dart
class HiveManager {
  Future<void> initializeBoxes() async {
    _txnBox = await Hive.openBox<dynamic>('transactions');
    _catBox = await Hive.openBox<dynamic>('categories');
    _userBox = await Hive.openBox<dynamic>('user');
    _budgetBox = await Hive.openBox<dynamic>('budget');
  }
  
  Future<void> saveTransaction(TransactionModel txn) async {
    await _txnBox.put(txn.id, txn.toJson());
  }
}
```

### Alternatives Considered
1. **SQLite** → More powerful, but over-engineered
2. **Firebase Realtime DB** → Coupled to Firebase, limits flexibility
3. **ObjectBox** → Faster than Hive, but less documentation
4. **Shared Preferences** → Limited to simple key-value (not suitable)

---

## ADR-005: Repository Pattern with Abstraction

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Use **Repository Pattern** with clear separation between data sources and business logic.

### Context
- Multiple data sources (Supabase, Hive)
- Need to switch between them based on connectivity
- Want to make providers unaware of data layer complexity
- Facilitate testing with mock repositories

### Consequences

#### Pros
✅ Clean separation of concerns
✅ Providers don't know about Supabase/Hive
✅ Easy to mock for testing
✅ Flexible (can swap Supabase for another API)
✅ Single responsibility principle

#### Cons
❌ Extra abstraction layer
❌ More boilerplate code
❌ Potential over-engineering for simple CRUD

### Implementation
```
UI → Provider → Repository → Service + HiveManager
                                ↓
                        [Offline-First Logic]
```

### Architecture Layers
1. **UI Layer**: Widgets, Pages, Consumers
2. **State Layer**: Providers (ChangeNotifierProvider)
3. **Data Layer**: Repository (abstraction)
4. **Service Layer**: TransactionService (API), HiveManager (local)

---

## ADR-006: freezed for Model Immutability

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Use `freezed` package for immutable data models with automatic `copyWith`, `==`, `hashCode`.

### Context
- Models are data containers with no behavior
- Need immutable objects (functional programming principles)
- Want to avoid boilerplate (toString, ==, copyWith, etc.)
- Need JSON serialization

### Consequences

#### Pros
✅ Immutable by default (no accidental mutations)
✅ Pattern matching support (if needed)
✅ Automatic copyWith (for updates)
✅ Clean == and hashCode
✅ Auto-generated JSON serialization
✅ Less boilerplate code

#### Cons
❌ Build runner dependency
❌ Compilation time increase
❌ Code generation complexity
❌ Learning curve for pattern matching

### Implementation
```dart
@freezed
abstract class TransactionModel with _$TransactionModel {
  const factory TransactionModel({
    required String id,
    required String userId,
    required double amount,
    @Default('expense') String type,
  }) = _TransactionModel;
  
  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      _$TransactionModelFromJson(json);
}

// Usage
final txn1 = TransactionModel(...);
final txn2 = txn1.copyWith(amount: 100); // Creates new instance
```

---

## ADR-007: ScreenUtil for Responsive Design

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Use `flutter_screenutil` for responsive UI scaling across devices.

### Context
- App runs on phones with various screen sizes (320px to 720px+ width)
- Need consistent scaling without hardcoding pixels
- Designers work with specific design size (360x690)

### Consequences

#### Pros
✅ Automatic scaling for all screen sizes
✅ Maintains design proportions
✅ Works with orientation changes
✅ Less boilerplate than MediaQuery
✅ Good community & maintained

#### Cons
❌ Extra dependency
❌ Slight performance overhead (minimal)
❌ Must initialize with design size

### Implementation
```dart
// In main.dart
ScreenUtilInit(
  designSize: const Size(360, 690),
  builder: (context, child) {
    return MaterialApp(
      home: child,
    );
  },
)

// In widgets
Text(
  'Hello',
  style: TextStyle(fontSize: 14.sp), // 14 scaled units
),
SizedBox(height: 16.h), // 16 height units
```

---

## ADR-008: Supabase over Firebase

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Use **Supabase** (PostgRES + Auth) instead of Firebase for backend.

### Context
- Need database + authentication + real-time capabilities
- Prefer open-source & standard SQL (easier to migrate later)
- Don't want vendor lock-in
- Cost: Firebase might be cheaper at scale, but Supabase more flexible

### Consequences

#### Pros
✅ Open-source (can self-host later)
✅ Standard PostgreSQL (familiar, powerful)
✅ Row Level Security (RLS) for authorization
✅ Strong authentication (not email-only)
✅ REST + RealtimeAPI + Webhooks
✅ Better for financial apps (stricter schema)

#### Cons
❌ Smaller community than Firebase
❌ Less Flutter integration than Firebase
❌ Steeper learning curve for RLS
❌ Potential vendor lock-in (if using managed service)

### Implementation
Already integrated in project with:
- `supabase_flutter` package
- Auth integrated in `AuthProvider`
- Database integration in `TransactionService`

---

## ADR-009: DashboardProvider for Metrics Aggregation

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Create separate `DashboardProvider` that listens to `TransactionProvider` and computes metrics.

### Context
- Dashboard needs real-time metrics (balance, income, expense, etc.)
- These are derived from transactions
- Want to avoid computing in UI (business logic in provider)
- Need automatic updates when transactions change

### Consequences

#### Pros
✅ Clean separation (derived state)
✅ Reusable metrics across pages
✅ Automatic updates via provider listener
✅ Testable (just check metrics property)
✅ Performance (computed once per change, not on every rebuild)

#### Cons
❌ Extra provider to manage
❌ Requires understanding of ChangeNotifierProxyProvider
❌ More complex initialization (needs TransactionProvider)

### Implementation
```dart
ChangeNotifierProxyProvider<TransactionProvider, DashboardProvider>(
  create: (_) => DashboardProvider(),
  update: (_, txnProvider, dashboardProvider) {
    dashboardProvider?.initialize(txnProvider);
    return dashboardProvider ?? DashboardProvider();
  },
)
```

---

## ADR-010: Currency Formatting with intl Package

**Status**: ACCEPTED  
**Date**: April 26, 2026

### Decision
Use `intl` package with Indonesian locale for currency display.

### Context
- App is for Indonesian market (Rupiah currency)
- Need consistent formatting (Rp 1.000.000)
- intl is standard in Flutter community
- Easy to localize later for other countries

### Consequences

#### Pros
✅ Standard formatting (thousands separator, currency symbol)
✅ Locale-aware
✅ Easy to change currency/locale later
✅ Large community support
✅ Handles edge cases (negative, decimals, etc.)

#### Cons
❌ Extra dependency
❌ Slightly larger app size

### Implementation
```dart
final formatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String formatted = formatter.format(1000000); // "Rp 1.000.000"
```

---

## Summary of Architectural Principles

| Principle | Implementation |
|-----------|-----------------|
| **Offline-First** | Hive cache + Supabase sync |
| **Immutability** | freezed data models |
| **Separation of Concerns** | Clean 4-layer architecture |
| **Dependency Injection** | Provider pattern |
| **Responsive Design** | ScreenUtil scaling |
| **Currency Localization** | intl package |
| **Client Optimization** | UUID for instant UI |
| **Data Abstraction** | Repository pattern |

---

## Future ADRs (To Be Decided)

- **ADR-011**: Notification system (Background sync vs. Local alerts)
- **ADR-012**: Chart library selection (fl_chart vs. alternatives)
- **ADR-013**: Deep linking & app shortcuts
- **ADR-014**: Analytics & crash reporting
- **ADR-015**: Build & deployment strategy (CI/CD)

---

**Last Updated**: April 26, 2026  
**Next Review**: After Fase 3.2 completion
