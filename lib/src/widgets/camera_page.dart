import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 拍照类型
enum CameraType {
  tongueSurface, // 舌面
  sublingualVeins, // 舌下脉络
  face, // 面部
}

/// 拍照页面
class CameraPage extends StatefulWidget {
  final CameraType type;
  final Function(String imagePath, Map<String, dynamic>? recognitionResult)? onPhotoTaken;

  const CameraPage({
    super.key,
    required this.type,
    this.onPhotoTaken,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  XFile? _capturedImage;
  Map<String, dynamic>? _recognitionResult;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到相机设备')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // 使用后置摄像头
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机初始化失败: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!_isInitialized || _controller == null || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();
      
      // 保存到临时目录
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(tempDir.path, fileName);
      final File imageFile = File(image.path);
      await imageFile.copy(filePath);

      setState(() {
        _capturedImage = XFile(filePath);
      });

      // 模拟识别结果（实际应该调用识别接口）
      await _simulateRecognition();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _simulateRecognition() async {
    // TODO: 调用实际的识别接口
    await Future.delayed(const Duration(seconds: 1));
    
    // 模拟识别结果（随机成功/失败，用于测试）
    final random = DateTime.now().millisecond % 3;
    
    if (random == 0) {
      // 模拟识别失败
      switch (widget.type) {
        case CameraType.tongueSurface:
          _recognitionResult = {
            'success': false,
            'errorMessage': '未检测到图片中西部区域',
          };
          break;
        case CameraType.sublingualVeins:
          _recognitionResult = {
            'success': false,
            'errorMessage': '舌下络脉目标检测失败',
          };
          break;
        case CameraType.face:
          _recognitionResult = {
            'success': false,
            'errorMessage': '未检测到图片中面部区域',
          };
          break;
      }
    } else {
      // 模拟识别成功
      switch (widget.type) {
        case CameraType.tongueSurface:
          _recognitionResult = {
            'success': true,
            'results': ['舌色红', '舌苔黄'],
          };
          break;
        case CameraType.sublingualVeins:
          _recognitionResult = {
            'success': true,
            'results': ['未识别出异常'],
          };
          break;
        case CameraType.face:
          _recognitionResult = {
            'success': true,
            'results': ['面色黄', '唇紫'],
          };
          break;
      }
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  void _confirmPhoto() {
    if (_capturedImage != null && widget.onPhotoTaken != null) {
      widget.onPhotoTaken!(_capturedImage!.path, _recognitionResult);
      Navigator.of(context).pop();
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _recognitionResult = null;
    });
  }

  String _getTitle() {
    switch (widget.type) {
      case CameraType.tongueSurface:
        return '拍摄舌面照片';
      case CameraType.sublingualVeins:
        return '拍摄舌底照片';
      case CameraType.face:
        return '拍摄面部照片';
    }
  }

  String _getInstructions() {
    switch (widget.type) {
      case CameraType.tongueSurface:
        return '保证光线充足, 不反光\n舌头无异色、异物, 舌面伸展';
      case CameraType.sublingualVeins:
        return '保证光线充足、不反光\n嘴巴张开, 舌尖顶住上颚';
      case CameraType.face:
        return '保证光线充足、不反光\n正脸、素颜、去掉眼镜等遮挡';
    }
  }

  String _getGuideText() {
    switch (widget.type) {
      case CameraType.tongueSurface:
        return '将舌头完整放入框内拍摄';
      case CameraType.sublingualVeins:
        return '将舌下脉络完整放入框内拍摄';
      case CameraType.face:
        return '将脸部完整放入框内拍摄';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C), // 深灰色背景
      body: SafeArea(
        child: _capturedImage == null 
            ? _buildCameraView() 
            : (_recognitionResult != null && _recognitionResult!['success'] == false
                ? _buildFailureView()
                : _buildPreviewView()),
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // 相机预览
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),
        // 遮罩层和引导框
        Positioned.fill(
          child: CustomPaint(
            painter: CameraOverlayPainter(widget.type),
          ),
        ),
        // 顶部导航栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        // 说明文字
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Text(
              _getInstructions(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // 底部引导文字
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              _getGuideText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // 左下角缩略图
        Positioned(
          bottom: 140,
          left: 16,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              widget.type == CameraType.face 
                  ? Icons.person 
                  : Icons.face,
              color: Colors.white70,
              size: 30,
            ),
          ),
        ),
        // 底部控制按钮
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
                  onPressed: () {},
                ),
                GestureDetector(
                  onTap: _isCapturing ? null : _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!, width: 4),
                    ),
                    child: _isCapturing
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.grey,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.photo_library, color: Colors.white, size: 30),
                  onPressed: () async {
                    // TODO: 从相册选择
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailureView() {
    return Stack(
      children: [
        // 背景图片（拍摄的图片）
        Positioned.fill(
          child: Image.file(
            File(_capturedImage!.path),
            fit: BoxFit.cover,
          ),
        ),
        // 顶部导航栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        // 说明文字
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Text(
              _getInstructions(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // 错误信息卡片
        Positioned(
          top: 140,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '识别失败',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _recognitionResult = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 相机预览区域（显示拍摄的图片）
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(_capturedImage!.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 错误提示
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _recognitionResult!['errorMessage'] ?? '识别失败',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 引导文字和示例图片
        Positioned(
          bottom: 120,
          left: 16,
          right: 16,
          child: Column(
            children: [
              const Text(
                '请参照下图正确的方式重新拍摄',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // 示例图片对比
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildExampleImages(),
              ),
            ],
          ),
        ),
        // 底部重新拍摄按钮
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _retakePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  '重新拍摄',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildExampleImages() {
    List<Map<String, dynamic>> examples = [];
    
    switch (widget.type) {
      case CameraType.tongueSurface:
        examples = [
          {'label': '正确', 'icon': Icons.check_circle, 'color': Colors.green},
          {'label': '太大', 'icon': Icons.zoom_in, 'color': Colors.orange},
          {'label': '太小', 'icon': Icons.zoom_out, 'color': Colors.orange},
          {'label': '看不全', 'icon': Icons.visibility_off, 'color': Colors.red},
        ];
        break;
      case CameraType.sublingualVeins:
        examples = [
          {'label': '正确', 'icon': Icons.check_circle, 'color': Colors.green},
          {'label': '太偏', 'icon': Icons.swap_horiz, 'color': Colors.orange},
          {'label': '太小', 'icon': Icons.zoom_out, 'color': Colors.orange},
          {'label': '看不全', 'icon': Icons.visibility_off, 'color': Colors.red},
        ];
        break;
      case CameraType.face:
        examples = [
          {'label': '正确', 'icon': Icons.check_circle, 'color': Colors.green},
          {'label': '太大', 'icon': Icons.zoom_in, 'color': Colors.orange},
          {'label': '太小', 'icon': Icons.zoom_out, 'color': Colors.orange},
          {'label': '不正脸', 'icon': Icons.swap_horiz, 'color': Colors.red},
        ];
        break;
    }

    return examples.map((example) {
      return Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: example['color'] as Color,
                width: 2,
              ),
            ),
            child: Icon(
              example['icon'] as IconData,
              color: example['color'] as Color,
              size: 30,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            example['label'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildPreviewView() {
    return Stack(
      children: [
        // 背景（深灰色）
        Positioned.fill(
          child: Container(
            color: const Color(0xFF2C2C2C),
          ),
        ),
        // 顶部导航栏
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        // 说明文字
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Text(
              _getInstructions(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // 拍摄的图片（带蓝色边框）
        Positioned(
          top: 140,
          left: 16,
          right: 16,
          bottom: 200,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        // 识别结果卡片
        if (_recognitionResult != null && _recognitionResult!['success'] == true)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '识别结果',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _recognitionResult = null;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(_recognitionResult!['results'] as List)
                      .map((result) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              result.toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          )),
                ],
              ),
            ),
          ),
        // 底部按钮
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _retakePhoto,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text('重新拍摄'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmPhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text('下一步'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 相机遮罩绘制器
class CameraOverlayPainter extends CustomPainter {
  final CameraType type;

  CameraOverlayPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // 绘制遮罩
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 绘制引导框
    final guidePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 根据类型绘制不同的引导框
    switch (type) {
      case CameraType.tongueSurface:
        // 舌面：大U形（张开的嘴巴，舌头伸展）
        _drawTongueSurfaceGuide(canvas, centerX, centerY, size, guidePaint);
        break;
      case CameraType.sublingualVeins:
        // 舌下脉络：小弧形（嘴巴张开，舌尖顶住上颚）
        _drawSublingualVeinsGuide(canvas, centerX, centerY, size, guidePaint);
        break;
      case CameraType.face:
        // 面部：人脸轮廓
        _drawFaceGuide(canvas, centerX, centerY, size, guidePaint);
        break;
    }
  }

  // 绘制舌面引导框（大U形）
  void _drawTongueSurfaceGuide(
    Canvas canvas,
    double centerX,
    double centerY,
    Size size,
    Paint paint,
  ) {
    final width = size.width * 0.6;
    final height = size.height * 0.35;
    
    // 绘制嘴巴外轮廓（椭圆形）
    final mouthRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height * 0.6,
    );
    
    // 清除嘴巴区域
    canvas.drawOval(mouthRect, Paint()..blendMode = BlendMode.clear);
    
    // 绘制嘴巴边框
    canvas.drawOval(mouthRect, paint);
    
    // 绘制舌头轮廓（大U形）
    final tonguePath = Path();
    final tongueWidth = width * 0.7;
    final tongueHeight = height * 0.8;
    final tongueTop = centerY - height * 0.1;
    final tongueLeft = centerX - tongueWidth / 2;
    final tongueRight = centerX + tongueWidth / 2;
    final tongueBottom = centerY + tongueHeight * 0.5;
    
    tonguePath.moveTo(tongueLeft, tongueTop);
    tonguePath.quadraticBezierTo(
      tongueLeft,
      tongueBottom,
      centerX,
      tongueBottom,
    );
    tonguePath.quadraticBezierTo(
      tongueRight,
      tongueBottom,
      tongueRight,
      tongueTop,
    );
    tonguePath.close();
    
    // 清除舌头区域
    canvas.drawPath(tonguePath, Paint()..blendMode = BlendMode.clear);
    
    // 绘制舌头边框
    canvas.drawPath(tonguePath, paint);
  }

  // 绘制舌下脉络引导框（小弧形）
  void _drawSublingualVeinsGuide(
    Canvas canvas,
    double centerX,
    double centerY,
    Size size,
    Paint paint,
  ) {
    final width = size.width * 0.5;
    final height = size.height * 0.25;
    
    // 绘制嘴巴外轮廓
    final mouthRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height * 0.7,
    );
    
    // 清除嘴巴区域
    canvas.drawOval(mouthRect, Paint()..blendMode = BlendMode.clear);
    
    // 绘制嘴巴边框
    canvas.drawOval(mouthRect, paint);
    
    // 绘制舌下脉络轮廓（小弧形，中间有垂直线表示舌系带）
    final veinPath = Path();
    final veinWidth = width * 0.5;
    final veinHeight = height * 0.6;
    final veinTop = centerY - height * 0.15;
    final veinLeft = centerX - veinWidth / 2;
    final veinRight = centerX + veinWidth / 2;
    final veinBottom = centerY + veinHeight * 0.3;
    
    // 绘制弧形
    veinPath.moveTo(veinLeft, veinTop);
    veinPath.quadraticBezierTo(
      centerX,
      veinBottom,
      veinRight,
      veinTop,
    );
    
    // 清除舌下区域
    canvas.drawPath(veinPath, Paint()..blendMode = BlendMode.clear);
    
    // 绘制舌下边框
    canvas.drawPath(veinPath, paint);
    
    // 绘制中间的垂直线（舌系带）
    canvas.drawLine(
      Offset(centerX, veinTop),
      Offset(centerX, veinBottom),
      paint,
    );
  }

  // 绘制面部引导框（人脸轮廓）
  void _drawFaceGuide(
    Canvas canvas,
    double centerX,
    double centerY,
    Size size,
    Paint paint,
  ) {
    final width = size.width * 0.7;
    final height = size.height * 0.5;
    
    // 绘制人脸轮廓（椭圆形）
    final faceRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );
    
    // 清除人脸区域
    canvas.drawOval(faceRect, Paint()..blendMode = BlendMode.clear);
    
    // 绘制人脸边框
    canvas.drawOval(faceRect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

