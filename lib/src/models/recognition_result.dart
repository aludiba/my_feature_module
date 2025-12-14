/// 识别结果数据模型
class RecognitionResult {
  /// 是否识别成功
  final bool success;
  
  /// 识别结果文本列表（如：舌色红、舌苔黄等）
  final List<String> results;
  
  /// 错误信息（识别失败时）
  final String? errorMessage;

  RecognitionResult({
    required this.success,
    this.results = const [],
    this.errorMessage,
  });

  /// 从 JSON 创建
  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      success: json['success'] ?? false,
      results: json['results'] != null 
          ? List<String>.from(json['results'])
          : [],
      errorMessage: json['errorMessage'],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'results': results,
      'errorMessage': errorMessage,
    };
  }
}

/// 图片数据模型
class ImageData {
  /// 图片路径
  final String? imagePath;
  
  /// 识别结果
  final RecognitionResult? recognitionResult;
  
  /// 是否显示示例图
  final bool showExample;

  ImageData({
    this.imagePath,
    this.recognitionResult,
    this.showExample = true,
  });

  /// 是否有图片
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  /// 复制并更新
  ImageData copyWith({
    String? imagePath,
    RecognitionResult? recognitionResult,
    bool? showExample,
  }) {
    return ImageData(
      imagePath: imagePath ?? this.imagePath,
      recognitionResult: recognitionResult ?? this.recognitionResult,
      showExample: showExample ?? this.showExample,
    );
  }
}

