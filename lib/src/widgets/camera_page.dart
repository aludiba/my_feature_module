import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
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
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  XFile? _capturedImage;
  Map<String, dynamic>? _recognitionResult;
  final ImagePicker _imagePicker = ImagePicker();

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

      // 默认使用前置摄像头
      _currentCameraIndex = _cameras!.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      // 如果找不到前置摄像头，使用第一个摄像头
      if (_currentCameraIndex == -1) {
        _currentCameraIndex = 0;
      }

      await _switchCamera(_currentCameraIndex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机初始化失败: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _switchCamera(int cameraIndex) async {
    if (_cameras == null || cameraIndex < 0 || cameraIndex >= _cameras!.length) {
      return;
    }

    // 先释放旧的控制器
    await _controller?.dispose();

    setState(() {
      _isInitialized = false;
    });

    try {
      _controller = CameraController(
        _cameras![cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _currentCameraIndex = cameraIndex;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换摄像头失败: $e')),
        );
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设备只有一个摄像头')),
      );
      return;
    }

    // 切换到另一个摄像头
    int nextIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _switchCamera(nextIndex);
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        // 从相册选择的图片不进行裁剪，原样保存
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e')),
        );
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
      
      // 裁剪图片，只保留引导框内的部分
      final String croppedImagePath = await _cropImageToGuideBox(image.path);
      
      setState(() {
        _capturedImage = XFile(croppedImagePath);
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

  /// 裁剪图片到引导框区域
  Future<String> _cropImageToGuideBox(String imagePath) async {
    try {
      // 读取原始图片
      final Uint8List imageBytes = await File(imagePath).readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        throw Exception('无法解码图片');
      }

      // 获取相机预览尺寸和实际图片尺寸
      final Size previewSize = _controller!.value.previewSize ?? Size.zero;
      final int imageWidth = originalImage.width;
      final int imageHeight = originalImage.height;

      // 计算引导框在屏幕上的位置和大小
      final Rect guideRect = _getGuideBoxRect(previewSize);

      // 将屏幕坐标转换为图片坐标
      final double scaleX = imageWidth / previewSize.width;
      final double scaleY = imageHeight / previewSize.height;
      
      // 计算裁剪区域（使用较小的缩放比例以确保不超出图片范围）
      final double scale = scaleX < scaleY ? scaleX : scaleY;
      final int cropX = ((guideRect.left) * scale).round();
      final int cropY = ((guideRect.top) * scale).round();
      final int cropWidth = (guideRect.width * scale).round();
      final int cropHeight = (guideRect.height * scale).round();

      // 确保裁剪区域在图片范围内
      final int safeX = cropX.clamp(0, imageWidth);
      final int safeY = cropY.clamp(0, imageHeight);
      final int safeWidth = (cropX + cropWidth).clamp(0, imageWidth) - safeX;
      final int safeHeight = (cropY + cropHeight).clamp(0, imageHeight) - safeY;

      // 裁剪图片
      final img.Image croppedImage = img.copyCrop(
        originalImage,
        x: safeX,
        y: safeY,
        width: safeWidth,
        height: safeHeight,
      );

      // 保存裁剪后的图片
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_cropped.jpg';
      final String filePath = path.join(tempDir.path, fileName);
      final File croppedFile = File(filePath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));

      return filePath;
    } catch (e) {
      // 如果裁剪失败，返回原图片路径
      return imagePath;
    }
  }

  /// 从相册选择图片后裁剪
  Future<String> _cropImageFromGallery(String imagePath, Size previewSize) async {
    try {
      // 读取原始图片
      final Uint8List imageBytes = await File(imagePath).readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        throw Exception('无法解码图片');
      }

      // 获取实际图片尺寸
      final int imageWidth = originalImage.width;
      final int imageHeight = originalImage.height;

      // 计算引导框在屏幕上的位置和大小
      final Rect guideRect = _getGuideBoxRect(previewSize);

      // 将屏幕坐标转换为图片坐标
      // 对于相册图片，我们需要根据图片的实际尺寸和预览尺寸的比例来计算
      final double scaleX = imageWidth / previewSize.width;
      final double scaleY = imageHeight / previewSize.height;
      
      // 使用较小的缩放比例以确保不超出图片范围
      final double scale = scaleX < scaleY ? scaleX : scaleY;
      final int cropX = ((guideRect.left) * scale).round();
      final int cropY = ((guideRect.top) * scale).round();
      final int cropWidth = (guideRect.width * scale).round();
      final int cropHeight = (guideRect.height * scale).round();

      // 确保裁剪区域在图片范围内
      final int safeX = cropX.clamp(0, imageWidth);
      final int safeY = cropY.clamp(0, imageHeight);
      final int safeWidth = (cropX + cropWidth).clamp(0, imageWidth) - safeX;
      final int safeHeight = (cropY + cropHeight).clamp(0, imageHeight) - safeY;

      // 裁剪图片
      final img.Image croppedImage = img.copyCrop(
        originalImage,
        x: safeX,
        y: safeY,
        width: safeWidth,
        height: safeHeight,
      );

      // 保存裁剪后的图片
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_cropped.jpg';
      final String filePath = path.join(tempDir.path, fileName);
      final File croppedFile = File(filePath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));

      return filePath;
    } catch (e) {
      // 如果裁剪失败，返回原图片路径
      return imagePath;
    }
  }

  /// 获取引导框在屏幕上的矩形区域
  Rect _getGuideBoxRect(Size screenSize) {
    final double centerX = screenSize.width / 2;
    final double centerY = screenSize.height / 2;
    
    // 判断是否为横屏/平板（宽高比大于1）
    final bool isLandscape = screenSize.width > screenSize.height;
    final double aspectRatio = screenSize.width / screenSize.height;

    switch (widget.type) {
      case CameraType.tongueSurface:
        // 舌面：嘴巴外轮廓 + 舌头轮廓的边界框
        double width, height;
        if (isLandscape) {
          // 横屏时，使用高度作为基准
          height = screenSize.height * 0.4;
          width = height * 0.8; // 保持比例
        } else {
          width = screenSize.width * 0.6;
          height = screenSize.height * 0.35;
        }
        final double mouthHeight = height * 0.6;
        final double tongueHeight = height * 0.8;
        final double tongueBottom = centerY + tongueHeight * 0.5;
        final double top = centerY - height * 0.1;
        final double bottom = tongueBottom;
        return Rect.fromLTWH(
          centerX - width / 2,
          top,
          width,
          bottom - top,
        );
      case CameraType.sublingualVeins:
        // 舌下脉络：嘴巴外轮廓的边界框
        double width, height;
        if (isLandscape) {
          height = screenSize.height * 0.3;
          width = height * 0.7;
        } else {
          width = screenSize.width * 0.5;
          height = screenSize.height * 0.25;
        }
        final double mouthHeight = height * 0.7;
        return Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: width,
          height: mouthHeight,
        );
      case CameraType.face:
        // 面部：人脸轮廓的边界框
        double width, height;
        if (isLandscape) {
          // 横屏时，使用高度作为基准，保持人脸比例
          height = screenSize.height * 0.6;
          width = height * 0.75; // 人脸通常比身高稍宽
        } else {
          width = screenSize.width * 0.7;
          height = screenSize.height * 0.5;
        }
        return Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: width,
          height: height,
        );
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
            'errorMessage': '未检测到图片中舌部区域',
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
        // 底部引导文字（根据拍摄类型调整位置，避免与引导框重叠）
        Positioned(
          bottom: widget.type == CameraType.face ? 180 : 140,
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
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
                  onPressed: _isInitialized ? _toggleCamera : null,
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
                  onPressed: _pickImageFromGallery,
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
        // 错误信息卡片
        Positioned(
          top: 120,
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
                    GestureDetector(
                      onTap: _retakePhoto,
                      child: const Icon(Icons.close, size: 20, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 相机预览区域（显示拍摄的图片，带蓝色边框）
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4FC3F7),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4FC3F7).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(_capturedImage!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      // 错误信息横幅（在图片底部）
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[900]!.withOpacity(0.8),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(6),
                              bottomRight: Radius.circular(6),
                            ),
                          ),
                          child: Text(
                            _recognitionResult!['errorMessage'] ?? '识别失败',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 引导文字和示例图片
        Positioned(
          bottom: 100,
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
                  backgroundColor: const Color(0xFF4FC3F7),
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
          {'label': '太偏', 'icon': Icons.swap_horiz, 'color': Colors.orange},
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
          {'label': '太偏', 'icon': Icons.swap_horiz, 'color': Colors.orange},
          {'label': '太小', 'icon': Icons.zoom_out, 'color': Colors.orange},
          {'label': '非正面', 'icon': Icons.swap_horiz, 'color': Colors.red},
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
        // 识别结果卡片（带关闭按钮）
        if (_recognitionResult != null && _recognitionResult!['success'] == true)
          Positioned(
            top: 120,
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
                      GestureDetector(
                        onTap: _retakePhoto,
                        child: const Icon(Icons.close, size: 20, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 拍摄的图片（带蓝色发光边框）
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4FC3F7),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4FC3F7).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(_capturedImage!.path),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 识别结果标签
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_recognitionResult!['results'] as List)
                        .map((result) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                result.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
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
                      backgroundColor: const Color(0xFF4FC3F7),
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
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 创建遮罩路径（整个屏幕）
    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 根据类型创建引导框路径（需要排除的区域）
    Path guidePath;
    switch (type) {
      case CameraType.tongueSurface:
        guidePath = _getTongueSurfacePath(centerX, centerY, size);
        break;
      case CameraType.sublingualVeins:
        guidePath = _getSublingualVeinsPath(centerX, centerY, size);
        break;
      case CameraType.face:
        guidePath = _getFacePath(centerX, centerY, size);
        break;
    }

    // 从遮罩路径中排除引导框路径（使用 PathOperation.difference）
    final finalPath = Path.combine(
      PathOperation.difference,
      maskPath,
      guidePath,
    );

    // 绘制半透明遮罩（排除引导框区域）
    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(finalPath, maskPaint);

    // 绘制引导框边框
    final guidePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(guidePath, guidePaint);

    // 对于舌下脉络，需要绘制中间的垂直线（舌系带）
    if (type == CameraType.sublingualVeins) {
      final bool isLandscape = size.width > size.height;
      final double width = isLandscape
          ? size.height * 0.3 * 0.7
          : size.width * 0.5;
      final double height = isLandscape
          ? size.height * 0.3
          : size.height * 0.25;
      final double veinHeight = height * 0.6;
      final double veinTop = centerY - height * 0.15;
      final double veinBottom = centerY + veinHeight * 0.3;
      
      canvas.drawLine(
        Offset(centerX, veinTop),
        Offset(centerX, veinBottom),
        guidePaint,
      );
    }
  }

  // 获取舌面引导框路径
  Path _getTongueSurfacePath(double centerX, double centerY, Size size) {
    final bool isLandscape = size.width > size.height;
    final double width = isLandscape 
        ? size.height * 0.4 * 0.8  // 横屏时使用高度作为基准
        : size.width * 0.6;
    final double height = isLandscape
        ? size.height * 0.4
        : size.height * 0.35;
    
    // 创建嘴巴外轮廓路径（椭圆形）
    final mouthPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: width,
        height: height * 0.6,
      ));
    
    // 创建舌头轮廓路径（大U形）
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
    
    // 合并嘴巴和舌头路径
    return Path.combine(PathOperation.union, mouthPath, tonguePath);
  }

  // 获取舌下脉络引导框路径
  Path _getSublingualVeinsPath(double centerX, double centerY, Size size) {
    final bool isLandscape = size.width > size.height;
    final double width = isLandscape
        ? size.height * 0.3 * 0.7  // 横屏时使用高度作为基准
        : size.width * 0.5;
    final double height = isLandscape
        ? size.height * 0.3
        : size.height * 0.25;
    
    // 创建嘴巴外轮廓路径
    final mouthPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: width,
        height: height * 0.7,
      ));
    
    // 创建舌下脉络轮廓路径（小弧形）
    final veinPath = Path();
    final veinWidth = width * 0.5;
    final veinHeight = height * 0.6;
    final veinTop = centerY - height * 0.15;
    final veinLeft = centerX - veinWidth / 2;
    final veinRight = centerX + veinWidth / 2;
    final veinBottom = centerY + veinHeight * 0.3;
    
    veinPath.moveTo(veinLeft, veinTop);
    veinPath.quadraticBezierTo(
      centerX,
      veinBottom,
      veinRight,
      veinTop,
    );
    veinPath.close();
    
    // 合并嘴巴和舌下路径
    return Path.combine(PathOperation.union, mouthPath, veinPath);
  }

  // 获取面部引导框路径
  Path _getFacePath(double centerX, double centerY, Size size) {
    final bool isLandscape = size.width > size.height;
    final double width = isLandscape
        ? size.height * 0.6 * 0.75  // 横屏时使用高度作为基准，保持人脸比例
        : size.width * 0.7;
    final double height = isLandscape
        ? size.height * 0.6
        : size.height * 0.5;
    
    // 创建人脸轮廓路径（椭圆形）
    return Path()
      ..addOval(Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: width,
        height: height,
      ));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

