# Wangku - Implementation Roadmap & Fase 3–5

**Status**: Fase 1–2 selesai (Auth + Fondasi Struktur) | **Fase 3 dimulai**: Manajemen Transaksi & Sinkronisasi  
**Target**: Full MVP dengan Offline Mode + Notifikasi + Reports  

---

## ✅ Status Fase 1–2: Selesai

### Fase 1 - Fondasi ✓
- [x] GoRouter setup & navigasi
- [x] ScreenUtil responsive design
- [x] Tema (Light mode, AppColors, Typography)
- [x] Project structure (Clean Architecture)
- [x] Models (TransactionModel, CategoryModel, UserModel)

### Fase 2 - Autentikasi ✓
- [x] Supabase integration (Auth & Database)
- [x] AuthService (SignUp, SignIn, ResetPassword, SignOut)
- [x] AuthProvider (State Management dengan Provider)
- [x] LoginPage & RegisterPage UI
- [x] Auth state detection & routing

---

## 🚀 Fase 3: Manajemen Transaksi & Dashboard Dinamis (CURRENT)

### 3.1 Transaction Management - Backend Layer
**Status**: Models exist, servicnya belum ada.  
**Target**: Supabase API + Hive offline sync  
**Files to Create**:

1. **lib/features/transactions/data/services/transaction_service.dart**
   - `fetchTransactions(userId, dateRange)`
   - `createTransaction(transaction)`
   - `updateTransaction(id, transaction)`
   - `deleteTransaction(id)`
   - `getCategories()` — fetch dari DB

2. **lib/features/transactions/data/repositories/transaction_repository.dart**
   - Interface CRUD + error handling
   - Hive fallback jika offline

3. **lib/features/transactions/presentation/providers/transaction_provider.dart**
   - ChangeNotifierProvider (Provider pattern)
   - State: transactions, categories, filters
   - Methods: add, edit, delete, fetchData

4. **lib/core/database/hive_manager.dart**
   - Box inits (transactions, categories, user_budget)
   - Sync logic ke Supabase

### 3.2 Dashboard Dinamis
**Status**: Placeholder skeleton ada, no real data binding.  
**Target**: Real-time income/expense saldo + weekly progress  
**Files to Create/Edit**:

1. **lib/features/dashboard/presentation/providers/dashboard_provider.dart**
   - Aggregate totals (pemasukan, pengeluaran, saldo)
   - Week/month views
   - Listen ke TransactionProvider

2. **Edit lib/features/dashboard/presentation/pages/dashboard_page.dart**
   - Bind UI ke DashboardProvider
   - Show real saldo, income, expense
   - Add Quick Add persistence

### 3.3 Quick Add Feature (Fully Functional)
**Status**: UI shell exists, no persistence.  
**Target**: Add transaction directly → Supabase + Hive  
**Files to Modify**:

1. **dashboard_page.dart** (_showQuickAddSheet method)
   - Integrate TransactionProvider.addTransaction()
   - Validate input
   - Show success/error snackbar

---

## 📊 Fase 4: Visualisasi Data & Analisis (Planned)

### 4.1 Transaction History View
**Files to Create**:
- **lib/features/transactions/presentation/pages/transaction_list_page.dart**
  - Paginated list dengan filter (date, category)
  - Swipe to delete
  - Edit on tap

### 4.2 Reports & Charts
**Files to Create**:
- **lib/features/reports/domain/models/report_model.dart**
- **lib/features/reports/data/services/report_service.dart**
  - Monthly data aggregation
- **lib/features/reports/presentation/providers/report_provider.dart**
- **lib/features/reports/presentation/pages/reports_page.dart**
  - Bar chart (monthly income vs expense) — **dependency: fl_chart**
  - Pie chart (category distribution) — **dependency: fl_chart**
  - Date range filter widget

---

## 🔔 Fase 5: Notifikasi Pintar (Planned)

### 5.1 Budget Alert System
**Files to Create**:
- **lib/features/profile/data/models/budget_model.dart**
- **lib/core/notifications/notification_manager.dart**
  - Local notifications (flutter_local_notifications)
  - Check daily spending vs budget

### 5.2 Pengingat Pencatatan
**Files to Create**:
- **lib/core/notifications/schedule_manager.dart**
  - Setup cron / WorkManager
  - Daily reminder at user-set time

---

## 📋 Dependency Checklist

### Existing (Already in pubspec.yaml)
- ✅ supabase_flutter
- ✅ hive_flutter
- ✅ provider
- ✅ go_router
- ✅ freezed_annotation
- ✅ json_serializable

### Need to Add (Fase 3–5)
```yaml
fl_chart: ^7.0.0              # Fase 4 (Bar & Pie Charts)
flutter_local_notifications: ^17.0.0  # Fase 5
workmanager: ^0.5.2           # Fase 5 (Periodic Tasks)
intl: ^0.19.0                 # Date formatting
uuid: ^4.0.0                  # Generate transaction IDs
```

---

## 🎯 Quick Implementation Checklist - Fase 3 (Next 2 Days)

- [ ] Create TransactionService (CRUD + Supabase)
- [ ] Create TransactionRepository (interface + Hive)
- [ ] Create TransactionProvider (state management)
- [ ] Create HiveManager (box initialization)
- [ ] Create DashboardProvider (aggregation)
- [ ] Modify dashboard_page.dart (bind to real data)
- [ ] Test Quick Add end-to-end
- [ ] Push to Supabase & verify offline sync

---

## 📁 Directory Structure (Post-Fase-3)

```
lib/
├── features/
│   ├── auth/        ✅
│   ├── dashboard/   ⚙️ (Fase 3)
│   ├── transactions/ ⚙️ (Fase 3)
│   │   ├── domain/models/
│   │   ├── data/
│   │   │   ├── services/         ← NEW
│   │   │   └── repositories/     ← NEW
│   │   └── presentation/providers/ ← NEW
│   ├── reports/     📋 (Fase 4)
│   ├── profile/     📋 (Fase 5)
│   └── notifications/ 📋 (Fase 5)
├── core/
│   ├── config/      ✅
│   ├── theme/       ✅
│   ├── database/    ← NEW (hive_manager.dart)
│   ├── notifications/ ← NEW (Fase 5)
│   └── utils/
└── shared/
    └── widgets/     ✅
```

---

## Notes for Execution

1. **Transaction ID Generation**: Gunakan `uuid` package untuk client-side ID generation (lebih cepat daripada tunggu dari DB).
2. **Offline Sync Strategy**:
   - Write ke Hive (instant) + mark as "pending_sync"
   - When online, push ke Supabase
   - If conflict: server wins (last-write-wins)
3. **Error Handling**: Wrap semua DB calls dengan try-catch, notify user via SnackBar
4. **Testing**: Gunakan `flutter test` untuk unit test model + provider sebelum E2E

---

**Next**: Mulai dengan `TransactionService` + `TransactionRepository` (Fase 3.1)
