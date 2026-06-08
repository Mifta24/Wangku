import '../../domain/models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileRepository {
  final ProfileService _service = ProfileService();

  Future<UserProfile?> getProfile(String userId) {
    return _service.getProfile(userId);
  }

  Future<UserProfile> saveProfile(UserProfile profile) {
    return _service.saveProfile(profile);
  }

  void subscribeToProfile(String userId, void Function() onChanged) {
    _service.subscribeToProfile(userId, onChanged);
  }

  void unsubscribeProfile() {
    _service.unsubscribeProfile();
  }
}
