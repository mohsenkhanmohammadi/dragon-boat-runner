import '../config.dart';
import '../models/models.dart';

const drummerSeat = 'D';
const steerSeat = 'S';

/// Small boat: 5 rows (10 paddlers) + drummer + steerer.
/// Large boat: 10 rows (20 paddlers) + drummer + steerer.
class BoatSpec {
  const BoatSpec._(this.id, this.rows);
  final String id;
  final int rows;

  static const small = BoatSpec._('small', AppConfig.smallBoatRows);
  static const large = BoatSpec._('large', AppConfig.largeBoatRows);

  int get paddlers => rows * 2;
  int get capacity => paddlers + 2;

  static BoatSpec byId(String id) => id == 'large' ? large : small;

  /// Up to [small.capacity] attendees -> small boat, otherwise the large one.
  static BoatSpec forAttendees(int n) => n <= small.capacity ? small : large;

  static String left(int row) => 'L$row';
  static String right(int row) => 'R$row';

  List<String> get allSeats => [
        drummerSeat,
        for (var r = 1; r <= rows; r++) ...[left(r), right(r)],
        steerSeat,
      ];

  bool hasSeat(String id) => allSeats.contains(id);

  /// Left/right side of a paddle seat (null for drummer / steerer).
  static Side? sideOf(String seat) => seat.startsWith('L')
      ? Side.left
      : seat.startsWith('R')
          ? Side.right
          : null;

  static int? rowOf(String seat) =>
      seat.length > 1 ? int.tryParse(seat.substring(1)) : null;
}

class SeatCandidate {
  const SeatCandidate(this.uid, {this.weight, this.pref});
  final String uid;
  final double? weight;
  final Side? pref;
}

class SeatingResult {
  SeatingResult(this.seats, this.reserves);
  final Map<String, String> seats; // seatId -> uid
  final List<String> reserves; // attendees without a seat
}

/// Rows ordered from the middle of the boat outwards. Heavy paddlers go to
/// the middle, which keeps the boat balanced front/back.
List<int> _middleOut(Iterable<int> rows, int total) {
  final c = (total + 1) / 2;
  final list = rows.toList()
    ..sort((a, b) {
      final da = (a - c).abs(), db = (b - c).abs();
      return da == db ? a.compareTo(b) : da.compareTo(db);
    });
  return list;
}

