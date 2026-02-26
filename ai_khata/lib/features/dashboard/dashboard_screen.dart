import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../auth/auth_service.dart';
import '../stocks/stock_screen.dart';

// 4 Tabs: Home | Bills | Records | AI Tips
class DashboardScreen extends StatefulWidget {
  final Widget child;
  const DashboardScreen({super.key, required this.child});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _stats;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
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

      // Today's total
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

      final topProduct = rankRes.data['data'].isNotEmpty
          ? rankRes.data['data'][0]['product_name']
          : '—';
      if (mounted) {
        setState(
          () => _stats = {
            'monthly': total,
            'today': todayTotal,
            'topProduct': topProduct,
            'txCount': trends.length,
          },
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  static const _tabs = [
    (
      label: 'Home',
      icon: Icons.home_rounded,
      outlinedIcon: Icons.home_outlined,
    ),
    (
      label: 'Bills',
      icon: Icons.receipt_rounded,
      outlinedIcon: Icons.receipt_outlined,
    ),
    (
      label: 'Records',
      icon: Icons.book_rounded,
      outlinedIcon: Icons.book_outlined,
    ),
    (
      label: 'Stock',
      icon: Icons.inventory_2_rounded,
      outlinedIcon: Icons.inventory_2_outlined,
    ),
    (
      label: 'AI Tips',
      icon: Icons.lightbulb_rounded,
      outlinedIcon: Icons.lightbulb_outline,
    ),
  ];

  static const _routes = [
    '/dashboard',
    '/dashboard/bills',
    '/dashboard/records',
    '/dashboard/stocks',
    '/dashboard/insights',
  ];

  String get _storeName {
    final auth = context.read<AuthService>();
    return auth.userName ?? 'My Shop';
  }

  Widget _buildHomeContent() {
    final auth = context.read<AuthService>();
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Greeting header
            Text(
              'Hello, ${auth.userName ?? 'there'} 👋',
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(_storeName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),

            // Today's sales — big card
            _TodaySalesCard(
              loading: _statsLoading,
              todayTotal: _stats?['today'] as double? ?? 0,
              monthlyTotal: _stats?['monthly'] as double? ?? 0,
            ),
            const SizedBox(height: 16),

            // Quick stats row
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    label: 'Best Seller',
                    value: _statsLoading
                        ? '...'
                        : (_stats?['topProduct'] as String? ?? '—'),
                    icon: Icons.star_rounded,
                    color: AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatCard(
                    label: 'Days Tracked',
                    value: _statsLoading
                        ? '...'
                        : (_stats?['txCount'] ?? 0).toString(),
                    icon: Icons.calendar_today_rounded,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _BigActionButton(
                    label: 'Scan a Bill',
                    sublabel: 'Take photo',
                    icon: Icons.camera_alt_rounded,
                    color: AppTheme.primary,
                    onTap: () => context.go(AppConstants.routeBillScanner),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _BigActionButton(
                    label: 'Add Bill',
                    sublabel: 'Type manually',
                    icon: Icons.edit_rounded,
                    color: AppTheme.primaryLight,
                    onTap: () => context.go(AppConstants.routeBillManual),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _BigActionButton(
                    label: 'Sales Report',
                    sublabel: 'View charts',
                    icon: Icons.bar_chart_rounded,
                    color: AppTheme.success,
                    onTap: () {
                      setState(() => _currentIndex = 3);
                      context.go(_routes[3]);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _BigActionButton(
                    label: 'Records',
                    sublabel: 'All transactions',
                    icon: Icons.book_rounded,
                    color: AppTheme.warning,
                    onTap: () {
                      setState(() => _currentIndex = 2);
                      context.go(_routes[2]);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 0) return _buildHomeContent();
    if (_currentIndex == 3) return const StockScreen();
    return widget.child;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex].label),
        actions: [
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
      body: _buildBody(),
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
      // Floating Add Bill button (visible on home)
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOptions(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Bill',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : _currentIndex == 3
          ? null // Stock screen has its own FAB
          : null,
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'How would you like to add a bill?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            _BottomSheetOption(
              icon: Icons.camera_alt_rounded,
              iconBg: AppTheme.primarySurface,
              iconColor: AppTheme.primary,
              title: 'Scan a Bill',
              subtitle: 'Take a photo — we read it for you',
              onTap: () {
                Navigator.pop(context);
                context.go(AppConstants.routeBillScanner);
              },
            ),
            _BottomSheetOption(
              icon: Icons.edit_rounded,
              iconBg: AppTheme.success.withOpacity(0.12),
              iconColor: AppTheme.success,
              title: 'Type it in',
              subtitle: 'Enter bill details manually',
              onTap: () {
                Navigator.pop(context);
                context.go(AppConstants.routeBillManual);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Today's Sales Card ─────────────────────────────────────────────────────────

class _TodaySalesCard extends StatelessWidget {
  final bool loading;
  final double todayTotal;
  final double monthlyTotal;
  const _TodaySalesCard({
    required this.loading,
    required this.todayTotal,
    required this.monthlyTotal,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
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
              const SizedBox(height: 6),
              Text(
                '₹${todayTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: Colors.white24),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'This month: ₹${monthlyTotal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
  );
}

// ── Mini Stat Card ─────────────────────────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

// ── Big Action Button ──────────────────────────────────────────────────────────

class _BigActionButton extends StatelessWidget {
  final String label, sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BigActionButton({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
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

// ── Bottom Sheet Option ────────────────────────────────────────────────────────

class _BottomSheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle;
  final VoidCallback onTap;
  const _BottomSheetOption({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
    ),
    onTap: onTap,
  );
}
