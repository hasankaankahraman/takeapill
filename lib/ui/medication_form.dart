import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/db/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../features/schedule/domain/rule_codec.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'labels.dart';
import 'providers.dart';
import 'theme.dart';
import 'widgets.dart';

enum _Kind { daily, interval, asNeeded }

class _SlotDraft {
  _SlotDraft({
    this.anchor = TimingAnchor.fixed,
    this.minutes = 8 * 60,
    this.offset = 0,
    this.food = FoodRelation.none,
  });

  TimingAnchor anchor;
  int minutes;
  int offset;
  FoodRelation food;

  DoseSlot toSlot() => anchor == TimingAnchor.fixed
      ? DoseSlot.fixed(minutes, food: food)
      : DoseSlot.anchored(anchor, offsetMinutes: offset, food: food);
}

const _palette = [
  0xFF3B82F6,
  0xFF10B981,
  0xFFF59E0B,
  0xFFEF4444,
  0xFF8B5CF6,
  0xFFEC4899,
  0xFF14B8A6,
  0xFF64748B,
];

class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({super.key, this.medicationId});

  final int? medicationId;

  @override
  ConsumerState<MedicationFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _purpose = TextEditingController();
  final _notes = TextEditingController();
  String _form = 'pill';
  int _color = _palette.first;

  _Kind _kind = _Kind.daily;
  final List<_SlotDraft> _slots = [_SlotDraft()];
  Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  int _everyNDays = 1;
  int _everyHours = 8;
  int _firstMinutes = 8 * 60;
  FoodRelation _intervalFood = FoodRelation.none;
  int? _maxPerDay;
  DateTime _start = _today();
  DateTime? _end;

  bool _loading = true;
  bool _saving = false;

  static DateTime _today() {
    final n = clock.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.medicationId;
    if (id != null) {
      final r = await ref.read(dbProvider).medicationWithRule(id);
      if (r != null) {
        final (m, json) = r;
        _name.text = m.name;
        _strength.text = m.strength;
        _purpose.text = m.purpose;
        _notes.text = m.notes;
        _form = m.form;
        _color = m.color;
        final rule = decodeRule(json);
        _start = rule.startDate;
        _end = rule.endDate;
        switch (rule) {
          case DailyRule():
            _kind = _Kind.daily;
            _weekdays = {...rule.weekdays};
            _everyNDays = rule.everyNDays;
            _slots
              ..clear()
              ..addAll([
                for (final s in rule.slots)
                  _SlotDraft(
                    anchor: s.anchor,
                    minutes: s.fixedMinutes,
                    offset: s.offsetMinutes,
                    food: s.food,
                  ),
              ]);
          case IntervalRule():
            _kind = _Kind.interval;
            _everyHours = rule.everyHours;
            _firstMinutes = rule.firstMinutes;
            _intervalFood = rule.food;
          case AsNeededRule():
            _kind = _Kind.asNeeded;
            _maxPerDay = rule.maxPerDay;
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _purpose.dispose();
    _notes.dispose();
    super.dispose();
  }

  ScheduleRule _buildRule() => switch (_kind) {
    _Kind.daily => DailyRule(
      startDate: _start,
      endDate: _end,
      weekdays: _weekdays,
      everyNDays: _everyNDays,
      slots: [for (final s in _slots) s.toSlot()],
    ),
    _Kind.interval => IntervalRule(
      startDate: _start,
      endDate: _end,
      everyHours: _everyHours,
      firstMinutes: _firstMinutes,
      food: _intervalFood,
    ),
    _Kind.asNeeded => AsNeededRule(
      startDate: _start,
      endDate: _end,
      maxPerDay: _maxPerDay,
    ),
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kind == _Kind.daily && _weekdays.isEmpty) {
      _snack('En az bir gün seç.');
      return;
    }
    if (_kind == _Kind.daily && _slots.isEmpty) {
      _snack('En az bir doz saati ekle.');
      return;
    }
    if (_end != null && _end!.isBefore(_start)) {
      _snack('Bitiş tarihi başlangıçtan önce olamaz.');
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final med = MedicationsCompanion(
      name: Value(_name.text.trim()),
      form: Value(_form),
      strength: Value(_strength.text.trim()),
      purpose: Value(_purpose.text.trim()),
      notes: Value(_notes.text.trim()),
      color: Value(_color),
    );
    final json = encodeRule(_buildRule());
    final id = widget.medicationId;
    if (id == null) {
      await db.addMedication(med, json);
    } else {
      await db.updateMedication(id, med, json);
    }
    await syncNotifications(db);
    if (mounted) context.pop();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<int?> _pickTime(int current) async {
    final t = await showTimePicker(
      context: context,
      initialTime: toTimeOfDay(current),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kapat',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.medicationId == null ? 'Yeni ilaç' : 'İlacı düzenle',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Kaydet'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _Section(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  style: _inputStyle,
                  decoration: const InputDecoration(labelText: 'İlaç adı'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'İlaç adı gerekli'
                      : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _strength,
                        style: _inputStyle,
                        decoration: const InputDecoration(
                          labelText: 'Doz / güç',
                          hintText: '500 mg',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _purpose,
                        style: _inputStyle,
                        decoration: const InputDecoration(
                          labelText: 'Ne için kullanılıyor?',
                          hintText: 'Tansiyon…',
                        ),
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  minLines: 1,
                  style: _inputStyle,
                  decoration: const InputDecoration(
                    labelText: 'Notlar',
                    hintText: 'Doktor talimatı, uyarılar…',
                  ),
                ),
                const _FieldLabel('Form'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in formLabels.entries)
                      ChoicePill(
                        label: e.value,
                        selected: _form == e.key,
                        onTap: () => setState(() => _form = e.key),
                      ),
                  ],
                ),
                const _FieldLabel('Renk'),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final col in _palette)
                      Semantics(
                        button: true,
                        selected: _color == col,
                        label: 'Renk',
                        child: GestureDetector(
                          onTap: () => setState(() => _color = col),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Color(col),
                              shape: BoxShape.circle,
                              border: Border.all(color: c.surface, width: 3),
                              boxShadow: [
                                if (_color == col)
                                  BoxShadow(color: Color(col), spreadRadius: 2),
                              ],
                            ),
                            child: _color == col
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Zamanlama',
              children: [
                Segmented<_Kind>(
                  options: const {
                    _Kind.daily: 'Günlük',
                    _Kind.interval: 'Her X saat',
                    _Kind.asNeeded: 'Gerekirse',
                  },
                  selected: _kind,
                  onChanged: (k) => setState(() => _kind = k),
                ),
                if (_kind == _Kind.daily) ..._dailySection(),
                if (_kind == _Kind.interval) ..._intervalSection(),
                if (_kind == _Kind.asNeeded) _asNeededSection(),
              ],
            ),
            const SizedBox(height: 16),
            GroupPanel(
              children: [
                PanelRow(
                  title: 'Başlangıç',
                  trailing: Tag(_fmtDate(_start)),
                  onTap: () async {
                    final d = await _pickDate(_start);
                    if (d != null) setState(() => _start = d);
                  },
                ),
                PanelRow(
                  title: 'Bitiş (kür süresi)',
                  trailing: _end == null
                      ? Text(
                          'Süresiz',
                          style: TextStyle(
                            color: c.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tag(_fmtDate(_end!)),
                            IconButton(
                              tooltip: 'Bitişi kaldır',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() => _end = null),
                            ),
                          ],
                        ),
                  onTap: () async {
                    final d = await _pickDate(_end ?? _start);
                    if (d != null) setState(() => _end = d);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  static const _inputStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  List<Widget> _dailySection() => [
    for (var i = 0; i < _slots.length; i++) _slotCard(i),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () =>
            setState(() => _slots.add(_SlotDraft(minutes: 20 * 60))),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Doz saati ekle'),
      ),
    ),
    const _FieldLabel('Hangi günler?'),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var d = 1; d <= 7; d++)
          ChoicePill(
            circle: true,
            label: weekdayShort[d - 1],
            selected: _weekdays.contains(d),
            onTap: () => setState(() {
              _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d);
            }),
          ),
      ],
    ),
    DropdownButtonFormField<int>(
      initialValue: _everyNDays,
      decoration: const InputDecoration(labelText: 'Sıklık'),
      items: [
        const DropdownMenuItem(value: 1, child: Text('Her gün')),
        for (var n = 2; n <= 7; n++)
          DropdownMenuItem(value: n, child: Text('$n günde bir')),
      ],
      onChanged: (v) => setState(() => _everyNDays = v ?? 1),
    ),
  ];

  Widget _slotCard(int i) {
    final s = _slots[i];
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        spacing: 10,
        children: [
          Row(
            children: [
              Text(
                '${i + 1}. doz',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: c.onAccentSoft,
                ),
              ),
              const Spacer(),
              if (s.anchor == TimingAnchor.fixed)
                Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final m = await _pickTime(s.minutes);
                      if (m != null) setState(() => s.minutes = m);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        fmtMinutes(s.minutes),
                        semanticsLabel: 'Saat ${fmtMinutes(s.minutes)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_slots.length > 1)
                IconButton(
                  tooltip: 'Dozu sil',
                  icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                  onPressed: () => setState(() => _slots.removeAt(i)),
                ),
            ],
          ),
          _dropdown<TimingAnchor>(
            label: 'Ne zaman',
            value: s.anchor,
            items: anchorLabels,
            onChanged: (v) => setState(() => s.anchor = v),
          ),
          if (s.anchor != TimingAnchor.fixed)
            _dropdown<int>(
              label: 'Fark',
              value: s.offset,
              items: {
                for (final o in const [-60, -30, -15, 0, 15, 30, 60, 90])
                  o: o == 0
                      ? 'Tam o anda'
                      : o < 0
                      ? '${-o} dk önce'
                      : '$o dk sonra',
              },
              onChanged: (v) => setState(() => s.offset = v),
            ),
          _dropdown<FoodRelation>(
            label: 'Yemekle ilişki',
            value: s.food,
            items: foodLabels,
            onChanged: (v) => setState(() => s.food = v),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    borderRadius: BorderRadius.circular(14),
    decoration: InputDecoration(labelText: label, fillColor: context.c.surface),
    items: [
      for (final e in items.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: (v) => v == null ? null : onChanged(v),
  );

  List<Widget> _intervalSection() => [
    DropdownButtonFormField<int>(
      initialValue: _everyHours,
      decoration: const InputDecoration(labelText: 'Kaç saatte bir'),
      items: [
        for (final h in const [2, 3, 4, 6, 8, 12])
          DropdownMenuItem(value: h, child: Text('$h saatte bir')),
      ],
      onChanged: (v) => setState(() => _everyHours = v ?? 8),
    ),
    Material(
      color: context.c.chip,
      borderRadius: BorderRadius.circular(14),
      child: PanelRow(
        title: 'İlk doz saati',
        trailing: Text(
          fmtMinutes(_firstMinutes),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.c.accent,
          ),
        ),
        onTap: () async {
          final m = await _pickTime(_firstMinutes);
          if (m != null) setState(() => _firstMinutes = m);
        },
      ),
    ),
    DropdownButtonFormField<FoodRelation>(
      initialValue: _intervalFood,
      decoration: const InputDecoration(labelText: 'Yemekle ilişki'),
      items: [
        for (final e in foodLabels.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) => setState(() => _intervalFood = v ?? _intervalFood),
    ),
  ];

  Widget _asNeededSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Text(
        'Bu ilaç için otomatik hatırlatma yapılmaz. '
        'Günlük üst sınırı not olarak belirleyebilirsin.',
        style: TextStyle(color: context.c.muted, height: 1.4),
      ),
      DropdownButtonFormField<int?>(
        initialValue: _maxPerDay,
        decoration: const InputDecoration(labelText: 'Günlük en fazla'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Belirtilmedi')),
          for (var n = 1; n <= 8; n++)
            DropdownMenuItem(value: n, child: Text('$n doz')),
        ],
        onChanged: (v) => setState(() => _maxPerDay = v),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (title != null)
          Text(
            title!,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ...children,
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.c.muted,
      ),
    ),
  );
}
