/// Visit lifecycle states required by the spec.
enum VisitStatus { notPlanned, planned, visited, skipped }

VisitStatus visitStatusFrom(String? s) => switch (s) {
      'planned' => VisitStatus.planned,
      'visited' => VisitStatus.visited,
      'skipped' => VisitStatus.skipped,
      _ => VisitStatus.notPlanned,
    };

class TripDay {
  final String id;
  DateTime date; // date-only, interpreted in Asia/Riyadh for scheduling
  String city; // region key, e.g. 'makkah'
  String? startPoint; // hotel / current location label

  TripDay({required this.id, required this.date, required this.city, this.startPoint});

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String().substring(0, 10),
        'city': city,
        'start_point': startPoint,
      };

  factory TripDay.fromMap(Map<String, dynamic> m) => TripDay(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        city: m['city'] as String,
        startPoint: m['start_point'] as String?,
      );
}

class TripVisit {
  final String id;
  final String dayId;
  final String destinationId;
  String? time; // "08:00" preferred visit time (user-chosen, not verified hours)
  int sortOrder;
  VisitStatus status;
  DateTime? visitedAt;
  String? notes;
  double? checkinLat;
  double? checkinLng;

  TripVisit({
    required this.id,
    required this.dayId,
    required this.destinationId,
    this.time,
    required this.sortOrder,
    this.status = VisitStatus.planned,
    this.visitedAt,
    this.notes,
    this.checkinLat,
    this.checkinLng,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'day_id': dayId,
        'destination_id': destinationId,
        'time': time,
        'sort_order': sortOrder,
        'status': status.name,
        'visited_at': visitedAt?.toIso8601String(),
        'notes': notes,
        'checkin_lat': checkinLat,
        'checkin_lng': checkinLng,
      };

  factory TripVisit.fromMap(Map<String, dynamic> m) => TripVisit(
        id: m['id'] as String,
        dayId: m['day_id'] as String,
        destinationId: m['destination_id'] as String,
        time: m['time'] as String?,
        sortOrder: (m['sort_order'] as num).toInt(),
        status: visitStatusFrom(m['status'] as String?),
        visitedAt: m['visited_at'] == null ? null : DateTime.tryParse(m['visited_at'] as String),
        notes: m['notes'] as String?,
        checkinLat: (m['checkin_lat'] as num?)?.toDouble(),
        checkinLng: (m['checkin_lng'] as num?)?.toDouble(),
      );
}

class Expense {
  final String id;
  final DateTime date;
  final String category; // transport, hotels, food, tickets, shopping, other
  final double amountSar;
  final String? note;

  Expense({required this.id, required this.date, required this.category, required this.amountSar, this.note});

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'category': category,
        'amount_sar': amountSar,
        'note': note,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        category: m['category'] as String,
        amountSar: (m['amount_sar'] as num).toDouble(),
        note: m['note'] as String?,
      );
}

/// Pure, persistence-free trip planner so core rules are unit-testable
/// (deliverable #15). The AppState wires this to SQLite.
class TripPlanner {
  final List<TripDay> days = [];
  final List<TripVisit> visits = [];

  List<TripDay> get sortedDays {
    final d = [...days]..sort((a, b) => a.date.compareTo(b.date));
    return d;
  }

  List<TripVisit> visitsOf(String dayId) {
    final v = visits.where((v) => v.dayId == dayId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return v;
  }

  TripDay addDay({required String id, required DateTime date, required String city, String? startPoint}) {
    final day = TripDay(id: id, date: DateTime(date.year, date.month, date.day), city: city, startPoint: startPoint);
    days.add(day);
    return day;
  }

  void removeDay(String dayId) {
    days.removeWhere((d) => d.id == dayId);
    visits.removeWhere((v) => v.dayId == dayId);
  }

  TripVisit addVisit({required String id, required String dayId, required String destinationId, String? time}) {
    final order = visitsOf(dayId).length;
    final visit = TripVisit(id: id, dayId: dayId, destinationId: destinationId, time: time, sortOrder: order);
    visits.add(visit);
    return visit;
  }

  void removeVisit(String visitId) {
    final v = visits.where((v) => v.id == visitId).firstOrNull;
    if (v == null) return;
    visits.remove(v);
    _renumber(v.dayId);
  }

  /// Reorder within a day (drag & drop semantics: ReorderableListView indices).
  void reorder(String dayId, int oldIndex, int newIndex) {
    final list = visitsOf(dayId);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
    }
  }

