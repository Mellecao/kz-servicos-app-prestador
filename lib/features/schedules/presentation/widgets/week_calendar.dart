import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

class WeekCalendar extends StatelessWidget {
  final DateTime? selectedDate;
  final List<DateTime> tripDates;
  final ValueChanged<DateTime?> onDaySelected;
  final VoidCallback onCalendarTapped;

  const WeekCalendar({
    super.key,
    required this.selectedDate,
    required this.tripDates,
    required this.onDaySelected,
    required this.onCalendarTapped,
  });

  static const _dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  List<DateTime> get _weekDays {
    final base = selectedDate ?? DateTime.now();
    final monday = base.subtract(Duration(days: base.weekday - 1));
    return List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasTripOnDay(DateTime day) => tripDates.any((d) => _isSameDay(d, day));

  @override
  Widget build(BuildContext context) {
    final days = _weekDays;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((day) {
                final isSelected =
                    selectedDate != null && _isSameDay(day, selectedDate!);
                final isToday = _isSameDay(day, today);
                final hasTrip = _hasTripOnDay(day);

                return GestureDetector(
                  onTap: () => onDaySelected(isSelected ? null : day),
                  child: SizedBox(
                    width: 38,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dayNames[day.weekday - 1],
                          style: TextStyle(
                            fontFamily: 'QuasimodoSemiBold',
                            fontSize: 11,
                            color: isSelected
                                ? AppColors.highlight
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.highlight
                                : Colors.transparent,
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: AppColors.highlight,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontFamily: 'OutfitBlack',
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasTrip
                                ? AppColors.secondary
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onCalendarTapped,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.calendar_month,
                size: 18,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
