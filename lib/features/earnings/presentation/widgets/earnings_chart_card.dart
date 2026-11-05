import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/core/utils/kz_format.dart';

class EarningsChartCard extends StatefulWidget {
  final List<MonthlyEarning> monthlyHistory;
  final double monthOverMonthDiff;

  const EarningsChartCard({
    super.key,
    required this.monthlyHistory,
    this.monthOverMonthDiff = 0,
  });

  @override
  State<EarningsChartCard> createState() => _EarningsChartCardState();
}

class _EarningsChartCardState extends State<EarningsChartCard>
    with SingleTickerProviderStateMixin {
  bool _showAnnual = false;
  late AnimationController _animController;
  late Animation<double> _animation;

  static const _monthNames = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<MonthlyEarning> get _visibleMonths {
    if (_showAnnual) return widget.monthlyHistory;
    // Show last 6 months
    final data = widget.monthlyHistory;
    return data.length > 6 ? data.sublist(data.length - 6) : data;
  }

  double get _maxValue {
    final vals = _visibleMonths.map((e) => e.total);
    return vals.isEmpty ? 1000 : vals.reduce((a, b) => a > b ? a : b) * 1.15;
  }

  void _toggleView() {
    setState(() => _showAnnual = !_showAnnual);
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle
          Row(
            children: [
              const Text(
                'Comparativo',
                style: TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              if (widget.monthOverMonthDiff != 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${widget.monthOverMonthDiff > 0 ? '+' : '-'}${formatKz(widget.monthOverMonthDiff.abs())} face ao mês anterior',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.monthOverMonthDiff >= 0
                        ? const Color(0xFF2ECC71)
                        : Colors.red.shade400,
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: _toggleView,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showAnnual
                            ? Icons.bar_chart_rounded
                            : Icons.calendar_view_month,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showAnnual ? '6 meses' : 'Visão anual',
                        style: const TextStyle(
                          fontFamily: 'QuasimodoSemiBold',
                          fontSize: 12,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return SizedBox(
                height: _showAnnual ? 200 : 180,
                child: _showAnnual ? _buildLineChart() : _buildBarChart(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final months = _visibleMonths;
    return BarChart(
      BarChartData(
        maxY: _maxValue,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  formatKzCompact(value),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _monthNames[months[i].month - 1],
                    style: const TextStyle(
                      fontFamily: 'QuasimodoSemiBold',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _maxValue / 4,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(months.length, (i) {
          final val = months[i].total * _animation.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                width: _showAnnual ? 16 : 28,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2ECC71),
                    const Color(0xFF2ECC71).withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildLineChart() {
    final months = _visibleMonths;
    return LineChart(
      LineChartData(
        maxY: _maxValue,
        lineTouchData: LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  formatKzCompact(value),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _monthNames[months[i].month - 1],
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _maxValue / 4,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(months.length, (i) {
              return FlSpot(i.toDouble(), months[i].total * _animation.value);
            }),
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFF2ECC71),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, xPercentage, bar, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: const Color(0xFF2ECC71),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2ECC71).withValues(alpha: 0.3),
                  const Color(0xFF2ECC71).withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}
