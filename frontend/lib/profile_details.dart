enum ProfileGender {
  male('male', 'Male'),
  female('female', 'Female'),
  nonBinary('non_binary', 'Non-binary'),
  preferNotToSay('prefer_not_to_say', 'Prefer not to say');

  const ProfileGender(this.value, this.label);
  final String value;
  final String label;
}

class ProfileDetails {
  const ProfileDetails({
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.age,
  });

  final ProfileGender gender;
  final String heightCm;
  final String weightKg;
  final int age;

  Map<String, Object> toJson() => {
    'gender': gender.value,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'age': age,
  };
}
