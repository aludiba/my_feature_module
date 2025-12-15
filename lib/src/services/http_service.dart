import 'dart:developer' as developer;
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
    Options? options,
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
        options: options,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 上传图片到服务器
  /// [imagePath] 本地图片路径
  /// [businessType] 业务类型，默认为 'mini_tongue'
  /// [token] 认证 token（可选）
  /// 返回图片 URL
  Future<String?> uploadImage(
    String imagePath, {
    String? businessType,
    String? token,
  }) async {
    try {
      developer.log(
        '开始上传图片',
        name: 'HttpService',
        error: {
          'imagePath': imagePath,
          'businessType': businessType,
          'hasToken': token != null,
        },
      );

      Map<String, dynamic>? extraData;
      Map<String, String>? headers;
      
      if (businessType != null) {
        extraData = {'BUSINESS-TYPE': businessType};
      }
      
      if (token != null) {
        headers = {'Authorization': 'Bearer $token'};
        if (businessType != null) {
          headers['BUSINESS-TYPE'] = businessType;
        }
      }
      
      final uploadUrl = '${_baseUrl ?? ''}/api/his-system/file/';
      developer.log(
        '上传图片请求',
        name: 'HttpService',
        error: {
          'url': uploadUrl,
          'filePath': imagePath,
          'extraData': extraData,
          'hasHeaders': headers != null,
        },
      );

      final response = await uploadFile<Map<String, dynamic>>(
        '/api/his-system/file/',
        imagePath,
        fileKey: 'file',
        data: extraData,
        options: headers != null ? Options(headers: headers) : null,
      );
      
      developer.log(
        '上传图片响应',
        name: 'HttpService',
        error: {
          'statusCode': response.statusCode,
          'responseData': response.data,
        },
      );
      
      if (response.data != null && 
          response.data!['success'] == true && 
          response.data!['data'] != null) {
        final data = response.data!['data'];
        final imageUrl = data['url'] as String?;
        developer.log(
          '上传图片成功',
          name: 'HttpService',
          error: {'imageUrl': imageUrl},
        );
        return imageUrl;
      }
      
      developer.log(
        '上传图片失败：响应数据格式错误',
        name: 'HttpService',
        error: {'responseData': response.data},
      );
      return null;
    } catch (e, stackTrace) {
      developer.log(
        '上传图片异常',
        name: 'HttpService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('上传图片失败: $e');
    }
  }

  /// 舌面诊断 2.0 拍照诊断
  /// [imageUrl] 已上传的图片 URL
  /// [type] 拍摄类型：'tf' 舌面, 'tb' 舌底, 'ff' 面部
  /// [appId] 应用 ID
  /// [appSecret] 应用密钥
  /// [authCode] 授权码
  /// [tongueApiBaseUrl] 舌诊 API 基础 URL
  Future<RecognitionResult> aiRecognizeFaceTongue2(
    String imageUrl,
    String type, {
    required String appId,
    required String appSecret,
    required String authCode,
    required String tongueApiBaseUrl,
  }) async {
    try {
      // 根据类型设置对应的字段名
      String typeKey = '';
      switch (type) {
        case 'ff':
          typeKey = 'ff_image';
          break;
        case 'tf':
          typeKey = 'tf_image';
          break;
        case 'tb':
          typeKey = 'tb_image';
          break;
        default:
          throw Exception('不支持的拍摄类型: $type');
      }

      // 构建请求参数
      final Map<String, dynamic> params = {
        'scene': 2,
        'app_id': appId,
        'app_secret': appSecret,
        'auth_code': authCode,
        typeKey: imageUrl,
      };

      final requestUrl = '$tongueApiBaseUrl/open/api/diagnose/face-tongue/result/v2.0/';
      developer.log(
        '开始调用识别接口',
        name: 'HttpService',
        error: {
          'url': requestUrl,
          'type': type,
          'typeKey': typeKey,
          'imageUrl': imageUrl,
          'appId': appId,
          'hasAppSecret': appSecret.isNotEmpty,
          'hasAuthCode': authCode.isNotEmpty,
        },
      );

      // 调用识别接口（不使用 baseUrl，使用完整的 tongueApiBaseUrl）
      final dio = Dio();
      final response = await dio.post<Map<String, dynamic>>(
        requestUrl,
        data: params,
      );

      developer.log(
        '识别接口响应',
        name: 'HttpService',
        error: {
          'statusCode': response.statusCode,
          'hasData': response.data != null,
          'responseData': response.data,
        },
      );

      if (response.data != null) {
        final data = response.data!;
        final success = data['success'] == true;
        
        if (success && data['data'] != null) {
          final resultData = data['data'] as Map<String, dynamic>;
          
          developer.log(
            '识别成功，开始解析特征',
            name: 'HttpService',
            error: {
              'hasFeatures': resultData['features'] != null,
              'featuresCount': resultData['features'] != null 
                  ? (resultData['features'] as List).length 
                  : 0,
            },
          );
          
          // 提取识别特征
          List<String> results = [];
          if (resultData['features'] != null) {
            final features = resultData['features'] as List;
            for (var feature in features) {
              if (feature is Map<String, dynamic>) {
                final featureName = feature['feature_name'] as String?;
                final featureSituation = feature['feature_situation'] as String?;
                // 只显示异常特征
                if (featureName != null && 
                    featureSituation == '异常' && 
                    featureName != '正常') {
                  results.add(featureName);
                }
              }
            }
          }
          
          // 如果没有异常特征，显示"未识别出异常"
          if (results.isEmpty) {
            results.add('未识别出异常');
          }

          developer.log(
            '识别结果解析完成',
            name: 'HttpService',
            error: {
              'results': results,
              'resultsCount': results.length,
            },
          );

          return RecognitionResult(
            success: true,
            results: results,
          );
        } else {
          // 识别失败，返回错误信息
          final msg = data['msg'] as String? ?? '识别失败';
          developer.log(
            '识别失败',
            name: 'HttpService',
            error: {
              'errorMessage': msg,
              'responseData': data,
            },
          );
          return RecognitionResult(
            success: false,
            errorMessage: msg,
          );
        }
      }
      
      developer.log(
        '识别失败：服务器返回数据格式错误',
        name: 'HttpService',
        error: {'response': response.data},
      );
      
      return RecognitionResult(
        success: false,
        errorMessage: '识别失败：服务器返回数据格式错误',
      );
    } catch (e, stackTrace) {
      developer.log(
        '识别接口调用异常',
        name: 'HttpService',
        error: e,
        stackTrace: stackTrace,
      );
      return RecognitionResult(
        success: false,
        errorMessage: '识别失败: $e',
      );
    }
  }

  /// 识别舌面照片
  Future<RecognitionResult> recognizeTongueSurface(
    String imagePath, {
    required String appId,
    required String appSecret,
    required String authCode,
    required String tongueApiBaseUrl,
    String? businessType,
  }) async {
    try {
      developer.log(
        '开始识别舌面照片',
        name: 'HttpService',
        error: {
          'imagePath': imagePath,
          'businessType': businessType,
        },
      );

      // 先上传图片
      final imageUrl = await uploadImage(imagePath, businessType: businessType);
      if (imageUrl == null) {
        developer.log(
          '识别舌面照片失败：上传图片失败',
          name: 'HttpService',
        );
        return RecognitionResult(
          success: false,
          errorMessage: '上传图片失败',
        );
      }

      // 调用识别接口
      final result = await aiRecognizeFaceTongue2(
        imageUrl,
        'tf',
        appId: appId,
        appSecret: appSecret,
        authCode: authCode,
        tongueApiBaseUrl: tongueApiBaseUrl,
      );

      developer.log(
        '识别舌面照片完成',
        name: 'HttpService',
        error: {
          'success': result.success,
          'results': result.results,
          'errorMessage': result.errorMessage,
        },
      );

      return result;
    } catch (e, stackTrace) {
      developer.log(
        '识别舌面照片异常',
        name: 'HttpService',
        error: e,
        stackTrace: stackTrace,
      );
      return RecognitionResult(
        success: false,
        errorMessage: '识别失败: $e',
      );
    }
  }

  /// 识别舌下脉络
  Future<RecognitionResult> recognizeSublingualVeins(
    String imagePath, {
    required String appId,
    required String appSecret,
    required String authCode,
    required String tongueApiBaseUrl,
    String? businessType,
  }) async {
    try {
      developer.log(
        '开始识别舌下脉络',
        name: 'HttpService',
        error: {
          'imagePath': imagePath,
          'businessType': businessType,
        },
      );

      // 先上传图片
      final imageUrl = await uploadImage(imagePath, businessType: businessType);
      if (imageUrl == null) {
        developer.log(
          '识别舌下脉络失败：上传图片失败',
          name: 'HttpService',
        );
        return RecognitionResult(
          success: false,
          errorMessage: '上传图片失败',
        );
      }

      // 调用识别接口
      final result = await aiRecognizeFaceTongue2(
        imageUrl,
        'tb',
        appId: appId,
        appSecret: appSecret,
        authCode: authCode,
        tongueApiBaseUrl: tongueApiBaseUrl,
      );

      developer.log(
        '识别舌下脉络完成',
        name: 'HttpService',
        error: {
          'success': result.success,
          'results': result.results,
          'errorMessage': result.errorMessage,
        },
      );

      return result;
    } catch (e, stackTrace) {
      developer.log(
        '识别舌下脉络异常',
        name: 'HttpService',
        error: e,
        stackTrace: stackTrace,
      );
      return RecognitionResult(
        success: false,
        errorMessage: '识别失败: $e',
      );
    }
  }

  /// 识别面部照片
  Future<RecognitionResult> recognizeFace(
    String imagePath, {
    required String appId,
    required String appSecret,
    required String authCode,
    required String tongueApiBaseUrl,
    String? businessType,
  }) async {
    try {
      developer.log(
        '开始识别面部照片',
        name: 'HttpService',
        error: {
          'imagePath': imagePath,
          'businessType': businessType,
        },
      );

      // 先上传图片
      final imageUrl = await uploadImage(imagePath, businessType: businessType);
      if (imageUrl == null) {
        developer.log(
          '识别面部照片失败：上传图片失败',
          name: 'HttpService',
        );
        return RecognitionResult(
          success: false,
          errorMessage: '上传图片失败',
        );
      }

      // 调用识别接口
      final result = await aiRecognizeFaceTongue2(
        imageUrl,
        'ff',
        appId: appId,
        appSecret: appSecret,
        authCode: authCode,
        tongueApiBaseUrl: tongueApiBaseUrl,
      );

      developer.log(
        '识别面部照片完成',
        name: 'HttpService',
        error: {
          'success': result.success,
          'results': result.results,
          'errorMessage': result.errorMessage,
        },
      );

      return result;
    } catch (e, stackTrace) {
      developer.log(
        '识别面部照片异常',
        name: 'HttpService',
        error: e,
        stackTrace: stackTrace,
      );
      return RecognitionResult(
        success: false,
        errorMessage: '识别失败: $e',
      );
    }
  }

  /// 上传问诊照片
  Future<void> uploadDiagnosisImages({
    String? tongueSurfacePath,
    String? sublingualVeinsPath,
    String? facePath,
  }) async {
    developer.log(
      '上传问诊照片',
      name: 'HttpService',
      error: {
        'tongueSurfacePath': tongueSurfacePath,
        'sublingualVeinsPath': sublingualVeinsPath,
        'facePath': facePath,
      },
    );
    await Future.delayed(const Duration(seconds: 1));
  }

  /// 错误处理
  dynamic _handleError(dynamic error) {
    if (error is DioException) {
      developer.log(
        'HTTP请求错误',
        name: 'HttpService',
        error: {
          'type': error.type.toString(),
          'message': error.message,
          'statusCode': error.response?.statusCode,
          'responseData': error.response?.data,
        },
      );
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
    developer.log(
      '未知错误',
      name: 'HttpService',
      error: error,
    );
    return error;
  }
}

