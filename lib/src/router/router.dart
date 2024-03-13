import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silence_remover/src/homepage.dart';
import 'package:silence_remover/src/features/record/record_page.dart';
import 'package:silence_remover/src/features/explorer/recording_explorer.dart';
import 'package:silence_remover/src/features/explorer/specific_recording.dart';


/**
 * Usage guide:
 * run "flutter pub run build_runner build"
 * in router.g.dart:
    * change state.params function call to state.pathParameters
    * change state.queryParams to state.uri.queryParameters
 * DONE
 */

part 'router.g.dart';
@TypedGoRoute<HomepageRoute>(
  path: '/',
)

@immutable
class HomepageRoute extends GoRouteData {
  const HomepageRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const Homepage();
  }
}

@TypedGoRoute<RecordingExplorerRoute>(
  path: '/files',
  routes: [
    TypedGoRoute<RecordingExplorerWithDateRoute>(
      path: 'date/:dateChosen',
      routes: [TypedGoRoute<SpecificRecordingRoute>(path: 'specific-recording/:path'),
      ],
    ),
  ],
)
@immutable
class RecordingExplorerRoute extends GoRouteData {
  const RecordingExplorerRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const RecordingExplorerPage();
  }
}

@immutable
class RecordingExplorerWithDateRoute extends GoRouteData {
  const RecordingExplorerWithDateRoute({required this.dateChosen});

  final String dateChosen;
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return RecordingExplorerPage(dateChosen: dateChosen,);
  }
}
@immutable
class SpecificRecordingRoute extends GoRouteData {
   const SpecificRecordingRoute(this.dateChosen,{required this.path,this.errorOccurred=false});

  final String dateChosen;
  final String path;
  final bool errorOccurred;
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return SpecificRecordingPage(path: path, errorOccurred:errorOccurred);
  }
}
@immutable
class SpecificRecordingWithErrRoute extends GoRouteData {
   const SpecificRecordingWithErrRoute( {required this.path,this.errorOccurred=false});

  final String path;
  final bool errorOccurred;
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return SpecificRecordingPage(path: path, errorOccurred:errorOccurred);
  }
}

@TypedGoRoute<RecordRoute>(
  path: '/record',
  routes: [
    TypedGoRoute<SpecificRecordingWithErrRoute>(path: 'specific-recording/:path/:errorOccurred'),
  ],)
@immutable
class RecordRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const RecordPage();
  }
}
