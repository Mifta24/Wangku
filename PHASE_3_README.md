# Wangku Fase 3 - Complete Implementation Guide

**Aplikasi**: Wangku Personal Finance Manager  
**Status**: Fase 3.1 Complete (Backend + Dashboard Integration)  
**Last Updated**: April 26, 2026  
**Target**: Production-ready transaction management with offline support

---

## 📚 Quick Navigation

- **Getting Started**: See section "🚀 Setup & First Run"
- **Architecture**: See section "🏗️ System Architecture"
- **Feature Details**: See section "✨ Implemented Features"
- **Testing**: See section "🧪 Testing Guide"
- **Troubleshooting**: See section "🐛 Troubleshooting"

---

## 🚀 Setup & First Run

### Prerequisites
- Flutter 3.0+ installed
- Dart SDK included with Flutter
- Supabase account with project created
- Android/iOS emulator OR physical device

### Step 1: Update Dependencies
```bash
cd c:\Aplikasi-Mobile\Wangku

# Add required packages
flutter pub add intl uuid fl_chart flutter_local_notifications workmanager

# Get all dependencies
flutter pub get
```

### Step 2: Generate Code from Models
```bash
# Build freezed models + json serialization
dart run build_runner build --delete-conflicting-outputs
```

### Step 3: Verify Setup
```bash
# Check for errors
flutter analyze

# Should show: No issues found!
```

### Step 4: Prepare Database
1. Go to Supabase Dashboard → SQL Editor
2. Run the script: `sql/setup_sample_data.sql`
3. Verify categories are created:
   ```sql
   SELECT * FROM categories;
   ```

### Step 5: Run App
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Or just run (uses default)
flutter run
```

---

## 🏗️ System Architecture

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ DashboardPage                                        │   │
│  │ - Quick Add Modal                                   │   │
│  │ - Balance Display                                   │   │
│  │ - Recent Transactions                               │   │
│  └──────────────────────────────────────────────────────┘   │
│                      ↑ watches                                │
└──────────────────────┼───────────────────────────────────────┘
                       │
                       │ Consumer2
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                   State Management Layer                     │
│  ┌──────────────────────┐  ┌─────────────────────────────┐  │
│  │TransactionProvider   │  │ DashboardProvider           │  │
│  │- addTransaction()    │  │ - metrics aggregation       │  │
│  │- deleteTransaction() │  │ - top categories           │  │
│  │- getCategories()     │  │ - monthly progress         │  │
│  │- monthTransactions   │  │                             │  │
│  └──────────────────────┘  └─────────────────────────────┘  │
│           ↓ uses                                              │
└───────────┼──────────────────────────────────────────────────┘
            │
            ↓ uses
┌─────────────────────────────────────────────────────────────┐
│                   Data Layer                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ TransactionRepository (Interface)                   │   │
│  │ - getTransactions()                                 │   │
│  │ - addTransaction()                                  │   │
│  │ - getMonthlyAggregates()                            │   │
│  └──────────────────────────────────────────────────────┘   │
│           ↓                                                   │
│  ┌──────────────────────────────┬──────────────────────┐   │
│  │ TransactionService           │  HiveManager         │   │
│  │ (Supabase API)               │  (Local Storage)     │   │
│  │- fetchTransactions()         │- getTransactions()   │   │
│  │- createTransaction()         │- saveTransaction()   │   │
│  │- updateTransaction()         │- deleteTransaction() │   │
│  │- getCategoryDistribution()   │                      │   │
│  └──────────────────────────────┴──────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────────┐
│              Database & Storage Layer                       │
│  ┌───────────────────────┐  ┌──────────────────────────┐   │
│  │ Supabase (Cloud)      │  │ Hive (Local)             │   │
│  │ - transactions table  │  │ - transactions box       │   │
│  │ - categories table    │  │ - categories box         │   │
│  │ - auth.users          │  │ - budget box             │   │
│  │ - RLS policies        │  │ - user metadata          │   │
│  └───────────────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Offline-First Strategy

```
User Action (Add Transaction)
           ↓
    ┌──────────────────────┐
    │ Check Internet?      │
    └──────────────────────┘
         ↙                ↘
    Online               Offline
     ↓                    ↓
┌─────────────┐    ┌────────────────┐
│ Save to     │    │ Save to Hive   │
│ Supabase    │    │ (pending_sync) │
│ + Hive      │    └────────────────┘
└─────────────┘           ↓
     ↓             Return to user
┌─────────────┐    (cached data)
│ Return      │
│ Synced data │
└─────────────┘
     ↓
 Update UI via
 Provider notify
     ↓
┌─────────────────────────┐
│ DashboardProvider       │
│ recalculates metrics    │
│ & notifies listeners    │
└─────────────────────────┘
     ↓
