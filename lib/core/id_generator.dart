import 'package:uuid/uuid.dart';

/// Injectable id factory. Kept out of `domain/` so entities stay free of the
/// `uuid` dependency and tests can supply predictable ids.
typedef IdGenerator = String Function();

const Uuid _uuid = Uuid();

/// UUID v4. The default [IdGenerator] for production wiring.
String generateUuidV4() => _uuid.v4();
