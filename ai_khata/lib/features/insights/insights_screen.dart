import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';

/// AI Tips screen — reads from backend cache only. No AI is called from the app.
/// The backend auto-refreshes insights every 24h or after 20 new ledger entries.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? _insights;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  /// Loads cached insights from backend — instant, no AI call.
  Future<void> _loadInsights() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final res = await ApiClient.instance.dio.get(
        '/ai/insights',
        queryParameters: {'storeId': auth.storeId, 'storeType': auth.storeType},
      );
      if (mounted) setState(() => _insights = res.data['insights']);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not load tips. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Triggers a background refresh, then waits 35s and reloads.
  Future<void> _onPullRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final auth = context.read<AuthService>();
      await ApiClient.instance.dio.post(
        '/ai/insights/refresh',
        data: {'storeId': auth.storeId, 'storeType': auth.storeType},
      );
      // Wait for the background worker to finish, then reload cached result
      await Future.delayed(const Duration(seconds: 35));
      await _loadInsights();
    } catch (_) {
      if (mounted) await _loadInsights();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 2) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null && _insights == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.textHint,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadInsights,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final festivals = (_insights?['festival'] as List?) ?? [];
    final forecast = _insights?['forecast'] as Map<String, dynamic>?;
    final inventory = _insights?['inventory'] as Map<String, dynamic>?;
    final generatedAt = _insights?['generatedAt']?.toString();
    final hasAnyData =
        festivals.isNotEmpty || forecast != null || inventory != null;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _onPullRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Last updated badge ───────────────────────────────────────────
            if (generatedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.update_rounded,
                      size: 13,
                      color: AppTheme.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tips last updated ${_timeAgo(generatedAt)}',
                      style: const TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12,
                      ),
                    ),
                    if (_refreshing) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        height: 10,
                        width: 10,
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 1.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Refreshing…',
                        style: TextStyle(color: AppTheme.primary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

            if (!hasAnyData) ...[
              _EmptyInsightsState(
                onRefresh: _onPullRefresh,
                refreshing: _refreshing,
              ),
            ] else ...[
              // ── Upcoming Events ──────────────────────────────────────────
              _SectionHeader(
                icon: Icons.celebration_rounded,
                title: 'Upcoming Events',
                subtitle: 'Stock up before festivals',
              ),
              const SizedBox(height: 12),
              if (festivals.isEmpty)
                _InfoCard(
                  icon: Icons.event_outlined,
                  text: 'No upcoming festivals in the next 30 days.',
                )
              else
                SizedBox(
                  height: 196,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: festivals.length,
                    itemBuilder: (_, i) => _FestivalCard(festivals[i]),
                  ),
                ),
              const SizedBox(height: 28),

              // ── Sales Forecast ───────────────────────────────────────────
              _SectionHeader(
                icon: Icons.trending_up_rounded,
                title: 'Sales Forecast',
                subtitle: 'Expected sales for next 30 days',
              ),
              const SizedBox(height: 12),
              if (forecast == null)
                const _InfoCard(
                  icon: Icons.auto_graph_outlined,
                  text: 'Pull down to refresh and generate your forecast.',
                )
              else
                _ForecastCard(forecast),
              const SizedBox(height: 28),

              // ── Stock Alerts ─────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.inventory_2_rounded,
                title: 'Stock Check',
                subtitle: 'Items that might run out soon',
              ),
              const SizedBox(height: 12),
              if (inventory == null)
                const _InfoCard(
                  icon: Icons.check_circle_outline_rounded,
                  text: 'No stock analysis available yet.',
                )
              else if ((inventory['alerts'] as List?)?.isEmpty != false)
                const _InfoCard(
                  icon: Icons.check_circle_outline_rounded,
                  text: 'All good! No low stock alerts.',
                )
              else
                ...(inventory['alerts'] as List).map((a) => _AlertCard(a)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyInsightsState extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool refreshing;
  const _EmptyInsightsState({
    required this.onRefresh,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lightbulb_rounded,
            color: AppTheme.primary,
            size: 48,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'AI Tips Are Being Prepared',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your first AI insights are being generated in the background.\nPull down to refresh after a minute.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: refreshing ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(refreshing ? 'Generating…' : 'Generate Tips Now'),
        ),
      ],
    ),
  );
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 18),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    ],
  );
}

// ── Info / Empty State Card ────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 36),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}

// ── Festival Card ──────────────────────────────────────────────────────────────

class _FestivalCard extends StatelessWidget {
  final Map<String, dynamic> festival;
  const _FestivalCard(this.festival);

  @override
  Widget build(BuildContext context) {
    final recs = (festival['recommendations'] as List?) ?? [];
    return Container(
      width: 230,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  festival['festival'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.15),
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
          const SizedBox(height: 4),
          const Text(
            'Consider stocking:',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: recs.length,
              itemBuilder: (_, i) {
                final r = recs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fiber_manual_record_rounded,
                        size: 6,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r['product'] ?? '',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${r['percentIncrease']}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w700,
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
}

// ── Forecast Card ──────────────────────────────────────────────────────────────

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> forecast;
  const _ForecastCard(this.forecast);

  @override
  Widget build(BuildContext context) {
    final pts = (forecast['forecast'] as List? ?? []);
    if (pts.isEmpty) {
      return const _InfoCard(
        icon: Icons.auto_graph_outlined,
        text: 'Forecast data is not available yet.',
      );
    }

    final totalPredicted = pts.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p['predicted'].toString()) ?? 0),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (forecast['summary'] != null) ...[
            Text(
              forecast['summary'],
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                color: AppTheme.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Predicted next 30 days:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹${totalPredicted.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppTheme.success,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 12),
          ...pts.take(5).map((p) {
            final predicted = double.tryParse(p['predicted'].toString()) ?? 0;
            final high = double.tryParse(p['confidenceHigh'].toString()) ?? 0;
            final dayLabel = p['date']?.toString().substring(5, 10) ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      dayLabel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: high > 0 ? predicted / high : 0,
                        backgroundColor: AppTheme.surface,
                        color: AppTheme.primary.withOpacity(0.7),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '₹${predicted.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (pts.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+ ${pts.length - 5} more days',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Alert Card ─────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  const _AlertCard(this.alert);

  Color _urgencyColor(String? u) => switch (u) {
    'high' => AppTheme.error,
    'medium' => AppTheme.warning,
    _ => AppTheme.success,
  };

  String _urgencyLabel(String? u) => switch (u) {
    'high' => '🔴 Urgent',
    'medium' => '🟡 Soon',
    _ => '🟢 OK',
  };

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColor(alert['urgency']);
    final daysLeft = alert['estimatedDaysLeft'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 3.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert['product'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                _urgencyLabel(alert['urgency']),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            daysLeft != null
                ? 'About $daysLeft days of stock left — order ${alert['reorderQty']} units'
                : 'Check your stock levels',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (alert['recommendation'] != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_rounded,
                  color: AppTheme.warning,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    alert['recommendation'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