┌─────────────────────────┐
│ UI rebuilds with new    │
│ balance, income, expense│
└─────────────────────────┘
```

---

## ✨ Implemented Features (Fase 3.1)

### 1. Transaction Management
✅ **Add Transaction** (Quick Add)
- Select transaction type (Income/Expense)
- Choose category with color coding
- Input amount with validation
- Add optional note
- Instant UI update (optimistic)
- Automatic Hive cache on offline

✅ **View Transactions**
- Recent transactions list (latest 5)
- Full transaction data with category
- Display date, amount, category, note
- Currency formatting (Rp)

✅ **Transaction Data**
- Client-side UUID generation
- Automatic timestamp
- Category relation from DB
- Type differentiation (income vs expense)

### 2. Dashboard Metrics
✅ **Real-Time Balance**
- Total Saldo (Pemasukan - Pengeluaran)
- Monthly Income total
- Monthly Expense total
- Weekly Expense tracking

✅ **Metrics Aggregation**
- Live calculation from TransactionProvider
- Automatic recalculation on new transactions
- Month-based filtering
- Type-based filtering (income/expense)

### 3. Categories
✅ **Category Management**
- Fetch from Supabase categories table
- Filter by type (income/expense)
- Display in Quick Add modal
- Color-coded UI rendering
- Caching in Hive

### 4. Offline Support
✅ **Hive Local Storage**
- Multi-box architecture (transactions, categories, budget, user)
- Automatic caching from API
- Fallback to Hive when offline
- Sync pending transactions when online

✅ **Sync Logic**
- Automatic attempt to Supabase
- Graceful fallback to Hive
- Client-side ID generation for instant UI
- Ready for background sync (Fase 5)

### 5. UI/UX
✅ **Dashboard Page**
- Balance card with gradient
- Income/Expense metric cards
- Recent transactions list
- 7-day spending tracker
- Responsive design with ScreenUtil
- Bottom navigation (4 tabs)
- Floating action button (Quick Add)

✅ **Quick Add Modal**
- Bottom sheet UI
- Transaction type selector
- Category picker with chips
- Input validation
- Error messaging
- Success feedback

---

## 📊 File Structure (Fase 3.1)

```
lib/
├── core/
│   ├── database/
│   │   └── hive_manager.dart              ← NEW
│   ├── theme/
│   │   └── app_colors.dart                ← UPDATED
│   └── ...
├── features/
│   ├── auth/
│   │   ├── presentation/
│   │   │   └── providers/
│   │   │       └── auth_provider.dart
│   │   └── ...
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   └── dashboard_page.dart    ← UPDATED
│   │   │   └── providers/
│   │   │       └── dashboard_provider.dart ← NEW
│   │   └── ...
│   ├── transactions/
│   │   ├── domain/
│   │   │   └── models/
│   │   │       ├── transaction_model.dart
│   │   │       └── category_model.dart
│   │   ├── data/
│   │   │   ├── services/
│   │   │   │   └── transaction_service.dart ← NEW
│   │   │   └── repositories/
│   │   │       └── transaction_repository.dart ← NEW
│   │   └── presentation/
│   │       └── providers/
│   │           └── transaction_provider.dart ← NEW
│   └── ...
├── main.dart                               ← UPDATED
└── ...
```

---

## 🧪 Testing Guide

### Manual Testing - Happy Path

1. **Start App**
   ```
   Expected: Dashboard loads with "Belum ada transaksi" state
   ```

2. **Click Quick Add Button**
   ```
   Expected: Modal bottom sheet appears with clean form
   ```

3. **Select Category**
   ```
   Action: Tap "Makanan" category
   Expected: Category is highlighted with color
   ```

4. **Input Data**
   ```
   Action: 
   - Amount: 50000
   - Note: Makan siang di restoran
   Expected: Form accepts input, no validation errors
   ```

5. **Submit**
   ```
   Action: Tap "Simpan Cepat"
   Expected: 
   - Modal closes
   - Success snackbar appears
   - New transaction appears in recent list
   - Balance updates (if income) or decreases (if expense)
   ```

6. **Verify Metrics**
   ```
   Expected:
   - Total Saldo updates
   - Pengeluaran card shows new total
   - 7-day spending updates if within last week
   ```

### Testing Offline Mode

1. **Turn Off Internet**
   ```bash
   # On Mac/Linux: disable WiFi
   # On Android: Settings → WiFi OFF, Airplane mode ON
   ```

2. **Add Transaction While Offline**
   ```
   Expected: 
   - Transaction saves to Hive immediately
   - No Supabase sync error shown
   - UI updates normally
   - Data persists in app
   ```

3. **Turn On Internet**
   ```
   Expected:
   - App attempts to sync pending
   - Transactions eventually reach Supabase
   - No duplicate entries
   ```

### Edge Cases

1. **Empty Categories**
   - [ ] Quick Add shows message if no categories
   - [ ] App doesn't crash

2. **Large Amounts**
   - [ ] 1,000,000 displays as "Rp 1.000.000"
   - [ ] Decimal handling (Rp 1.500)

3. **Special Characters in Notes**
   - [ ] Emoji support (🍔, 🚗, etc.)
   - [ ] Unicode characters

4. **Rapid Clicks**
   - [ ] Multiple Quick Add opens handled
   - [ ] Double-click submit doesn't create duplicates

---

## 🐛 Troubleshooting

### Problem: "HiveManager._instance initialization failed"
**Solution:**
1. Check `main.dart` has:
   ```dart
   await HiveManager.instance.initializeBoxes();
   ```
2. Ensure call is BEFORE `runApp()`

---

### Problem: "Categories list is empty in Quick Add"
**Solution:**
1. Check Supabase `categories` table has data:
   ```sql
   SELECT * FROM categories;
   ```
2. If empty, run: `sql/setup_sample_data.sql`
3. Force refresh: `txnProvider.loadCategories()`

---

### Problem: "Balance shows 'Rp NaN'"
**Solution:**
1. Check `_formatCurrency()` logic
2. Ensure amount is parsed as `double`:
   ```dart
   final amount = double.tryParse(_amountController.text);
   if (amount == null || amount <= 0) {
     // Show error
   }
   ```

---

### Problem: "Transaction doesn't appear after submit"
**Solution:**
1. Check console for errors: `flutter logs`
2. Verify `TransactionProvider.addTransaction()` called
3. Check if DashboardProvider is watching correctly:
   ```dart
   // Should use Consumer2
   Consumer2<DashboardProvider, TransactionProvider>(...)
   ```

---

### Problem: "App crashes on logout"
**Solution:**
1. Ensure `TransactionProvider.clear()` called on logout
2. Update `AuthProvider.logout()`:
   ```dart
   await context.read<TransactionProvider>().clear();
   ```

---

### Problem: "Build runner code gen fails"
**Solution:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

---

## 📚 Key Code Examples

### Example 1: Adding a Transaction

```dart
// In dashboard_page.dart Quick Add submit
final newTxn = TransactionModel(
  id: '', // Repository will generate
  userId: authProvider.currentUser!.id,
  categoryId: _selectedCategoryId!,
  amount: amount,
  note: _noteController.text,
  date: DateTime.now(),
  type: selectedType, // 'income' or 'expense'
);

