import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/db/app_database.dart';
import '../core/labels.dart';
import '../core/notifications/notification_service.dart';
import '../features/schedule/domain/rule_codec.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'form_rows.dart';
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

/// Doz birimleri; kayıtlı birim listede yoksa düzenlerken eklenir.
const _units = [
  'mg',
  'mcg',
  'g',
  'ml',
  'IU',
  '%',
  'tablet',
  'kapsül',
  'damla',
  'puf',
  'ölçek',
];

class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({super.key, this.medicationId});

  final int? medicationId;

  @override
  ConsumerState<MedicationFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<MedicationFormScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String _unit = _units.first;
  bool _nameMissing = false;
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
        // "500 mg" → miktar ve birim; sayıyla başlamıyorsa olduğu gibi kalır.
        final dose = RegExp(r'^([\d.,]+)\s*(.*)$')
            .firstMatch(m.strength.trim());
        if (dose != null) {
          _amount.text = dose[1]!;
          if (dose[2]!.isNotEmpty) _unit = dose[2]!;
        } else {
          _amount.text = m.strength;
          _unit = '';
        }
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
    _amount.dispose();
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
    if (_name.text.trim().isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
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
      strength: Value(
        _amount.text.trim().isEmpty
            ? ''
            : '${_amount.text.trim()} $_unit'.trim(),
      ),
      purpose: Value(_purpose.text.trim()),
      notes: Value(_notes.text.trim()),
      color: Value(_color),
    );
    final json = encodeRule(_buildRule());
    final id = widget.medicationId;
    try {
      if (id == null) {
        await db.addMedication(med, json);
      } else {
        await db.updateMedication(id, med, json);
      }
    } catch (e) {
      debugPrint('İlaç kaydedilemedi: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Kaydedilemedi. Lütfen tekrar dene.');
      return;
    }
    // Kayıt tamam; plan yenilenemese de form kapanır, açılışta tekrar denenir.
    await trySyncNotifications(db);
    if (mounted) context.pop();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Loading());
    }
    final c = context.c;
    final apple = isApple(context);
    final title = widget.medicationId == null ? 'Yeni ilaç' : 'İlacı düzenle';
    final side = math.max(20.0, (MediaQuery.sizeOf(context).width - 640) / 2);
    return Scaffold(
      appBar: AppBar(
        // iOS sayfası kendi üst boşluğunu bırakır.
        primary: !apple,
        leadingWidth: apple ? 96 : null,
        leading: apple
            ? CupertinoButton(
                padding: const EdgeInsets.only(left: 16),
                onPressed: () => context.pop(),
                child: Text(
                  'Vazgeç',
                  style: TextStyle(fontFamily: fontFamily, color: c.accent),
                ),
              )
            : IconButton(
                tooltip: 'Kapat',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.pop(),
              ),
        title: Text(title),
        actions: [
          if (apple)
            CupertinoButton(
              padding: const EdgeInsets.only(right: 16),
              onPressed: _saving ? null : _save,
              child: Text(
                'Kaydet',
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: c.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else ...[
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text(
                'Kaydet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: ListView(
        // Tablette form ortada dar bir sütun olarak kalır.
        padding: EdgeInsets.fromLTRB(
          side,
          0,
          side,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          FormSection(
            footer: _nameMissing
                ? const FormNote('İlaç adı gerekli', error: true)
                : null,
            children: [
              FieldRow(
                key: const ValueKey('name'),
                controller: _name,
                placeholder: 'İlaç adı',
                textCapitalization: TextCapitalization.words,
                // Medications.name sütununun sınırı.
                maxLength: 120,
                onChanged: (_) {
                  if (_nameMissing) setState(() => _nameMissing = false);
                },
              ),
              FieldRow(
                key: const ValueKey('amount'),
                controller: _amount,
                label: 'Doz',
                placeholder: '500',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                trailing: MenuButton<String>(
                  value: _unit,
                  options: {
                    for (final u in {..._units, _unit}) u: u.isEmpty ? '—' : u,
                  },
                  onChanged: (u) => setState(() => _unit = u),
                ),
              ),
              FieldRow(
                key: const ValueKey('purpose'),
                controller: _purpose,
                label: 'Ne için',
                placeholder: 'Tansiyon, takviye…',
              ),
              FieldRow(
                key: const ValueKey('notes'),
                controller: _notes,
                placeholder: 'Notlar: doktor talimatı, uyarılar…',
                maxLines: 4,
              ),
            ],
          ),
          FormSection(
            header: 'Görünüm',
            children: [
              MenuRow<String>(
                title: 'Form',
                value: _form,
                options: {
                  ...formLabels,
                  if (!formLabels.containsKey(_form)) _form: _form,
                },
                onChanged: (v) => setState(() => _form = v),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [for (final col in _palette) _swatch(col)],
                ),
              ),
            ],
          ),
          const SectionLabel('Zamanlama'),
          Segmented<_Kind>(
            options: const {
              _Kind.daily: 'Günlük',
              _Kind.interval: 'Her X saat',
              _Kind.asNeeded: 'Gerekirse',
            },
            selected: _kind,
            onChanged: (k) => setState(() => _kind = k),
          ),
          ...switch (_kind) {
            _Kind.daily => _dailySection(),
            _Kind.interval => _intervalSection(),
            _Kind.asNeeded => _asNeededSection(),
          },
          FormSection(
            header: 'Süre',
            footer: _end == null
                ? const FormNote('Bitiş tarihi yoksa süresiz devam eder.')
                : null,
            children: [
              DateRow(
                title: 'Başlangıç',
                date: _start,
                onChanged: (d) => setState(() => _start = d),
              ),
              SwitchRow(
                title: 'Bitiş tarihi (kür)',
                value: _end != null,
                onChanged: (on) => setState(
                  () => _end = on ? _start.add(const Duration(days: 7)) : null,
                ),
              ),
              if (_end case final end?)
                DateRow(
                  title: 'Bitiş',
                  date: end,
                  onChanged: (d) => setState(() => _end = d),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatch(int col) => Semantics(
    button: true,
    selected: _color == col,
    label: 'Renk',
    child: GestureDetector(
      onTap: () => setState(() => _color = col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Color(col),
          shape: BoxShape.circle,
          border: Border.all(color: context.c.surface, width: 2.5),
          boxShadow: [
            if (_color == col) BoxShadow(color: Color(col), spreadRadius: 2),
          ],
        ),
        child: _color == col
            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
            : null,
      ),
    ),
  );

  static const _offsets = [-60, -30, -15, 0, 15, 30, 60, 90];

  List<Widget> _dailySection() => [
    for (var i = 0; i < _slots.length; i++) _slotSection(i),
    const SizedBox(height: 12),
    GroupPanel(
      children: [
        PanelRow(
          title: 'Doz saati ekle',
          leading: Icon(
            isApple(context)
                ? CupertinoIcons.add_circled_solid
                : Icons.add_circle_rounded,
            color: context.c.accent,
          ),
          onTap: () => setState(() => _slots.add(_SlotDraft(minutes: 20 * 60))),
        ),
      ],
    ),
    FormSection(
      header: 'Hangi günler?',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 1; d <= 7; d++)
                ChoicePill(
                  circle: true,
                  label: weekdayShort[d - 1],
                  selected: _weekdays.contains(d),
                  onTap: () => setState(() {
                    _weekdays.contains(d)
                        ? _weekdays.remove(d)
                        : _weekdays.add(d);
                  }),
                ),
            ],
          ),
        ),
        MenuRow<int>(
          title: 'Sıklık',
          value: _everyNDays,
          options: {
            1: 'Her gün',
            for (var n = 2; n <= 7; n++) n: '$n günde bir',
          },
          onChanged: (v) => setState(() => _everyNDays = v),
        ),
      ],
    ),
  ];

  Widget _slotSection(int i) {
    final s = _slots[i];
    return FormSection(
      header: '${i + 1}. doz',
      action: _slots.length > 1
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => setState(() => _slots.removeAt(i)),
                child: const Text('Dozu sil'),
              ),
            )
          : null,
      children: [
        MenuRow<TimingAnchor>(
          title: 'Ne zaman',
          value: s.anchor,
          options: anchorLabels,
          onChanged: (v) => setState(() => s.anchor = v),
        ),
        if (s.anchor == TimingAnchor.fixed)
          TimeRow(
            title: 'Saat',
            minutes: s.minutes,
            onChanged: (m) => setState(() => s.minutes = m),
          )
        else
          MenuRow<int>(
            title: 'Fark',
            value: s.offset,
            options: {
              for (final o in {..._offsets, s.offset})
                o: o == 0
                    ? 'Tam o anda'
                    : o < 0
                    ? '${-o} dk önce'
                    : '$o dk sonra',
            },
            onChanged: (v) => setState(() => s.offset = v),
          ),
        MenuRow<FoodRelation>(
          title: 'Yemekle ilişki',
          value: s.food,
          options: foodLabels,
          onChanged: (v) => setState(() => s.food = v),
        ),
      ],
    );
  }

  List<Widget> _intervalSection() => [
    FormSection(
      children: [
        MenuRow<int>(
          title: 'Sıklık',
          value: _everyHours,
          options: {
            for (final h in {2, 3, 4, 6, 8, 12, _everyHours})
              h: '$h saatte bir',
          },
          onChanged: (v) => setState(() => _everyHours = v),
        ),
        TimeRow(
          title: 'İlk doz',
          minutes: _firstMinutes,
          onChanged: (m) => setState(() => _firstMinutes = m),
        ),
        MenuRow<FoodRelation>(
          title: 'Yemekle ilişki',
          value: _intervalFood,
          options: foodLabels,
          onChanged: (v) => setState(() => _intervalFood = v),
        ),
      ],
    ),
  ];

  List<Widget> _asNeededSection() => [
    FormSection(
      footer: const FormNote(
        'Bu ilaç için otomatik hatırlatma yapılmaz. Günlük üst sınırı '
        'not olarak belirleyebilirsin.',
      ),
      children: [
        MenuRow<int?>(
          title: 'Günlük en fazla',
          value: _maxPerDay,
          options: {
            null: 'Belirtilmedi',
            for (var n = 1; n <= 8; n++) n: '$n doz',
          },
          onChanged: (v) => setState(() => _maxPerDay = v),
        ),
      ],
    ),
  ];
}
