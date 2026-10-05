import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/seating.dart';
import '../theme.dart';

/// Top view of the dragon boat: drummer at the bow, rows of two paddlers
/// (left / right), steerer at the stern. Seats placed by the admin are blue.
class BoatView extends StatelessWidget {
  const BoatView({
    super.key,
    required this.boat,
    required this.seats,
    required this.manual,
    required this.members,
    this.showWeights = false,
    this.onSeatTap,
    this.highlightUid,
  });

  final BoatSpec boat;
  final Map<String, String> seats;
  final Set<String> manual;
  final Map<String, Member> members;
  final bool showWeights;
  final void Function(String seatId)? onSeatTap;
  final String? highlightUid;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CustomPaint(
      painter: _HullPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 70, 28, 56),
        child: Column(children: [
          Row(children: [
            const Spacer(),
            Expanded(flex: 2, child: _seat(context, drummerSeat, s.t('drummer'))),
            const Spacer(),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
                child: Center(
                    child: Text(s.t('left'),
                        style: Theme.of(context).textTheme.labelSmall))),
            const SizedBox(width: 26),
            Expanded(
                child: Center(
                    child: Text(s.t('right'),
                        style: Theme.of(context).textTheme.labelSmall))),
          ]),
          for (var r = 1; r <= boat.rows; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: _seat(context, BoatSpec.left(r), null)),
                SizedBox(
                  width: 26,
                  child: Center(
                    child: Text('$r',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6B3F12))),
                  ),
                ),
                Expanded(child: _seat(context, BoatSpec.right(r), null)),
              ]),
            ),
          const SizedBox(height: 6),
          Row(children: [
            const Spacer(),
            Expanded(flex: 2, child: _seat(context, steerSeat, s.t('steerer'))),
            const Spacer(),
          ]),
        ]),
      ),
    );
  }

  Widget _seat(BuildContext context, String seatId, String? role) {
    final uid = seats[seatId];
    final m = uid == null ? null : members[uid];
    final isManual = manual.contains(seatId);
    final isMe = uid != null && uid == highlightUid;
    final bg = isManual
        ? adminBlue
        : uid == null
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.white;
    final fg = isManual ? Colors.white : Colors.black87;
    final name = uid == null ? '—' : (m?.shortName ?? '?');
    final weight = (showWeights && m?.weight != null)
        ? '${m!.weight!.toStringAsFixed(0)} kg'
        : null;
    return Material(
      color: bg,
      elevation: uid == null ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: isMe ? dragonGold : const Color(0x33000000),
            width: isMe ? 3 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSeatTap == null ? null : () => onSeatTap!(seatId),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (role != null)
                  Text(role,
                      style: TextStyle(
                          fontSize: 10,
                          color: fg.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600)),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: fg, fontSize: 13)),
                if (weight != null && role == null)
                  Text(weight,
                      style: TextStyle(
                          fontSize: 11, color: fg.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HullPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hull = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * 0.95, h * 0.04, w, h * 0.12, w * 0.98, h * 0.22)
      ..lineTo(w * 0.98, h * 0.86)
      ..cubicTo(w * 0.97, h * 0.97, w * 0.7, h, w / 2, h)
      ..cubicTo(w * 0.3, h, w * 0.03, h * 0.97, w * 0.02, h * 0.86)
      ..lineTo(w * 0.02, h * 0.22)
      ..cubicTo(0, h * 0.12, w * 0.05, h * 0.04, w / 2, 0)
      ..close();
    canvas.drawPath(
        hull,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFE9C38F), Color(0xFFD9A066)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        hull,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF8B4513));
    // dragon scales along the rails
    final scale = Paint()..color = dragonRed.withValues(alpha: 0.85);
    for (double y = h * 0.2; y < h * 0.86; y += 16) {
      canvas.drawCircle(Offset(w * 0.02 + 3, y), 4, scale);
      canvas.drawCircle(Offset(w * 0.98 - 3, y), 4, scale);
    }
    // dragon head at the bow
    final head = Paint()..color = dragonRed;
    canvas.drawCircle(Offset(w / 2, 26), 18, head);
    canvas.drawCircle(
        Offset(w / 2 - 7, 22), 3.5, Paint()..color = dragonGold);
    canvas.drawCircle(
        Offset(w / 2 + 7, 22), 3.5, Paint()..color = dragonGold);
    // tail at the stern
    final tail = Path()
      ..moveTo(w / 2 - 14, h - 6)
      ..lineTo(w / 2, h + 14)
      ..lineTo(w / 2 + 14, h - 6)
      ..close();
    canvas.drawPath(tail, head);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
