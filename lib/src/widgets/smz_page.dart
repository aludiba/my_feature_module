import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:my_feature_module/src/models/recognition_result.dart';
import 'package:my_feature_module/src/services/http_service.dart';
import 'package:my_feature_module/src/widgets/camera_page.dart';

class SmzPage extends StatefulWidget {
  const SmzPage({super.key});

  @override
  State<SmzPage> createState() => _SmzPageState();
}

class _SmzPageState extends State<SmzPage> {
  final ScrollController _controller = ScrollController();
  final HttpService _httpService = HttpService();

  // 三个图片数据
  ImageData _tongueSurface = ImageData();
  ImageData _sublingualVeins = ImageData();
  ImageData _face = ImageData();

  // 舌面诊接口配置
  static const String _appId = '58928655-2a2b-4177-a81e-88ce7e272485';
  static const String _appSecret = '7a3d4f1a-a8ad-494e-9f72-bbcec7ae230f';
  static const String _authCode = '4e06c40b3b61432d9889b041ea27dab9';
  // 识别接口的 baseUrl
  // static const String _tongueApiBaseUrl = 'https://api.macrocura.com';//生产
  static const String _tongueApiBaseUrl = 'https://qaapi.macrocura.com';//测试
  // 上传接口的 baseUrl
  // static const String _uploadApiBaseUrl = 'https://api.lightcura.com';//生产
  static const String _uploadApiBaseUrl = 'https://qaapi.lightcura.com';//测试
  static const String _businessType = 'mini_tongue';

