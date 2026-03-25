import 'package:drift/drift.dart';

/// The Event Journal.
/// 
/// Corresponds to the 'One Truth' requirement.
/// Append-only log of every user action.
class SyncEvents extends Table {

  TextColumn get id => text().unique()();


  TextColumn get entityType => text()();
  

  TextColumn get entityId => text()();
  

  TextColumn get action => text()();
  

  TextColumn get payload => text()();
  

  TextColumn get timestamp => text()();
  

  TextColumn get hash => text()();
  

  IntColumn get localVersion => integer().autoIncrement()();
  

  TextColumn get deviceId => text()();
  
 
  IntColumn get status => integer().withDefault(const Constant(0))();

}
