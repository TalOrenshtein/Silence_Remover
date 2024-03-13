import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' as io;
import 'package:audioplayers/audioplayers.dart';
import 'package:loader_overlay/loader_overlay.dart';
//import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:silence_remover/src/router/router.dart';
import 'package:silence_remover/src/utils/utils.dart';
import 'package:silence_remover/src/utils/processingException.dart';

/// Shows the files in a directory that represents a specific day.
class SpecificRecordingPage extends StatefulWidget{
  final String path;
  final bool errorOccurred;
  const SpecificRecordingPage({super.key, required this.path,this.errorOccurred=false});
  

  @override
  State<SpecificRecordingPage> createState() => _SpecificRecordingPageState();
}

class _SpecificRecordingPageState extends State<SpecificRecordingPage> {
  List<io.FileSystemEntity> files=[];
  final chainedFileMark="_chained";
  PlayerState _playerState=PlayerState.stopped;
  int _indexOfAudioPlaying=-1;
  final AudioPlayer ap=AudioPlayer();
  StreamSubscription<PlayerState>? _apSub;
  bool lastProcessUnfinished=false;
  bool errorOccurred=false;
  // ignore: non_constant_identifier_names
  //String? ogAudioRecordingPath;
  @override
  void initState(){
    errorOccurred=widget.errorOccurred; //setting the error occurred from the widget parameter in a variable so we can edit it if needed.
    _getListofFiles();
    if(!errorOccurred) lastProcessUnfinished=_isLastProcessUnfinished();
    super.initState();
    _apSub=ap.onPlayerStateChanged.listen((PlayerState s) {
      setState(() {
        _playerState=s;
        if (s==PlayerState.stopped) _indexOfAudioPlaying=-1;
      });
    });
  }
  //returns the key that belong to this recording's NoiseTimeStamps, which is depending on the date and time of the recording.
  String _getNoiseStampsKey(){
    return widget.path.substring(widget.path.indexOf("records/")+("records/").length);
  }
  
  /// Set files list as the list of audio files, which we sort by OG, chained audio file, and then by timestamps.
  /// 
  /// Assuming that OG audio file don't have _ chars in it's m4a filename (after "audio_") and that the proccesed audio files do.
  /// Also assumes that the chained audio file that RecordPage.silenceRemover outputs is marked with "_chained" .
  void _getListofFiles(){
    files=io.Directory(widget.path).listSync();
    files.sort((a, b) {
      // Makes sure the OG audio file is at the beginning, if it exists. We have to sort it somehow anyway, so it's better its at the beginning as we search for it at _isLastProcessUnfinished
      if (!a.path.substring(a.path.indexOf("audio_")+"audio_".length).contains("_")) return -1;
      if (!b.path.substring(b.path.indexOf("audio_")+"audio_".length).contains("_")) return 1;
      // Makes sure the chained audio file get shown as the first audio file. Doesn't really matter here but we have to deal with this file anyway, and it saves searching time.
      if (a.path.contains(chainedFileMark)) return -1;
      if (b.path.contains(chainedFileMark)) return 1;

      /**
       * Extracting the {startTimeStamp} from the path,so we can sort from older to newer. For example:
       * /storage/emulated/0/Android/data/com.example.silence_remover/files/2023-8-17/audio_hh:mm:ss_{startTimeStamp}_{endTimeStamp}.m4a -> {startTimeStamp}
       */
      const fileExtentionConst=".m4a".length;
      // ignore: non_constant_identifier_names
      final double a_startTimeStamp=double.parse(a.path.substring(a.path.lastIndexOf("_")+1,a.path.length-fileExtentionConst));
      // ignore: non_constant_identifier_names
      final double b_startTimeStamp=double.parse(b.path.substring(b.path.lastIndexOf("_")+1,b.path.length-fileExtentionConst));
      return a_startTimeStamp.compareTo(b_startTimeStamp);
    });
  }

