import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../auth/auth_service.dart';

// 3 Tabs: Home | Smart Advice | Inventory
class DashboardScreen extends StatefulWidget {
  final Widget child;
  const DashboardScreen({super.key, required this.child});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // Home state
  Map<String, dynamic>? _stats;
  bool _statsLoading = true;
  List<dynamic> _urgentAlerts = [];

  // AI suggestions for Action Center
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => _statsLoading = true);
    await Future.wait([_loadStats(), _loadUrgentAlerts()]);
    if (mounted) setState(() => _statsLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      final dio = ApiClient.instance.dio;
      final trendsRes = await dio.get('/analytics/sales-trends?days=30');
      final rankRes = await dio.get(
        '/analytics/product-rankings?days=30&limit=1',
      );
      final trends = (trendsRes.data['data'] as List);
      final total = trends.fold<double>(
        0,
        (sum, d) => sum + (double.tryParse(d['total'].toString()) ?? 0),
      );

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todayData = trends
          .where((d) => d['day']?.toString().startsWith(todayStr) == true)
          .toList();
      final todayTotal = todayData.fold<double>(
        0,
        (sum, d) => sum + (double.tryParse(d['total'].toString()) ?? 0),
      );

      // Yesterday comparison
      final yesterdayStr = (() {
        final y = today.subtract(const Duration(days: 1));
        return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
      })();
      final yesterdayData = trends
          .where((d) => d['day']?.toString().startsWith(yesterdayStr) == true)
          .toList();
      final yesterdayTotal = yesterdayData.fold<double>(
        0,
        (sum, d) => sum + (double.tryParse(d['total'].toString()) ?? 0),
      );

      final topProduct = rankRes.data['data'].isNotEmpty
          ? rankRes.data['data'][0]['product_name']
          : '—';

      if (mounted) {
        _stats = {
          'monthly': total,
          'today': todayTotal,
          'yesterday': yesterdayTotal,
          'topProduct': topProduct,
          'txCount': trends.length,
        };
      }
    } catch (_) {}
  }

  Future<void> _loadUrgentAlerts() async {
    try {
      final auth = context.read<AuthService>();
      final res = await ApiClient.instance.dio.get(
        '/ai/insights',
        queryParameters: {'storeId': auth.storeId, 'storeType': auth.storeType},
      );
      final insights = res.data['insights'] as Map<String, dynamic>?;
      final inventory = insights?['inventory'] as Map<String, dynamic>?;
      final alerts = (inventory?['alerts'] as List?) ?? [];
      final festivals = (insights?['festival'] as List?) ?? [];

      if (mounted) {
        // Build Action Center suggestions from AI data
        final suggestions = <Map<String, dynamic>>[];
        for (final a in alerts.where((a) => a['urgency'] == 'high').take(2)) {
          suggestions.add({
            'type': 'restock',
            'urgency': 'high',
            'title': '${a['product']} will run out soon',
            'body': a['recommendation'] ?? 'Order before you run out of stock.',
            'cta': 'Order Now →',
            'ctaRoute': '/dashboard/inventory',
          });
        }
        for (final a in alerts.where((a) => a['urgency'] == 'medium').take(1)) {
          suggestions.add({
            'type': 'restock',
            'urgency': 'medium',
            'title': '${a['product']} is getting low',
            'body':
                a['recommendation'] ??
                'About ${a['estimatedDaysLeft']} days left. Order soon.',
            'cta': 'Check Stock →',
            'ctaRoute': '/dashboard/inventory',
          });
        }
        if (festivals.isNotEmpty) {
          final f = festivals[0];
          suggestions.add({
            'type': 'festival',
            'urgency': 'opportunity',
            'title': '${f['festival']} — ${f['daysAway']} days away',
            'body': 'Customers will buy more. Stock up now to avoid missing out.',
            'cta': 'See Plan →',
            'ctaRoute': '/dashboard/advice',
          });
        }

        _urgentAlerts = alerts
            .where((a) => a['urgency'] == 'high' || a['urgency'] == 'medium')
            .take(3)
            .toList();
        _suggestions = suggestions;
      }
    } catch (_) {}
  }

  static const _tabs = [
    (
      label: 'Home',
      icon: Icons.home_rounded,
      outlinedIcon: Icons.home_outlined,
    ),
    (
      label: 'Advice',
      icon: Icons.lightbulb_rounded,
      outlinedIcon: Icons.lightbulb_outline,
    ),
    (
      label: 'Inventory',
      icon: Icons.inventory_2_rounded,
      outlinedIcon: Icons.inventory_2_outlined,
    ),
  ];

  static const _routes = [
    '/dashboard',
    '/dashboard/advice',
    '/dashboard/inventory',
  ];

  Widget _buildHomeContent() {
    final todayTotal = _stats?['today'] as double? ?? 0;
    final yesterday = _stats?['yesterday'] as double? ?? 0;
    final monthly = _stats?['monthly'] as double? ?? 0;
    final topProduct = _stats?['topProduct'] as String? ?? '—';

    // High-urgency alerts only — shown as a banner above the fold
    final highAlerts = _urgentAlerts
        .where((a) => a['urgency'] == 'high')
        .take(1)
        .toList();
    final mediumAlerts = _urgentAlerts
        .where((a) => a['urgency'] == 'medium')
        .take(2)
        .toList();

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadHomeData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // ── 1. URGENT BANNER — shown first if stock is critical ───
            if (!_statsLoading && highAlerts.isNotEmpty) ...[
              _UrgentBanner(
                alert: highAlerts[0],
                onTap: () => context.go('/dashboard/inventory'),
              ),
              const SizedBox(height: 14),
            ],

            // ── 2. PRIMARY ACTION — always above the fold ─────────────
            _PrimaryAddBillCard(
              onScan: () => context.go(AppConstants.routeBillScanner),
              onManual: () => context.go(AppConstants.routeBillManual),
            ),
            const SizedBox(height: 14),

            // ── 3. TODAY SALES — compact, decision-oriented ───────────
            _TodayPerformanceCard(
              loading: _statsLoading,
              todayTotal: todayTotal,
              monthlyTotal: monthly,
              yesterdayTotal: yesterday,
            ),
            const SizedBox(height: 14),

            // ── 4. AI ACTION CENTER — swipeable suggestions ───────────
            if (!_statsLoading && _suggestions.isNotEmpty) ...[
              _ActionCenterCard(suggestions: _suggestions),
              const SizedBox(height: 14),
            ],

            // ── 5. QUICK HEALTH CHIPS — ambient store pulse ───────────
            _QuickHealthRow(
              loading: _statsLoading,
              topProduct: topProduct,
              urgentCount: _urgentAlerts.length,
            ),
            const SizedBox(height: 20),

            // ── 6. MEDIUM ALERTS — restocking nudges ──────────────────
            if (!_statsLoading && mediumAlerts.isNotEmpty) ...[
              _SectionLabel(
                icon: Icons.inventory_2_rounded,
                label: 'Running Low',
                color: AppTheme.warning,
              ),
              const SizedBox(height: 10),
              ...mediumAlerts.map(
                (a) => _HomeAlertTile(
                  alert: a,
                  onTap: () => context.go('/dashboard/inventory'),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── 7. SECONDARY ACTIONS — history & records ──────────────
            _SectionLabel(
              icon: Icons.folder_open_rounded,
              label: 'Records',
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    label: 'Bills',
                    sublabel: 'View history',
                    icon: Icons.receipt_long_rounded,
                    color: AppTheme.success,
                    onTap: () => context.go('/dashboard/bills'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    label: 'Transactions',
                    sublabel: 'All records',
                    icon: Icons.book_rounded,
                    color: AppTheme.warning,
                    onTap: () => context.go('/dashboard/records'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _secondaryRoutes = [
    '/dashboard/bills',
    '/dashboard/records',
    '/dashboard/bills/scan',
    '/dashboard/bills/manual',
  ];

  Widget _buildBody(String location) {
    // Secondary screens (Bills, Records, Scanner, Manual) render widget.child
    if (_secondaryRoutes.contains(location)) return widget.child;
    if (_currentIndex == 0) return _buildHomeContent();
    return widget.child;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isSecondary = _secondaryRoutes.contains(location);

    // Derive AppBar title
    final appBarTitle = switch (location) {
      '/dashboard/bills' => 'All Bills',
      '/dashboard/records' => 'Transactions',
      '/dashboard/bills/scan' => 'Scan a Bill',
      '/dashboard/bills/manual' => 'Add a Bill',
      _ => switch (_currentIndex) {
        0 => '',        // Home uses custom title widget
        1 => 'Smart Advice',
        2 => 'Inventory',
        _ => '',
      },
    };

    final auth = context.read<AuthService>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      appBar: AppBar(
        title: (!isSecondary && _currentIndex == 0)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$greeting, ${auth.userName ?? 'there'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _statsLoading
                        ? 'Loading your shop...'
                        : _urgentAlerts.isNotEmpty
                            ? '${_urgentAlerts.length} item${_urgentAlerts.length > 1 ? 's' : ''} need your attention'
                            : 'Everything looks good today ✓',
                    style: TextStyle(
                      fontSize: 11,
                      color: _statsLoading
                          ? AppTheme.textHint
                          : _urgentAlerts.isNotEmpty
                              ? AppTheme.warning
                              : AppTheme.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Text(appBarTitle),
        // Show back button on secondary screens
        leading: isSecondary
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go(AppConstants.routeDashboard),
              )
            : null,
        actions: isSecondary
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  tooltip: 'Log out',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppTheme.card,
                        title: const Text('Log out?'),
                        content: const Text(
                          'You will be returned to the login screen.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Log out',
                              style: TextStyle(color: AppTheme.error),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await context.read<AuthService>().logout();
                      if (mounted) context.go(AppConstants.routeLogin);
                    }
                  },
                ),
              ],
      ),
      body: _buildBody(location),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (_currentIndex == i) return;
          setState(() => _currentIndex = i);
          context.go(_routes[i]);
        },
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.outlinedIcon),
                selectedIcon: Icon(t.icon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }

}


// ── Urgent Banner ──────────────────────────────────────────────────────────────
/// Full-width strip shown at the very top when a high-urgency stock alert fires.
/// Immediately answers: "What's broken right now?"
class _UrgentBanner extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onTap;
  const _UrgentBanner({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final product = alert['product'] as String? ?? 'Unknown product';
    final daysLeft = alert['estimatedDaysLeft'];
    final timeMsg = daysLeft != null
        ? (daysLeft <= 1 ? 'runs out tomorrow' : 'only $daysLeft days left')
        : 'running critically low';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.error.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_rounded, color: AppTheme.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$product $timeMsg',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to order before you run out',
                    style: TextStyle(color: AppTheme.error, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Order Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Primary Add Bill Card ───────────────────────────────────────────────────────
/// The #1 action on the home screen. Prominent, always visible, impossible to miss.
/// Adding a bill is the core daily loop — so it earns the top real estate.
class _PrimaryAddBillCard extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onManual;
  const _PrimaryAddBillCard({required this.onScan, required this.onManual});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.primarySurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.add_circle_rounded, color: AppTheme.primary, size: 18),
            SizedBox(width: 8),
            Text(
              'Add a Bill',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: onScan,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Scan Bill',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: onManual,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_rounded,
                          color: AppTheme.primary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Type In',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Section Label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ],
  );
}

// ── Action Center Card ─────────────────────────────────────────────────────────

class _ActionCenterCard extends StatefulWidget {
  final List<Map<String, dynamic>> suggestions;
  const _ActionCenterCard({required this.suggestions});
  @override
  State<_ActionCenterCard> createState() => _ActionCenterCardState();
}

class _ActionCenterCardState extends State<_ActionCenterCard> {
  int _page = 0;
  final _ctrl = PageController();

  Color _urgencyColor(String? u) => switch (u) {
    'high' => AppTheme.error,
    'medium' => AppTheme.warning,
    'opportunity' => AppTheme.primary,
    _ => AppTheme.textSecondary,
  };

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Priorities',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${widget.suggestions.length} item${widget.suggestions.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (widget.suggestions.length > 1)
                  Text(
                    '${_page + 1} of ${widget.suggestions.length}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Swipeable suggestion cards
          SizedBox(
            height: 110,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: widget.suggestions.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final s = widget.suggestions[i];
                final color = _urgencyColor(s['urgency']);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: _urgencyColor(s['urgency']),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s['body'],
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => context.go(s['ctaRoute']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Text(
                            s['cta'],
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Page dots
          if (widget.suggestions.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.suggestions.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? AppTheme.primary : AppTheme.textHint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Today Performance Card ─────────────────────────────────────────────────────

class _TodayPerformanceCard extends StatelessWidget {
  final bool loading;
  final double todayTotal;
  final double monthlyTotal;
  final double yesterdayTotal;
  const _TodayPerformanceCard({
    required this.loading,
    required this.todayTotal,
    required this.monthlyTotal,
    required this.yesterdayTotal,
  });

  String get _comparisonText {
    if (yesterdayTotal <= 0) return 'No sales yesterday to compare';
    final diff = todayTotal - yesterdayTotal;
    final pct = (diff / yesterdayTotal * 100).abs().toStringAsFixed(0);
    if (diff > 0) return '↑ $pct% from yesterday';
    if (diff < 0) return '↓ $pct% from yesterday';
    return 'Same as yesterday';
  }

  String get _aiInterpretation {
    if (todayTotal <= 0) return 'No bills added yet — scan your first bill to start tracking.';
    if (todayTotal > yesterdayTotal && yesterdayTotal > 0) {
      return 'You\'re beating yesterday. Keep the momentum going!';
    }
    if (todayTotal < yesterdayTotal && yesterdayTotal > 0) {
      return 'Slower than yesterday. Check if any popular items are out of stock.';
    }
    if (monthlyTotal > 0) {
      final projected =
          (todayTotal / DateTime.now().hour.clamp(1, 24)) * 24 * 30;
      final projStr = '₹${(projected / 1000).toStringAsFixed(1)}L';
      return 'On this pace, you\'ll do ~$projStr this month.';
    }
    return 'Sales tracking active.';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppTheme.primary, AppTheme.primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: loading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Sales",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${todayTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'till ${TimeOfDay.now().format(context)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Comparison row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _comparisonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white24),
              const SizedBox(height: 10),
              // AI interpretation sentence
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white70,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _aiInterpretation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white70,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'This month: ₹${monthlyTotal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
  );
}

// ── Quick Health Row ───────────────────────────────────────────────────────────

class _QuickHealthRow extends StatelessWidget {
  final bool loading;
  final String topProduct;
  final int urgentCount;
  const _QuickHealthRow({
    required this.loading,
    required this.topProduct,
    required this.urgentCount,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _HealthChip(
          icon: Icons.star_rounded,
          label: 'Best Seller',
          value: loading ? '...' : topProduct,
          color: AppTheme.warning,
        ),
      ),
      if (urgentCount > 0) ...[
        const SizedBox(width: 10),
        Expanded(
          child: _HealthChip(
            icon: Icons.warning_amber_rounded,
            label: 'Low Stock',
            value: '$urgentCount item${urgentCount > 1 ? 's' : ''}',
            color: AppTheme.error,
          ),
        ),
      ],
      if (urgentCount == 0) ...[
        const SizedBox(width: 10),
        Expanded(
          child: _HealthChip(
            icon: Icons.check_circle_outline_rounded,
            label: 'Stock Status',
            value: 'All good',
            color: AppTheme.success,
          ),
        ),
      ],
    ],
  );
}

class _HealthChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _HealthChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

// ── Inline Home Alert Tile ─────────────────────────────────────────────────────

class _HomeAlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onTap;
  const _HomeAlertTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHigh = alert['urgency'] == 'high';
    final color = isHigh ? AppTheme.error : AppTheme.warning;
    final daysLeft = alert['estimatedDaysLeft'];
    final daysText = daysLeft != null
        ? (daysLeft <= 1 ? '⏰ Runs out tomorrow' : '~$daysLeft days left')
        : 'Check stock levels';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Text(isHigh ? '🔴' : '🟡', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert['product'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(daysText, style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isHigh ? 'Order Now' : 'Restock',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Action Tile ──────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final String label, sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
