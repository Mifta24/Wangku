# 🚀 QUICK START CHECKLIST - Wangku Fase 3

Print this or keep it open while setting up.

---

## ✅ PRE-SETUP (5 min)

- [ ] Clone latest code from GitHub
- [ ] Open `c:\Aplikasi-Mobile\Wangku` in VS Code
- [ ] Terminal ready: `cd c:\Aplikasi-Mobile\Wangku`
- [ ] Emulator/device connected: `flutter devices`

---

## ✅ STEP 1: ADD DEPENDENCIES (2 min)

```bash
flutter pub add intl uuid fl_chart flutter_local_notifications workmanager
```

**Status**: 
- [ ] Command ran without errors
- [ ] `pubspec.lock` updated

---

## ✅ STEP 2: GET PACKAGES (1 min)

```bash
flutter pub get
```

**Status**:
- [ ] Output shows packages fetched
- [ ] No error messages

---

## ✅ STEP 3: CODE GENERATION (2 min)

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Status**:
- [ ] Build completed
- [ ] Generated files created
- [ ] No build errors

---

## ✅ STEP 4: ANALYSIS (1 min)

```bash
flutter analyze
```

**Status**:
- [ ] Output: "No issues found!" OR
- [ ] Minor warnings only (not errors)

---

## ✅ STEP 5: DATABASE SETUP (5 min)

1. Open Supabase Dashboard
2. Go to: **SQL Editor**
3. Create new query
4. Copy entire content from:
   ```
   c:\Aplikasi-Mobile\Wangku\sql\setup_sample_data.sql
   ```
5. Paste into Supabase SQL Editor
6. Click **RUN**

**Status**:
- [ ] SQL executed successfully
- [ ] No errors

**Verify**:
```sql
SELECT COUNT(*) FROM categories;
```
Should return: **7 expense + 4 income = 11 total** ✓

---

## ✅ STEP 6: RUN APP (2 min)

```bash
flutter run
```

**Status**:
- [ ] Build compiled successfully
- [ ] App installed on device
- [ ] App launched without crashes

---

## ✅ STEP 7: LOGIN TEST (1 min)

1. Use existing account OR
2. Create new account via "Register"

**Status**:
- [ ] Login successful
- [ ] Redirected to Dashboard
- [ ] No error messages

---

## ✅ STEP 8: QUICK ADD TEST (2 min)

1. Click **"Quick Add"** button (bottom-right FAB)
2. **Select**: Pengeluaran
3. **Pick Category**: Makanan
4. **Amount**: 50000
5. **Note**: Test transaction
6. **Submit**

**Status**:
- [ ] Modal appears smoothly
- [ ] Categories load correctly
- [ ] Form validates input
- [ ] Success message appears
- [ ] Modal closes

---

## ✅ STEP 9: VERIFY DASHBOARD UPDATE (1 min)

After step 8, check:

- [ ] New transaction appears in "Transaksi Terbaru"
- [ ] Pengeluaran card shows Rp 50.000
- [ ] Total Saldo shows -Rp 50.000 (negative since no income)
- [ ] 7-day expense updates

---

## ✅ STEP 10: TEST INCOME (2 min)

1. Click Quick Add again
2. **Select**: Pemasukan
3. **Pick Category**: Gaji
4. **Amount**: 5000000
5. **Submit**

**Status**:
- [ ] Transaction added
- [ ] Pemasukan card shows Rp 5.000.000
- [ ] Total Saldo becomes positive
- [ ] Balance calculation correct

---

## ✅ OFFLINE TEST (Optional, 3 min)

1. Disable WiFi on device
2. Add another transaction
3. Transaction saves (no error)
4. Enable WiFi
5. Transaction syncs to Supabase

**Status**:
- [ ] Offline transaction saves
- [ ] No UI errors
- [ ] Auto-sync on reconnect

---

## ✅ FINAL CHECKS

- [ ] No console errors: `flutter logs` (Ctrl+C to exit)
- [ ] App responsive on all screen sizes
- [ ] Navigation smooth between tabs
- [ ] No duplicate transactions

---

## 🎉 SUCCESS!

All checks passed? Congratulations! Fase 3.1 is working.

**Next**:
- Read `PHASE_3_README.md` for detailed docs
- Start Fase 3.2 (Transaction List) planning
- Commit changes: `git add . && git commit -m "feat: phase 3.1 transaction management"`

---

## 🆘 QUICK FIXES (if something breaks)

### App won't build
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### HiveManager error
→ Check `main.dart` line ~30: 
```dart
await HiveManager.instance.initializeBoxes();
```
Must be BEFORE `runApp()`

### Categories empty
→ Re-run SQL script: `sql/setup_sample_data.sql`

### Provider error
→ Check `pub get` succeeded
→ Verify import statements (no typos)

### Currency shows "Rp NaN"
→ Check amount input validation
→ Verify `intl` package installed

---

## 📞 Need Help?

1. **Compile errors?** → Run `flutter analyze`
2. **Database issues?** → Check Supabase logs
3. **Provider error?** → Check `main.dart` MultiProvider
4. **UI not updating?** → Verify `Consumer2` wrapper

---

## ⏱️ TOTAL SETUP TIME: ~25 minutes

- Dependencies: 2 min
- Build: 3 min
- DB setup: 5 min
- App run: 2 min
- Testing: 13 min

**Go!** 🚀