  /// Builds a single tile list for a [file]. [i] is an iterable from _listOfListTilesBuilder that's used to both check [chainedIndex] equality for setting title name and deciding the position of the play icon when player is playing.
  ListTile _listTileBuilder(int i,String file,int chainedIndex){
    String filename=file.substring(file.lastIndexOf("/"));
    return ListTile(
      //Althought we sort the elements at _getListofFiles and make sure the _chained audio file is the first, this is more bug proof.
      title: i==chainedIndex?const Text("Full night's noises chained together"):_calcFileName(filename),
      trailing:
      //Here we're wrapping so we can use multiple buttons for the same tile.
      Wrap(spacing: 10, children: [
        _playerState==PlayerState.playing&&_indexOfAudioPlaying==i
        ?ElevatedButton.icon(
          icon: const Icon(Icons.stop), 
          label: const Text ("Stop"),
          onPressed: () async {
            await ap.stop();
            _indexOfAudioPlaying=-1;
          }
        )
        :ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow), 
          label: const Text ("Play"),
          onPressed: () async {
            ap.play(DeviceFileSource(file));
            setState(() {
              _indexOfAudioPlaying=i;
            });
          }
        ),
        SizedBox(child: 
          PopupMenuButton<int>(
            itemBuilder: (context) => [
              //Popup item For delete.
              PopupMenuItem( 
                value: 1,
                child: const Row(
                  children: [
                    Icon(Icons.delete),
                    SizedBox(
                      width: 10,
                    ),
                    Text("Delete")
                  ],
                ),
          onTap: () async {
              final delFile=io.File(file);
              await delFile.delete();
              _getListofFiles(); // we need to refresh the list of files, thus _getListofFiles is being called here too.
              setState(() {});
            },
        ),
              //Popup item for share
              PopupMenuItem( 
                value: 1,
                child: const Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(
                      width: 10,
                    ),
                    Text("Share")
                  ],
                ),
          onTap: () async => await Share.shareXFiles([XFile(file)],),
        ),])),
      ],)
    );
  }
  
  /// Builds a list of ListTile widgets while making sure the chained audio file appears first.
  /// 
  /// Assumes that if theres an audio file that chains together all the trimmed audio files, it'll contain "_chained" in its' filename.
  /// (filename is hard coded at RecordPage).
  List<ListTile> _listOfListTilesBuilder(){
    List<ListTile> list=<ListTile>[];
    final chainedIndex=(files.indexWhere((e) => e.path.contains(chainedFileMark)));
    if (chainedIndex!=-1) {
      list.add(_listTileBuilder(chainedIndex, files[chainedIndex].path,chainedIndex));
    }
    for(var i=0;i<files.length;i++){
      if (i==chainedIndex) continue;
      list.add(_listTileBuilder(i,files[i].path,chainedIndex));
    }
    return list;
  }

