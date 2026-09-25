/// Maps to the `users` collection.
/// Firestore document ID = Firebase Auth UID (no separate userId field needed;
/// the doc ID *is* the unique identifier, and it's what Firebase Auth gives us
/// for free when someone logs in).
enum UserRole { owner, employee }

UserRole roleFromString(String value) {
  switch (value) {
    case 'owner':
      return UserRole.owner;
    case 'employee':
    default:
      return UserRole.employee;
  }
}

String roleToString(UserRole role) {
  return role == UserRole.owner ? 'owner' : 'employee';
}

class AppUser {
  final String uid; // Firestore doc id == Firebase Auth uid
  final String email;
  final UserRole role;
  final String displayName;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName = '',
  });

  bool get isOwner => role == UserRole.owner;

  Map<String, dynamic> toMap() {
    return {
      'userEmail': email,
      'role': roleToString(role),
      'displayName': displayName,
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      email: map['userEmail'] ?? '',
      role: roleFromString(map['role'] ?? 'employee'),
      displayName: map['displayName'] ?? '',
    );
  }
}
