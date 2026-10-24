import 'dart:io';

abstract final class SystemUtils {
  static Future<String> getRouteTable() async {
    final command = Platform.isWindows
        ? 'route'
        : Platform.isLinux
        ? 'ip'
        : 'netstat';
    final args = Platform.isWindows
        ? ['print']
        : Platform.isLinux
        ? ['route', 'show', 'table', 'all']
        : ['-rn'];
    try {
      final result = await Process.run(command, args);
      return '${result.stdout}${result.stderr}';
    } on ProcessException catch (error) {
      return error.toString();
    }
  }
}
