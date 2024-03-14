import 'dart:async';
import 'dart:io';
import "dart:convert";

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:silence_remover/src/router/router.dart';
import 'package:silence_remover/src/utils/utils.dart';
import 'package:p_limit/p_limit.dart';
import 'package:numberpicker/numberpicker.dart';
import "package:silence_remover/src/utils/processingException.dart";



class RecordPage extends StatefulWidget{
  static int dB=-50; //default dB value.
  static const dotM4aWordLength=4; // ".m4a" length is 4 lol. I miss #define
  
  ///Use the recorded file in [path] to detect silence parts, so that file can be split late.
  ///returns: a List of pairs, in each pair, the first element is the start timestamp of a silence part
  ///and the second is the end timestamp of said silence part
  ///
  ///Assuming FFmpegKit's output is a string which the silence start and end periods are documented as "silence_start", "silence_end" respectively.
  ///Also, assuming that at the output, after listing the silence_start(s) and silence_end(s), FFmpeg will document properties of the original file such as "time" and "bitrate", and that "bitrate" will be documented after "time".
  ///
  /// Throws if FFmpeg processing fail.
  static Future<List<Pair<double, double>>> getNoisyPairs(String path) async{
    List<Pair<double,double>> noiseTimeStamps=[];
    final String? output;
    try{
      FFmpegSession ffLog=await FFmpegKit.execute('-i $path -af silencedetect=noise=${dB}dB:d=0.3 -f null - ');
      output=await ffLog.getOutput();
    }catch(e){
      if (kDebugMode) print("The execution of FFmpeg failed");
      rethrow;
    }
    if (output==null){
      throw Exception("The execution of FFmpeg failed");
    }
    final String log=output.substring(output.indexOf("silence_start"),output.indexOf("bitrate",output.indexOf("silence_start")));
    /**
    Here we find the place in the log that the output begins, then,because we want the noisy parts and not the silence parts, if we looking at two consecutive pairs,
    (silence_start,silence_end) and (silence_start2,silence_end2), we capture (silence_end,silence_start2), as they're representing a period when a noise occurred.
    So, although unintuitive, following the logic above we mark the ending of the first pair as start, and the starting of the second pair as end.
    
    The regex detects either
    '''
    silence_end: 123.45600| silence_duration: 1.2300
    [silencedetect @ 0x7b3e8e2f2840] silence_start: 124.67800
    '''
    or
    '''
    silence_end: 123.456 | silence_duration: 2.90832
    '''
    and group by "silence_end" and "silence_start".
    (Not counting the newline before\after ''', it's just for presenting the strings clearly.)
    */
    RegExp regex= RegExp(
      r"silence_end:\s(?<silence_end>\d+(\.\d+)?)\s\|\s\w+:\s\d+(\.\d+)?((\r|\n|\r\n)?\[\w+\s\@\s0x\w+\]\s(silence_start:\s(?<silence_start>\d+(\.\d+)?)))?"
    );
    for (var match in regex.allMatches(log)){
      double start=double.parse(match.namedGroup("silence_end")!);
      double end=0;
      try{
        end=double.parse(match.namedGroup("silence_start")!);
        if (end-start>0.2) noiseTimeStamps.add(Pair(start,end));
      }catch(err){ //This catch is only relevant at the last iteration of the loop, which means the last match of the nameGroup "silence_start", since it's impossible that another match doesn't have it's "silence_start" pair.
        if (start>0 &&end==0){
          /*There is a noisy part at the end of the recording, so we include that too.
          searching said "time" documentation, extracting the timestamp, and add it as a pair with the start var.*/
          final String timeProperty=log.substring(log.indexOf("time")); //The time string looks like time=xx:yy:zz
          final List timeList=timeProperty.split("=")[1].split(":");
          int hour,minute;
          double second,timeAsSeconds;
          hour=int.parse(timeList[0]);
          minute=int.parse(timeList[1]);
          second=double.parse(timeList[2]);
          timeAsSeconds=hour*60*60+minute*60+second; //converting hour and minute to seconds and sum them up
          noiseTimeStamps.add(Pair(start, timeAsSeconds));
        }
      }
    }
    String date=path.substring(path.indexOf("records/")+("records/").length,path.lastIndexOf("/audio"));
    NoiseTimeStamps.setNoiseTimeStamps(date,jsonEncode(noiseTimeStamps));
    return noiseTimeStamps;
  }
  
