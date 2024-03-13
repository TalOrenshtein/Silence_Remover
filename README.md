# silence_remover

An Android app that let the user record audio, detect silent parts in said audio, trim them and output both a trimmed version of the audio file, and a list of individual trimmed parts marked by time of occurrence. The app supports adding persistent notes to folders and files, and resuming a processing if the app detects that the processing didn't complete successfully.
This App was developed for family members' personal use and as a reason to learn dart and flutter, and is covered by AGPL license. Any suggestion is welcome.

## Getting Started

If you want to compile it from the source code, folllow these steps:
 * run "flutter pub run build_runner build"
 * in router.g.dart:
    * change state.params function call to state.pathParameters
    * change state.queryParams to state.uri.queryParameters
 * run "flutter build apk --split-per-abi" to get a release version of the app.
 * DONE