import 'dart:convert';
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
  /// [token] 认证 token（可选，但通常需要）
  /// [uploadBaseUrl] 上传接口的基础 URL（可选，如果不提供则使用 _baseUrl）
  /// 注意：根据小程序代码，上传接口路径是 /api/his-system/file/
  /// 返回图片 URL
  Future<String?> uploadImage(
    String imagePath, {
    String? businessType,
    String? token,
    String? uploadBaseUrl,
  }) async {
    try {
      developer.log(
        '开始上传图片',
        name: 'HttpService',
        error: {
          'imagePath': imagePath,
          'businessType': businessType,
          'hasToken': token != null,
          'uploadBaseUrl': uploadBaseUrl,
          'baseUrl': _baseUrl,
        },
      );

      // 构建请求头 - BUSINESS-TYPE 应该放在请求头中，而不是 FormData
      Map<String, String> headers = {};
      
      if (businessType != null) {
        headers['BUSINESS-TYPE'] = businessType;
      }
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      // 确定上传接口的完整 URL
      // 上传接口路径是 /api/his-system/file/
      // 注意：不同于识别接口的服务器
      // 如果 uploadBaseUrl 未提供，尝试使用 _baseUrl，如果都没有则使用 tongueApiBaseUrl
      final String finalBaseUrl = uploadBaseUrl ?? _baseUrl ?? '';
      
      // 上传接口路径
      String uploadPath = '/api/his-system/file/';
      
      // 如果 finalBaseUrl 为空，说明没有配置上传接口的 baseUrl
      if (finalBaseUrl.isEmpty) {
        developer.log(
          '警告：上传接口 baseUrl 未配置',
          name: 'HttpService',
          error: {
            'uploadBaseUrl': uploadBaseUrl,
            '_baseUrl': _baseUrl,
          },
        );
      }
      
      developer.log(
        '上传图片请求',
        name: 'HttpService',
        error: {
          'baseUrl': finalBaseUrl,
          'uploadPath': uploadPath,
          'fullUrl': '$finalBaseUrl$uploadPath',
          'filePath': imagePath,
          'headers': headers,
          'hasToken': token != null && token.isNotEmpty,
        },
      );

      // 如果提供了 uploadBaseUrl，使用新的 Dio 实例；否则使用现有的 _dio
      Dio dioToUse;
      if (uploadBaseUrl != null && uploadBaseUrl != _baseUrl) {
        dioToUse = Dio(BaseOptions(
          baseUrl: uploadBaseUrl,
          connectTimeout: const Duration(milliseconds: 60000), // 增加超时时间
          receiveTimeout: const Duration(milliseconds: 60000),
          sendTimeout: const Duration(milliseconds: 60000),
          headers: {
            'Accept': 'application/json',
          },
        ));
        dioToUse.interceptors.add(LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: true,
        ));
      } else {
        dioToUse = _dio;
      }

      String fileName = imagePath.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imagePath,
          filename: fileName,
        ),
      });

      final response = await dioToUse.post(
        uploadPath,
        data: formData,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (status) => status! < 500, // 允许 4xx 状态码，以便获取错误信息
        ),
      );
      
      developer.log(
        '上传图片响应',
        name: 'HttpService',
        error: {
          'statusCode': response.statusCode,
          'responseType': response.data.runtimeType.toString(),
          'responseData': response.data is String 
              ? (response.data as String).substring(0, (response.data as String).length > 200 ? 200 : (response.data as String).length)
              : response.data,
        },
      );
      
      // 检查状态码
      if (response.statusCode == 404) {
        developer.log(
          '上传接口不存在（404），请检查接口路径',
          name: 'HttpService',
          error: {
            'uploadPath': uploadPath,
            'baseUrl': finalBaseUrl,
            'fullUrl': '$finalBaseUrl$uploadPath',
          },
        );
        throw Exception('上传接口不存在（404），请检查接口路径配置');
      }
      
      if (response.statusCode != null && response.statusCode! >= 400) {
        developer.log(
          '上传失败：服务器返回错误状态码',
          name: 'HttpService',
          error: {
            'statusCode': response.statusCode,
            'responseData': response.data,
          },
        );
        throw Exception('上传失败：服务器错误 ${response.statusCode}');
      }
      
      // 处理响应数据：可能是 String 或 Map
      Map<String, dynamic>? responseData;
      if (response.data is String) {
        final String jsonString = response.data as String;
        // 如果是 HTML（通常是错误页面），跳过解析
        if (jsonString.trim().startsWith('<!DOCTYPE') || jsonString.trim().startsWith('<html')) {
          developer.log(
            '服务器返回 HTML 页面（可能是错误页面）',
            name: 'HttpService',
            error: {'statusCode': response.statusCode},
          );
          throw Exception('上传失败：服务器返回错误页面（${response.statusCode}）');
        }
        
        try {
          if (jsonString.trim().isNotEmpty) {
            responseData = jsonDecode(jsonString) as Map<String, dynamic>?;
            developer.log(
              '成功解析 JSON 字符串',
              name: 'HttpService',
              error: {'responseData': responseData},
            );
          }
        } catch (e) {
          developer.log(
            '解析 JSON 字符串失败',
            name: 'HttpService',
            error: {'error': e, 'jsonString': jsonString.substring(0, jsonString.length > 100 ? 100 : jsonString.length)},
          );
          throw Exception('上传失败：服务器响应格式错误');
        }
      } else if (response.data is Map) {
        responseData = response.data as Map<String, dynamic>?;
      }
      
      if (responseData != null && 
          responseData['success'] == true && 
          responseData['data'] != null) {
        final data = responseData['data'] as Map<String, dynamic>;
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
        error: {'responseData': responseData ?? response.data},
      );
      return null;
    } catch (e, stackTrace) {
      developer.log(
        '上传图片异常',
        name: 'HttpService',
        error: e,
        stackTrace: stackTrace,
      );
      
      // 如果是 DioException，提供更详细的错误信息
      if (e is DioException) {
        String errorMsg = '上传图片失败';
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMsg = '连接超时，请检查网络';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMsg = '接收超时，请稍后重试';
        } else if (e.type == DioExceptionType.sendTimeout) {
          errorMsg = '发送超时，请检查网络';
        } else if (e.response != null) {
          errorMsg = '服务器错误: ${e.response?.statusCode}';
          if (e.response?.data != null) {
            developer.log(
              '服务器响应错误',
              name: 'HttpService',
              error: e.response?.data,
            );
          }
        } else if (e.type == DioExceptionType.connectionError) {
          // DNS 解析失败或连接错误
          final errorString = e.error?.toString() ?? '';
          if (errorString.contains('Failed host lookup') || 
              errorString.contains('No address associated with hostname')) {
            errorMsg = '无法连接到服务器，请检查域名配置或网络连接';
            developer.log(
              'DNS 解析失败或连接错误',
              name: 'HttpService',
              error: {
                'error': e.error,
                'baseUrl': uploadBaseUrl ?? _baseUrl,
                'message': '请确认域名是否正确，或检查网络连接',
              },
            );
          } else {
            errorMsg = '网络连接错误: ${e.error}';
          }
        } else if (e.error != null) {
          errorMsg = '网络错误: ${e.error}';
        }
        throw Exception(errorMsg);
      }
      
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
          'tongueApiBaseUrl': tongueApiBaseUrl,
        },
      );

      // 先上传图片
      // 注意：上传接口和识别接口在不同的服务器上
      // 上传接口使用 _baseUrl（已在 HttpService.init 中配置为上传接口的 baseUrl）
      // 识别接口使用 tongueApiBaseUrl
      // 注意：上传接口需要 token，但 Flutter 中可能没有 token，先传 null
      // 如果服务器要求 token，会返回 401，而不是 DNS 错误
      final imageUrl = await uploadImage(
        imagePath, 
        businessType: businessType,
        token: null, // TODO: 从存储中获取 token（如果需要）
        // 不传入 uploadBaseUrl，使用 _baseUrl（已配置为上传接口的 baseUrl）
      );
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
      // 注意：上传接口和识别接口在不同的服务器上
      // 上传接口使用 _baseUrl（已在 HttpService.init 中配置为上传接口的 baseUrl）
      // 识别接口使用 tongueApiBaseUrl
      // 注意：上传接口需要 token，但 Flutter 中可能没有 token，先传 null
      // 如果服务器要求 token，会返回 401，而不是 DNS 错误
      final imageUrl = await uploadImage(
        imagePath, 
        businessType: businessType,
        token: null, // TODO: 从存储中获取 token（如果需要）
        // 不传入 uploadBaseUrl，使用 _baseUrl（已配置为上传接口的 baseUrl）
      );
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
      // 注意：上传接口和识别接口在不同的服务器上
      // 上传接口使用 _baseUrl（已在 HttpService.init 中配置为上传接口的 baseUrl）
      // 识别接口使用 tongueApiBaseUrl
      // 注意：上传接口需要 token，但 Flutter 中可能没有 token，先传 null
      // 如果服务器要求 token，会返回 401，而不是 DNS 错误
      final imageUrl = await uploadImage(
        imagePath, 
        businessType: businessType,
        token: null, // TODO: 从存储中获取 token（如果需要）
        // 不传入 uploadBaseUrl，使用 _baseUrl（已配置为上传接口的 baseUrl）
      );
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

