import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:gt4_flutter_plugin/gt4_session_configuration.dart';

typedef EventHandler = Function(Map<String, dynamic> event);

class Gt4FlutterPlugin {
  static const String flutterLog = "| Geetest 4.0 | Flutter | ";
  
  static String get version {
    return "0.1.5";
  }

  static Future<String?> get platformVersion async {
    return "4.0.0";
  }

  EventHandler? _onShow;
  EventHandler? _onResult;
  EventHandler? _onError;
  
  String? _captchaId;
  GT4SessionConfiguration? _config;
  WebViewController? _webViewController;
  BuildContext? _context;
  bool _isShowing = false;

  Gt4FlutterPlugin(String captchaId, [GT4SessionConfiguration? config]) {
    _captchaId = captchaId;
    _config = config;
  }

  /// 开启验证
  void verify() {
    if (_captchaId == null) {
      debugPrint("${flutterLog}CaptchaId is null");
      return;
    }
    
    if (_isShowing) {
      debugPrint("${flutterLog}Verification is already showing");
      return;
    }
    
    _isShowing = true;
    
    // 创建一个临时的MaterialApp来显示WebView
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          color: Colors.white,
          child: WebView(
            initialUrl: _getInitialUrl(),
            javascriptMode: JavascriptMode.unrestricted,
            javascriptChannels: {
              _getJavascriptChannel(),
            },
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _injectJsBridge();
            },
            onPageFinished: (url) {
              _onShow?.call({"show": "1"});
            },
            // 添加WebView平台特定配置
            navigationDelegate: (NavigationRequest request) {
              // 阻止跳转到其他页面
              if (!request.url.startsWith('https://www.geetest.com')) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        ),
      ),
    ));
  }

  // 关闭验证
  void close() {
    _isShowing = false;
    // 在实际应用中，这里应该关闭WebView
    if (kIsWeb) {
      // Web平台处理
    } else if (Platform.isAndroid || Platform.isIOS) {
      // 移动平台处理
    }
  }

  void configurationChanged(Object object) {
    // 配置变更处理
  }

  ///
  /// 注册事件回调
  ///
  void addEventHandler({
    /// 验证完成，可能成功或者错误
    /// 成功结构示例:
    /// {result: {"lot_number":"5df5c616d4aa49aa82d44aceb6c76264",
    /// "pass_token":"282282c00077c1cc11d8b4b29e361fcfb3421916220ed9bf253803711b98f1ef",
    /// "gen_time":"1636015810","captcha_output":"1X_RK3ag_IKlW15iHhSywQ=="}, status: "1"}
    /// 失败结构示例:
    /// {result: {"captchaId":"647f5ed2ed8acb4be36784e01556bb71","captchaType":"slide",
    /// "challenge":"d04423f3-5297-44f5-bafa-cb868095c605"}, status: "0"}
    EventHandler? onResult,

    /// 错误回调
    /// 结构示例：{msg: 验证会话已取消, code: -14460, desc: {"description":"User cancelled 'Captcha'"}}
    /// 需要根据端类型区别处理错误码
    /// Android: https://docs.geetest.com/gt4/apirefer/errorcode/android
    /// iOS: https://docs.geetest.com/gt4/apirefer/errorcode/ios
    EventHandler? onError,

    ///
    ///
    ///
    EventHandler? onShow,
  }) {
    debugPrint("${flutterLog}addEventHandler");

    _onShow = onShow;
    _onResult = onResult;
    _onError = onError;
  }

  /// 获取初始URL
  String _getInitialUrl() {
    // 构建验证码参数
    final params = {
      'captchaId': _captchaId,
      'debug': _config?.debugEnable ?? false,
      'title': _config?.title ?? '请通过以下验证',
    };
    
    // 这里应该使用实际的GeeTest验证码URL
    // 由于我们没有实际的URL，这里使用一个占位符
    return 'https://www.geetest.com/demo/gt4-demo';
  }

  /// 获取JavaScript通道
  JavascriptChannel _getJavascriptChannel() {
    return JavascriptChannel(
      name: 'FlutterBridge',
      onMessageReceived: (JavascriptMessage message) {
        _handleJsMessage(message.message);
      },
    );
  }

  /// 注入JSBridge
  void _injectJsBridge() {
    final jsBridge = '''
      window.jsBridge = {
        callNative: function(data) {
          FlutterBridge.postMessage(JSON.stringify(data));
        }
      };
    ''';
    
    _webViewController?.runJavascript(jsBridge);
  }

  /// 处理JS消息
  void _handleJsMessage(String message) {
    try {
      final data = json.decode(message);
      final type = data['type'];
      
      switch (type) {
        case 'result':
          _onResult?.call({
            'status': '1',
            'result': data['data'],
          });
          _isShowing = false;
          break;
        case 'error':
          _onError?.call({
            'code': data['data']['code'],
            'msg': data['data']['msg'],
            'desc': data['data']['desc'],
          });
          _isShowing = false;
          break;
        case 'close':
          _isShowing = false;
          break;
        case 'ready':
          // 验证码准备就绪
          break;
      }
    } catch (e) {
      debugPrint("${flutterLog}Error handling JS message: $e");
    }
  }
}