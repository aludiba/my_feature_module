import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'my_feature_module_method_channel.dart';

abstract class MyFeatureModulePlatform extends PlatformInterface {
  /// Constructs a MyFeatureModulePlatform.
  MyFeatureModulePlatform() : super(token: _token);

  static final Object _token = Object();

  static MyFeatureModulePlatform _instance = MethodChannelMyFeatureModule();

  /// The default instance of [MyFeatureModulePlatform] to use.
  ///
  /// Defaults to [MethodChannelMyFeatureModule].
  static MyFeatureModulePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MyFeatureModulePlatform] when
  /// they register themselves.
  static set instance(MyFeatureModulePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
