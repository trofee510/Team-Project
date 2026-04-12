import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme.dart';
import '../../models/outfit_log.dart';

final calendarLogsProvider =
    StateProvider<Map<DateTime, List<OutfitLog>>>((ref) => {});

final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());
final focusedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final focusedDay = ref.watch(focusedDayProvider);
    final logs = ref.watch(calendarLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Outfit Calendar')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            onDaySelected: (selected, focused) {
              ref.read(selectedDayProvider.notifier).state = selected;
              ref.read(focusedDayProvider.notifier).state = focused;
            },
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return logs[key] ?? [];
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              markerSize: 6,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),

          const SizedBox(height: 16),

          // Selected day content
          Expanded(
            child: _SelectedDayContent(selectedDay: selectedDay, logs: logs),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab',
        onPressed: () {
          // TODO: Show LogOutfitSheet
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _SelectedDayContent extends StatelessWidget {
  final DateTime selectedDay;
  final Map<DateTime, List<OutfitLog>> logs;

  const _SelectedDayContent({required this.selectedDay, required this.logs});

  @override
  Widget build(BuildContext context) {
    final key = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final dayLogs = logs[key] ?? [];

    if (dayLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 48,
                color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No outfit logged for this day',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to log what you wore',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: dayLogs.length,
      itemBuilder: (context, index) {
        final log = dayLogs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.style, color: AppTheme.primary),
            ),
            title: Text('Outfit logged', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: log.notes != null ? Text(log.notes!) : null,
          ),
        );
      },
    );
  }
}
