class AppUser {
  final String uid;
  final String email;
  final int ecoPoints;

  AppUser({
    required this.uid,
    required this.email,
    this.ecoPoints = 0,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      ecoPoints: data['ecoPoints'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'ecoPoints': ecoPoints,
    };
  }
}
