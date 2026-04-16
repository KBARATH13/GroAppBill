# Grocery Billing System - Flutter Mobile App

This is a complete Flutter implementation of the Grocery Billing System, featuring the same functionality as the React web version and Node.js backend.

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── product.dart            # Product model
│   ├── cart_item.dart          # Cart item model
│   ├── bill.dart               # Bill model
│   ├── default_products.dart   # Default product data
│   └── index.dart              # Models barrel export
├── providers/
│   └── app_providers.dart      # State management (Riverpod)
├── services/
│   └── printer_service.dart    # Thermal printer integration
└── screens/
    ├── login_screen.dart       # Login/authentication
    ├── home_screen.dart        # Navigation hub
    ├── billing_screen.dart     # Create bills
    ├── admin_screen.dart       # Inventory management
    └── index.dart              # Screens barrel export
```

## 🎯 Features Implemented

### 1. **Authentication**
- Simple login with operator name
- Session persistence using SharedPreferences
- Logout functionality

### 2. **Billing Screen**
- **Product Catalog**: Browse all products with search and category filtering
- **Cart Management**: Add items with custom quantities
- **Bill Calculation**: 
  - Subtotal calculation
  - 5% GST tax calculation
  - Grand total display
- **Thermal Printer Integration**: 
  - Print bills directly to network thermal printer
  - ESC/POS command formatting
  - Bill generation with all transaction details

### 3. **Inventory Management**
- **Add Products**: Create new products with name, price, unit, and category
- **Edit Products**: Modify existing product details
- **Delete Products**: Remove products from inventory
- **Sync Defaults**: Add missing products from the default list
- **Search & Filter**: Find products by name and category

### 4. **State Management** (Riverpod)
- **UserProvider**: Manages operator authentication
- **ProductsProvider**: Manages product inventory with persistent storage
- **CartProvider**: Manages shopping cart with calculations

### 5. **Local Storage** (SharedPreferences)
- Operator name persistence
- Product inventory persistence
- Cart data (can be added)

## 🔌 Printer Integration

### Backend Integration (Node.js API)
The app communicates with the Node.js backend for thermal printer support:
```
POST http://localhost:5000/api/print
```

**Request Format:**
```json
{
  "printerConfig": {
    "host": "192.168.1.8",
    "port": 9100,
    "timeout": 5000
  },
  "billData": {
    "shopName": "AVS",
    "shopAddress": "...",
    "cartItems": [...],
    "grandTotal": 1234.56,
    "customerType": "Walk-in",
    "operatorName": "John",
    "billNumber": "BILL-123456",
    "date": "09/03/2026",
    "time": "10:30 AM"
  }
}
```

### Direct Printer Connection (Fallback)
If the backend is unavailable, the app can connect directly to the thermal printer via TCP/IP:
```dart
PrinterService.sendDirectToPrinter(data);
```

### ESC/POS Formatting
Bills are formatted using ESC/POS commands:
- Printer initialization
- Text alignment and formatting
- Item line formatting
- Total calculations
- Paper cut command

## 📦 Dependencies

- **flutter_riverpod**: State management
- **shared_preferences**: Local storage
- **http**: HTTP client for backend communication
- **intl**: Date/time formatting

## 🚀 Getting Started

### Prerequisites
1. Flutter SDK (^3.11.1)
2. Node.js backend running on `http://localhost:5000` (for printing)
3. Network thermal printer configured at `192.168.1.8:9100`

### Setup & Run

1. **Install Dependencies**
   ```bash
   cd groappbill
   flutter pub get
   ```

2. **Update Printer Configuration** (if needed)
   Edit `lib/services/printer_service.dart`:
   ```dart
   static const String printerHost = '192.168.1.8';  // Your printer IP
   static const int printerPort = 9100;
   ```

3. **Run the App**
   ```bash
   flutter run
   ```

## 🔄 Data Flow

### Adding a Product to Cart
1. User selects a product from the catalog
2. Enters quantity/weight
3. Clicks "Add to Cart"
4. Item is added to CartProvider state
5. Cart total is recalculated