  void _renumber(String dayId) {
    final list = visitsOf(dayId);
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
    }
  }

  /// Manual status change only — never automatic (spec requirement).
  void setStatus(String visitId, VisitStatus status, {DateTime? at, double? lat, double? lng, String? notes}) {
    final v = visits.where((v) => v.id == visitId).firstOrNull;
    if (v == null) return;
    v.status = status;
    if (status == VisitStatus.visited) {
      v.visitedAt = at ?? DateTime.now();
      v.checkinLat = lat;
      v.checkinLng = lng;
      if (notes != null) v.notes = notes;
    } else {
      v.visitedAt = null;
      v.checkinLat = null;
      v.checkinLng = null;
    }
  }

  /// Effective status of a destination across the whole trip.
  VisitStatus statusOfDestination(String destinationId) {
    final related = visits.where((v) => v.destinationId == destinationId).toList();
    if (related.isEmpty) return VisitStatus.notPlanned;
    if (related.any((v) => v.status == VisitStatus.visited)) return VisitStatus.visited;
    if (related.any((v) => v.status == VisitStatus.planned)) return VisitStatus.planned;
    return VisitStatus.skipped;
  }

  ({int planned, int visited, int remaining, int skipped}) counters() {
    var planned = 0, visited = 0, skipped = 0;
    for (final v in visits) {
      switch (v.status) {
        case VisitStatus.planned:
          planned++;
        case VisitStatus.visited:
          visited++;
        case VisitStatus.skipped:
          skipped++;
        case VisitStatus.notPlanned:
          break;
      }
    }
    return (planned: planned, visited: visited, remaining: planned, skipped: skipped);
  }

  /// Visits scheduled for [date] (date-only comparison), in order,
  /// across all days matching that date.
  List<TripVisit> visitsOn(DateTime date) {
    final dayIds = days
        .where((d) => d.date.year == date.year && d.date.month == date.month && d.date.day == date.day)
        .map((d) => d.id)
        .toSet();
    final list = visits.where((v) => dayIds.contains(v.dayId)).toList()
      ..sort((a, b) {
        final t = (a.time ?? '99:99').compareTo(b.time ?? '99:99');
        return t != 0 ? t : a.sortOrder.compareTo(b.sortOrder);
      });
    return list;
  }

  /// Next upcoming planned visit for [date]: first planned item today.
  TripVisit? nextPlanned(DateTime date) {
    for (final v in visitsOn(date)) {
      if (v.status == VisitStatus.planned) return v;
    }
    return null;
  }

  /// Greedy nearest-neighbour ordering suggestion within one day.
  /// Purely a suggestion — the UI must allow manual reordering and must not
  /// discard user-fixed times (spec: never optimize away religious priorities).
  List<TripVisit> suggestOrder(String dayId,
      {required double startLat,
      required double startLng,
      required ({double lat, double lng}) Function(String destId) coordsOf}) {
    final pool = visitsOf(dayId).where((v) => v.status == VisitStatus.planned).toList();
    final ordered = <TripVisit>[];
    var curLat = startLat, curLng = startLng;
    while (pool.isNotEmpty) {
      pool.sort((a, b) {
        final ca = coordsOf(a.destinationId);
        final cb = coordsOf(b.destinationId);
        final da = _d2(curLat, curLng, ca.lat, ca.lng);
        final db = _d2(curLat, curLng, cb.lat, cb.lng);
        return da.compareTo(db);
      });
      final next = pool.removeAt(0);
      ordered.add(next);
      final c = coordsOf(next.destinationId);
      curLat = c.lat;
      curLng = c.lng;
    }
    return ordered;
  }

  static double _d2(double aLat, double aLng, double bLat, double bLng) {
    final dx = aLat - bLat, dy = aLng - bLng;
    return dx * dx + dy * dy;
  }
}

extension FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
