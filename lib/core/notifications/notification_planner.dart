import '../../features/schedule/domain/schedule_models.dart';

enum NotifKind { lead, due, nag, snooze }

class NotificationPrefs {
  const NotificationPrefs({
    this.leadMinutes = 5,
    this.nagMinutes = 10,
    this.snoozeMinutes = 10,
  });

  /// Dozdan kaç dk önce haber verilsin; 0 = kapalı.
  final int leadMinutes;

  /// Doz alınmadıysa kaç dk sonra tekrar hatırlat; 0 = kapalı.
  final int nagMinutes;
  final int snoozeMinutes;

  NotificationPrefs copyWith({int? lead, int? nag, int? snooze}) =>
      NotificationPrefs(
        leadMinutes: lead ?? leadMinutes,
        nagMinutes: nag ?? nagMinutes,
        snoozeMinutes: snooze ?? snoozeMinutes,
      );
}

/// Ertelenmiş dozlar: (ilaç, doz zamanı) → yeniden hatırlatılacağı an.
typedef Snoozes = Map<(int, DateTime), DateTime>;

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.at,
    required this.kind,
    required this.medicationId,
    required this.medicationName,
    required this.doseAt,
    required this.food,
  });

  final int id;
  final DateTime at;
  final NotifKind kind;
  final int medicationId;
  final String medicationName;
  final DateTime doseAt;
  final FoodRelation food;

  String get payload => encodePayload(medicationId, doseAt);
}

String encodePayload(int medicationId, DateTime doseAt) =>
    '$medicationId|${doseAt.millisecondsSinceEpoch}';

(int, DateTime)? decodePayload(String? payload) {
  final parts = payload?.split('|');
  if (parts == null || parts.length != 2) return null;
  final id = int.tryParse(parts[0]);
  final ms = int.tryParse(parts[1]);
  if (id == null || ms == null) return null;
  return (id, DateTime.fromMillisecondsSinceEpoch(ms));
}

/// Kararlı 31-bit kimlik (FNV-1a). Aynı doz her zaman aynı kimliği alır; böylece
/// yeniden planlama ve iptal tutarlı çalışır.
int notificationId(int medicationId, DateTime doseAt, NotifKind kind) {
  var h = 0x811c9dc5;
  for (final c
      in '$medicationId|${doseAt.millisecondsSinceEpoch}|${kind.name}'
          .codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// iOS en fazla 64 bekleyen yerel bildirime izin verir. En yakın [limit]
/// bildirimi seçer; kalanlar bir sonraki yeniden planlamada eklenir.
/// Ertelenmiş bir doz yalnızca erteleme bildirimini alır.
List<PlannedNotification> planNotifications({
  required List<(PlannedDose, String)> doses,
  required DateTime now,
  NotificationPrefs prefs = const NotificationPrefs(),
  Snoozes snoozes = const {},
  int limit = 60,
}) {
  final out = <PlannedNotification>[];

  void add(PlannedDose d, String name, NotifKind kind, DateTime at) {
    if (!at.isAfter(now)) return;
    out.add(
      PlannedNotification(
        id: notificationId(d.medicationId, d.scheduledAt, kind),
        at: at,
        kind: kind,
        medicationId: d.medicationId,
        medicationName: name,
        doseAt: d.scheduledAt,
        food: d.food,
      ),
    );
  }

  for (final (d, name) in doses) {
    final snoozedUntil = snoozes[(d.medicationId, d.scheduledAt)];
    if (snoozedUntil != null && snoozedUntil.isAfter(now)) {
      add(d, name, NotifKind.snooze, snoozedUntil);
      continue;
    }
    if (prefs.leadMinutes > 0) {
      add(
        d,
        name,
        NotifKind.lead,
        d.scheduledAt.subtract(Duration(minutes: prefs.leadMinutes)),
      );
    }
    add(d, name, NotifKind.due, d.scheduledAt);
    if (prefs.nagMinutes > 0) {
      add(
        d,
        name,
        NotifKind.nag,
        d.scheduledAt.add(Duration(minutes: prefs.nagMinutes)),
      );
    }
  }

  out.sort((a, b) {
    final c = a.at.compareTo(b.at);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out.length > limit ? out.sublist(0, limit) : out;
}
