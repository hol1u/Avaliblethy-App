import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ApiKeyStorage {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> delete();
}

class FlutterSecureApiKeyStorage implements ApiKeyStorage {
  FlutterSecureApiKeyStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'apiKey';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}
