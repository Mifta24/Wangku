class UserProfile {
  final String id;
  final String name;
  final String phone;
  final String bio;
  final String job;
  final String city;
  final String? gender;
  final DateTime? birthDate;

  const UserProfile({
    required this.id,
    this.name = '',
    this.phone = '',
    this.bio = '',
    this.job = '',
    this.city = '',
    this.gender,
    this.birthDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      job: json['job']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      gender: json['gender']?.toString().isEmpty == true
          ? null
          : json['gender']?.toString(),
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'bio': bio,
        'job': job,
        'city': city,
        'gender': gender ?? '',
        'birth_date': birthDate?.toIso8601String().split('T').first,
        'updated_at': DateTime.now().toIso8601String(),
      };

  UserProfile copyWith({
    String? name,
    String? phone,
    String? bio,
    String? job,
    String? city,
    String? gender,
    DateTime? birthDate,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      job: job ?? this.job,
      city: city ?? this.city,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
    );
  }
}
