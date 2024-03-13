import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:silence_remover/src/utils/utils.dart';
import 'package:silence_remover/src/router/router.dart'; 
import 'package:go_router/go_router.dart';


  /// This class is shows all the folders inside a specifc folder (that are representig either a dates or a times in a day) while integrating notes for specific folders, sorts from new to old, and let the user navigate them.
class RecordingExplorerPage extends StatefulWidget{
  final String? dateChosen;
  const RecordingExplorerPage({super.key, this.dateChosen});

  @override
  State<RecordingExplorerPage> createState() => _RecordingExplorerPageState();
}

class _RecordingExplorerPageState extends State<RecordingExplorerPage> {
  List<io.FileSystemEntity> files=[]; // holds the various folders that the user created while recording.

  /// Seperates [time], which represent a time in a hh-mm-ss, returns all units in a list.
  List<int> _seperateTimeToUnits(String time){
    var index=time.indexOf("-"); // Index holds the starting point index of the text that represents minutes or seconds.
    var hour=int.parse(time.substring(0,index));
    var minute=int.parse(time.substring(index+1,time.indexOf("-",index+1)));
    index=time.indexOf("-",index+1);
    var seconds=int.parse(time.substring(index+1));
    return [hour,minute,seconds];
  }

  Future<void> _getListofFiles() async {
    final appDirPath=(await getApplicationDocumentsDirectory()).path;
    late final String recDirPath;
    widget.dateChosen==null?
      recDirPath=io.Directory('$appDirPath/records/').path
      :recDirPath=io.Directory('$appDirPath/records/${widget.dateChosen}').path;
    try{
      files=io.Directory(recDirPath).listSync();
    }
    on io.PathNotFoundException {
      //We'll reach here at the first run of the app. If the user won't record anything, the 'records' folder wouldn't exist, so we'll create it here.
      io.Directory(recDirPath).createSync(recursive: true);
      files=io.Directory(recDirPath).listSync();
    }
    catch(e){
      if (kDebugMode) print("an error occurred while trying to list the files at \"$recDirPath\"\n$e");
      rethrow;
    }
    /**
     * Sort is usually used to sort from smaller to bigger. We want the oppiside, so we flip the results.
     * In general, given a,b as input, it places a before b if the returned value isn't positive.
     */
    files.sort((a, b) {
      if(widget.dateChosen!=null){
      /**
       * Extracts the date from the path, For example:
       * /storage/emulated/0/Android/data/com.example.silence_remover/files/records/2023-8-17/13-52-43 -> 13-52-43 .
       * compares the hours, minutes and seconds, and sort by the latest.
       */
        final aTime=(a.path.substring(a.path.lastIndexOf('/')+1));
        final bTime=(b.path.substring(b.path.lastIndexOf('/')+1));
        List<int> aList=_seperateTimeToUnits(aTime);
        List<int> bList=_seperateTimeToUnits(bTime);
        if(aList.length!=bList.length) throw FormatException("An error occured while trying to sort by time. One of the folder in \"${widget.dateChosen}\" recording's folder name is in a wrong format (folder name: \"${aList.length>bList.length?bTime:aTime}\" at \"${aList.length>bList.length?b.parent.path:a.parent.path}\").");
        for (var i = 0; i < aList.length-1; i++) {
          if (aList[i]-bList[i]==0) continue;
          return -1*(aList[i]-bList[i]);
        }
        return -1*(aList[aList.length-1]-bList[aList.length-1]); // comparing by seconds.
      }
      else{
      /**
       * Extracts the date from the path, For example:
       * /storage/emulated/0/Android/data/com.example.silence_remover/files/records/2023-8-17 -> 2023-8-17 .
       * and sorts by latest.
       */
        final aDate=DateTime.parse(a.path.substring(a.path.lastIndexOf('/')+1));
        final bDate=DateTime.parse(b.path.substring(b.path.lastIndexOf('/')+1));
        return -1*aDate.compareTo(bDate);
      }
    });
  }
  

  /// Deletes the directory and remove the data accosiated with [key], if exists.
  // Note that we can ignore the async part in term of UI functuality, so the user doesn't have to wait for the Futures.
  Future<List<void>> deleteDir(io.Directory dir,String key) async{
    try {
      if(dir.existsSync()) dir.deleteSync(recursive: true);
    }catch (err) {
      if (kDebugMode) print("An error occurred while trying to delete the folder at ${dir.path}");
      rethrow;
    }
    var removeNotes=Notes.removeNotes(key); //using removeNotes instead of removeNote.
    var removeStamps=NoiseTimeStamps.removeNoiseTimeStamps(key); //Should work only if the key is a date, and not a string like "$date_$time".
    return Future.wait([removeNotes,removeStamps]); //this method gives the user of the function the option to await for COMPLETE removal.
  }

