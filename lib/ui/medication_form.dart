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
import 'med_icons.dart';
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

/// Sihirbazın adımları: başlık, açıklama ve adım çubuğundaki kısa ad.
const _steps = [
  ('İlaç', 'Hangi ilaç?', 'Adını yaz ve formunu seç.'),
  (
    'Doz',
    'Ne kadar?',
    'Dozu ve ne için kullandığını gir; ilacın bu renkle görünür.',
  ),
  (
    'Zamanlama',
    'Ne zaman?',
    'Belirli saatler, yemek zamanları ya da saat aralığıyla planla.',
  ),
  (
    'Süre',
    'Ne kadar süre?',
    'Kür ise bitiş tarihi ekle; doktorunun talimatını da not edebilirsin.',
  ),
];

class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({
    super.key,
    this.medicationId,
    this.initialStep = 0,
  });

  final int? medicationId;

  /// Açılıştaki adım; düzenlerken doğrudan bir adıma gitmek için.
  final int initialStep;

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

  late int _step = widget.initialStep.clamp(0, _steps.length - 1);
  late final _pages = PageController(initialPage: _step);

  bool _loading = true;
  bool _saving = false;

  bool get _editing => widget.medicationId != null;
  bool get _last => _step == _steps.length - 1;

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
    _pages.dispose();
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

  /// Adımın alanları geçerliyse true; değilse hatayı gösterir.
  bool _check(int step) {
    switch (step) {
      case 0 when _name.text.trim().isEmpty:
        setState(() => _nameMissing = true);
        return false;
      case 2 when _kind == _Kind.daily && _weekdays.isEmpty:
        _snack('En az bir gün seç.');
        return false;
      case 2 when _kind == _Kind.daily && _slots.isEmpty:
        _snack('En az bir doz saati ekle.');
        return false;
      case 3 when _end != null && _end!.isBefore(_start):
        _snack('Bitiş tarihi başlangıçtan önce olamaz.');
        return false;
    }
    return true;
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(step);
    } else {
      _pages.animateToPage(
        step,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _next() {
    if (!_check(_step)) return;
    _last ? _save() : _go(_step + 1);
  }

  Future<void> _save() async {
    // Düzenlerken her adımdan kaydedilebilir; hatalı adıma geri dönülür.
    for (var i = 0; i < _steps.length; i++) {
      if (!_check(i)) {
        if (i != _step) _go(i);
        return;
      }
    }
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final med = MedicationsCompanion(
      name: Value(_name.text.trim()),
      form: Value(_form),
      strength: Value(_strength),
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

  String get _strength =>
      _amount.text.trim().isEmpty ? '' : '${_amount.text.trim()} $_unit'.trim();

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Loading());
    }
    final c = context.c;
    final apple = isApple(context);
    final title = _editing ? 'İlacı düzenle' : 'Yeni ilaç';
    final side = math.max(20.0, (MediaQuery.sizeOf(context).width - 640) / 2);
    return PopScope(
      // Geri hareketi önceki adıma döner; ilk adımda formu kapatır.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
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
            // Yeni ilaç son adımda kaydedilir; düzenlerken her adımda.
            if (_editing && apple)
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
            else if (_editing) ...[
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
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, 4, side, 0),
              child: _StepBar(
                step: _step,
                labels: [for (final s in _steps) s.$1],
                // Yeni ilaçta ileri atlanmaz; adımlar sırayla doğrulanır.
                canOpen: (i) => _editing || i < _step,
                onOpen: _go,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _page(0, side, _nameStep()),
                  _page(1, side, _doseStep()),
                  _page(2, side, _scheduleStep()),
                  _page(3, side, _durationStep()),
                ],
              ),
            ),
            _bottomBar(side),
          ],
        ),
      ),
    );
  }

  Widget _page(int i, double side, List<Widget> children) {
    final (_, heading, text) = _steps[i];
    return ListView(
      // Tablette form ortada dar bir sütun olarak kalır.
      padding: EdgeInsets.fromLTRB(side, 24, side, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Semantics(
          header: true,
          child: Text(
            heading,
            style: const TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(fontSize: 15, height: 1.35, color: context.c.muted),
        ),
        ...children,
      ],
    );
  }

  Widget _bottomBar(double side) {
    final c = context.c;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, 8, side, 0),
        child: Row(
          children: [
            if (_step > 0) ...[
              IconButton(
                tooltip: 'Geri',
                style: IconButton.styleFrom(
                  fixedSize: const Size(56, 56),
                  backgroundColor: c.surface,
                  foregroundColor: c.ink,
                  side: BorderSide(color: c.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _go(_step - 1),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _saving ? null : _next,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _last
                      ? const Text('Kaydet', key: ValueKey('save'))
                      : const Row(
                          key: ValueKey('next'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Devam'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. İlaç ---------------------------------------------------------------

  List<Widget> _nameStep() => [
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
          autofocus: !_editing,
          // Medications.name sütununun sınırı.
          maxLength: 120,
          onChanged: (_) {
            if (_nameMissing) setState(() => _nameMissing = false);
          },
        ),
      ],
    ),
    const SectionLabel('Form'),
    LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final w = (box.maxWidth - gap * 3) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final f in formLabels.keys) _formTile(f, w)],
        );
      },
    ),
  ];

  Widget _formTile(String form, double width) {
    final c = context.c;
    final selected = _form == form;
    final (bg, fg) = medTint(context, _color);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: selected
          ? BorderSide(color: fg, width: 2)
          : BorderSide(color: c.line),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: formLabels[form],
      child: ExcludeSemantics(
        child: Material(
          color: c.surface,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: () => setState(() => _form = form),
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? bg : c.chip,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: MedFormIcon(
                        form: form,
                        color: selected ? fg : c.muted,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formShortLabels[form] ?? form,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? c.ink : c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 2. Doz ----------------------------------------------------------------

  List<Widget> _doseStep() {
    final c = context.c;
    final name = _name.text.trim();
    return [
      const SizedBox(height: 20),
      // Seçimlerin listede nasıl görüneceğinin önizlemesi.
      Panel(
        child: Row(
          children: [
            MedBadge(color: _color, form: _form, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'İlaç adı' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      formLabels[_form] ?? _form,
                      if (_strength.isNotEmpty) _strength,
                    ].join(' · '),
                    style: TextStyle(fontSize: 14, color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      FormSection(
        header: 'Doz',
        children: [
          FieldRow(
            key: const ValueKey('amount'),
            controller: _amount,
            label: 'Miktar',
            placeholder: '500',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
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
        ],
      ),
      FormSection(
        header: 'Renk',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final col in _palette) _swatch(col)],
            ),
          ),
        ],
      ),
    ];
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

  // --- 3. Zamanlama ----------------------------------------------------------

  List<Widget> _scheduleStep() => [
    const SizedBox(height: 20),
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
  ];

  // --- 4. Süre ---------------------------------------------------------------

  List<Widget> _durationStep() => [
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
    FormSection(
      header: 'Notlar',
      children: [
        FieldRow(
          key: const ValueKey('notes'),
          controller: _notes,
          placeholder: 'Doktor talimatı, uyarılar…',
          maxLines: 4,
        ),
      ],
    ),
  ];

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

/// Formun üstündeki adım çubuğu: her adım bir şerit ve kısa ad. Geçilen
/// adımlara (düzenlerken hepsine) dokunulunca o adıma dönülür.
class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.step,
    required this.labels,
    required this.canOpen,
    required this.onOpen,
  });

  final int step;
  final List<String> labels;
  final bool Function(int) canOpen;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: canOpen(i),
              selected: i == step,
              label: 'Adım ${i + 1} / ${labels.length}: ${labels[i]}',
              child: ExcludeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: canOpen(i) && i != step ? () => onOpen(i) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= step ? c.accent : c.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: i == step
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == step
                                ? c.ink
                                : i < step
                                ? c.muted
                                : c.muted.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