/// We calculate here the starting time of this noise, and present it as the title.
/// 
/// Assumes the file looks like "audio_<hh>-<mm>-<ss>_<startTimeStamp>_<endTimeStamp>".
  Text _calcFileName(String file){
  // ignore: non_constant_identifier_names
  final int posof2nd_char=file.indexOf("_",file.indexOf('_')+1); // The position of the 2nd '_' char.
  final startStamp=int.parse(file.substring(posof2nd_char+1,file.indexOf(".")));
  final int hourStarted=startStamp~/(60*60);
  final int minuteStarted=startStamp~/60;
  final int secondStarted=startStamp%60;
  String startTime= _findStartTime(file, hourStarted, minuteStarted, secondStarted);
  String timePassed=_findTimePassed(hourStarted, minuteStarted, secondStarted);
  return Text("Noises occurred$timePassed at $startTime");
}
/// Calculate the time at day (24H format) that the noise occurred.
/// Assumes that the file contains an hour in this format "_<hh>-<mm>-<ss>_". Assuming also that each one of <x> is an int.
String _findStartTime(String file, int hourStarted, int minuteStarted, int secondStarted){
  var index=file.indexOf("-"); // Index holds the starting point index the text that represents minutes or seconds, respectively.
  var hour=int.parse(file.substring(file.indexOf("_")+1,index));
  var minute=int.parse(file.substring(index+1,file.indexOf("-",index+1)));
  index=file.indexOf("-",index+1);
  var seconds=int.parse(file.substring(index+1,file.indexOf("_",index+1)));
  if ((seconds+=secondStarted)>=60){
    minute++;
    seconds-=60;
  }
  if ((minute+=minuteStarted)>=60){
    hour++;
    minute-=60;
  }
  if ((hour+=hourStarted)>=24){
    hour-=24;
  }
  hour+=hourStarted;
  var time="";
  //adds 0's to the time, so it'll look like 01:02:03 instead of 1:2:3.
  hour<10? time+="0$hour:":time+="$hour:";
  minute<10? time+="0$minute:":time+="$minute:";
  seconds<10? time+="0$seconds":time+="$seconds";
  return time;
}
/// format the time passed after the start of the recording
String _findTimePassed(int hourStarted, int minuteStarted, int secondStarted){
    String timePassed="";
  if (hourStarted!=0) {
    if(hourStarted==1) {
      timePassed=" after $hourStarted hour";
    } else {
      timePassed=" after $hourStarted hours";
    }
  }
  else{
    if (minuteStarted!=0){
      if (minuteStarted==1) {
        timePassed=" after $minuteStarted minute";
      } else {
        timePassed=" after $minuteStarted minutes";
      }
    }
    else {
      switch(secondStarted){
      case 0:
      timePassed="";
        break;
      case 1:
        timePassed=" after $secondStarted second";
        break;
      default:
        timePassed=" after $secondStarted seconds";
    }
    }
  }
  return timePassed;
}

///Searches for the OG audio recording file, and return it if it exists.
///
/// Assuming the recording processing delete the OG audio file after the actual processing ended.
/// Also, assuming that OG audio file don't have _ chars in it's m4a filename (after "audio_"), and that the proccesed audio files do,
/// as we detect the OG audio file using the knowledge that the proccesed filenames are marked, and each mark is seperated by '_' .
String? getOGaudioPath(){
  // ignore: non_constant_identifier_names
  int? posof_char; // will be null only if there's no files in this folder, meaning that the user manually deleted all the files.
  for (var e in files){
    String filenameCut=e.path.substring(e.path.lastIndexOf("/audio_")+("/audio_").length);
    posof_char=filenameCut.indexOf("_"); // The position of the '_' char, which appears at all the processed audio files' names but not at the OG's.
    if(posof_char==-1){
      return e.path;
    }
  }
  return null;
}

/// Searches for the OG audio recording file, if it exists, it means the recording processing isn't finish as the last step of the recording processing is to delete this file.
bool _isLastProcessUnfinished() {
  return getOGaudioPath()!=null;
}

/// Searches for the OG audio recording file, if it exists, it means the recording processing isn't finish as the last step of the recording processing is to delete this file.
/// If exists, update [ogAudioRecordingPath] to its path.
/// 
/// Assuming the recording processing delete the OG audio file after the actual processing ended.
/// Also, assuming that OG audio file don't have _ chars in it's m4a filename (after "audio_"), and that the proccesed audio files do,
/// as we detect the OG audio file using the knowledge that the proccesed filenames are marked, and each mark is seperated by '_' .
// bool _isLastProcessUnfinished_old() {
//   // ignore: non_constant_identifier_names
//   int? posof_char; // will be null only if there's no files in this folder, meaning that the user manually deleted all the files.
//   for (var e in files){
//     String filenameCut=e.path.substring(e.path.lastIndexOf("/audio_")+("/audio_").length);
//     posof_char=filenameCut.indexOf("_"); // The position of the '_' char, which appears at all the processed audio files' names but not at the OG's.
//     if(posof_char==-1){
//       ogAudioRecordingPath=e.path;
//       break;
//     }
//   }
//   // setState(() {
//   //   lastProcessUnfinished=posof_char==null?false:posof_char==-1;
//   // });
//   return posof_char==null?false:posof_char==-1;
// }

