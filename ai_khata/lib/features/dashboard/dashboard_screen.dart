import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../auth/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  final Widget child;
  const DashboardScreen({super.key, required this.child});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
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
      final topProduct = rankRes.data['data'].isNotEmpty
          ? rankRes.data['data'][0]['product_name']
          : 'N/A';
      if (mounted)
        setState(
          () => _stats = {
            'total': total,
            'topProduct': topProduct,
            'txCount': trends.length,
          },
        );
    } catch (_) {}
  }

  static const _tabs = [
    ('Dashboard', Icons.dashboard_outlined),
    ('Bills', Icons.receipt_outlined),
    ('Ledger', Icons.book_outlined),
    ('Analytics', Icons.bar_chart),
    ('Insights', Icons.lightbulb_outlined),
  ];

  static const _routes = [
    '/dashboard',
    '/dashboard/bills',
    '/dashboard/ledger',
    '/dashboard/analytics',
    '/dashboard/insights',
  ];

  Widget _buildHomeContent() {
    final auth = context.read<AuthService>();
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              auth.userName ?? 'User',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    'Total Sales (30d)',
                    _stats == null
                        ? '...'
                        : '₹${(_stats!['total'] as double).toStringAsFixed(0)}',
                    Icons.trending_up,
                    AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    'Top Product',
                    _stats == null ? '...' : (_stats!['topProduct'] as String),
                    Icons.star_outline,
                    AppTheme.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              'Transactions (30d)',
              _stats == null ? '...' : _stats!['txCount'].toString(),
              Icons.receipt_long_outlined,
              AppTheme.success,
            ),
            const SizedBox(height: 24),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    'Scan Bill',
                    Icons.camera_alt_outlined,
                    () => context.go('/dashboard/bills'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    'Add Manual',
                    Icons.edit_outlined,
                    () => context.go(AppConstants.routeBillManual),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    'Insights',
                    Icons.lightbulb_outline,
                    () => context.go('/dashboard/insights'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex].$1),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (mounted) context.go(AppConstants.routeLogin);
            },
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildHomeContent() : widget.child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          context.go(_routes[i]);
        },
        destinations: _tabs
            .map((t) => NavigationDestination(icon: Icon(t.$2), label: t.$1))
            .toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickAction(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    ),
  );
}