  Future<List<ListTile>> _listOfListTilesBuilder() async{
    if(files.isEmpty){
      throw Exception("Folder is empty, yet the app tries to build a list");
    }
    List<ListTile> list=[];
    for(var e in files) {
      //Extracting the date/time from the path, which presented at the end of the path.
      String dateTimeTitle=e.path.substring(e.path.lastIndexOf('/')+1);
      String? key=dateTimeTitle; //As stated at Notes class, Notes table key will be either a date or string like "$date/$time" in case a date was chosen (widget.dateChosen!=null).
      if (widget.dateChosen!=null){ //adding the date part to the key if needed.
        final String pathWithoutTime=e.path.substring(0,e.path.lastIndexOf('/'));
        key="${pathWithoutTime.substring(pathWithoutTime.lastIndexOf('/')+1)}/$dateTimeTitle";
      }
      String? note;
      if((note=await Notes.getNote(key))==null) {
        list.add(_listTileBuilder(e.path,dateTimeTitle,key));
      } else{
        list.add(_listTileBuilder(e.path,dateTimeTitle,key,note));
      }
    }
    return list;
  }

  ListTile _listTileBuilder(String path,String dateTimeTitle,String key, [String? title]){
    return ListTile(
      title: widget.dateChosen!=null?
      title != null?Text("$title (${dateTimeTitle.replaceAll("-", ":")})"):Text(dateTimeTitle.replaceAll("-", ":")) // will show the time folders as hh:mm:ss instead of hh-mm-ss.
      :title != null?Text("$title ($dateTimeTitle)"):Text(dateTimeTitle),

      onTap: () {
        widget.dateChosen==null? RecordingExplorerWithDateRoute(dateChosen: dateTimeTitle).push(context)
        :SpecificRecordingRoute(widget.dateChosen!, path: path).push(context);
      },
      leading: const Icon(Icons.folder_outlined),
      trailing: SizedBox(child: 
        PopupMenuButton<int>(
          itemBuilder: (context) => [
            //Popup item for setting a note.
            PopupMenuItem( 
              value: 1,
              child: const Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(
                    width: 10,
                  ),
                  Text("Set a note")
                ],
              ),
              onTap: () {
                String newNote="";
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: TextField(
                        autofocus: true,
                        onChanged: (val){
                          newNote=val;
                        },
                      ),
                        actions: <Widget>[
                        MaterialButton(
                          color: Colors.red,
                          textColor: Colors.white,
                          child: const Text('Cancel'),
                          onPressed: () {
                            setState(() {
                              ctx.pop();
                            });
                          },
                        ),
                        MaterialButton(
                          color: Colors.green,
                          textColor: Colors.white,
                          child: const Text('OK'),
                          onPressed: () async {
                              //no "await" needed at both funcs as there's protection via a wrapped transaction. The app will await when trying to get the note, which will cause waiting for previous transactions.
                              if(newNote.isNotEmpty) {
                                Notes.setNote(key, newNote); 
                              } else{
                                Notes.removeNote(key);
                              }
                            setState(() {
                              ctx.pop();
                            });
                          },
                        ),
                      ],
                      ));
              },
            ),
            //Popup item for share
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
              onTap: () {
              deleteDir(io.Directory(path),key); //no "await" needed as there's protection via a wrapped transaction. The app will await when trying to get the note, which will cause waiting for previous transactions.
              setState((){});
              },
            ),
          ]
        ))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Silence Remover"),centerTitle: true,backgroundColor: Theme.of(context).colorScheme.primary,),
      body: FutureBuilder<void>(
        future: _getListofFiles(),
        builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center( //sets the CircularProgressIndicator at the center of the screen (x axis).
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, //sets the CircularProgressIndicator at the center of the screen (y axis).
                    children: [
                      Text("Please wait while loading available folders."),
                      CircularProgressIndicator(),
                    ],
                  ),
                );
            } else if (snapshot.hasError) {
              throw snapshot.error!;
            } else if (files.isNotEmpty){
            return FutureBuilder<List<ListTile>>(
              future: _listOfListTilesBuilder(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center( //sets the CircularProgressIndicator at the center of the screen (x axis).
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, //sets the CircularProgressIndicator at the center of the screen (y axis).
                        children: [
                          Text("Please wait while loading available folders."),
                          CircularProgressIndicator(),
                        ],
                      ),
                    );
                } else if (snapshot.hasError) {
                  throw snapshot.error!;
                } else {
                  List<ListTile> data = snapshot.data!;
                  return Column(
                    children: <Widget>[
                      Container(color: Theme.of(context).colorScheme.onSecondary,child:
                        widget.dateChosen==null
                          ?const Text("Choose the date of the desired recording",) //TODO: why is this text centered without us configuring it to be centered?
                          :Text("Choose the start time of the desired recording (date:${widget.dateChosen})",textAlign: TextAlign.center,),),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          return data[index];
                        },
                      ),
                    ],
                  );
                }
              },
            );
          }else{
            if(kDebugMode){
              print("object");
            }
              return const Center(child: Text("No recording found",style: TextStyle(color: Colors.red)));
          }
        },
      ),
    );
  }
}