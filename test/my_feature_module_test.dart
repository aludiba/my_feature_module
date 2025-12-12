import 'package:flutter_test/flutter_test.dart';
import 'package:my_feature_module/my_feature_module.dart';
import 'package:my_feature_module/my_feature_module_platform_interface.dart';
import 'package:my_feature_module/my_feature_module_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMyFeatureModulePlatform
    with MockPlatformInterfaceMixin
    implements MyFeatureModulePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MyFeatureModulePlatform initialPlatform = MyFeatureModulePlatform.instance;

  test('$MethodChannelMyFeatureModule is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMyFeatureModule>());
  });

  test('getPlatformVersion', () async {
    MyFeatureModule myFeatureModulePlugin = MyFeatureModule();
    MockMyFeatureModulePlatform fakePlatform = MockMyFeatureModulePlatform();
    MyFeatureModulePlatform.instance = fakePlatform;

    expect(await myFeatureModulePlugin.getPlatformVersion(), '42');
  });
}
