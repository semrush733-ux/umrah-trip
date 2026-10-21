import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/strings.dart';
import '../core/utils.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import 'database.dart';
import 'destination_repository.dart';
import 'location_service.dart';
import 'notifications_service.dart';

/// Single source of truth for the app. Wraps the pure [TripPlanner] with
/// SQLite persistence and exposes settings, location and favorites.
class AppState extends ChangeNotifier {
  final DestinationRepository repo;
  final AppDatabase dbService;
  final LocationService location;
  final _uuid = const Uuid();

  final TripPlanner planner = TripPlanner();
  final Set<String> favorites = {};
  final List<Expense> expenses = [];

  AppLanguage language = AppLanguage.en;
  ThemeMode themeMode = ThemeMode.system;
  bool romanUrdu = false;
  String? manualRegion; // user-picked city when GPS is off
  double? hotelLat;
  double? hotelLng;
  String? hotelLabel;
  double? budgetSar;
  double? pkrPerSar; // user-entered rate; shown with timestamp, never invented
  DateTime? rateUpdatedAt;

  Position? position;
  bool locationDenied = false;
  bool ready = false;

  AppState({DestinationRepository? repo, AppDatabase? db, LocationService? loc})
      : repo = repo ?? DestinationRepository(),
        dbService = db ?? AppDatabase(),
        location = loc ?? LocationService();

