class UserProfile {
  final String id;
  final String name;
  final String phone;
  final DateTime? birthDate;

  const UserProfile({
    required this.id,
    this.name = '',
    this.phone = '',
    this.birthDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'birth_date': birthDate?.toIso8601String().split('T').first,
      };

  UserProfile copyWith({
    String? name,
    String? phone,
    DateTime? birthDate,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
    );
  }
}
