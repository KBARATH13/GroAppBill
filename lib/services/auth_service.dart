import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/shop_info.dart';
import '../models/billing_history.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Currently signed-in Firebase user (raw).
  static User? get currentFirebaseUser => _auth.currentUser;

  /// Fetch the AppUser document from Firestore.
  static Future<AppUser?> fetchAppUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(uid, doc.data()!);
  }

  /// Stream that emits a fresh [AppUser] whenever auth state or Firestore doc changes.
  static Stream<AppUser?> get appUserStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      final user = await fetchAppUser(firebaseUser.uid);
      if (user?.isBlocked == true) {
        await _auth.signOut();
        return null;
      }
      return user;
    });
  }

  /// Sign up with email/password. Creates Firestore user doc with correct role.
  static Future<AppUser?> signUp({
    required String email,
    required String password,
    required bool isAdmin,
    String? adminEmail,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    
    // For admins, the adminEmail is their own email. 
    // For operators, it's the specific email provided during signup.
    final shopOwnerEmail = isAdmin ? email.trim() : (adminEmail?.trim() ?? '');

    final userData = AppUser(
      uid: uid,
      email: email.trim(),
      role: isAdmin ? 'admin' : 'operator',
      status: isAdmin ? 'approved' : 'pending',
      adminEmail: shopOwnerEmail,
      canAddInventory: false, // Default to false, granted by admin during approval
    );
    await _db.collection('users').doc(uid).set(userData.toMap());
    return userData;
  }

  /// Sign in with email/password.
  static Future<AppUser?> signIn({
    required String email,
    required String password,
    required bool isAdmin,
    String? adminEmail,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    final doc = await _db.collection('users').doc(uid).get();
    
    if (doc.exists) {
      final user = AppUser.fromMap(uid, doc.data()!);
      
      // Strict Role Validation
      if (isAdmin && user.role != 'admin') {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'This account is not registered as an Admin.',
        );
      }
      if (!isAdmin && user.role == 'admin') {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'This account is registered as an Admin. Please use Admin login.',
        );
      }

      if (user.isBlocked) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'This account has been removed by the shop administrator.',
        );
      }
      return user;
    }

    // ACCOUNT HEALING: If Firebase Auth exists but Firestore doc was deleted/missing,
    // re-create it using the current login details.
    final shopOwnerEmail = isAdmin ? email.trim() : (adminEmail?.trim() ?? '');
    final newUser = AppUser(
      uid: uid,
      email: email.trim(),
      role: isAdmin ? 'admin' : 'operator',
      status: isAdmin ? 'approved' : 'pending',
      adminEmail: shopOwnerEmail,
      canAddInventory: isAdmin, 
    );
    await _db.collection('users').doc(uid).set(newUser.toMap());
    return newUser;
  }

  /// Sign out.
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Approve a pending operator.
  static Future<void> approveUser(String uid, {bool canAddInventory = false}) async {
    await _db.collection('users').doc(uid).update({
      'status': 'approved',
      'canAddInventory': canAddInventory,
    });
  }

  /// Reject/delete a pending operator.
  static Future<void> rejectUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  /// Get all pending operator requests for a specific admin.
  static Stream<List<AppUser>> pendingUsersStream(String adminEmail) {
    return _db
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .where('adminEmail', isEqualTo: adminEmail)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromMap(d.id, d.data()))
            .toList());
  }

  /// Get all approved operators linked to a specific admin.
  static Stream<List<AppUser>> approvedUsersStream(String adminEmail) {
    return _db
        .collection('users')
        .where('status', isEqualTo: 'approved')
        .where('role', isEqualTo: 'operator')
        .where('adminEmail', isEqualTo: adminEmail)
        .where('isBlocked', isEqualTo: false) // Filter out blocked users
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromMap(d.id, d.data()))
            .toList());
  }

  /// Block and remove an operator.
  static Future<void> blockAndRemoveOperator(String uid) async {
    await _db.collection('users').doc(uid).update({
      'isBlocked': true,
      'status': 'removed', // Clear approved status
      'deletionScheduledAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3))),
    });
  }

  /// Update an existing user's inventory clearance.
  static Future<void> updateUserPermission(String uid, bool canAddInventory) async {
    await _db.collection('users').doc(uid).update({
      'canAddInventory': canAddInventory,
    });
  }

  /// Update shop profile information (for admin only).
  static Future<void> updateShopInfo(String adminEmail, ShopInfo info) async {
    await _db.collection('shops').doc(adminEmail).set(info.toMap());
  }

  /// Stream shop profile information.
  static Stream<ShopInfo?> shopInfoStream(String adminEmail) {
    return _db.collection('shops').doc(adminEmail).snapshots().map((snap) {
      if (!snap.exists) return const ShopInfo(); // Default if not found
      return ShopInfo.fromMap(snap.data()!);
    });
  }


  /// Push a new bill to Firestore for cloud sync.
  static Future<void> saveBill(String adminEmail, BillingHistoryRecord bill, {required String docId}) async {
    await _db
        .collection('shops')
        .doc(adminEmail)
        .collection('bills')
        .doc(docId)
        .set(bill.toJson());
  }

  /// Stream bills for the current shop. 
  /// Sorting and 3-day window filtering should be done in the UI/Provider.
  static Stream<List<BillingHistoryRecord>> billsStream(String adminEmail) {
    return _db
        .collection('shops')
        .doc(adminEmail)
        .collection('bills')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BillingHistoryRecord.fromJson(d.data(), d.id))
            .toList());
  }

  /// Delete bills older than a specified number of days from Firestore to save cloud cost
  static Future<void> purgeOldCloudBills(String adminEmail, {int keepDays = 3}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: keepDays));
      final cutoffKey = '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
      
      final snapshot = await _db
          .collection('shops')
          .doc(adminEmail)
          .collection('bills')
          .where('date', isLessThan: cutoffKey)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      // Ignored - will retry next time
    }
  }

  /// Clean up users scheduled for deletion (Admin only step).
  static Future<void> cleanUpRemovedUsers(String adminEmail) async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final snapshot = await _db
          .collection('users')
          .where('adminEmail', isEqualTo: adminEmail)
          .where('isBlocked', isEqualTo: true)
          .where('deletionScheduledAt', isLessThanOrEqualTo: now)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      // Ignored
    }
  }
}
