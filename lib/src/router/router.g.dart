// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
      $homepageRoute,
      $recordingExplorerRoute,
      $recordRoute,
    ];

RouteBase get $homepageRoute => GoRouteData.$route(
      path: '/',
      factory: $HomepageRouteExtension._fromState,
    );

extension $HomepageRouteExtension on HomepageRoute {
  static HomepageRoute _fromState(GoRouterState state) => const HomepageRoute();

  String get location => GoRouteData.$location(
        '/',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);
}

RouteBase get $recordingExplorerRoute => GoRouteData.$route(
      path: '/files',
      factory: $RecordingExplorerRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'date/:dateChosen',
          factory: $RecordingExplorerWithDateRouteExtension._fromState,
          routes: [
            GoRouteData.$route(
              path: 'specific-recording/:path',
              factory: $SpecificRecordingRouteExtension._fromState,
            ),
          ],
        ),
      ],
    );

extension $RecordingExplorerRouteExtension on RecordingExplorerRoute {
  static RecordingExplorerRoute _fromState(GoRouterState state) =>
      const RecordingExplorerRoute();

  String get location => GoRouteData.$location(
        '/files',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);
}

extension $RecordingExplorerWithDateRouteExtension
    on RecordingExplorerWithDateRoute {
  static RecordingExplorerWithDateRoute _fromState(GoRouterState state) =>
      RecordingExplorerWithDateRoute(
        dateChosen: state.pathParameters['dateChosen']!,
      );

  String get location => GoRouteData.$location(
        '/files/date/${Uri.encodeComponent(dateChosen)}',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);
}

extension $SpecificRecordingRouteExtension on SpecificRecordingRoute {
  static SpecificRecordingRoute _fromState(GoRouterState state) =>
      SpecificRecordingRoute(
        state.pathParameters['dateChosen']!,
        path: state.pathParameters['path']!,
        errorOccurred: _$convertMapValue(
                'error-occurred', state.uri.queryParameters, _$boolConverter) ??
            false,
      );

  String get location => GoRouteData.$location(
        '/files/date/${Uri.encodeComponent(dateChosen)}/specific-recording/${Uri.encodeComponent(path)}',
        queryParams: {
          if (errorOccurred != false)
            'error-occurred': errorOccurred.toString(),
        },
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);
}

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

bool _$boolConverter(String value) {
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw UnsupportedError('Cannot convert "$value" into a bool.');
  }
}

RouteBase get $recordRoute => GoRouteData.$route(
      path: '/record',
      factory: $RecordRouteExtension._fromState,
      routes: [
        GoRouteData.$route(
          path: 'specific-recording/:path/:errorOccurred',
          factory: $SpecificRecordingWithErrRouteExtension._fromState,
        ),
      ],
    );

extension $RecordRouteExtension on RecordRoute {
  static RecordRoute _fromState(GoRouterState state) => RecordRoute();

  String get location => GoRouteData.$location(
        '/record',
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);
}

extension $SpecificRecordingWithErrRouteExtension
    on SpecificRecordingWithErrRoute {
  static SpecificRecordingWithErrRoute _fromState(GoRouterState state) =>
      SpecificRecordingWithErrRoute(
        path: state.pathParameters['path']!,
        errorOccurred: _$convertMapValue(
                'error-occurred', state.uri.queryParameters, _$boolConverter) ??
            false,
      );

  String get location => GoRouteData.$location(
        '/record/specific-recording/${Uri.encodeComponent(path)}/${Uri.encodeComponent(errorOccurred.toString())}',
        queryParams: {
          if (errorOccurred != false)
            'error-occurred': errorOccurred.toString(),
        },
      );

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);
}
