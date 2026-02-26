import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<dynamic> _entries = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/ledger/entries?limit=200');
      setState(() => _entries = res.data['entries'] ?? []);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered => _search.isEmpty
      ? _entries
      : _entries
            .where(
              (e) =>
                  (e['merchant'] ?? '').toLowerCase().contains(
                    _search.toLowerCase(),
                  ) ||
                  (e['transaction_date'] ?? '').toString().contains(_search),
            )
            .toList();

  // Group entries by date
  Map<String, List<dynamic>> _groupByDate(List<dynamic> entries) {
    final grouped = <String, List<dynamic>>{};
    for (final e in entries) {
      final raw = e['transaction_date']?.toString() ?? '';
      final dateKey = raw.length >= 10 ? raw.substring(0, 10) : 'Unknown Date';
      grouped.putIfAbsent(dateKey, () => []).add(e);
    }
    return grouped;
  }

  String _friendlyDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) return 'Today';
      if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
      return '${date.day} ${_month(date.month)} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _month(int m) => [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final grouped = _groupByDate(_filtered);
      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) => b.compareTo(a)); // newest first

      if (sortedKeys.isEmpty) {
        body = ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.book_outlined,
                      color: AppTheme.textSecondary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No records yet',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add a bill and it will appear here',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      } else {
        body = RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: sortedKeys.length,
            itemBuilder: (_, gi) {
              final dateKey = sortedKeys[gi];
              final dayEntries = grouped[dateKey]!;
              final dayTotal = dayEntries.fold<double>(
                0,
                (sum, e) =>
                    sum + (double.tryParse(e['total_amount'].toString()) ?? 0),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Row(
                      children: [
                        Text(
                          _friendlyDate(dateKey),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${dayTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayEntries.map((e) => _EntryCard(e)),
                ],
              );
            },
          ),
        );
      }
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search records...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textSecondary,
                ),
                filled: true,
                fillColor: AppTheme.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _EntryCard(this.entry);

  @override
  Widget build(BuildContext context) {
    final lineItems =
        (entry['line_items'] as List?)?.where((li) => li != null).toList() ??
        [];
    final amount = double.tryParse(entry['total_amount'].toString()) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry['merchant'] ?? 'Unknown Shop',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (lineItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: AppTheme.divider),
            const SizedBox(height: 8),
            ...lineItems
                .take(3)
                .map(
                  (li) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fiber_manual_record_rounded,
                          size: 6,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            li['product_name'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${li['quantity']} × ₹${li['unit_price']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (lineItems.length > 3)
              Text(
                '+${lineItems.length - 3} more items',
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
