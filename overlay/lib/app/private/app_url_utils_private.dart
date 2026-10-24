import 'package:tuple/tuple.dart';

abstract final class AppUrlUtilsPrivate {
  // Signing keys are private upstream configuration and cannot be recovered
  // from the public repository. Preserve ordinary query fields only.
  static String signQueryParams(
    String version,
    int bodyLength,
    Map<String, dynamic> params,
  ) => {
    'v': Uri.encodeComponent(version),
    ...params,
  }.entries.map((e) => '${e.key}=${e.value}').join('&');
}

abstract final class BoardProviderPrivate {
  static bool get available => false;

  static Tuple3<String, String, String> getBycodeUrlAndBody({
    required String app,
    required String version,
    required String did,
    required String code,
  }) => throw UnsupportedError(
    'Provider lookup requires the upstream private API configuration. Import a subscription URL instead.',
  );
  static Tuple3<String, String, String> getNotifyIntegrationUrlAndBody({
    required String app,
    required String version,
    required String did,
    required String url,
    required String type,
  }) => throw UnsupportedError(
    'Provider integration notification requires the upstream private API configuration.',
  );
  static Tuple3<String, String, String> getNoticePushUrlAndBody({
    required String app,
    required String version,
    required String did,
    required String pid,
  }) => throw UnsupportedError(
    'Provider notices require the upstream private API configuration.',
  );
}
