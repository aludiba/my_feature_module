import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'my_feature_module_platform_interface.dart';

/// An implementation of [MyFeatureModulePlatform] that uses method channels.
class MethodChannelMyFeatureModule extends MyFeatureModulePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('my_feature_module');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
