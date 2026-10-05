import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isDarkMode = prefs.getBool('dark_mode') ?? false);
  }

  Future<void> _setDarkMode(bool enabled) async {
    setState(() => _isDarkMode = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', enabled);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F6F1),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315C4B),
          surface: const Color(0xFFF7F6F1),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF111814),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315C4B),
          brightness: Brightness.dark,
          surface: const Color(0xFF111814),
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: PrayerBeadsScreen(
          isDarkMode: _isDarkMode,
          onThemeChanged: _setDarkMode,
        ),
      ),
    );
  }
}

class PrayerBeadsScreen extends StatefulWidget {
  const PrayerBeadsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<PrayerBeadsScreen> createState() => _PrayerBeadsScreenState();
}

class _PrayerBeadsScreenState extends State<PrayerBeadsScreen> {
  static const _gold = Color(0xFFB38A4A);
  static const _salawat = [
    (
      'الصلاة الإبراهيمية',
      'اللَّهُمَّ صَلِّ عَلَىٰ سَيِّدُنَا مُحَمَّدٍ وَعَلَىٰ آلِ سَيِّدُنَا مُحَمَّدٍ',
    ),
    (
      'الصلاة والسلام',
      'اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَىٰ سَيِّدُنَا مُحَمَّد',
    ),
    ('صيغة مختصرة', 'صَلَّى اللَّهُ عَلَىٰ سَيِّدُنَا مُحَمَّد'),
  ];

  final List<(String, String)> _customDhikr = [];
  final Map<String, int> _dailyDhikrCounts = {};
  int _count = 0;
  int _goal = 33;
  int _selectedDhikr = 1;
  String _todayKey = '';
  bool _isLoadingDailyCounts = true;

  List<(String, String)> get _allDhikr => [..._salawat, ..._customDhikr];

  int get _selectedDhikrDailyCount =>
      _dailyDhikrCounts[_dhikrKey(_selectedDhikr)] ?? 0;

  int get _totalDailyCount =>
      _dailyDhikrCounts.values.fold<int>(0, (sum, value) => sum + value);

  String _dhikrKey(int index) => 'dhikr_$index';

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadDailyCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final customDhikrJson = prefs.getString('custom_dhikr');
    if (customDhikrJson != null && customDhikrJson.isNotEmpty) {
      final decodedCustomDhikr = jsonDecode(customDhikrJson);
      if (decodedCustomDhikr is List) {
        _customDhikr
          ..clear()
          ..addAll(
            decodedCustomDhikr
                .whereType<Map>()
                .map(
                  (entry) => (
                    entry['name']?.toString() ?? '',
                    entry['phrase']?.toString() ?? '',
                  ),
                )
                .where((entry) => entry.$1.isNotEmpty && entry.$2.isNotEmpty),
          );
      }
    }

    final todayKey = _dateKey(DateTime.now());
    _todayKey = todayKey;