### Creating a Bill
1. User adds items to cart
2. Enters operator name and customer type
3. Clicks "Print Bill"
4. Bill object is created with all details
5. Request sent to backend API
6. Thermal printer outputs the bill
7. Cart is cleared
8. Success message displayed

### Managing Inventory
1. Admin views product list (with search/filter)
2. Can add new products
3. Can edit existing products
4. Can delete products
5. Changes saved to SharedPreferences
6. Can sync with default product list

## 📱 Screens Overview

### Login Screen
- Simple operator authentication
- Name input field
- Session persistence

### Home Screen (Navigation Hub)
- Bottom navigation between Billing and Inventory
- Drawer menu with operator info
- Logout option

### Billing Screen
- Product search and filtering
- Product selection with visual feedback
- Quantity input
- Cart management with item removal
- Bill totals display
- Print button with status feedback

### Admin Screen
- Product inventory table
- Search and category filtering
- Add/Edit/Delete forms
- Sync defaults button
- Real-time data persistence

## 🛠️ Configuration

### Printer Configuration
Edit `lib/services/printer_service.dart`:
```dart
class PrinterService {
  static const String apiBaseUrl = 'http://localhost:5000';
  static const String printerHost = '192.168.1.8';
  static const int printerPort = 9100;
  static const int timeout = 5000;
}
```

### Shop Details
Edit `lib/models/bill.dart`:
```dart
'shopName': 'AVS',
'shopAddress': 'Your shop address',
'phoneNumber': 'Your phone',
```

## 📊 Default Product Categories

1. **Fruits** (22 products)
   - Apples, Bananas, Oranges, Mangoes, etc.

2. **Vegetables** (20 products)
   - Tomatoes, Onions, Potatoes, Carrots, etc.

3. **Dhall** (5 products)
   - Toor Dal, Moong Dal, Urad Dal, Chana Dal

4. **Groceries** (5 products)
   - Rice, Wheat Flour, Sugar, Salt

## 🔄 State Management Pattern

```
UserProvider (user login state)
├── login(name) -> saves to SharedPreferences
├── logout() -> removes from SharedPreferences
└── state -> current operator name

ProductsProvider (inventory management)
├── products -> all products
├── addProduct(product)
├── updateProduct(id, product)
├── deleteProduct(id)
├── syncDefaults()
└── persists to SharedPreferences

CartProvider (shopping cart)
├── cartItems -> items in cart
├── addItem(product, quantity)
├── removeItem(index)
├── clearCart()
├── subtotal -> calculated
├── tax -> 5% GST
└── grandTotal -> calculated
```

## 🖨️ Printing Features

### Bill Format
```
========================================
              AVS
LIG NO.165,4TH CROSS
PHONE: 892550536
========================================
Bill #: BILL-1234567890
Date: 09/03/2026  Time: 10:30 AM
Operator: John
========================================
Item              Qty       Total
========================================
Apple (Kashmir)   1.00 kg   ₹180.00
Tomato (Local)    2.50 kg   ₹75.00
Banana (Yellow)   3.00 kg   ₹150.00
========================================
                   Subtotal: ₹405.00
                   GST (5%): ₹20.25
                Grand Total: ₹425.25
========================================
        Thank You!
========================================
```

## 🐛 Troubleshooting

### Backend Connection Issues
- Ensure Node.js server is running on `http://localhost:5000`
- Check firewall settings
- Verify printer IP and port configuration

### Printer Issues
- Test printer connection with backend test endpoint
- Verify network connectivity to printer
- Check printer IP address
- Ensure printer supports ESC/POS commands

### Data Not Persisting
- Check SharedPreferences permissions
- Verify app has storage access (for Android)
- Clear app data and reinstall if needed

## 📝 License

This project is part of the Grocery Billing System suite.

## 🤝 Integration Notes

This Flutter app mirrors the functionality of:
- **Frontend**: React.js web application
- **Backend**: Node.js Express server
- **Database**: LocalStorage (SharedPreferences in Flutter)

All three components can work together:
1. Flutter app → Print request → Node.js backend → Thermal printer
2. Flutter app → LocalStorage → Persistent data
3. React web app ↔ Same backend for printing

---

**Developed**: March 2026
**Version**: 1.0.0
