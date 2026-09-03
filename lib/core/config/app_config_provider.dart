import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_environment.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromDefines();
});
