# 🚀 Flutter App - Developer Quick Reference

## ⚡ Quick Navigation

### I want to... 

#### **Add a New Feature**
1. Create model in `lib/models/`
2. Add provider in `lib/providers/app_providers.dart`
3. Create screen in `lib/screens/`
4. Add route in `HomeScreen` or `main.dart`

#### **Modify Printer Settings**
→ Edit: `lib/services/printer_service.dart`
```dart
static const String printerHost = '192.168.1.8';
static const int printerPort = 9100;
```

#### **Change Shop Details (on Bill)**
→ Edit: `lib/models/bill.dart` in `Bill.toJson()` method

#### **Add Default Products**
→ Edit: `lib/models/default_products.dart`
```dart
Product(id: 'p1', name: 'Product Name', price: 100, unit: 'kg', category: 'Vegetables'),
```

#### **Understand Riverpod State Flow**
→ Study: `lib/providers/app_providers.dart`
```dart
final userProvider = StateNotifierProvider<UserNotifier, String?>(...);
// Usage in Widget:
final user = ref.watch(userProvider);
ref.read(userProvider.notifier).login(name);
```

#### **Access Cart Data**
→ In any `ConsumerWidget` or `ConsumerStatefulWidget`:
```dart
final cart = ref.watch(cartProvider);
final totals = ref.read(cartProvider.notifier);
```

#### **Add a New Product Programmatically**
```dart
ref.read(productsProvider.notifier).addProduct(
  Product(
    id: DateTime.now().toString(),
    name: 'New Product',
    price: 100.0,
    unit: 'kg',
    category: 'Vegetables',
  ),
);
```

#### **Clear Cart & Start Fresh**
```dart
ref.read(cartProvider.notifier).clearCart();
```

#### **Send Bill to Printer**
```dart
final bill = Bill(...);
final result = await PrinterService.sendBillToPrinter(bill);
if (result['success']) {
  // Handle success
} else {
  // Handle error
}
```

---

## 📚 Key Code Snippets

### Create a ConsumerStatefulWidget
```dart
class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    return Scaffold(...);
  }
}
```

### Create a ConsumerWidget (Stateless)
```dart
class MyWidget extends ConsumerWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    return ListView(...);
  }
}
```

### Watch & Read Data
```dart
// Watch - rebuilds widget when data changes
final data = ref.watch(myProvider);

// Read - get data once (doesn't rebuild)
final data = ref.read(myProvider);

// Modify state
ref.read(myProvider.notifier).someMethod();
```

### Save Data to SharedPreferences
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('key', 'value');
final value = prefs.getString('key');
```

### Calculate Bill Totals
```dart
final cartNotifier = ref.read(cartProvider.notifier);
double subtotal = cartNotifier.subtotal;      // Sum of all items
double tax = cartNotifier.tax;                 // 5% of subtotal
double grandTotal = cartNotifier.grandTotal;   // subtotal + tax
```

### Format Date & Time
```dart
import 'package:intl/intl.dart';

final now = DateTime.now();
final dateStr = DateFormat('dd/MM/yyyy').format(now);
final timeStr = DateFormat('hh:mm a').format(now);
```

---

## 🔍 File Purpose Reference

| File | Purpose | Lines |
|------|---------|-------|
| `main.dart` | App entry, theme, routing | 30 |
| `models/product.dart` | Product data model | 38 |
| `models/cart_item.dart` | Shopping cart item | 18 |
| `models/bill.dart` | Complete bill representation | 34 |
| `models/default_products.dart` | 50+ pre-loaded products | 45 |
| `providers/app_providers.dart` | All state management | 105 |
| `services/printer_service.dart` | Thermal printer integration | 180 |
| `screens/login_screen.dart` | Operator login | 110 |
| `screens/home_screen.dart` | Navigation hub | 90 |
| `screens/billing_screen.dart` | Create bills | 450 |
| `screens/admin_screen.dart` | Manage inventory | 420 |

---

## 🔌 Backend Endpoints Used

### Print Bill
```
POST http://localhost:5000/api/print
Content-Type: application/json

