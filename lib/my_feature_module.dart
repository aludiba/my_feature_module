library my_feature_module;

// 导出平台接口（保持向后兼容）
export 'my_feature_module_platform_interface.dart';
export 'my_feature_module_method_channel.dart';

// 导出主要组件
export 'src/widgets/smz_page.dart';
export 'src/widgets/camera_page.dart';
export 'src/models/recognition_result.dart';
export 'src/services/http_service.dart';

import 'my_feature_module_platform_interface.dart';

/// MyFeatureModule 主类（保持向后兼容）
class MyFeatureModule {
  /// 获取平台版本
  Future<String?> getPlatformVersion() {
    return MyFeatureModulePlatform.instance.getPlatformVersion();
  }
}
