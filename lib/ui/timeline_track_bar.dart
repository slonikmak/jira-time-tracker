import 'package:flutter/material.dart';
import '../models.dart';
import 'app_theme.dart';

/// Визуальная шкала распределения времени (.jt-track) с интерактивными ручками изменения границ.
class TimelineTrackBar extends StatefulWidget {
  final DayDraft draft;
  final List<Segment> segments;
  final List<Break> breaks;
  final List<ImportedWorklog> existingWorklogs;
  final Map<String, String> issueKeys;
  final void Function(Segment segment)? onEditSegment;
  final void Function(Break breakItem)? onEditBreak;
  final void Function(Segment segment, int newDurationSeconds)?
  onResizeSegmentRight;
  final void Function(Segment segment, DateTime newStartUtc)?
  onResizeSegmentLeft;
  final bool isReadOnly;

  const TimelineTrackBar({
    super.key,
    required this.draft,
    required this.segments,
    required this.breaks,
    this.existingWorklogs = const [],
    this.issueKeys = const {},
    this.onEditSegment,
    this.onEditBreak,
    this.onResizeSegmentRight,
    this.onResizeSegmentLeft,
    this.isReadOnly = false,
  });

  @override
  State<TimelineTrackBar> createState() => _TimelineTrackBarState();
}

class _TimelineTrackBarState extends State<TimelineTrackBar> {
  String? _hoveredSegmentId;
  String? _draggingSegmentId;
  double _dragDeltaDx = 0;

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

    // Цвета для каждого sourceLogId
    final sourceIds = widget.segments
        .map((s) => s.sourceLogId)
        .toSet()
        .toList();
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