///Figureing out if the last processed was cut at the middle or didn't even started, and starts processing accourdinaly.
Future<void> _resumeLastProcess() async{
  String? ogAudioRecordingPath=getOGaudioPath();
  if(ogAudioRecordingPath==null){
    //nothing to process
    throw Exception("Original audio file not found. Cannot resume processing!");
  }
  String? stampsListSTR=await NoiseTimeStamps.getNoiseTimeStamps(_getNoiseStampsKey());
  if (stampsListSTR == null || stampsListSTR=='[]'){
    /**If stampsListSTR represents an empty list, it means that either the OG audio recoring file didn't have any silence parts,
     * or that the last processing attempt got stopped before it could process the noise time stamps. We can't tell with of the cases is true,
     * so we must restart the processing. */
    return NoiseTimeStamps.restartProcessing(ogAudioRecordingPath);
  }
  else{
    List<Pair<double,double>> noiseTimeStamps=[];
    try{
      List<dynamic> stampsList=jsonDecode(stampsListSTR);
      for (var e in stampsList){
        noiseTimeStamps.add(Pair.fromJson(e));
      }
    }catch(err){
      //Decode the JSON object resulted with an error.
      if (kDebugMode) print("Error occurred while trying to decode the JSON object at SpecificRecordingPage._resumeLastProcess:\n $err \nRestarting the processing.");
      return NoiseTimeStamps.restartProcessing(ogAudioRecordingPath);
    }
    //find where the last processing stopped, so we can continue processing from there.
    double biggestEndTime=-1;
    for(var e in files){
      String endTimeStr="";
      //skipping the OG and chained files.
      if (e.path==ogAudioRecordingPath||e.path.lastIndexOf(chainedFileMark)>-1) continue;
      //Assuming the trimmed audio files had the second element in a Pair documented at its filename between a _ char and .m4a extention.
      try{
        endTimeStr=e.path.substring(e.path.lastIndexOf("_")+1,e.path.lastIndexOf(".m4a"));
      }catch(err){
        if (kDebugMode) print("The trimmed audio files didn't have the second element in a Pair documented at its filename between a _ char and .m4a extention.");
        rethrow;
      }
      try{
        double endTime=double.parse(endTimeStr);
        if (biggestEndTime<endTime) biggestEndTime=endTime;
      }catch(err){
        if (kDebugMode) print("An error occurred while trying to convert \"$endTimeStr\" to double.");
        rethrow;
      }
    }
    //Removing the elements that got proccessed already, remove entry from DB in the background and resume processing while letting the user await for it.
    noiseTimeStamps.removeWhere((element) => element.second<=biggestEndTime);
    NoiseTimeStamps.removeNoiseTimeStamps(_getNoiseStampsKey());
    return NoiseTimeStamps.resumeProcessing(ogAudioRecordingPath, noiseTimeStamps);
  }
}
  ///Showing a screen that notes the user of a detection of unfinished processing, asking what to do next.
  Widget unfinishedScreen() {
    return Scaffold(
      body: Column(children: [
        const Text("We noticed this recording's processing didn't succeed. Do you want to resume the processing?\n Notice that if you select no, this recording will be deleted. This is unreversal!"),
        ElevatedButton.icon(icon: const Icon(Icons.check_circle), label: const Text("Yes"),onPressed: () async{
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
          try{
            await _resumeLastProcess();
          }on processingException{
            //using [errorOccurred] to signal that there's an error, rebuild and show errorOccurredScreen
            //that will notify the user that an error occurred, and ask if they want to try again, delete the recording or export the original audio file.
            _getListofFiles(); //The error might occurred after some processing so we update the files list to detect file additions (probably noisy parts audio files)
            setState(() {
              errorOccurred=true;
            });
          }
          // ignore: use_build_context_synchronously
          context.loaderOverlay.hide();
          _getListofFiles(); //After processing, the directory's content has been changed, so we need to reget it.
          setState(() {
            lastProcessUnfinished=false;
          });
        },),
        ElevatedButton.icon(icon: const Icon(Icons.cancel), label: const Text("No"),onPressed: (){
          io.Directory folder=io.Directory(widget.path);
          try {
            if(folder.existsSync()) folder.deleteSync(recursive: true);
          }catch (err) {
            if (kDebugMode) print("An error occurred while trying to delete the folder at ${widget.path}");
            rethrow;
          }
          const HomepageRoute().go(context);
        },),
      ]),
    );
  }
  