  ///Split the recorded file in $path using the $pairsList pair list.
  static Future<List<FFmpegSession>> splitAudioBySilence(List<Pair<double,double>> pairsList,String path) async {
    final noExtPath=path.substring(0,path.length-dotM4aWordLength); //removing file extention i.e .m4a.
    final limit=PLimit<FFmpegSession>(7); //creates a workers pool. We can try increase the workers pool in production; though it crashes my avd.
    final futures= pairsList.map((e) => limit (()=> FFmpegKit.execute('-ss ${e.first} -t ${e.second-e.first} -i $path ${noExtPath}_${e.first}_${e.second}.m4a'))); //creates an iterable that each element will exec one FFmpeg execution.
    return Future.wait(futures); //waiting for the workers to iterate over the iterable, once they're done, the promises are fulfilled.
  }

  static Future<FFmpegSession> silenceRemover(String path) async{
    final noExtPath=path.substring(0,path.length-dotM4aWordLength); //removing file extention i.e .m4a.
    //return FFmpegKit.execute('-i $path -af silenceremove=stop_threshold=${dB}dB:start_threshold=${dB}dB:stop_periods=-1:stop_duration=0.1 ${noExtPath}_chained.m4a');
    return FFmpegKit.execute('-i $path -af silenceremove=stop_threshold=${dB}dB:stop_periods=-1:stop_duration=0.7 ${noExtPath}_chained.m4a'); //this new version seems to not leaving silence there and cut pretty well.
  }

  /// Trim/split the audio by silence parts, and delete the OG audio file.
  /// [path] is the path of the OG audio file, and the optional [silencePairs] is a list of the file's noiseTimeStamps, which is optional for giving the option of resuming instead of reprocessing the pairs.
  ///
  /// Throws [processingException] if FFmpeg processing fail.
  static Future<void> processRecording(String path, [List<Pair<double,double>>? silencePairs]) async{
    // path isn't updated to null after going back to the record screen, so we verify we didn't processed and deleted the recoreded file already.
    if (File(path).existsSync()) {
      try {
        silencePairs ??= await RecordPage.getNoisyPairs(path);
        var split=RecordPage.splitAudioBySilence(silencePairs,path);
        var remove=RecordPage.silenceRemover(path);
        await Future.wait([split,remove]);
      }catch(e){
        //in case FFmpeg throws an error
        throw processingException("FFmpeg's processing failed.");
      }
      final file=File(path);
      try {
        if (file.existsSync()) file.deleteSync();
      }catch (err) {
        if (kDebugMode) print("An error occurred while trying to delete the OG recording file at ${file.path}");
        rethrow;
      }
    }
    //Nothing to process, either the recorder returned a wrong file, or the file got processed already.
  }

  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  late final Record _recorder;
  StreamSubscription<RecordState>? _recordSub;
  RecordState _recordState = RecordState.stop;
  int _recordDuration = 0;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Amplitude? _amplitude;

