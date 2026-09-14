import 'package:flutter/material.dart';
import '../models.dart';
import 'app_theme.dart';

/// Визуальная шкала распределения времени (.jt-track) из дизайн-макета.
class TimelineTrackBar extends StatelessWidget {
  final DayDraft draft;
  final List<Segment> segments;
  final List<Break> breaks;
  final Map<String, String> issueKeys;
  final void Function(Segment segment)? onEditSegment;

  const TimelineTrackBar({
    super.key,
    required this.draft,
    required this.segments,
    required this.breaks,
    this.issueKeys = const {},
    this.onEditSegment,
  });

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final m = (seconds / 60).round();
    final h = m ~/ 60;
    final mins = m % 60;
    if (h == 0) return '$mins мин';
    if (mins == 0) return '$h ч';
    return '$h ч $mins мин';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Собираем все интервалы (сегменты и паузы) в единую временную шкалу
    final List<_TrackItem> items = [];

    // Определяем цвета для каждого sourceLogId
    final sourceIds = segments.map((s) => s.sourceLogId).toSet().toList();
    final Map<String, Color> sourceColors = {};
    for (int i = 0; i < sourceIds.length; i++) {
      final sId = sourceIds[i];
      if (sId.toLowerCase().contains('existing') ||
          sId.toLowerCase().contains('jira')) {
        sourceColors[sId] = AppColors.trackExisting(isDark);
      } else {
        sourceColors[sId] = (i % 2 == 0)
            ? AppColors.trackOne(isDark)
            : AppColors.trackTwo(isDark);
      }
    }

    for (final seg in segments) {
      final key = issueKeys[seg.issueId] ?? 'Задача';
      final isExisting = seg.sourceLogId.toLowerCase().contains('existing');
      items.add(
        _TrackItem(
          start: seg.startUtc,
          durationSeconds: seg.durationSeconds,
          color: isExisting
              ? AppColors.trackExisting(isDark)
              : (sourceColors[seg.sourceLogId] ?? AppColors.trackOne(isDark)),
          label:
              '$key · ${_formatTime(seg.startUtc)}–${_formatTime(seg.startUtc.add(Duration(seconds: seg.durationSeconds)))} (${_formatDuration(seg.durationSeconds)})',
          segment: seg,
          isBreak: false,
        ),
      );
    }

    for (final b in breaks) {
      items.add(
        _TrackItem(
          start: b.startUtc,
          durationSeconds: b.durationSeconds,
          color: AppColors.trackBreak(isDark),
          label: 'Пауза (${_formatDuration(b.durationSeconds)})',
          isBreak: true,
        ),
      );
    }

    items.sort((a, b) => a.start.compareTo(b.start));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Полоса-трек (.jt-track)
        Container(
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: AppColors.trackBreak(isDark),
            border: Border.all(color: AppColors.line(isDark), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: items.map((item) {
              final flex = item.durationSeconds.clamp(1, 86400);
              return Expanded(
                flex: flex,
                child: Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: item.segment != null && onEditSegment != null
                        ? () => onEditSegment!(item.segment!)
                        : null,
                    child: Container(
                      color: item.color,
                      height: double.infinity,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 5),

        // 2. Временные метки под треком (.jt-track-labels)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(draft.startUtc),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted(isDark),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '12:00',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted(isDark),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _formatTime(draft.endUtc),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted(isDark),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. Легенда (.jt-legend)
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendItem(
              color: AppColors.trackOne(isDark),
              label: 'Выбранные логи',
              isDark: isDark,
            ),
            _LegendItem(
              color: AppColors.trackExisting(isDark),
              label: 'Уже в Jira',
              isDark: isDark,
            ),
            _LegendItem(
              color: AppColors.trackBreak(isDark),
              label: 'Паузы',
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }
}

class _TrackItem {
  final DateTime start;
  final int durationSeconds;
  final Color color;
  final String label;
  final Segment? segment;
  final bool isBreak;

  _TrackItem({
    required this.start,
    required this.durationSeconds,
    required this.color,
    required this.label,
    this.segment,
    required this.isBreak,
  });
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.muted(isDark)),
        ),
      ],
    );
  }
}