Request: { printerConfig, billData }
Response: { success: bool, message: string, bytes_sent?: number }
```

### Test Printer Connection
```
POST http://localhost:5000/api/test-printer
Content-Type: application/json

Request: { printerConfig }
Response: { success: bool, message: string }
```

---

## 🎨 Color Scheme

| Usage | Color | Code |
|-------|-------|------|
| Primary (Buttons) | Blue | `Colors.blue[600]` |
| Success (Print) | Green | `Colors.green` |
| Error/Delete | Red | `Colors.red` |
| Text Main | Dark Slate | `#0f172a` |
| Text Muted | Gray | `#64748b` |
| Border | Light Gray | `#e2e8f0` |
| Background | Very Light | `#f1f5f9` |

---

## 📏 Common UI Patterns

### Card Container
```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(children: [...]),
  ),
)
```

### Button with Icon
```dart
ElevatedButton.icon(
  onPressed: () {},
  icon: const Icon(Icons.add),
  label: const Text('Add'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue[600],
  ),
)
```

### Text Input Field
```dart
TextField(
  controller: controller,
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Hint text',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)
```

### List with Remove
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(
      title: Text(items[index].name),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => notifier.removeItem(index),
      ),
    );
  },
)
```

---

## 🧪 Testing Checklist

- [ ] Login saves operator name
- [ ] Products load on startup
- [ ] Can search and filter products
- [ ] Can add items to cart
- [ ] Cart calculations are correct (5% GST)
- [ ] Can remove items from cart
- [ ] Can print bill (requires backend)
- [ ] Can add new product
- [ ] Can edit existing product
- [ ] Can delete product
- [ ] Can sync products with defaults
- [ ] Data persists after app restart
- [ ] Logout clears session

---

## 🚨 Common Mistakes to Avoid

1. **Forgetting `WidgetRef ref` in ConsumerWidget build**
   ```dart
   // ❌ Wrong
   Widget build(BuildContext context) { }
   
   // ✅ Correct
   Widget build(BuildContext context, WidgetRef ref) { }
   ```

2. **Using `ref.watch()` outside build method**
   ```dart
   // ❌ Wrong - in event handler
   onPressed: () {
     final data = ref.watch(provider);
   }
   
   // ✅ Correct - in build method
   @override
   Widget build(BuildContext context, WidgetRef ref) {
     final data = ref.watch(provider);
   }
   ```

3. **Modifying state in build method**
   ```dart
   // ❌ Wrong
   @override
   Widget build(BuildContext context, WidgetRef ref) {
     ref.read(provider.notifier).addItem(...);
   }
   
   // ✅ Correct
   onPressed: () {
     ref.read(provider.notifier).addItem(...);
   }
   ```

4. **Forgetting to await async operations**
   ```dart
   // ❌ Wrong
   PrinterService.sendBillToPrinter(bill);
   
   // ✅ Correct
   final result = await PrinterService.sendBillToPrinter(bill);
   ```

---

## 📚 Useful Resources

- [Riverpod Documentation](https://riverpod.dev/)
- [Flutter Docs](https://flutter.dev/docs)
- [Dart Lang](https://dart.dev/)
- [Material Design](https://material.io/design)

---

## 🔐 Sensitive Configuration

**⚠️ BEFORE PRODUCTION:**
1. ✅ Update printer IP address
2. ✅ Update shop details (name, address, phone)
3. ✅ Update backend URL if different
4. ✅ Test with real thermal printer
5. ✅ Verify all calculations

---

## 💬 Code Style

- Use const constructors where possible
- Keep widgets small and focused
- Avoid deeply nested widgets
- Use descriptive variable names
- Comment complex logic
- Use barrel exports (index.dart) for clean imports
- Follow Flutter/Dart conventions

---

**Happy Coding! 🎉**
