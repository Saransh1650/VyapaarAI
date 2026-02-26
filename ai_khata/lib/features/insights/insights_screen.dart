import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<dynamic> _festivals = [];
  Map<String, dynamic>? _forecast;
  List<dynamic> _invAlerts = [];
  bool _loadingFestivals = false, _loadingForecast = false, _loadingInv = false;
  String? _forecastJobId, _invJobId;

  @override
  void initState() {
    super.initState();
    _loadFestivals();
  }

  Future<void> _loadFestivals() async {
    setState(() => _loadingFestivals = true);
    try {
      final auth = context.read<AuthService>();
      final res = await ApiClient.instance.dio.post(
        '/ai/festival-recommendations',
        data: {'storeId': auth.storeId, 'storeType': auth.storeType},
      );
      setState(() => _festivals = res.data['recommendations'] ?? []);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFestivals = false);
    }
  }

  Future<void> _requestForecast() async {
    setState(() => _loadingForecast = true);
    try {
      final auth = context.read<AuthService>();
      final res = await ApiClient.instance.dio.post(
        '/ai/forecast',
        data: {
          'storeId': auth.storeId,
          'storeType': auth.storeType,
          'horizon': 30,
        },
      );
      _forecastJobId = res.data['job']['id'];
      await _pollForecast();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingForecast = false);
    }
  }

  Future<void> _pollForecast() async {
    if (_forecastJobId == null) return;
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 3));
      final res = await ApiClient.instance.dio.get(
        '/ai/jobs/$_forecastJobId/result',
      );
      final status = res.data['job']['status'];
      if (status == 'COMPLETED' && res.data['result'] != null) {
        if (mounted) setState(() => _forecast = res.data['result']['data']);
        return;
      }
      if (status == 'FAILED') return;
    }
  }

  Future<void> _requestInventory() async {
    setState(() => _loadingInv = true);
    try {
      final auth = context.read<AuthService>();
      final res = await ApiClient.instance.dio.post(
        '/ai/inventory-analysis',
        data: {'storeId': auth.storeId, 'storeType': auth.storeType},
      );
      _invJobId = res.data['job']['id'];
      await _pollInventory();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingInv = false);
    }
  }

  Future<void> _pollInventory() async {
    if (_invJobId == null) return;
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 3));
      final res = await ApiClient.instance.dio.get(
        '/ai/jobs/$_invJobId/result',
      );
      final status = res.data['job']['status'];
      if (status == 'COMPLETED' && res.data['result'] != null) {
        final alerts = res.data['result']['data']['alerts'];
        if (mounted) setState(() => _invAlerts = alerts ?? []);
        return;
      }
      if (status == 'FAILED') return;
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Festival Recommendations ─────────────────────────────────────
        Text(
          '🎉 Upcoming Events',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _loadingFestivals
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : _festivals.isEmpty
            ? _EmptyState(
                'No upcoming festivals in next 30 days.',
                Icons.event_outlined,
                onRetry: _loadFestivals,
              )
            : SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _festivals.length,
                  itemBuilder: (_, i) => _FestivalCard(_festivals[i]),
                ),
              ),
        const SizedBox(height: 24),

        // ── Demand Forecast ───────────────────────────────────────────────
        Row(
          children: [
            Text(
              '📈 Demand Forecast',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            if (!_loadingForecast)
              TextButton.icon(
                onPressed: _requestForecast,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Generate'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingForecast)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'Gemini is generating your forecast...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_forecast != null)
          _ForecastChart(_forecast!)
        else
          _EmptyState(
            'Tap Generate to get a 30-day AI forecast.',
            Icons.auto_graph_outlined,
          ),
        const SizedBox(height: 24),

        // ── Inventory Alerts ──────────────────────────────────────────────
        Row(
          children: [
            Text(
              '⚠️ Inventory Alerts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            if (!_loadingInv)
              TextButton.icon(
                onPressed: _requestInventory,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Analyze'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingInv)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'Analyzing your inventory...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_invAlerts.isEmpty)
          _EmptyState(
            'Tap Analyze to check inventory health.',
            Icons.inventory_2_outlined,
          )
        else
          ..._invAlerts.map((a) => _AlertCard(a)),
      ],
    ),
  );
}

// ── Festival Card ─────────────────────────────────────────────────────────────

class _FestivalCard extends StatelessWidget {
  final Map<String, dynamic> festival;
  const _FestivalCard(this.festival);

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.primary.withOpacity(0.3), AppTheme.card],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              festival['festival'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${festival['daysAway']}d away',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: (festival['recommendations'] as List?)?.length ?? 0,
            itemBuilder: (_, i) {
              final r = festival['recommendations'][i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r['product'] ?? '',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${r['percentIncrease']}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

// ── Forecast Chart ────────────────────────────────────────────────────────────

class _ForecastChart extends StatelessWidget {
  final Map<String, dynamic> forecast;
  const _ForecastChart(this.forecast);

  @override
  Widget build(BuildContext context) {
    final pts = (forecast['forecast'] as List? ?? []);
    if (pts.isEmpty) return const SizedBox();
    final spots = pts
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            double.tryParse(e.value['predicted'].toString()) ?? 0,
          ),
        )
        .toList();
    final highSpots = pts
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            double.tryParse(e.value['confidenceHigh'].toString()) ?? 0,
          ),
        )
        .toList();
    final lowSpots = pts
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            double.tryParse(e.value['confidenceLow'].toString()) ?? 0,
          ),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (forecast['summary'] != null)
            Text(
              forecast['summary'],
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
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
                    sideTitles: SideTitles(showTitles: false),
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
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: highSpots,
                    isCurved: true,
                    color: AppTheme.primary.withOpacity(0.3),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    dashArray: [4, 4],
                  ),
                  LineChartBarData(
                    spots: lowSpots,
                    isCurved: true,
                    color: AppTheme.primary.withOpacity(0.3),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    dashArray: [4, 4],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Alert Card ────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  const _AlertCard(this.alert);

  Color _urgencyColor(String? u) => switch (u) {
    'high' => AppTheme.error,
    'medium' => AppTheme.warning,
    _ => AppTheme.success,
  };

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColor(alert['urgency']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert['product'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (alert['urgency'] ?? 'low').toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '~${alert['estimatedDaysLeft']} days left · Reorder: ${alert['reorderQty']} units',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (alert['recommendation'] != null) ...[
            const SizedBox(height: 4),
            Text(
              alert['recommendation'],
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  const _EmptyState(this.message, this.icon, {this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 36),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ],
    ),
  );
}
