import 'package:flutter_test/flutter_test.dart';
import 'package:umrah_journey/models/trip.dart';

void main() {
  group('TripPlanner — itinerary management', () {
    test('adds days and timed visits, keeps order', () {
      final p = TripPlanner();
      final d1 = p.addDay(id: 'd1', date: DateTime(2026, 11, 1), city: 'makkah');
      p.addVisit(id: 'v1', dayId: d1.id, destinationId: 'masjid-ayesha', time: '08:00');
      p.addVisit(id: 'v2', dayId: d1.id, destinationId: 'jannat-ul-mualla', time: '11:00');
      p.addVisit(id: 'v3', dayId: d1.id, destinationId: 'masjid-jinn', time: '16:00');

      final visits = p.visitsOf(d1.id);
      expect(visits.map((v) => v.id), ['v1', 'v2', 'v3']);
      expect(visits.map((v) => v.sortOrder), [0, 1, 2]);
    });

    test('reorder matches ReorderableListView semantics', () {
      final p = TripPlanner();
      final d = p.addDay(id: 'd1', date: DateTime(2026, 11, 1), city: 'madinah');
      p.addVisit(id: 'a', dayId: d.id, destinationId: 'masjid-quba');
      p.addVisit(id: 'b', dayId: d.id, destinationId: 'masjid-qiblatain');
      p.addVisit(id: 'c', dayId: d.id, destinationId: 'jabal-uhud');

      p.reorder(d.id, 0, 3); // move 'a' to the end
      expect(p.visitsOf(d.id).map((v) => v.id), ['b', 'c', 'a']);

      p.reorder(d.id, 2, 0); // move 'a' back to front
      expect(p.visitsOf(d.id).map((v) => v.id), ['a', 'b', 'c']);
    });

    test('removing a visit renumbers the rest', () {
      final p = TripPlanner();
      final d = p.addDay(id: 'd1', date: DateTime(2026, 11, 2), city: 'makkah');
      p.addVisit(id: 'a', dayId: d.id, destinationId: 'x');
      p.addVisit(id: 'b', dayId: d.id, destinationId: 'y');
      p.addVisit(id: 'c', dayId: d.id, destinationId: 'z');
      p.removeVisit('b');
      expect(p.visitsOf(d.id).map((v) => v.sortOrder), [0, 1]);
      expect(p.visitsOf(d.id).map((v) => v.id), ['a', 'c']);
    });

    test('removing a day removes its visits', () {
      final p = TripPlanner();
      final d = p.addDay(id: 'd1', date: DateTime(2026, 11, 3), city: 'jeddah');
      p.addVisit(id: 'a', dayId: d.id, destinationId: 'x');
      p.removeDay(d.id);
      expect(p.days, isEmpty);
      expect(p.visits, isEmpty);
    });

    test('days sort by date; visitsOn returns time-sorted items for that date', () {
      final p = TripPlanner();
      p.addDay(id: 'd2', date: DateTime(2026, 11, 5), city: 'madinah');
      p.addDay(id: 'd1', date: DateTime(2026, 11, 4), city: 'makkah');
      expect(p.sortedDays.map((d) => d.id), ['d1', 'd2']);

      p.addVisit(id: 'late', dayId: 'd1', destinationId: 'x', time: '16:00');
      p.addVisit(id: 'early', dayId: 'd1', destinationId: 'y', time: '07:00');
      p.addVisit(id: 'noTime', dayId: 'd1', destinationId: 'z');
      final on = p.visitsOn(DateTime(2026, 11, 4));
      expect(on.map((v) => v.id), ['early', 'late', 'noTime']);
      expect(p.visitsOn(DateTime(2026, 11, 6)), isEmpty);
    });
  });

  group('TripPlanner — visit tracking', () {
    test('status is manual-only and undoable, with counters', () {
      final p = TripPlanner();
      final d = p.addDay(id: 'd1', date: DateTime(2026, 11, 1), city: 'makkah');
      p.addVisit(id: 'a', dayId: d.id, destinationId: 'jabal-noor');
      p.addVisit(id: 'b', dayId: d.id, destinationId: 'jabal-rahmah');

      expect(p.statusOfDestination('jabal-noor'), VisitStatus.planned);
      expect(p.counters().planned, 2);
      expect(p.counters().visited, 0);

      p.setStatus('a', VisitStatus.visited, at: DateTime(2026, 11, 1, 9), lat: 21.45, lng: 39.85);
      expect(p.statusOfDestination('jabal-noor'), VisitStatus.visited);
      final a = p.visits.firstWhere((v) => v.id == 'a');
      expect(a.visitedAt, isNotNull);
      expect(a.checkinLat, 21.45);
      expect(p.counters().visited, 1);
      expect(p.counters().planned, 1);

      // Undo back to planned clears visit evidence.
      p.setStatus('a', VisitStatus.planned);
      expect(p.statusOfDestination('jabal-noor'), VisitStatus.planned);
      expect(p.visits.firstWhere((v) => v.id == 'a').visitedAt, isNull);

      p.setStatus('b', VisitStatus.skipped);
      expect(p.statusOfDestination('jabal-rahmah'), VisitStatus.skipped);
      expect(p.counters().skipped, 1);
    });

    test('unplanned destination reports notPlanned', () {
      final p = TripPlanner();
      expect(p.statusOfDestination('anything'), VisitStatus.notPlanned);
    });

    test('nextPlanned returns first planned visit of the day', () {
      final p = TripPlanner();
      final d = p.addDay(id: 'd1', date: DateTime(2026, 11, 1), city: 'makkah');
      p.addVisit(id: 'a', dayId: d.id, destinationId: 'x', time: '08:00');
      p.addVisit(id: 'b', dayId: d.id, destinationId: 'y', time: '11:00');
      p.setStatus('a', VisitStatus.visited);
      expect(p.nextPlanned(DateTime(2026, 11, 1))?.id, 'b');
    });
  });

  group('TripPlanner — route suggestion', () {
    test('greedy nearest-neighbour suggests sensible order without mutating', () {
      final p = TripPlanner();
      final d = p.addDay(id: 'd1', date: DateTime(2026, 11, 1), city: 'madinah');
      p.addVisit(id: 'far', dayId: d.id, destinationId: 'uhud');
      p.addVisit(id: 'near', dayId: d.id, destinationId: 'quba');
      p.addVisit(id: 'mid', dayId: d.id, destinationId: 'qiblatain');

      final coords = {
        'quba': (lat: 24.4393, lng: 39.6172),
        'qiblatain': (lat: 24.4842, lng: 39.5789),
        'uhud': (lat: 24.5008, lng: 39.6128),
      };
      final ordered = p.suggestOrder('d1',
          startLat: 24.4300, startLng: 39.6100, coordsOf: (id) => coords[id]!);
      expect(ordered.map((v) => v.destinationId), ['quba', 'qiblatain', 'uhud']);
      // Original order untouched (suggestion only).
      expect(p.visitsOf('d1').map((v) => v.id), ['far', 'near', 'mid']);
    });
  });

  group('Serialization round-trips (offline persistence)', () {
    test('TripDay and TripVisit survive toMap/fromMap', () {
      final day = TripDay(id: 'd1', date: DateTime(2026, 11, 7), city: 'taif', startPoint: 'Hotel');
      final day2 = TripDay.fromMap(day.toMap());
      expect(day2.id, 'd1');
      expect(day2.city, 'taif');
      expect(day2.startPoint, 'Hotel');
      expect(day2.date, DateTime(2026, 11, 7));

      final v = TripVisit(
          id: 'v1',
          dayId: 'd1',
          destinationId: 'taif',
          time: '09:30',
          sortOrder: 2,
          status: VisitStatus.visited,
          visitedAt: DateTime(2026, 11, 7, 9, 45),
          notes: 'Beautiful weather',
          checkinLat: 21.2854,
          checkinLng: 40.4248);
      final v2 = TripVisit.fromMap(v.toMap());
      expect(v2.status, VisitStatus.visited);
      expect(v2.time, '09:30');
      expect(v2.notes, 'Beautiful weather');
      expect(v2.checkinLat, closeTo(21.2854, 1e-9));
    });
  });
}