    for (final seg in widget.segments) {
      final key = widget.issueKeys[seg.issueId] ?? 'Задача';
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
          isExisting: isExisting,
        ),
      );
    }

    for (final b in widget.breaks) {
      items.add(
        _TrackItem(
          start: b.startUtc,
          durationSeconds: b.durationSeconds,
          color: AppColors.trackBreak(isDark),
          label:
              'Перерыв · ${_formatTime(b.startUtc)}–${_formatTime(b.endUtc)} (${_formatDuration(b.durationSeconds)})',
          breakItem: b,
          isBreak: true,
          isExisting: false,
        ),
      );
    }

    for (final worklog in widget.existingWorklogs) {
      items.add(
        _TrackItem(
          start: worklog.startUtc,
          durationSeconds: worklog.durationSeconds,
          color: AppColors.trackExisting(isDark),
          label:
              '${worklog.issueKey ?? worklog.issueId} · уже в Jira · ${_formatTime(worklog.startUtc)}–${_formatTime(worklog.endUtc)}',
          isBreak: false,
          isExisting: true,
        ),
      );
    }

    items.sort((a, b) => a.start.compareTo(b.start));
    final laneEnds = <DateTime>[];
    final placedItems = <({_TrackItem item, int lane})>[];
    for (final item in items) {
      final end = item.start.add(Duration(seconds: item.durationSeconds));
      var lane = laneEnds.indexWhere(
        (occupiedUntil) => !occupiedUntil.isAfter(item.start),
      );
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(end);
      } else {
        laneEnds[lane] = end;
      }
      placedItems.add((item: item, lane: lane));
    }

    final totalSeconds = widget.draft.endUtc
        .difference(widget.draft.startUtc)
        .inSeconds;
    final safeTotalSeconds = totalSeconds > 0 ? totalSeconds : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Полоса-трек (.jt-track) с LayoutBuilder для вычисления пикселей в секунды
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final secondsPerPixel =
                safeTotalSeconds / (trackWidth > 0 ? trackWidth : 1);

            return Container(
              height: laneEnds.isEmpty ? 28 : laneEnds.length * 30 - 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: AppColors.trackBreak(isDark),
                border: Border.all(color: AppColors.line(isDark), width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: placedItems.map((placed) {
                  final item = placed.item;
                  final left =
                      (item.start.difference(widget.draft.startUtc).inSeconds /
                              safeTotalSeconds *
                              trackWidth)
                          .clamp(0.0, trackWidth)
                          .toDouble();
                  final right =
                      ((item.start.difference(widget.draft.startUtc).inSeconds +
                                  item.durationSeconds) /
                              safeTotalSeconds *
                              trackWidth)
                          .clamp(0.0, trackWidth)
                          .toDouble();
                  if (right <= left) return const SizedBox.shrink();
                  final seg = item.segment;
                  final isEditableSegment =
                      seg != null && !item.isExisting && !widget.isReadOnly;
                  final isHovered =
                      isEditableSegment &&
                      (_hoveredSegmentId == seg.id ||
                          _draggingSegmentId == seg.id);

                  return Positioned(
                    key: seg == null ? null : Key('track_segment_${seg.id}'),
                    left: left,
                    width: right - left,
                    top: placed.lane * 30,
                    height: 28,
                    child: Tooltip(
                      message: item.label,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Базовое тело блока
                          InkWell(
                            mouseCursor:
                                (!widget.isReadOnly &&
                                        seg != null &&
                                        widget.onEditSegment != null) ||
                                    (!widget.isReadOnly &&
                                        item.breakItem != null &&
                                        widget.onEditBreak != null)
                                ? SystemMouseCursors.click
                                : SystemMouseCursors.basic,
                            onTap:
                                !widget.isReadOnly &&
                                    seg != null &&
                                    widget.onEditSegment != null
                                ? () => widget.onEditSegment!(seg)
                                : (!widget.isReadOnly &&
                                          item.breakItem != null &&
                                          widget.onEditBreak != null
                                      ? () =>
                                            widget.onEditBreak!(item.breakItem!)
                                      : null),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: item.color,
                                border: isHovered
                                    ? Border.all(
                                        color: AppColors.primary(isDark),
                                        width: 2,
                                      )
                                    : null,
                              ),
                            ),
                          ),

                          // Левая ручка изменения границы
                          if (isEditableSegment &&
                              widget.onResizeSegmentLeft != null)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 14,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeLeftRight,
                                onEnter: (_) =>
                                    setState(() => _hoveredSegmentId = seg.id),
                                onExit: (_) => setState(() {
                                  if (_draggingSegmentId == null) {
                                    _hoveredSegmentId = null;
                                  }
                                }),
                                child: GestureDetector(
                                  key: Key('drag_handle_left_${seg.id}'),
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragStart: (_) {
                                    setState(() {
                                      _draggingSegmentId = seg.id;
                                      _dragDeltaDx = 0;
                                    });
                                  },
                                  onHorizontalDragUpdate: (details) {
                                    _dragDeltaDx += details.delta.dx;
                                  },
                                  onHorizontalDragEnd: (_) {
                                    final deltaSec =
                                        (_dragDeltaDx * secondsPerPixel)
                                            .round();
                                    final newStart = seg.startUtc.add(
                                      Duration(seconds: deltaSec),
                                    );
                                    setState(() {
                                      _draggingSegmentId = null;
                                      _hoveredSegmentId = null;
                                      _dragDeltaDx = 0;
                                    });
                                    widget.onResizeSegmentLeft?.call(
                                      seg,
                                      newStart,
                                    );
                                  },
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 2),
                                    child: isHovered
                                        ? Container(
                                            width: 3,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),

                          // Правая ручка изменения границы
                          if (isEditableSegment &&
                              widget.onResizeSegmentRight != null)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: 14,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeLeftRight,
                                onEnter: (_) =>
                                    setState(() => _hoveredSegmentId = seg.id),
                                onExit: (_) => setState(() {
                                  if (_draggingSegmentId == null) {
                                    _hoveredSegmentId = null;
                                  }
                                }),
                                child: GestureDetector(
                                  key: Key('drag_handle_right_${seg.id}'),
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragStart: (_) {
                                    setState(() {
                                      _draggingSegmentId = seg.id;
                                      _dragDeltaDx = 0;
                                    });
                                  },
                                  onHorizontalDragUpdate: (details) {
                                    _dragDeltaDx += details.delta.dx;
                                  },
                                  onHorizontalDragEnd: (_) {
                                    final deltaSec =
                                        (_dragDeltaDx * secondsPerPixel)
                                            .round();
                                    final newDur =
                                        seg.durationSeconds + deltaSec;
                                    setState(() {
                                      _draggingSegmentId = null;
                                      _hoveredSegmentId = null;
                                      _dragDeltaDx = 0;
                                    });
                                    widget.onResizeSegmentRight?.call(
                                      seg,
                                      newDur,
                                    );
                                  },
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 2),
                                    child: isHovered
                                        ? Container(
                                            width: 3,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 5),

        // 2. Временные метки под треком (.jt-track-labels)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(widget.draft.startUtc),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted(isDark),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _formatTime(
                widget.draft.startUtc.add(
                  Duration(seconds: safeTotalSeconds ~/ 2),
                ),
              ),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted(isDark),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _formatTime(widget.draft.endUtc),
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
  final Break? breakItem;
  final bool isBreak;
  final bool isExisting;

  _TrackItem({
    required this.start,
    required this.durationSeconds,
    required this.color,
    required this.label,
    this.segment,
    this.breakItem,
    required this.isBreak,
    required this.isExisting,
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