  @override
  void initState() {
    super.initState();
    // 初始化 HTTP 服务
    // 注意：上传接口可能在不同的服务器上，需要单独配置 baseUrl
    // 如果上传接口和识别接口在同一服务器，则使用相同的 baseUrl
    _httpService.init(
      baseUrl: _uploadApiBaseUrl, // 使用上传接口的 baseUrl
    );
    
    developer.log(
      'SmzPage 初始化完成',
      name: 'SmzPage',
      error: {
        'hasHttpService': true,
        'appId': _appId,
        'tongueApiBaseUrl': _tongueApiBaseUrl,
        'uploadApiBaseUrl': _uploadApiBaseUrl,
        'businessType': _businessType,
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 检查是否可以提交（至少有一张图片）
  bool get _canSubmit {
    return _tongueSurface.hasImage ||
        _sublingualVeins.hasImage ||
        _face.hasImage;
  }

  /// 跳转到拍照页面
  Future<void> _navigateToCamera(CameraType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraPage(
          type: type,
          httpService: _httpService,
          appId: _appId,
          appSecret: _appSecret,
          authCode: _authCode,
          tongueApiBaseUrl: _tongueApiBaseUrl,
          businessType: _businessType,
          onPhotoTaken: (imagePath, recognitionResult) {
            RecognitionResult? recognition;
            if (recognitionResult != null) {
              recognition = RecognitionResult(
                success: recognitionResult['success'] ?? false,
                results: recognitionResult['results'] != null
                    ? List<String>.from(recognitionResult['results'])
                    : [],
              );
            }

            if (mounted) {
              setState(() {
                switch (type) {
                  case CameraType.tongueSurface:
                    _tongueSurface = ImageData(
                      imagePath: imagePath,
                      recognitionResult: recognition,
                      showExample: false,
                    );
                    break;
                  case CameraType.sublingualVeins:
                    _sublingualVeins = ImageData(
                      imagePath: imagePath,
                      recognitionResult: recognition,
                      showExample: false,
                    );
                    break;
                  case CameraType.face:
                    _face = ImageData(
                      imagePath: imagePath,
                      recognitionResult: recognition,
                      showExample: false,
                    );
                    break;
                }
              });
            }
          },
        ),
      ),
    );
  }

  /// 删除图片
  void _deleteImage(String type) {
    setState(() {
      switch (type) {
        case 'tongueSurface':
          _tongueSurface = ImageData(showExample: true);
          break;
        case 'sublingualVeins':
          _sublingualVeins = ImageData(showExample: true);
          break;
        case 'face':
          _face = ImageData(showExample: true);
          break;
      }
    });
  }

  /// 提交
  Future<void> _submit() async {
    if (!_canSubmit) {
      developer.log(
        '提交失败：至少需要一张图片',
        name: 'SmzPage',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少上传一张图片')),
      );
      return;
    }

    developer.log(
      '开始提交问诊照片',
      name: 'SmzPage',
      error: {
        'tongueSurfacePath': _tongueSurface.imagePath,
        'sublingualVeinsPath': _sublingualVeins.imagePath,
        'facePath': _face.imagePath,
      },
    );

    try {
      await _httpService.uploadDiagnosisImages(
        tongueSurfacePath: _tongueSurface.imagePath,
        sublingualVeinsPath: _sublingualVeins.imagePath,
        facePath: _face.imagePath,
      );

      developer.log(
        '提交成功',
        name: 'SmzPage',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传成功,医生将进一步分析')),
        );
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      developer.log(
        '提交失败',
        name: 'SmzPage',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final double maxWidth = isLandscape ? 800 : double.infinity;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('舌面诊'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              // 头部区域
              // _buildHeader(),
              // 主要内容区域
              Expanded(
                child: SingleChildScrollView(
                  controller: _controller,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 舌部部分
                      _buildSectionTitle('舌部'),
                      const SizedBox(height: 16),
                      _buildImageUploadRow(
                        '舌面',
                        _tongueSurface,
                        () => _navigateToCamera(CameraType.tongueSurface),
                        () => _deleteImage('tongueSurface'),
                      ),
                      const SizedBox(height: 16),
                      _buildImageUploadRow(
                        '舌下脉络',
                        _sublingualVeins,
                        () => _navigateToCamera(CameraType.sublingualVeins),
                        () => _deleteImage('sublingualVeins'),
                      ),
                      const SizedBox(height: 32),
                      // 面部部分
                      _buildSectionTitle('面部'),
                      const SizedBox(height: 16),
                      _buildImageUploadRow(
                        '正面',
                        _face,
                        () => _navigateToCamera(CameraType.face),
                        () => _deleteImage('face'),
                      ),
                      const SizedBox(height: 100), // 为底部按钮留出空间
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  // 头部区域
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // 浅绿色背景
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // 左侧房子图标
          IconButton(
            icon: const Icon(Icons.home, color: Colors.grey),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
          // 中间标题和副标题
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '智能舌面诊',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '极速识别舌面异常',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // 右侧图标（舌头扫描效果）
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.green[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.face,
              size: 30,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  // 部分标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // 图片上传行
  Widget _buildImageUploadRow(
    String label,
    ImageData imageData,
    VoidCallback onTap,
    VoidCallback onDelete,
  ) {
    return Row(
      children: [
        // 左侧上传框
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: imageData.hasImage && !imageData.showExample ? null : onTap,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey[300]!,
                  style: BorderStyle.solid,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageData.hasImage && !imageData.showExample
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(imageData.imagePath!),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // 删除按钮
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 右侧：识别结果或示例图片
        Expanded(
          flex: 2,
          child: imageData.hasImage && !imageData.showExample
              ? _buildRecognitionResultOrExample(imageData, label)
              : Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        label == '舌面' || label == '舌下脉络'
                            ? Icons.face
                            : Icons.person,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '示例',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // 构建识别结果或示例图
  Widget _buildRecognitionResultOrExample(ImageData imageData, String label) {
    // 如果有识别结果且成功，显示识别结果标签
    if (imageData.recognitionResult != null &&
        imageData.recognitionResult!.success &&
        imageData.recognitionResult!.results.isNotEmpty) {
      return Container(
        height: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: imageData.recognitionResult!.results
                .map((result) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        result,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      );
    }
    // 如果识别失败或没有识别结果，显示"未识别出异常"或示例图
    if (imageData.recognitionResult != null &&
        imageData.recognitionResult!.success &&
        imageData.recognitionResult!.results.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '未识别出异常',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    // 默认显示示例图
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            label == '舌面' || label == '舌下脉络'
                ? Icons.face
                : Icons.person,
            size: 50,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          const Text(
            '示例',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // 底部确定按钮
  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSubmit
                  ? const Color(0xFF81C784) // 浅绿色
                  : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              '确定',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
