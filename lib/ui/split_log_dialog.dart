import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import 'app_theme.dart';

/// Диалог разделения локального лога на две части.
class SplitLogDialog extends StatefulWidget {
  final AppState appState;
  final LocalLog log;

  const SplitLogDialog({super.key, required this.appState, required this.log});

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required LocalLog log,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => SplitLogDialog(appState: appState, log: log),
    );
  }

  @override
  State<SplitLogDialog> createState() => _SplitLogDialogState();
}

class _SplitLogDialogState extends State<SplitLogDialog> {
  late final TextEditingController _part1HoursController;
  late final TextEditingController _part1MinutesController;
  late final TextEditingController _part1DescController;
  late final TextEditingController _part2DescController;

  int _part1Seconds = 0;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // По умолчанию делим пополам
    final half = widget.log.accumulatedSeconds ~/ 2;
    _part1Seconds = half > 0 ? half : 60;

    final h = _part1Seconds ~/ 3600;
    final m = (_part1Seconds % 3600) ~/ 60;

    _part1HoursController = TextEditingController(text: h.toString());
    _part1MinutesController = TextEditingController(text: m.toString());
    _part1DescController = TextEditingController(text: widget.log.description);
    _part2DescController = TextEditingController(text: widget.log.description);

    _part1HoursController.addListener(_recalcPart1);
    _part1MinutesController.addListener(_recalcPart1);
  }

  @override
  void dispose() {
    _part1HoursController.dispose();
    _part1MinutesController.dispose();
    _part1DescController.dispose();
    _part2DescController.dispose();
    super.dispose();
  }

  void _recalcPart1() {
    final h = int.tryParse(_part1HoursController.text.trim()) ?? 0;
    final m = int.tryParse(_part1MinutesController.text.trim()) ?? 0;
    final sec = (h * 3600) + (m * 60);
    setState(() {
      _part1Seconds = sec;
      _errorMessage = null;
    });
  }

  int get _part2Seconds => widget.log.accumulatedSeconds - _part1Seconds;

  bool get _isValid =>
      _part1Seconds > 0 && _part1Seconds < widget.log.accumulatedSeconds;

  Future<void> _handleSplit() async {
    if (!_isValid) {
      setState(() {
        _errorMessage =
            'Длительность первой части должна быть больше 0 и меньше ${LogClock.formatHoursMinutes(widget.log.accumulatedSeconds)}';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.appState.splitLog(
        logId: widget.log.id,
        part1DurationSeconds: _part1Seconds,
        part1Description: _part1DescController.text.trim(),
        part2Description: _part2DescController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Лог разделен на две части: ${LogClock.formatHoursMinutes(_part1Seconds)} и ${LogClock.formatHoursMinutes(_part2Seconds)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Разбить запись времени'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.log.titleSnapshot,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Общее время: ${LogClock.formatHoursMinutes(widget.log.accumulatedSeconds)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted(isDark),
                ),
              ),
              const SizedBox(height: 16),

              // Часть 1
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line(isDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Часть 1',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _part1HoursController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Часы',
                              border: OutlineInputBorder(),
                              isDense: true,
                              suffixText: 'ч',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _part1MinutesController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Минуты',
                              border: OutlineInputBorder(),
                              isDense: true,
                              suffixText: 'м',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _part1DescController,
                      decoration: const InputDecoration(
                        labelText: 'Описание части 1',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Часть 2
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line(isDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Часть 2 (остаток)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _part2Seconds > 0
                              ? LogClock.formatHoursMinutes(_part2Seconds)
                              : '0 мин',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _part2Seconds > 0
                                ? AppColors.primary(isDark)
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _part2DescController,
                      decoration: const InputDecoration(
                        labelText: 'Описание части 2',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isSaving || !_isValid ? null : _handleSplit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Разбить'),
        ),
      ],
    );
  }
}
