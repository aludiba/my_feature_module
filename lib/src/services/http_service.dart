import 'package:dio/dio.dart';
import 'package:my_feature_module/src/models/recognition_result.dart';

/// HTTP 服务封装类
class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  late Dio _dio;
  String? _baseUrl;

  /// 初始化
  void init({
    String? baseUrl,
    Map<String, dynamic>? headers,
    int? connectTimeout,
    int? receiveTimeout,
  }) {
    _baseUrl = baseUrl;
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        headers: headers ?? {},
        connectTimeout: Duration(milliseconds: connectTimeout ?? 30000),
        receiveTimeout: Duration(milliseconds: receiveTimeout ?? 30000),
      ),
    );

    // 添加拦截器
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST 请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 上传文件
  Future<Response<T>> uploadFile<T>(
    String path,
    String filePath, {
    String fileKey = 'file',
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        fileKey: await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
        if (data != null) ...data,
      });

      return await _dio.post<T>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 识别舌面照片
  /// TODO: 实现实际的识别接口调用
  Future<RecognitionResult> recognizeTongueSurface(String imagePath) async {
    // TODO: 调用实际的识别接口
    // final response = await uploadFile('/api/recognize/tongue-surface', imagePath);
    // return RecognitionResult.fromJson(response.data);
    
    // 模拟识别结果
    await Future.delayed(const Duration(seconds: 1));
    return RecognitionResult(
      success: true,
      results: ['舌色红', '舌苔黄'],
    );
  }

  /// 识别舌下脉络
  /// TODO: 实现实际的识别接口调用
  Future<RecognitionResult> recognizeSublingualVeins(String imagePath) async {
    // TODO: 调用实际的识别接口
    // final response = await uploadFile('/api/recognize/sublingual-veins', imagePath);
    // return RecognitionResult.fromJson(response.data);
    
    // 模拟识别结果
    await Future.delayed(const Duration(seconds: 1));
    return RecognitionResult(
      success: true,
      results: ['未识别出异常'],
    );
  }

  /// 识别面部照片
  /// TODO: 实现实际的识别接口调用
  Future<RecognitionResult> recognizeFace(String imagePath) async {
    // TODO: 调用实际的识别接口
    // final response = await uploadFile('/api/recognize/face', imagePath);
    // return RecognitionResult.fromJson(response.data);
    
    // 模拟识别结果
    await Future.delayed(const Duration(seconds: 1));
    return RecognitionResult(
      success: true,
      results: ['面色黄', '唇紫'],
    );
  }

  /// 上传问诊照片
  /// TODO: 实现实际上传接口调用
  Future<void> uploadDiagnosisImages({
    String? tongueSurfacePath,
    String? sublingualVeinsPath,
    String? facePath,
  }) async {
    // TODO: 实现实际上传接口
    // final formData = FormData.fromMap({
    //   if (tongueSurfacePath != null)
    //     'tongue_surface': await MultipartFile.fromFile(tongueSurfacePath),
    //   if (sublingualVeinsPath != null)
    //     'sublingual_veins': await MultipartFile.fromFile(sublingualVeinsPath),
    //   if (facePath != null)
    //     'face': await MultipartFile.fromFile(facePath),
    // });
    // await post('/api/diagnosis/upload', data: formData);
    
    // 模拟上传
    await Future.delayed(const Duration(seconds: 1));
  }

  /// 错误处理
  dynamic _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return Exception('请求超时，请检查网络连接');
        case DioExceptionType.badResponse:
          return Exception('服务器错误：${error.response?.statusCode}');
        case DioExceptionType.cancel:
          return Exception('请求已取消');
        default:
          return Exception('网络错误：${error.message}');
      }
    }
    return error;
  }
}