  /// Startup is deliberately fault-tolerant: whatever fails (storage,
  /// prefs, even the seed JSON) the app still reaches the home screen —
  /// a stuck splash is never acceptable.
  Future<void> init() async {
    try {
      await repo.load();
    } catch (e) {
      debugPrint('init: repo.load failed: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      language = AppLanguage.values[(prefs.getInt('lang') ?? 0).clamp(0, 2)];
      themeMode = ThemeMode.values[(prefs.getInt('theme') ?? 0).clamp(0, 2)];
      romanUrdu = prefs.getBool('romanUrdu') ?? false;
      manualRegion = prefs.getString('manualRegion');
      hotelLat = prefs.getDouble('hotelLat');
      hotelLng = prefs.getDouble('hotelLng');
      hotelLabel = prefs.getString('hotelLabel');
      budgetSar = prefs.getDouble('budgetSar');
      pkrPerSar = prefs.getDouble('pkrPerSar');
      final rt = prefs.getString('rateUpdatedAt');
      rateUpdatedAt = rt == null ? null : DateTime.tryParse(rt);
    } catch (e) {
      debugPrint('init: prefs failed: $e');
    }
    try {
      final (days, visits) = await dbService.loadTrip();
      planner.days
        ..clear()
        ..addAll(days);
      planner.visits
        ..clear()
        ..addAll(visits);
      favorites
        ..clear()
        ..addAll(await dbService.loadFavorites());
      expenses
        ..clear()
        ..addAll(await dbService.loadExpenses());
    } catch (e) {
      debugPrint('init: database failed: $e');
    }
    ready = true;
    notifyListeners();
    // Try a silent position fix if permission was already granted.
    try {
      refreshLocation(request: false);
    } catch (_) {}
  }

  // ---------- Settings ----------
  Future<void> setLanguage(AppLanguage l) async {
    language = l;
    (await SharedPreferences.getInstance()).setInt('lang', l.index);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    (await SharedPreferences.getInstance()).setInt('theme', m.index);
    notifyListeners();
  }

  Future<void> setRomanUrdu(bool v) async {
    romanUrdu = v;
    (await SharedPreferences.getInstance()).setBool('romanUrdu', v);
    notifyListeners();
  }

  Future<void> setManualRegion(String? region) async {
    manualRegion = region;
    final prefs = await SharedPreferences.getInstance();
    if (region == null) {
      prefs.remove('manualRegion');
    } else {
      prefs.setString('manualRegion', region);
    }
    notifyListeners();
  }

  /// Saves "my hotel" at the given point (usually the current GPS position).
  Future<void> setHotel(double? lat, double? lng, String? label) async {
    hotelLat = lat;
    hotelLng = lng;
    hotelLabel = label;
    final prefs = await SharedPreferences.getInstance();
    if (lat == null || lng == null) {
      prefs.remove('hotelLat');
      prefs.remove('hotelLng');
      prefs.remove('hotelLabel');
    } else {
      prefs.setDouble('hotelLat', lat);
      prefs.setDouble('hotelLng', lng);
      prefs.setString('hotelLabel', label ?? 'My Hotel');
    }
    notifyListeners();
  }

  Future<void> setBudget(double? sar) async {
    budgetSar = sar;
    final prefs = await SharedPreferences.getInstance();
    if (sar == null) {
      prefs.remove('budgetSar');
    } else {
      prefs.setDouble('budgetSar', sar);
    }
    notifyListeners();
  }

  Future<void> setPkrRate(double? rate) async {
    pkrPerSar = rate;
    rateUpdatedAt = rate == null ? null : DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (rate == null) {
      prefs.remove('pkrPerSar');
      prefs.remove('rateUpdatedAt');
    } else {
      prefs.setDouble('pkrPerSar', rate);
      prefs.setString('rateUpdatedAt', rateUpdatedAt!.toIso8601String());
    }
    notifyListeners();
  }

  // ---------- Location ----------
  Future<void> refreshLocation({bool request = true}) async {
    final pos = await location.currentPosition(request: request);
    locationDenied = pos == null;
    position = pos;
    notifyListeners();
  }

  /// Active region: GPS city if near one, else manual selection, else Makkah.
  String get activeRegion {
    if (position != null) {
      final r = nearestRegion(position!.latitude, position!.longitude);
      if (r != null) return r;
    }
    return manualRegion ?? 'makkah';
  }

  double? distanceKmTo(Destination d) {
    final p = position;
    if (p == null) return null;
    return haversineKm(p.latitude, p.longitude, d.lat, d.lng);
  }

  List<Destination> nearbyDestinations({int limit = 6}) {
    final p = position;
    final list = [...repo.all];
    if (p != null) {
      list.sort((a, b) => haversineKm(p.latitude, p.longitude, a.lat, a.lng)
          .compareTo(haversineKm(p.latitude, p.longitude, b.lat, b.lng)));
    } else {
      final region = activeRegion;
      list.sort((a, b) {
        final ar = a.region == region ? 0 : 1;
        final br = b.region == region ? 0 : 1;
        return ar.compareTo(br);
      });
    }
    return list.take(limit).toList();
  }

  // ---------- Favorites ----------
  bool isFavorite(String id) => favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    final fav = !favorites.contains(id);
    if (fav) {
      favorites.add(id);
    } else {
      favorites.remove(id);
    }
    notifyListeners();
    await dbService.setFavorite(id, fav);
  }

  // ---------- Trip planning ----------
  Future<TripDay> addDay(DateTime date, String city, {String? startPoint}) async {
    final day = planner.addDay(id: _uuid.v4(), date: date, city: city, startPoint: startPoint);
    notifyListeners();
    await dbService.upsertDay(day);
    return day;
  }

  Future<void> removeDay(String dayId) async {
    planner.removeDay(dayId);
    notifyListeners();
    await dbService.deleteDay(dayId);
  }

  Future<TripVisit> addVisit(String dayId, String destinationId, {String? time}) async {
    final v = planner.addVisit(id: _uuid.v4(), dayId: dayId, destinationId: destinationId, time: time);
    notifyListeners();
    await dbService.upsertVisit(v);
    _scheduleReminder(v);
    return v;
  }

  void _scheduleReminder(TripVisit v) {
    if (v.time == null) return;
    final day = planner.days.where((d) => d.id == v.dayId).firstOrNull;
    final dest = repo.byId(v.destinationId);
    if (day == null || dest == null) return;
    NotificationsService.instance.requestPermission();
    NotificationsService.instance.scheduleVisitReminder(
      visitId: v.id,
      destinationName: dest.nameEn,
      date: day.date,
      time: v.time!,
    );
  }

