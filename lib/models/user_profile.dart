class UserProfile {
  const UserProfile({
    this.fullName = '',
    this.age,
    this.contactNumber = '',
    this.email = '',
    this.imagePath,
  });

  final String fullName;
  final int? age;
  final String contactNumber;
  final String email;
  final String? imagePath;

  UserProfile copyWith({
    String? fullName,
    int? age,
    String? contactNumber,
    String? email,
    String? imagePath,
  }) =>
      UserProfile(
        fullName: fullName ?? this.fullName,
        age: age ?? this.age,
        contactNumber: contactNumber ?? this.contactNumber,
        email: email ?? this.email,
        imagePath: imagePath ?? this.imagePath,
      );

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'age': age,
        'contactNumber': contactNumber,
        'email': email,
        'imagePath': imagePath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        fullName: json['fullName'] as String? ?? '',
        age: json['age'] as int?,
        contactNumber: json['contactNumber'] as String? ?? '',
        email: json['email'] as String? ?? '',
        imagePath: json['imagePath'] as String?,
      );
}