/// Automatic seating, balanced by weight.
///
/// * [fixed] seats (placed by the admin) are kept.
/// * Side preferences (left/right) are respected when there is room.
/// * Members with a weight are balanced left/right (greedy + swap
///   improvement) and front/back (heaviest in the middle rows).
/// * Members without a weight are placed afterwards into the free seats.
/// * When there are more people than paddle seats, the remaining ones fill
///   drummer and steerer, everyone else becomes a reserve.
SeatingResult autoSeat(BoatSpec boat, List<SeatCandidate> people,
    {Map<String, String> fixed = const {}}) {
  final seats = <String, String>{};
  final placed = <String>{};
  final byUid = {for (final p in people) p.uid: p};

  fixed.forEach((seat, uid) {
    if (boat.hasSeat(seat) && byUid.containsKey(uid) && !placed.contains(uid)) {
      seats[seat] = uid;
      placed.add(uid);
    }
  });

  final freeLeftRows = [
    for (var r = 1; r <= boat.rows; r++)
      if (!seats.containsKey(BoatSpec.left(r))) r
  ];
  final freeRightRows = [
    for (var r = 1; r <= boat.rows; r++)
      if (!seats.containsKey(BoatSpec.right(r))) r
  ];
  final paddleCap = freeLeftRows.length + freeRightRows.length;

  final free = people.where((p) => !placed.contains(p.uid)).toList();
  final weighted = free.where((p) => p.weight != null).toList()
    ..sort((a, b) => b.weight!.compareTo(a.weight!));
  final unweighted = free.where((p) => p.weight == null).toList();

  // Who paddles? Everybody, as long as there are seats. Overflow (lightest
  // first, people without weight before them) goes to drummer/steerer.
  final paddlers = [...weighted, ...unweighted];
  final overflow = <SeatCandidate>[];
  while (paddlers.length > paddleCap) {
    overflow.add(paddlers.removeLast());
  }

  // ------------------------------------------------ left / right split
  double weightOf(String seat) => byUid[seats[seat]]?.weight ?? 0;
  double lw = 0, rw = 0;
  for (var r = 1; r <= boat.rows; r++) {
    lw += weightOf(BoatSpec.left(r));
    rw += weightOf(BoatSpec.right(r));
  }

  final left = <SeatCandidate>[];
  final right = <SeatCandidate>[];

  void put(SeatCandidate p, {required bool byWeight}) {
    final canL = left.length < freeLeftRows.length;
    final canR = right.length < freeRightRows.length;
    Side side;
    if (p.pref == Side.left && canL) {
      side = Side.left;
    } else if (p.pref == Side.right && canR) {
      side = Side.right;
    } else if (!canL) {
      side = Side.right;
    } else if (!canR) {
      side = Side.left;
    } else if (byWeight) {
      side = lw <= rw ? Side.left : Side.right;
    } else {
      side = left.length <= right.length ? Side.left : Side.right;
    }
    if (side == Side.left) {
      left.add(p);
      lw += p.weight ?? 0;
    } else {
      right.add(p);
      rw += p.weight ?? 0;
    }
  }

  for (final p in paddlers.where((p) => p.weight != null)) {
    put(p, byWeight: true);
  }

  // Improve balance by swapping people without a conflicting preference.
  for (var guard = 0; guard < 400; guard++) {
    final diff = lw - rw;
    var best = diff.abs();
    int bi = -1, bj = -1;
    for (var i = 0; i < left.length; i++) {
      final a = left[i];
      if (a.weight == null || a.pref == Side.left) continue;
      for (var j = 0; j < right.length; j++) {
        final b = right[j];
        if (b.weight == null || b.pref == Side.right) continue;
        final d = a.weight! - b.weight!;
        final nd = (diff - 2 * d).abs();
        if (nd + 0.01 < best) {
          best = nd;
          bi = i;
          bj = j;
        }
      }
    }
    if (bi < 0) break;
    final a = left[bi], b = right[bj];
    left[bi] = b;
    right[bj] = a;
    lw += b.weight! - a.weight!;
    rw += a.weight! - b.weight!;
  }

  for (final p in paddlers.where((p) => p.weight == null)) {
    put(p, byWeight: false);
  }

  // ------------------------------------------------ front / back
  void fill(List<SeatCandidate> side, List<int> freeRows,
      String Function(int) seatId) {
    final heavy = side.where((p) => p.weight != null).toList()
      ..sort((a, b) => b.weight!.compareTo(a.weight!));
    final rest = side.where((p) => p.weight == null).toList();
    final rows = _middleOut(freeRows, boat.rows);
    var k = 0;
    for (final p in [...heavy, ...rest]) {
      seats[seatId(rows[k++])] = p.uid;
    }
  }

  fill(left, freeLeftRows, BoatSpec.left);
  fill(right, freeRightRows, BoatSpec.right);

  // ------------------------------------------------ drummer / steerer
  final reserves = <String>[];
  for (final p in overflow) {
    if (!seats.containsKey(drummerSeat)) {
      seats[drummerSeat] = p.uid;
    } else if (!seats.containsKey(steerSeat)) {
      seats[steerSeat] = p.uid;
    } else {
      reserves.add(p.uid);
    }
  }
  return SeatingResult(seats, reserves);
}

class BalanceStats {
  BalanceStats(
      {required this.left,
      required this.right,
      required this.front,
      required this.back,
      required this.unknown});
  final double left, right, front, back;
  final int unknown; // seated people without weight
}

BalanceStats balanceOf(
    BoatSpec boat, Map<String, String> seats, Map<String, double?> weights) {
  double l = 0, r = 0, f = 0, b = 0;
  var unknown = 0;
  final half = boat.rows / 2;
  seats.forEach((seat, uid) {
    final w = weights[uid];
    if (w == null) {
      unknown++;
      return;
    }
    final side = BoatSpec.sideOf(seat);
    if (side == Side.left) l += w;
    if (side == Side.right) r += w;
    final row = BoatSpec.rowOf(seat);
    if (seat == drummerSeat || (row != null && row <= half)) {
      f += w;
    } else {
      b += w;
    }
  });
  return BalanceStats(left: l, right: r, front: f, back: b, unknown: unknown);
}
