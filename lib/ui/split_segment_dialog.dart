import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../log_clock.dart';
import '../models.dart';
import 'app_theme.dart';

/// Диалог разделения сегмента дня на две части.
class SplitSegmentDialog extends StatefulWidget {
  final AppState appState;
  final Segment segment;
  final String issueKey;

  const SplitSegmentDialog({
    super.key,
    required this.appState,
    required this.segment,
    required this.issueKey,
  });

  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required Segment segment,
    required String issueKey,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => SplitSegmentDialog(
        appState: appState,
        segment: segment,
        issueKey: issueKey,
      ),
    );
  }

  @override
  State<SplitSegmentDialog> createState() => _SplitSegmentDialogState();
}

class _SplitSegmentDialogState extends State<SplitSegmentDialog> {
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
    final half = widget.segment.durationSeconds ~/ 2;
    _part1Seconds = half > 0 ? half : 60;

    final h = _part1Seconds ~/ 3600;
    final m = (_part1Seconds % 3600) ~/ 60;

    _part1HoursController = TextEditingController(text: h.toString());
    _part1MinutesController = TextEditingController(text: m.toString());
    _part1DescController = TextEditingController(text: widget.segment.description);
    _part2DescController = TextEditingController(text: widget.segment.description);

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

  int get _part2Seconds => widget.segment.durationSeconds - _part1Seconds;

  bool get _isValid =>
      _part1Seconds > 0 && _part1Seconds < widget.segment.durationSeconds;

  Future<void> _handleSplit() async {
    if (!_isValid) {
      setState(() {
        _errorMessage =
            'Длительность первой части должна быть больше 0 и меньше ${LogClock.formatHoursMinutes(widget.segment.durationSeconds)}';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      widget.appState.splitSegment(
        segmentId: widget.segment.id,
        splitOffsetSeconds: _part1Seconds,
        part1Description: _part1DescController.text.trim(),
        part2Description: _part2DescController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Интервал разделен: ${LogClock.formatHoursMinutes(_part1Seconds)} и ${LogClock.formatHoursMinutes(_part2Seconds)}',
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
      title: const Text('Разбить интервал'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Задача: ${widget.issueKey}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'Общая длительность: ${LogClock.formatHoursMinutes(widget.segment.durationSeconds)}',
                style: TextStyle(fontSize: 12, color: AppColors.muted(isDark)),
              ),
              const SizedBox(height: 16),

              // Первая часть
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
                      children: [
                        const Text(
                          'Часть 1',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          LogClock.formatHoursMinutes(_part1Seconds),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                      ],
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
                              isDense: true,
                              border: OutlineInputBorder(),
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
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _part1DescController,
                      decoration: const InputDecoration(
                        labelText: 'Описание первой части',
                        hintText: 'Что сделано в первой части...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Вторая часть
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
                      children: [
                        const Text(
                          'Часть 2 (остаток)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          LogClock.formatHoursMinutes(_part2Seconds > 0 ? _part2Seconds : 0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _part2Seconds > 0
                                ? AppColors.green(isDark)
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _part2DescController,
                      decoration: const InputDecoration(
                        labelText: 'Описание второй части',
                        hintText: 'Что сделано во второй части...',
                        isDense: true,
                        border: OutlineInputBorder(),
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
