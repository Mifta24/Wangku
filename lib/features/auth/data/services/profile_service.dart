import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/user_profile.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _profilesTable = 'profiles';

  RealtimeChannel? _profileChannel;

  void subscribeToProfile(String userId, void Function() onChanged) {
    _profileChannel?.unsubscribe();
    _profileChannel = _supabase
        .channel('profiles_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _profilesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  void unsubscribeProfile() {
    _profileChannel?.unsubscribe();
    _profileChannel = null;
  }

  /// Ambil profil user dari tabel profiles
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from(_profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      throw Exception('Gagal ambil profil: ${e.toString()}');
    }
  }

  /// Simpan/update profil ke tabel profiles (upsert)
  Future<UserProfile> saveProfile(UserProfile profile) async {
    try {
      final response = await _supabase
          .from(_profilesTable)
          .upsert(profile.toJson())
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      throw Exception('Gagal simpan profil: ${e.toString()}');
    }
  }
}
