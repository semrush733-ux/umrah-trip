import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/trip.dart';

/// SQLite persistence (offline-first). Trip plans, visit history, notes and
/// expenses survive app restarts — a non-negotiable spec requirement.
class AppDatabase {
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'umrah_journey.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE trip_days(
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            city TEXT NOT NULL,
            start_point TEXT
          )''');
        await db.execute('''
          CREATE TABLE trip_visits(
            id TEXT PRIMARY KEY,
            day_id TEXT NOT NULL,
            destination_id TEXT NOT NULL,
            time TEXT,
            sort_order INTEGER NOT NULL,
            status TEXT NOT NULL,
            visited_at TEXT,
            notes TEXT,
            checkin_lat REAL,
            checkin_lng REAL
          )''');
        await db.execute('''
          CREATE TABLE favorites(
            destination_id TEXT PRIMARY KEY
          )''');
        await db.execute('''
          CREATE TABLE expenses(
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            category TEXT NOT NULL,
            amount_sar REAL NOT NULL,
            note TEXT
          )''');
      },
    );
    return _db!;
  }

  // ---- Trip days / visits ----
  Future<void> upsertDay(TripDay d) async =>
      (await db).insert('trip_days', d.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteDay(String id) async {
    final d = await db;
    await d.delete('trip_days', where: 'id = ?', whereArgs: [id]);
    await d.delete('trip_visits', where: 'day_id = ?', whereArgs: [id]);
  }

  Future<void> upsertVisit(TripVisit v) async =>
      (await db).insert('trip_visits', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteVisit(String id) async =>
      (await db).delete('trip_visits', where: 'id = ?', whereArgs: [id]);

  Future<(List<TripDay>, List<TripVisit>)> loadTrip() async {
    final d = await db;
    final days = (await d.query('trip_days')).map(TripDay.fromMap).toList();
    final visits = (await d.query('trip_visits')).map(TripVisit.fromMap).toList();
    return (days, visits);
  }

  // ---- Favorites ----
  Future<Set<String>> loadFavorites() async {
    final rows = await (await db).query('favorites');
    return rows.map((r) => r['destination_id'] as String).toSet();
  }

  Future<void> setFavorite(String destinationId, bool fav) async {
    final d = await db;
    if (fav) {
      await d.insert('favorites', {'destination_id': destinationId},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await d.delete('favorites', where: 'destination_id = ?', whereArgs: [destinationId]);
    }
  }

  // ---- Expenses ----
  Future<void> upsertExpense(Expense e) async =>
      (await db).insert('expenses', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteExpense(String id) async =>
      (await db).delete('expenses', where: 'id = ?', whereArgs: [id]);

  Future<List<Expense>> loadExpenses() async =>
      (await (await db).query('expenses', orderBy: 'date DESC')).map(Expense.fromMap).toList();
}
