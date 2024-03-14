import "package:flutter/foundation.dart"; //imports kDebugMode
import "package:flutter/widgets.dart";
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:silence_remover/src/features/record/record_page.dart';

/*Note: from my understading, SQLite3 uses transactions when updating the DB, so we don't need to use a mutex here;
but I don't get if I need to use a transaction to ensure thread safety or if a single query is protected when running a SELECT query that isn't wrapped in a transaction by default.
For now, using transactions just to be safe. I thought about using transaction only for SELECT queries but wraps the other quries with a transaction change nothing anyway.
*/

class DB{
  static Database? _db;
  static Future<void> init() async{
    WidgetsFlutterBinding.ensureInitialized();
      openDatabase(p.join(await getDatabasesPath(), 'db.db')).then((value) {
      _db=value;
      Notes.init();
      NoiseTimeStamps.init();
    },onError: (err)=>throw err);
  }
  static Database get db=>_db!;
}

///Notes table key will be either a date or string like <date>-<time>. This ensures a unique key for every folder RecordingExplorerPage sets a note.
class Notes{
  static final Database _db=DB.db;

  static Future<void> init() async {
    return _db.execute(
      'CREATE TABLE IF NOT EXISTS Notes (ID TEXT PRIMARY KEY, Note TEXT NOT NULL)'
    );
  }
  static Future<void> setNote(String key, String note) async {
    return _db.transaction((txn) async {
      final num=await txn.rawInsert(
        'INSERT OR REPLACE INTO Notes (ID,Note) VALUES(?,?)',[key,note]
      );
      assert(num>0);
    });
  }
  static Future<void> removeNote(String key) async {
    return _db.transaction((txn) async {
      txn.rawDelete( //we don't need an assert here as we call this method systematically to verify that we cleaned the data that became irrelevant, but it might not exist.
        'DELETE FROM Notes WHERE ID=?',[key]
      );
    });
  }
  ///Removes all notes that their keys starts with [key] string.
  ///In a case that [key] will be a straight up date, it'll remove all the notes that are related to said date, based on the <date>-<time> key design.
  static Future<void> removeNotes(String key) async {
    return _db.transaction((txn) async {
      txn.rawDelete( //we don't need an assert here as we call this method systematically to verify that we cleaned the data that became irrelevant, but it might not exist.
        'DELETE FROM Notes WHERE ID LIKE ?',["$key%"]
      );
    });
  }

    ///Query the db and get the value stored under [key] key.
  static Future<String?> getNote(String key) async {
  ///Gets a List that potentially has only 1 pair (only if [key] is an existing ID), the key is 'Note' and the value (Note in Notes table) is the requested note.
    List list=[];
    await _db.transaction((txn) async {
      try{
        list=await txn.rawQuery('SELECT Note FROM Notes WHERE ID=?',[key]);
      }
      catch(err){
        if (kDebugMode) print("An error occurred while trying to query the DB at \"Notes.getNote\" function");
        rethrow;
      }
      });
      return list.isNotEmpty?list[0]['Note']:null;
  }
}
/// The key is usually the date and time of the recording, and the value is usually a JSON representation of the recording's noiseTimeStamps.
class NoiseTimeStamps{
  static final Database _db=DB.db;

  static Future<void> init() async {
    return _db.execute(
      'CREATE TABLE IF NOT EXISTS UnfinishedProcessing (ID TEXT PRIMARY KEY, NoiseTimeStamps TEXT NOT NULL)'
    );
  }
  static Future<void> setNoiseTimeStamps(String key, String noiseTimeStamps) async {
    return _db.transaction((txn) async {
      final num=await txn.rawInsert( 
        'INSERT OR REPLACE INTO UnfinishedProcessing (ID,NoiseTimeStamps) VALUES(?,?)',[key,noiseTimeStamps]
      );
      assert(num>0);
    });
  }
  static Future<void> removeNoiseTimeStamps(String key) async {
    return _db.transaction((txn) async {
      await txn.rawDelete( //we don't need an assert here as we call this method systematically to verify that we cleaned the data that became irrelevant, but it might not exist.
        'DELETE FROM UnfinishedProcessing WHERE ID=?',[key]
      );
    });
  }
  ///Query the db and get the value stored under [key] key.
  static Future<String?> getNoiseTimeStamps(String key) async {
  //Gets a List that potentially has only 1 pair, the we extract the value of the field "NoiseTimeStamps", which is usually a JSON representation of the recording's noiseTimeStamps.
    List list=[];
    await _db.transaction((txn) async {
      try{
        list=await txn.rawQuery('SELECT NoiseTimeStamps FROM UnfinishedProcessing WHERE ID=?',[key]);
      }catch(err){
        if (kDebugMode) print("An error occurred while trying to query the DB at \"NoiseTimeStamps.getNoiseTimeStamps\" function");
        rethrow;
      }
      });
      return list.isNotEmpty?list[0]['NoiseTimeStamps']:null;
  }
  ///Restart the processing for the original audio file. [path] holds the path of the original audio recording file.
  static Future<void> restartProcessing(String path) async{
    return RecordPage.processRecording(path);
  }

  /// resume processing by getting a modified [silencePairs] list that contains only the pairs that isn't proccessed yet.
  /// [path] holds the path of the original audio recording file.
  static Future<void> resumeProcessing(String path,List<Pair<double,double>> silencePairs) async{
    return RecordPage.processRecording(path,silencePairs);
  }
}

class Pair<T,E> {
  T first;
  E second;
  
  Pair(this. first, this.second);

  @override
  String toString() {
    return "($first,$second)";
  }
  Map<String,dynamic> toJson() =>{
    'first': first,
    'second': second
  };
  Pair.fromJson(Map<String,dynamic> json):
    first=json['first'],
    second=json['second'];
}