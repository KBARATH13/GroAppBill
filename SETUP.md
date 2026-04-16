# Flutter App - Quick Setup Guide

## 📦 Installation Steps

### 1. Install Dependencies
```bash
cd groappbill
flutter pub get
```

### 2. Update Printer Configuration (Optional)
Edit `lib/services/printer_service.dart` to match your printer:
```dart
static const String printerHost = '192.168.1.8';      // Your printer IP
static const int printerPort = 9100;
static const String apiBaseUrl = 'http://localhost:5000';
```

### 3. Update Shop Details (Optional)
Edit `lib/models/bill.dart` to add your shop information:
```dart
'shopName': 'Your Shop Name',
'shopAddress': 'Your Address',
'phoneNumber': 'Your Phone Number',
```

### 4. Run the App
```bash
flutter run
```

## 🏃 First Run Experience

1. **Login Page**: Enter operator name and tap "Get Started"
2. **Billing Screen** (Default): 
   - Search and select products
   - Enter quantity
   - Click "Add to Cart"
   - View cart totals
   - Click "Print Bill" to send to thermal printer
3. **Inventory Screen**: 
   - Manage products (Add/Edit/Delete)
   - Search and filter by category
   - Sync with default products

## 📝 Key Files & Locations

| Component | Location |
|-----------|----------|
| Models | `lib/models/` |
| State Management | `lib/providers/app_providers.dart` |
| Screens | `lib/screens/` |
| Printer Service | `lib/services/printer_service.dart` |
| Main Entry | `lib/main.dart` |

## ✨ Features at a Glance

✅ **Operator Login** - Session saved locally  
✅ **Product Catalog** - 50+ products with search & filter  
✅ **Shopping Cart** - Add/remove items, calculate totals  
✅ **Tax Calculation** - 5% GST included  
✅ **Thermal Printer** - Print bills via network printer  
✅ **Inventory Management** - Add/edit/delete products  
✅ **Data Persistence** - SharedPreferences for offline support  

## 🔗 Backend Requirements

For printing functionality, ensure Node.js backend is running:
```bash
cd Backend
npm install
npm start
```

Backend should be accessible at: `http://localhost:5000`

## 🐧 Supported Platforms

- ✅ Android
- ✅ iOS  
- ✅ Web (with browser restrictions)
- ✅ Windows/macOS (with socket permissions)

## 💡 Usage Tips

1. **First use**: Products load from default list
2. **Data persistence**: All changes saved automatically
3. **Printer not available**: Error message on print failure
4. **Add custom products**: Use Inventory screen
5. **Sync products**: "Sync" button merges new items from defaults

---

Happy Billing! 🛒
