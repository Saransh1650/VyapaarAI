import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';
import '../stocks/order_list_provider.dart';

/// Smart Advice screen — reads from backend cache only. No AI is called from the app.
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

  Future<void> _onPullRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      // Only re-fetch from cache — the GET endpoint triggers background
      // refresh automatically when data is stale. Never call the AI directly.
      await _loadInsights();
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
    final generatedAt = _insights?['generatedAt']?.toString();
    final hasAnyData = festivals.isNotEmpty || forecast != null;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _onPullRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last updated badge
            if (generatedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.update_rounded,
                      size: 13,
                      color: AppTheme.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${_timeAgo(generatedAt)}',
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
              const _EmptyInsightsState(),
            ] else ...[
              // ── Coming up for your shop ─────────────────────────────
              if (festivals.isNotEmpty) ...[
                _ConversationalSectionLabel(
                  icon: Icons.event_outlined,
                  title: 'Upcoming Events',
                  subtitle: festivals.length == 1
                      ? '1 event in the next 45 days'
                      : '${festivals.length} events coming up',
                ),
                const SizedBox(height: 14),
                ...festivals.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _UpcomingEventCard(f),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── What to expect next month ───────────────────────────
              _ConversationalSectionLabel(
                icon: Icons.analytics_outlined,
                title: 'Sales Forecast',
                subtitle: 'Next 30 days based on recent sales',
              ),
              const SizedBox(height: 14),
              if (forecast == null)
                const _InfoCard(
                  icon: Icons.auto_graph_outlined,
                  text: 'Pull down to generate your outlook.',
                )
              else
                _HumanForecastCard(forecast),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Conversational Section Label ───────────────────────────────────────────────

class _ConversationalSectionLabel extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _ConversationalSectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: AppTheme.primary),
      ),
      const SizedBox(width: 10),
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

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyInsightsState extends StatelessWidget {
  const _EmptyInsightsState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.primarySurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppTheme.primary,
            size: 48,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Smart Advice Is On Its Way',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep adding bills — advice refreshes\nautomatically once a day.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
      ],
    ),
  );
}

// ── Section Header (kept for compile compat — replaced by _ConversationalSectionLabel in build) ──
// (removed)

// ── Info Card ──────────────────────────────────────────────────────────────────

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

// ── Upcoming Event Card ────────────────────────────────────────────────────────
/// Full-width card per event. Reads like a business advisor message, not a
/// marketing calendar. Specific, warm, and ends with a clear action.

class _UpcomingEventCard extends StatelessWidget {
  final Map<String, dynamic> festival;
  const _UpcomingEventCard(this.festival);

  // Human-readable time (not just a number)
  String _timeLabel(int days) {
    if (days == 0) return 'Today!';
    if (days == 1) return 'Tomorrow';
    if (days <= 7) return 'In $days days';
    if (days <= 14) return 'Next week';
    return 'In $days days';
  }

  // Advisor-tone pitch: urgency + product-specific callout
  String _pitch(String name, int days, List recs) {
    final timeframe = days <= 2
        ? 'Stock up immediately'
        : days <= 7
            ? 'You have a few days to prepare'
            : 'Good time to get ahead of demand';
    if (recs.isEmpty) {
      return '$timeframe — ensure stock levels are ready before the festival.';
    }
    final top = recs
        .take(2)
        .map((r) => r['product'] as String? ?? '')
        .where((p) => p.isNotEmpty)
        .join(' and ');
    return '$timeframe. Demand for $top typically rises during $name. Order now to avoid stockouts.';
  }

  int _boostK(List recs) => recs.isEmpty ? 0 : (recs.length.clamp(1, 5) * 4800 ~/ 1000);