  @override
  void initState(){
    _recorder=Record();
    super.initState();
    _recordSub = _recorder.onStateChanged().listen((recordState) {
      _updateRecordState(recordState);
    });
    _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 300)).listen((amp) => setState(() => _amplitude = amp));
  }

  
  @override
  Widget build(BuildContext context) {
    Icon buttonIcon=Icon((_recordState != RecordState.stop)? Icons.stop: Icons.mic);
    String label=(_recordState != RecordState.stop)? "Stop": "Start";
    return Scaffold(
      appBar: AppBar(title: const Text("Silence Remover"),centerTitle: true,backgroundColor: Theme.of(context).colorScheme.primary,),
      body:Column(
        children: [
          const SizedBox(height: 10,),
          if(_recordState==RecordState.record)
            const Text("Note that when you press the stop recording button, the processing will begin.\nIt might take a while for processing long recordings.",)
          else change_dB(),
          Expanded(
            child: Center( child:Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(onPressed: () async{
                    if( _recordState != RecordState.stop){
                      context.loaderOverlay.show(widget:
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Theme.of(context).primaryColor),
                            const SizedBox(height: 10,),
                            Text("Processing the recording...\nIt might take a while",style: TextStyle(color: Theme.of(context).primaryColor),),
                          ])
                      );
                      await _stop();
                      // ignore: use_build_context_synchronously
                      context.loaderOverlay.hide();
                    }
                    else {
                      _start();
                    }
                  },
                  icon: buttonIcon,
                  label: Text("$label recording")
                  ),
                  _buildText(),
                  if (_recordState != RecordState.stop&&_amplitude != null) ...[
                    const SizedBox(height: 40),
                    Text('Current: ${_amplitude?.current ?? 0.0}'),
                    Text('Max: ${_amplitude?.max ?? 0.0}'),
                    ],
                ],
              ),),
          ),
        ],
      )
    );
    
  }

  /// Builds the text that appears below the button.
  Widget _buildText() {
    return Column(children: [
      const SizedBox(height: 15),
      _recordState != RecordState.stop?_buildTimer():const Text("Waiting for recording...")
    ]);
  }

  /// Builds the text of the timer.
  Widget _buildTimer() {
      final String seconds = _formatNumber(_recordDuration % 60);
      final String minutes = _formatNumber(_recordDuration ~/ 60);
      final String hours = _formatNumber(_recordDuration ~/(60*60));

      return Text(
        '$hours: $minutes : $seconds',
        style: TextStyle(color: Theme.of(context).primaryColor),
      );
  }
  /// Formating the number as a string that represent time.
  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0$numberStr';
    }
    return numberStr;
  }
  
  ///Update the state of RecordState and thus rebuilding.
  void _updateRecordState(RecordState recordState) {
    setState(() => _recordState = recordState);
    switch (recordState) {
      case RecordState.record:
        _startTimer();
        break;
      case RecordState.stop:
        _timer?.cancel();
        _recordDuration = 0;
        break;
      default:
        _timer?.cancel();
        break;
    }
  }
    /// Start a fresh timer and counting every second.
    void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }
  
  /// Starts the recorder after setting up a path to the soon to be created audio file.
  Future<void> _start() async {
    try {
      if (await _recorder.hasPermission()) {
        String startDate=DateTime.now().toIso8601String();
        startDate=startDate.replaceAll(':', "-");
        String startTime=startDate.substring(startDate.indexOf("T")+1,startDate.indexOf("."));
        final appDir = await getApplicationDocumentsDirectory();
        final recDir= Directory('${appDir.path}/records/${DateTime.now().year}-${DateTime.now().month<10?"0":""}${DateTime.now().month}-${DateTime.now().day<10?"0":""}${DateTime.now().day}/$startTime');
        recDir.createSync(recursive: true);
        String path = p.join(recDir.path,'audio_$startTime.m4a',);
        await _recorder.start(path: path);
        if (kDebugMode) print('Recorded file path: $path');
        _recordDuration = 0;
        _startTimer();
      }
      else {
        throw Exception("No permission to use the device's microphone.");
      }
    } catch (err) {
        if(kDebugMode) print("An error occurred: $err");
        rethrow;
    }
  }
  

  Future<void> _stop() async {
    String? path = await _recorder.stop();
    if (path==null){
      //The user decided not to record.
      return;
    }
    try{
      await RecordPage.processRecording(path);
    }on processingException{
      //shows a screen the let the user know that an error occurred and give some option to deal with it.
      String? folderPath=path.substring(0,path.lastIndexOf("/"));
      // ignore: use_build_context_synchronously
      SpecificRecordingWithErrRoute(path:folderPath ,errorOccurred: true).push(context);
    }
  }

  @override
  void dispose(){
    _stop();
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  ///returns a slider widget that lets the user to change the dB level.
  // ignore: non_constant_identifier_names
  Widget change_dB() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("You can choose a new dB value for the silence detector processor. We recommend a value around -50dB."),
        NumberPicker(
          value: RecordPage.dB,
          minValue: -60,
          maxValue: -20,
          step: 1,
          haptics: true,
          axis: Axis.horizontal,
          onChanged: (value) => setState(() => RecordPage.dB = value),
        ),
        Text("currect dB: ${RecordPage.dB}")
      ],
    );
  }
}
