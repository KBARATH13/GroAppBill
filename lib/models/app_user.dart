/// Represents an authenticated app user with role and approval status.
class AppUser {
  final String uid;
  final String email;
  final String role; // 'admin' or 'operator'
  final String status; // 'approved' or 'pending'
  final String adminEmail; // The email of the shop owner/admin
  final bool canAddInventory; // Clearance to add items to inventory
  final bool isBlocked; // Whether the user is blocked by admin
  final DateTime? deletionScheduledAt; // When the user is scheduled to be deleted

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.status,
    required this.adminEmail,
    required this.canAddInventory,
    this.isBlocked = false,
    this.deletionScheduledAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isApproved => status == 'approved';

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'operator',
      status: data['status'] as String? ?? 'pending',
      adminEmail: data['adminEmail'] as String? ?? '',
      canAddInventory: data['canAddInventory'] as bool? ?? false,
      isBlocked: data['isBlocked'] as bool? ?? false,
      deletionScheduledAt: data['deletionScheduledAt'] != null 
          ? (data['deletionScheduledAt'] as dynamic).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'status': status,
      'adminEmail': adminEmail,
      'canAddInventory': canAddInventory,
      'isBlocked': isBlocked,
      'deletionScheduledAt': deletionScheduledAt,
    };
  }
}
