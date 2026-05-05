import 'dart:io';

/// 全局 HTTP 代理配置
class GlobalHttpOverrides extends HttpOverrides {
  final String proxyString;
  final bool allowBadCertificates;

  /// [proxyString] 格式示例: "127.0.0.1:7890"
  GlobalHttpOverrides(this.proxyString, {this.allowBadCertificates = false});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // 设置代理
    client.findProxy = (uri) {
      // 如果是局域网地址，直接连接，不走代理
      if (_isLocalAddress(uri.host)) {
        return 'DIRECT';
      }
      return 'PROXY $proxyString;';
    };

    // 处理 HTTPS 证书问题 (有些代理可能会导致证书校验失败)
    /// todo
    // 警告：在生产环境中盲目返回 true 是不安全的，但个人使用为了方便通常会开启
    if (allowBadCertificates) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    }

    return client;
  }

  bool _isLocalAddress(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }

    // 检查常见的局域网 IP 段
    // 10.0.0.0 - 10.255.255.255
    // 172.16.0.0 - 172.31.255.255
    // 192.168.0.0 - 192.168.255.255
    // 169.254.0.0 - 169.254.255.255 (Link-local)

    final parts = host.split('.');
    if (parts.length != 4) return false;

    try {
      final p0 = int.parse(parts[0]);
      final p1 = int.parse(parts[1]);

      if (p0 == 10) return true;
      if (p0 == 172 && p1 >= 16 && p1 <= 31) return true;
      if (p0 == 192 && p1 == 168) return true;
      if (p0 == 169 && p1 == 254) return true;
    } catch (_) {
      return false;
    }

    return false;
  }
}