  Future<void> removeVisit(String visitId) async {
    NotificationsService.instance.cancelVisitReminder(visitId);
    final day = planner.visits.where((v) => v.id == visitId).firstOrNull?.dayId;
    planner.removeVisit(visitId);
    notifyListeners();
    await dbService.deleteVisit(visitId);
    if (day != null) {
      for (final v in planner.visitsOf(day)) {
        await dbService.upsertVisit(v);
      }
    }
  }

  Future<void> setVisitTime(String visitId, String? time) async {
    final v = planner.visits.where((v) => v.id == visitId).firstOrNull;
    if (v == null) return;
    v.time = time;
    notifyListeners();
    await dbService.upsertVisit(v);
    if (time == null) {
      NotificationsService.instance.cancelVisitReminder(visitId);
    } else {
      _scheduleReminder(v);
    }
  }

  Future<void> reorder(String dayId, int oldIndex, int newIndex) async {
    planner.reorder(dayId, oldIndex, newIndex);
    notifyListeners();
    for (final v in planner.visitsOf(dayId)) {
      await dbService.upsertVisit(v);
    }
  }

  /// Manual confirmation only. Optional GPS check-in coordinates are attached
  /// when the user explicitly checks in.
  Future<void> setStatus(String visitId, VisitStatus status,
      {bool attachCheckin = false, String? notes}) async {
    double? lat, lng;
    if (attachCheckin && position != null) {
      lat = position!.latitude;
      lng = position!.longitude;
    }
    planner.setStatus(visitId, status, lat: lat, lng: lng, notes: notes);
    notifyListeners();
    final v = planner.visits.where((v) => v.id == visitId).firstOrNull;
    if (v != null) await dbService.upsertVisit(v);
  }

  /// Quick "Mark Visited" from a destination page: logs it on today's day,
  /// creating today's day (active city) if needed.
  Future<void> markVisitedToday(String destinationId) async {
    final today = saudiNow();
    TripDay? day;
    for (final d in planner.days) {
      if (d.date.year == today.year && d.date.month == today.month && d.date.day == today.day) {
        day = d;
        break;
      }
    }
    day ??= await addDay(DateTime(today.year, today.month, today.day), activeRegion);
    TripVisit? existing;
    for (final v in planner.visitsOf(day.id)) {
      if (v.destinationId == destinationId) {
        existing = v;
        break;
      }
    }
    existing ??= await addVisit(day.id, destinationId);
    await setStatus(existing.id, VisitStatus.visited);
  }

  Future<void> setVisitNotes(String visitId, String? notes) async {
    final v = planner.visits.where((v) => v.id == visitId).firstOrNull;
    if (v == null) return;
    v.notes = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
    notifyListeners();
    await dbService.upsertVisit(v);
  }

  VisitStatus statusOf(String destinationId) => planner.statusOfDestination(destinationId);

  /// Last-resort unblock for the splash screen.
  void forceReady() {
    ready = true;
    notifyListeners();
  }

  /// Merge admin-added destinations fetched from the website.
  void mergeRemoteDestinations(List<Destination> remote) {
    repo.applyRemote(remote);
    notifyListeners();
  }

  // ---------- Expenses ----------
  Future<void> addExpense(String category, double amountSar, {String? note, DateTime? date}) async {
    final e = Expense(
        id: _uuid.v4(), date: date ?? DateTime.now(), category: category, amountSar: amountSar, note: note);
    expenses.insert(0, e);
    notifyListeners();
    await dbService.upsertExpense(e);
  }

  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    await dbService.deleteExpense(id);
  }

  double get totalSpentSar => expenses.fold(0.0, (s, e) => s + e.amountSar);

  double spentOn(DateTime date) => expenses
      .where((e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day)
      .fold(0.0, (s, e) => s + e.amountSar);
}
