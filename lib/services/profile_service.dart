import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user_profile.dart';
import 'storage_service.dart';

class ProfileService {
  ProfileService(this._storage);
  final StorageService _storage;
  static const _key = 'trackr_user_profile';

  Future<UserProfile> load() async {
    final rows = await _storage.readSecureList(_key);
    return rows.isEmpty ? const UserProfile() : UserProfile.fromJson(rows.first);
  }

  Future<void> save(UserProfile profile) => _storage.writeSecureList(_key, [profile.toJson()]);

  Future<String?> pickAndStoreImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (image == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    final target = File('${directory.path}/trackr_profile.jpg');
    await File(image.path).copy(target.path);
    return target.path;
  }
}