  @override
  Widget build(BuildContext context) {
    final name = festival['festival'] as String? ?? '';
    final days = (festival['daysAway'] as num?)?.toInt() ?? 0;
    final recs = (festival['recommendations'] as List?) ?? [];
    final boostK = _boostK(recs);
    final isUrgent = days <= 7;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? AppTheme.warning.withOpacity(0.35)
              : AppTheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header strip ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isUrgent ? AppTheme.warning : AppTheme.primary)
                      .withOpacity(0.12),
                  AppTheme.primarySurface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isUrgent ? AppTheme.warning : AppTheme.primary).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.event_rounded,
                    size: 24,
                    color: isUrgent ? AppTheme.warning : AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? AppTheme.warning.withOpacity(0.15)
                              : AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _timeLabel(days),
                          style: TextStyle(
                            fontSize: 12,
                            color: isUrgent ? AppTheme.warning : AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Estimated revenue
                if (boostK > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+₹${boostK}K est.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Human advisor pitch ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.primary,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pitch(name, days, recs),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Product list ──────────────────────────────────────────
          if (recs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'What to stock up on:',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            ...recs.take(4).toList().asMap().entries.map((e) {
              return _ProductRecommendationRow(
                e.value as Map<String, dynamic>,
                isTopPick: e.key == 0,
                festivalName: name,
                daysAway: days,
              );
            }),
          ],

          // ── CTA button ────────────────────────────────────────────
          if (recs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Consumer<OrderListProvider>(
                builder: (_, orders, __) {
                  final allAdded = recs.every(
                    (r) => orders.contains(r['product'] as String? ?? ''),
                  );
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            allAdded ? AppTheme.success : AppTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: allAdded
                          ? null
                          : () {
                              for (final r in recs) {
                                final product =
                                    r['product'] as String? ?? '';
                                if (product.isNotEmpty &&
                                    !orders.contains(product)) {
                                  orders.add(OrderItem(
                                    name: product,
                                    reason: days <= 3
                                        ? '$name is almost here'
                                        : '$name in $days days',
                                    qty: 10,
                                  ));
                                }
                              }
                            },
                      child: Text(
                        allAdded
                            ? '✓ All added to order list'
                            : days <= 3
                                ? 'Add all to order list →'
                                : 'Add all to order list →',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
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

// ── Product Recommendation Row ─────────────────────────────────────────────────
/// Top pick gets a highlighted treatment; rest are quieter.
/// Connects to OrderListProvider so the user can add items directly.

class _ProductRecommendationRow extends StatelessWidget {
  final Map<String, dynamic> rec;
  final bool isTopPick;
  final String? festivalName;
  final int? daysAway;
  const _ProductRecommendationRow(
    this.rec, {
    this.isTopPick = false,
    this.festivalName,
    this.daysAway,
  });

  @override
  Widget build(BuildContext context) {
    final pct = rec['percentIncrease'] as num? ?? 0;
    final productName = rec['product'] as String? ?? '';
    final reason = festivalName != null
        ? (daysAway != null && daysAway! <= 3
            ? '$festivalName is almost here'
            : '$festivalName in ${daysAway ?? '?'} days')
        : 'Festival demand';

    return Consumer<OrderListProvider>(
      builder: (_, orders, __) {
        final inList = orders.contains(productName);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isTopPick
                ? AppTheme.primary.withOpacity(0.08)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: isTopPick
                ? Border.all(color: AppTheme.primary.withOpacity(0.25))
                : null,
          ),
          child: Row(
            children: [
              if (isTopPick)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TOP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  productName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isTopPick ? FontWeight.w700 : FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (pct > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '↑$pct%',
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Add to Order button
              GestureDetector(
                onTap: inList
                    ? null
                    : () => orders.add(OrderItem(
                          name: productName,
                          reason: reason,
                          qty: 10,
                        )),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: inList
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: inList
                          ? AppTheme.success.withOpacity(0.3)
                          : AppTheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        inList ? Icons.check_rounded : Icons.add_rounded,
                        size: 12,
                        color: inList ? AppTheme.success : AppTheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        inList ? 'Added' : 'Order',
                        style: TextStyle(
                          color:
                              inList ? AppTheme.success : AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Human Forecast Card ────────────────────────────────────────────────────────
/// No day-by-day bars. Just the headline, a week signal, peak/slow chips,
/// and a single plain-language tip. Shop owners need "what to expect",
/// not a data table.

class _HumanForecastCard extends StatelessWidget {
  final Map<String, dynamic> forecast;
  const _HumanForecastCard(this.forecast);

  @override
  Widget build(BuildContext context) {
    final pts = (forecast['forecast'] as List? ?? []);
    if (pts.isEmpty) {
      return const _InfoCard(
        icon: Icons.auto_graph_outlined,
        text: 'Forecast data is not available yet.',
      );
    }

    // Weekly totals
    double week1 = 0, week2 = 0;
    for (int i = 0; i < pts.length && i < 7; i++) {
      week1 += double.tryParse(pts[i]['predicted'].toString()) ?? 0;
    }
    for (int i = 7; i < pts.length && i < 14; i++) {
      week2 += double.tryParse(pts[i]['predicted'].toString()) ?? 0;
    }
    final weekTrend = week1 > 0
        ? (week2 > week1 * 1.05
            ? 'Second week looks stronger'
            : week2 < week1 * 0.95
                ? 'Second week may be quieter'
                : 'Steady pace expected')
        : '';

    // Peak and slow day
    Map? peakDay, slowDay;
    double peakVal = 0, slowVal = double.infinity;
    for (final p in pts) {
      final v = double.tryParse(p['predicted'].toString()) ?? 0;
      if (v > peakVal) { peakVal = v; peakDay = p; }
      if (v < slowVal) { slowVal = v; slowDay = p; }
    }

    final totalPredicted = pts.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p['predicted'].toString()) ?? 0),
    );

    // Date shorthand helper
    String shortDate(dynamic raw) {
      final s = raw?.toString() ?? '';
      return s.length >= 10 ? s.substring(5, 10) : s;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI summary sentence in quotes
          if (forecast['summary'] != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.primary,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"${forecast['summary']}"',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: AppTheme.divider, height: 28),
          ],

          // Expected revenue headline
          const Text(
            'Expected this month',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${(totalPredicted / 1000).toStringAsFixed(1)}L',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 32,
            ),
          ),
          if (weekTrend.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              weekTrend,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Peak / Slow chips side by side
          Row(
            children: [
              if (peakDay != null)
                Expanded(
                  child: _ForecastSignalChip(
                    icon: Icons.trending_up_rounded,
                    label: 'Best day',
                    value: shortDate(peakDay['date']),
                    color: AppTheme.success,
                  ),
                ),
              if (peakDay != null && slowDay != null) const SizedBox(width: 10),
              if (slowDay != null)
                Expanded(
                  child: _ForecastSignalChip(
                    icon: Icons.trending_down_rounded,
                    label: 'Slower day',
                    value: shortDate(slowDay['date']),
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Single actionable tip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    slowDay != null
                        ? 'Consider running a small offer on your slower day to bring more customers in.'
                        : 'Keep your popular items fully stocked to make the most of this month.',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Forecast Signal Chip ───────────────────────────────────────────────────────

class _ForecastSignalChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _ForecastSignalChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}