await txnProvider.addTransaction(
  newTxn,
  authProvider.currentUser!.id,
);
```

### Example 2: Filtering by Month

```dart
// In transaction_provider.dart
Future<void> loadMonth(String userId, DateTime month) async {
  _selectedMonth = month;
  final startDate = DateTime(month.year, month.month, 1);
  final endDate = DateTime(month.year, month.month + 1, 1);
  await _loadTransactions(userId, startDate, endDate);
}
```

### Example 3: Computing Metrics

```dart
// In dashboard_provider.dart
double get monthBalance => 
  metrics?.balance ?? 0;

List<Map<String, dynamic>> getTopCategories() {
  // Group transactions by category
  // Sort by total descending
  // Return top 3
}
```

---

## 🔐 Security Notes

### Row Level Security (RLS)

Ensure Supabase RLS policies are set:

```sql
-- Transactions: Users can only see their own
CREATE POLICY "Users can view own transactions"
  ON transactions
  USING (auth.uid() = user_id);

-- Categories: Everyone can read
CREATE POLICY "Everyone can read categories"
  ON categories
  USING (true);
```

### API Keys

- **anonKey**: Embedded in app (current setup)
  - For public read (categories)
  - For authenticated writes (transactions)
- **serviceKey**: Keep secret, use in backend only

---

## 📈 Performance Notes

### Optimization Tips

1. **Lazy Load Categories**
   ```dart
   // Categories loaded once on init
   txnProvider.loadCategories();
   ```

2. **Cache Transactions**
   ```dart
   // HiveManager automatically caches
   // Fallback to cache on offline
   ```

3. **Limit Recent Transactions**
   ```dart
   // Show only 5 recent to reduce render time
   return transactions.take(5).toList();
   ```

4. **Avoid Unnecessary Rebuilds**
   ```dart
   // Use Consumer2 to watch only needed providers
   Consumer2<DashboardProvider, TransactionProvider>(...)
   ```

---

## 🚀 Next Steps (Fase 3.2)

1. **Create Transaction List Page**
   - Full list of all transactions
   - Pagination or infinite scroll
   - Swipe to delete
   - Tap to edit

2. **Add Advanced Filtering**
   - Date range picker
   - Category filter
   - Amount range slider
   - Type filter (income/expense)

3. **Edit Transaction**
   - Open transaction details
   - Modify amount/category/note
   - Update in Supabase + Hive

4. **Search**
   - Search by note
   - Search by category name

---

## 📞 Support & Resources

- **Supabase Docs**: https://supabase.com/docs
- **Flutter Docs**: https://flutter.dev/docs
- **Provider Package**: https://pub.dev/packages/provider
- **Hive DB**: https://pub.dev/packages/hive

---

## 📄 License

This project is part of Wangku Personal Finance Manager.  
All files created in Fase 3.1 are part of the core feature set.

---

**Status**: ✅ Ready for Testing  
**Next Review**: April 27, 2026 (after manual testing)  
**Estimated Completion of Fase 3**: April 29, 2026
