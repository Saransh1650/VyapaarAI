import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<dynamic> _trends = [];
  List<dynamic> _rankings = [];
  bool _loading = true;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final storeQ = auth.storeId != null ? '&storeId=${auth.storeId}' : '';
      final t = await ApiClient.instance.dio.get(
        '/analytics/sales-trends?days=$_days$storeQ',
      );
      final r = await ApiClient.instance.dio.get(
        '/analytics/product-rankings?days=$_days&limit=8$storeQ',
      );
      setState(() {
        _trends = t.data['data'] ?? [];
        _rankings = r.data['data'] ?? [];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period selector
                Row(
                  children: [
                    Text(
                      'Period:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 12),
                    for (final d in [7, 30, 90])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _days = d);
                            _load();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _days == d
                                  ? AppTheme.primary
                                  : AppTheme.card,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${d}d',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _days == d
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Sales Trend Line Chart
                Text(
                  'Sales Trend',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _trends.isEmpty
                      ? const Center(
                          child: Text(
                            'No data',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              getDrawingHorizontalLine: (_) =>
                                  FlLine(color: Colors.white10, strokeWidth: 1),
                              getDrawingVerticalLine: (_) =>
                                  FlLine(color: Colors.white10, strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (v, _) => Text(
                                    '₹${v.toInt()}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  interval: (_trends.length / 4).ceilToDouble(),
                                  getTitlesWidget: (v, _) {
                                    final idx = v.toInt();
                                    if (idx < 0 || idx >= _trends.length)
                                      return const SizedBox();
                                    return Text(
                                      _trends[idx]['day']?.toString().substring(
                                            5,
                                            10,
                                          ) ??
                                          '',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 9,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _trends
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(
                                        e.key.toDouble(),
                                        double.tryParse(
                                              e.value['total'].toString(),
                                            ) ??
                                            0,
                                      ),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: AppTheme.primary,
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppTheme.primary.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // Product Rankings Bar Chart
                Text(
                  'Top Products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  height: 260,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _rankings.isEmpty
                      ? const Center(
                          child: Text(
                            'No data',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            gridData: FlGridData(
                              show: true,
                              getDrawingHorizontalLine: (_) =>
                                  FlLine(color: Colors.white10, strokeWidth: 1),
                              drawVerticalLine: false,
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (v, _) => Text(
                                    '₹${v.toInt()}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  getTitlesWidget: (v, _) {
                                    final idx = v.toInt();
                                    if (idx < 0 || idx >= _rankings.length)
                                      return const SizedBox();
                                    final name =
                                        _rankings[idx]['product_name']
                                            ?.toString() ??
                                        '';
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        name.length > 6
                                            ? '${name.substring(0, 6)}..'
                                            : name,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 9,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _rankings
                                .asMap()
                                .entries
                                .map(
                                  (e) => BarChartGroupData(
                                    x: e.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY:
                                            double.tryParse(
                                              e.value['revenue'].toString(),
                                            ) ??
                                            0,
                                        color: AppTheme.primary,
                                        width: 18,
                                        borderRadius: BorderRadius.circular(4),
                                        backDrawRodData:
                                            BackgroundBarChartRodData(
                                              show: true,
                                              toY: 0,
                                              color: Colors.transparent,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
}