/// shows a screen the let the user know that an error occurred and give some option to deal with it.
Widget errorOccurredScreen() {
    return Scaffold(
      body: Column(children: [
        const Text("We noticed there was an error while processing this recording. Please choose what to do next:"),
        ElevatedButton.icon(icon: const Icon(Icons.check_circle), label: const Text("Try processing again"),onPressed: () async{
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
          try{
            await _resumeLastProcess();
          }on processingException{
            //using [errorOccurred] to signal that there's an error, rebuild and show errorOccurredScreen
            //that will notify the user that an error occurred, and ask if they want to try again, delete the recording or export the original audio file.
            _getListofFiles(); //The error might occurred after some processing so we update the files list to detect file additions (probably noisy parts audio files)
            setState(() {
              errorOccurred=true;
            });
          }
          // ignore: use_build_context_synchronously
          context.loaderOverlay.hide();
          _getListofFiles(); //After processing, the directory's content has been changed, so we need to reget it.
          setState(() {
            errorOccurred=false;
            lastProcessUnfinished=false;
          });
        },),
        ElevatedButton.icon(icon: const Icon(Icons.download), label: const Text("Export recording and delete"),onPressed: ()async{
          String? filePath = getOGaudioPath();
          if(filePath==null){
            throw Exception("Original audio file not found. Cannot export!");
          }
          io.Directory downloadsPath=io.Directory("/storage/emulated/0/Download");
          String? fileName="silenceRemover_audio_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().hour}-${DateTime.now().minute}-${DateTime.now().second}.m4a";//filePath.substring(filePath.lastIndexOf("/"));
          final XFile file =XFile(filePath);
          await file.saveTo("${downloadsPath.path}/$fileName");
          io.Directory folder=io.Directory(widget.path);
          try {
            if(folder.existsSync()) folder.deleteSync(recursive: true);
          }catch (err) {
            if (kDebugMode) print("An error occurred while trying to delete the folder at ${widget.path}");
            rethrow;
          }
          // ignore: use_build_context_synchronously
          const HomepageRoute().go(context);
        }),
        ElevatedButton.icon(icon: const Icon(Icons.cancel), label: const Text("Delete this recording"),onPressed: (){
          io.Directory folder=io.Directory(widget.path);
          try {
            if(folder.existsSync()) folder.deleteSync(recursive: true);
          }catch (err) {
            if (kDebugMode) print("An error occurred while trying to delete the folder at ${widget.path}");
            rethrow;
          }
          const HomepageRoute().go(context);
        },),
      ]),
    );
  }
  
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text("Silence Remover"),centerTitle: true, backgroundColor: Theme.of(context).colorScheme.primary,),
      //backgroundColor: Theme.of(context).primaryColorDark,
      body:Column(children: [
        const SizedBox(height: 10,),
        //Shows instruction text only when there are files to present.
        if(files.isNotEmpty)
          if(errorOccurred)
            Expanded(child: errorOccurredScreen())
          else if(lastProcessUnfinished)
            Expanded(child: unfinishedScreen())
          else ...[
            Container(color: Theme.of(context).colorScheme.onSecondary,child:const Text("These are files that got recorded and got sperated by silence. Choose one to hear.",),),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: _listOfListTilesBuilder()
              ),
            )
          ]
        //]
        else const Expanded(child: Center(child: Text("No recording found",style: TextStyle(color: Colors.red),))),
      ],)
    );
  }
  @override
  void dispose() {
    _apSub?.cancel();
    ap.dispose();
    super.dispose();
  }
  
}




