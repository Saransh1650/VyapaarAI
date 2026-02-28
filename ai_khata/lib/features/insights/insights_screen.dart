import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';
import '../stocks/order_list_provider.dart';

/// Smart Advice screen — renders AI guidance cards from the backend cache.
/// The backend auto-refreshes guidance daily or after 20 new ledger entries.
/// Card types: stock_check, pattern, event_context, info.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? _guidance;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  String? _generatedAt;

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
      final insights = res.data['insights'];
      if (mounted) {
        setState(() {
          _guidance = insights?['guidance'] as Map<String, dynamic>?;
          _generatedAt = insights?['generatedAt']?.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load advice. Pull down to retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onPullRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
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

    if (_error != null && _guidance == null) {
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

    final mode = _guidance?['mode'] as String? ?? 'NORMAL';
    final cards = (_guidance?['guidance'] as List?) ?? [];
    final isEvent = mode == 'EVENT';
    final hasData = cards.isNotEmpty;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _onPullRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Updated timestamp ──────────────────────────────────
            if (_generatedAt != null)
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
                      'Updated ${_timeAgo(_generatedAt)}',
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

            // ── Event mode banner ─────────────────────────────────
            if (isEvent) _EventModeBanner(cards: cards),

            // ── Guidance cards ─────────────────────────────────────
            if (!hasData)
              const _EmptyState()
            else
              ...cards.map((c) {
                final card = c as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildCard(card),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> card) {
    switch (card['type']) {
      case 'stock_check':
        return _StockCheckCard(card);
      case 'pattern':
        return _PatternCard(card);
      case 'event_context':
        return _EventContextCard(card);
      case 'info':
        return _GuidanceInfoCard(card);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENT MODE BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _EventModeBanner extends StatelessWidget {
  final List cards;
  const _EventModeBanner({required this.cards});

  Map<String, dynamic>? _eventCard() {
    for (final c in cards) {
      if (c is Map && c['type'] == 'event_context') return c as Map<String, dynamic>;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ec = _eventCard();
    final event = ec?['event'] as String?;
    final summary = ec?['summary'] as String?;
    final items = (ec?['items'] as List?) ?? [];
    final criticalCount = items.where((i) => (i['urgency'] as String?) == 'critical').length;
    final highCount = items.where((i) => (i['urgency'] as String?) == 'high').length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.error.withOpacity(criticalCount > 0 ? 0.12 : 0.06),
            AppTheme.warning.withOpacity(0.12),
            AppTheme.primary.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: criticalCount > 0
              ? AppTheme.error.withOpacity(0.35)
              : AppTheme.warning.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 18,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event != null ? '🎉 $event Mode' : 'Festival Mode',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (summary != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          summary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (criticalCount > 0 || highCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (criticalCount > 0)
                  _UrgencyBadge(
                    count: criticalCount,
                    label: 'Need Now',
                    color: AppTheme.error,
                  ),
                if (criticalCount > 0 && highCount > 0)
                  const SizedBox(width: 8),
                if (highCount > 0)
                  _UrgencyBadge(
                    count: highCount,
                    label: 'Stock Up',
                    color: AppTheme.warning,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _UrgencyBadge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            color == AppTheme.error
                ? Icons.priority_high_rounded
                : Icons.trending_up_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STOCK CHECK CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StockCheckCard extends StatelessWidget {
  final Map<String, dynamic> card;
  const _StockCheckCard(this.card);

  static const _statusConfig = {
    'GOOD': (
      color: AppTheme.success,
      icon: Icons.check_circle_rounded,
      label: 'Good',
    ),
    'WATCH': (
      color: AppTheme.warning,
      icon: Icons.watch_later_rounded,
      label: 'Watch',
    ),
    'LOW': (color: AppTheme.error, icon: Icons.warning_rounded, label: 'Low'),
  };

  @override
  Widget build(BuildContext context) {
    final items = (card['items'] as List?) ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Stock Health',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Summary badges
                _StatusCount(items: items, status: 'LOW'),
                const SizedBox(width: 6),
                _StatusCount(items: items, status: 'WATCH'),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          // Item rows
          ...items.map((item) => _StockItemRow(item as Map<String, dynamic>)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  final List items;
  final String status;
  const _StatusCount({required this.items, required this.status});

  @override
  Widget build(BuildContext context) {
    final count = items
        .where((i) => (i['status'] as String?)?.toUpperCase() == status)
        .length;
    if (count == 0) return const SizedBox.shrink();

    final color = status == 'LOW' ? AppTheme.error : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count ${status.toLowerCase()}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StockItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _StockItemRow(this.item);

  @override
  Widget build(BuildContext context) {
    final product = item['product'] as String? ?? '';
    final status = (item['status'] as String? ?? 'GOOD').toUpperCase();
    final reason = item['reason'] as String? ?? '';
    final action = item['action'] as String? ?? '';

    final cfg =
        _StockCheckCard._statusConfig[status] ??
        _StockCheckCard._statusConfig['GOOD']!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(cfg.icon, size: 18, color: cfg.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cfg.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cfg.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cfg.color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (action.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '→ $action',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cfg.color,
                        height: 1.4,
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

// ─────────────────────────────────────────────────────────────────────────────
// PATTERN CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PatternCard extends StatelessWidget {
  final Map<String, dynamic> card;
  const _PatternCard(this.card);

  @override
  Widget build(BuildContext context) {
    final insight = card['insight'] as String? ?? '';
    final action = card['action'] as String? ?? '';
    if (insight.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              size: 16,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trend',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (action.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 13,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            action,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENT CONTEXT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EventContextCard extends StatelessWidget {
  final Map<String, dynamic> card;
  const _EventContextCard(this.card);

  static const _urgencyOrder = {'critical': 0, 'high': 1, 'moderate': 2};

  @override
  Widget build(BuildContext context) {
    final event = card['event'] as String? ?? '';
    final items = List<Map<String, dynamic>>.from(
      (card['items'] as List?)?.map((e) => e as Map<String, dynamic>) ?? [],
    );
    if (items.isEmpty) return const SizedBox.shrink();

    // Sort by urgency: critical → high → moderate → rest
    items.sort((a, b) {
      final ua = _urgencyOrder[a['urgency']] ?? 3;
      final ub = _urgencyOrder[b['urgency']] ?? 3;
      return ua.compareTo(ub);
    });

    final hasCritical = items.any((i) => i['urgency'] == 'critical');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasCritical
              ? AppTheme.error.withOpacity(0.3)
              : AppTheme.warning.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasCritical
                    ? [
                        AppTheme.error.withOpacity(0.1),
                        AppTheme.warning.withOpacity(0.06),
                      ]
                    : [
                        AppTheme.warning.withOpacity(0.1),
                        AppTheme.primarySurface,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: hasCritical
                        ? AppTheme.error.withOpacity(0.12)
                        : AppTheme.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasCritical
                        ? Icons.local_fire_department_rounded
                        : Icons.event_rounded,
                    size: 16,
                    color: hasCritical ? AppTheme.error : AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.isEmpty ? 'Festival Demand' : '$event — Stock Up',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          // Item rows
          ...items.map((item) => _EventItemRow(item)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EventItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _EventItemRow(this.item);

  static const _urgencyConfig = {
    'critical': (
      color: AppTheme.error,
      icon: Icons.priority_high_rounded,
      label: '🔴 Order Now',
      bgOpacity: 0.08,
    ),
    'high': (
      color: AppTheme.warning,
      icon: Icons.trending_up_rounded,
      label: '🟠 Stock Up',
      bgOpacity: 0.06,
    ),
    'moderate': (
      color: AppTheme.primary,
      icon: Icons.info_outline_rounded,
      label: '🟡 Extra',
      bgOpacity: 0.04,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final product = item['product'] as String? ?? '';
    final urgency = item['urgency'] as String? ?? 'moderate';
    final demandNote = item['demand_note'] as String? ?? '';
    final classification =
        item['classification'] as String? ?? 'existing_product';
    final action = item['action'] as String? ?? '';
    final isOpportunity = classification == 'opportunity';

    final cfg = _urgencyConfig[urgency] ?? _urgencyConfig['moderate']!;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: cfg.color.withOpacity(cfg.bgOpacity),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(cfg.icon, size: 18, color: cfg.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name + urgency badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cfg.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOpportunity ? '✨ New' : cfg.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cfg.color,
                        ),
                      ),
                    ),
                  ],
                ),
                // Demand note — the key new info
                if (demandNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      demandNote,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cfg.color,
                        height: 1.4,
                      ),
                    ),
                  ),
                // Action
                if (action.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '→ $action',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Add to order list button
          Consumer<OrderListProvider>(
            builder: (_, orders, __) {
              final inList = orders.contains(product);
              return GestureDetector(
                onTap: inList
                    ? null
                    : () => orders.add(
                        OrderItem(
                          name: product,
                          reason: '${item['event'] ?? 'Festival'} prep — $urgency',
                          qty: urgency == 'critical' ? 30 : urgency == 'high' ? 20 : 10,
                        ),
                      ),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: inList
                        ? AppTheme.success.withOpacity(0.1)
                        : cfg.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: inList
                          ? AppTheme.success.withOpacity(0.3)
                          : cfg.color.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        inList ? Icons.check_rounded : Icons.add_rounded,
                        size: 12,
                        color: inList ? AppTheme.success : cfg.color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        inList ? 'Added' : 'Order',
                        style: TextStyle(
                          color: inList ? AppTheme.success : cfg.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _GuidanceInfoCard extends StatelessWidget {
  final Map<String, dynamic> card;
  const _GuidanceInfoCard(this.card);

  @override
  Widget build(BuildContext context) {
    final insight = card['insight'] as String? ?? '';
    if (insight.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