    final storedDate = prefs.getString('dhikr_daily_date');
    if (storedDate != todayKey) {
      await prefs.setString('dhikr_daily_date', todayKey);
      await prefs.setString('dhikr_daily_counts', jsonEncode({}));
      _dailyDhikrCounts.clear();
    } else {
      final countsJson = prefs.getString('dhikr_daily_counts');
      if (countsJson != null && countsJson.isNotEmpty) {
        final decoded = jsonDecode(countsJson);
        if (decoded is Map) {
          _dailyDhikrCounts
            ..clear()
            ..addAll(
              decoded.map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toInt()),
              ),
            );
        }
      } else {
        _dailyDhikrCounts.clear();
      }
    }

    final validKeys = {
      for (var index = 0; index < _allDhikr.length; index++) _dhikrKey(index),
    };
    _dailyDhikrCounts.removeWhere((key, _) => !validKeys.contains(key));
    _isLoadingDailyCounts = false;

    if (mounted) setState(() {});
  }

  Future<void> _saveCustomDhikr() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_dhikr',
      jsonEncode(
        _customDhikr
            .map((dhikr) => {'name': dhikr.$1, 'phrase': dhikr.$2})
            .toList(),
      ),
    );
  }

  Future<void> _saveDailyCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dhikr_daily_date', _todayKey);
    await prefs.setString('dhikr_daily_counts', jsonEncode(_dailyDhikrCounts));
  }

  void _increment() {
    if (_isLoadingDailyCounts || _count >= _goal) return;
    HapticFeedback.selectionClick();
    final todayKey = _dateKey(DateTime.now());
    if (_todayKey != todayKey) {
      _todayKey = todayKey;
      _dailyDhikrCounts.clear();
    }
    setState(() {
      _count++;
      final key = _dhikrKey(_selectedDhikr);
      _dailyDhikrCounts[key] = (_dailyDhikrCounts[key] ?? 0) + 1;
    });
    _saveDailyCounts();
  }

  void _selectGoal(int goal) {
    setState(() {
      _goal = goal;
      _count = 0;
    });
  }

  void _resetCounter() => setState(() => _count = 0);

  void _resetDailyCounts() {
    setState(() {
      _count = 0;
      _dailyDhikrCounts.clear();
    });
    _saveDailyCounts();
  }

  @override
  void initState() {
    super.initState();
    _loadDailyCounts();
  }

  Future<void> _addDhikr() async {
    final entry = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _AddDhikrDialog(),
    );

    if (entry == null || !mounted) return;

    setState(() {
      _customDhikr.insert(0, entry);
      final shiftedCounts = <String, int>{};
      for (final countEntry in _dailyDhikrCounts.entries) {
        final index = int.parse(countEntry.key.substring('dhikr_'.length));
        final shiftedIndex = index >= _salawat.length ? index + 1 : index;
        shiftedCounts[_dhikrKey(shiftedIndex)] = countEntry.value;
      }
      _dailyDhikrCounts
        ..clear()
        ..addAll(shiftedCounts);
      _selectedDhikr = _salawat.length;
      _count = 0;
    });
    await _saveCustomDhikr();
    await _saveDailyCounts();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final green = colors.primary;
    final ink = colors.onSurface;
    final muted = colors.onSurfaceVariant;
    final gold = widget.isDarkMode ? const Color(0xFFE1C27A) : _gold;
    final cardSurface = colors.surfaceContainerLow;
    final chipSurface = colors.surfaceContainerHighest;
    final borderColor = colors.outlineVariant;
    final isComplete = _count == _goal;
    final dhikrOptions = _allDhikr;
    final selectedDhikr = dhikrOptions[_selectedDhikr];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: chipSurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.spa_outlined, color: green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'وِرد الصلاة على النبي',
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'طُمأنينةٌ في كلّ تسبيحة لكى تؤجر عليها',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: widget.isDarkMode
                              ? 'الوضع الفاتح'
                              : 'الوضع الداكن',
                          onPressed: () =>
                              widget.onThemeChanged(!widget.isDarkMode),
                          icon: Icon(
                            widget.isDarkMode
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                          color: green,
                        ),
                        IconButton(
                          tooltip: 'تصفير العداد الحالي',
                          onPressed: _resetCounter,
                          icon: const Icon(Icons.refresh_rounded),
                          color: green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 17, 18, 19),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                'الصيغة',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                selectedDhikr.$1,
                                style: TextStyle(
                                  color: green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                tooltip: 'إضافة ذكر',
                                onPressed: _addDhikr,
                                icon: const Icon(Icons.add_circle_outline),
                                color: green,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedDhikr.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ink,
                              fontSize: 20,
                              height: 1.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 7,
                            runSpacing: 7,
                            children: List.generate(dhikrOptions.length, (
                              index,
                            ) {
                              final selected = index == _selectedDhikr;
                              return ChoiceChip(
                                label: Text(dhikrOptions[index].$1),
                                selected: selected,
                                showCheckmark: false,
                                onSelected: (_) => setState(() {
                                  _selectedDhikr = index;
                                  _count = 0;
                                }),
                                labelStyle: TextStyle(
                                  color: selected ? colors.onPrimary : muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: chipSurface,
                                selectedColor: green,
                                side: BorderSide(
                                  color: selected ? green : borderColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    LayoutBuilder(
                      builder: (context, box) {
                        final size = (box.maxWidth * 0.82).clamp(250.0, 310.0);
                        return SizedBox(
                          width: size,
                          height: size,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: Size.square(size),
                                painter: BeadRingPainter(
                                  progress: _count / _goal,
                                  activeColor: green,
                                  inactiveColor: widget.isDarkMode
                                      ? const Color(0xFF526258)
                                      : const Color(0xFFCAD4CB),
                                  trackColor: borderColor,
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: isComplete
                                    ? 'اكتمل الورد'
                                    : 'زد العداد بتسجيل صلاة',
                                value: '$_count من $_goal',
                                child: Material(
                                  color: colors.surfaceContainerHigh,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  shadowColor: colors.shadow.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: isComplete || _isLoadingDailyCounts
                                        ? null
                                        : _increment,
                                    child: SizedBox(
                                      width: size * 0.68,
                                      height: size * 0.68,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            transitionBuilder:
                                                (child, animation) =>
                                                    ScaleTransition(
                                                      scale: animation,
                                                      child: child,
                                                    ),
                                            child: Text(
                                              '$_count',
                                              key: ValueKey(_count),
                                              style: TextStyle(
                                                color: green,
                                                fontSize: 58,
                                                height: 1.1,
                                                fontWeight: FontWeight.w700,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'من $_goal',
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 11),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            child: Text(
                                              isComplete
                                                  ? 'تقبّل الله'
                                                  : 'اضغط للتسبيح',
                                              key: ValueKey(isComplete),
                                              style: TextStyle(
                                                color: isComplete
                                                    ? gold
                                                    : muted,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isComplete
                          ? 'أتممتَ وِردك، جعلها الله في ميزانك'
                          : 'اختر عدد التسبيحات',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isComplete ? green : muted,
                        fontSize: 13,
                        fontWeight: isComplete
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 13),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 33, label: Text('٣٣ مرة')),
                        ButtonSegment(value: 100, label: Text('١٠٠ مرة')),
                      ],
                      selected: {_goal},
                      onSelectionChanged: (selection) =>
                          _selectGoal(selection.first),
                      style: SegmentedButton.styleFrom(
                        foregroundColor: muted,
                        selectedForegroundColor: colors.onPrimary,
                        selectedBackgroundColor: green,
                        backgroundColor: cardSurface,
                        side: BorderSide(color: borderColor),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 17),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'الذكر الحالي: $_selectedDhikrDailyCount مرة',
                              style: TextStyle(
                                color: green,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'مجموع كل الأذكار اليوم: $_totalDailyCount مرة',
                              style: TextStyle(
                                color: gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _count == 0 && _totalDailyCount == 0
                          ? null
                          : _resetDailyCounts,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('إعادة العدّ'),
                      style: TextButton.styleFrom(
                        foregroundColor: muted,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
}

class _AddDhikrDialog extends StatefulWidget {
  const _AddDhikrDialog();

  @override
  State<_AddDhikrDialog> createState() => _AddDhikrDialogState();
}

class _AddDhikrDialogState extends State<_AddDhikrDialog> {
  final _nameController = TextEditingController();
  final _phraseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      scrollable: true,
      title: const Text('إضافة ذكر جديد'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'اسم الذكر',
                hintText: 'مثال: استغفار',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'أدخل اسم الذكر'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phraseController,
              textDirection: TextDirection.rtl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'نص الذكر',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'أدخل نص الذكر'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              _nameController.text.trim(),
              _phraseController.text.trim(),
            ));
          },
          child: const Text('إضافة'),
        ),
      ],
    ),
  );
}

class BeadRingPainter extends CustomPainter {
  const BeadRingPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.trackColor,
  });

  final Color activeColor;
  final Color inactiveColor;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.46;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    const beadCount = 33;
    for (var index = 0; index < beadCount; index++) {
      final angle = -math.pi / 2 + (2 * math.pi * index / beadCount);
      final position = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final active = index < (progress * beadCount).ceil();
      canvas.drawCircle(
        position,
        size.width * (active ? 0.019 : 0.016),
        Paint()..color = active ? activeColor : inactiveColor,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = activeColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant BeadRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.trackColor != trackColor;
}
