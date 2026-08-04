import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';

final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile>((ref) {
  return ProfileNotifier(ProfileService(StorageService.instance))..load();
});

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier(this._service) : super(const UserProfile());
  final ProfileService _service;

  Future<void> load() async => state = await _service.load();
  Future<void> save(UserProfile profile) async {
    state = profile;
    await _service.save(profile);
  }

  Future<String?> pickImage() => _service.pickAndStoreImage();
  Future<void> clear() async {
    state = const UserProfile();
    await _service.save(state);
  }
}
