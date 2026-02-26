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
      final res = await ApiClient.instance.dio.get('/ledger/entries?limit=100');
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
              (e) => (e['merchant'] ?? '').toLowerCase().contains(
                _search.toLowerCase(),
              ),
            )
            .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by merchant...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.textSecondary,
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No entries found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _EntryCard(_filtered[i]),
                        ),
                ),
        ),
      ],
    ),
  );
}

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _EntryCard(this.entry);

  @override
  Widget build(BuildContext context) {
    final lineItems = entry['line_items'] as List? ?? [];
    final filtered = lineItems.where((li) => li != null).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry['merchant'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '₹${double.tryParse(entry['total_amount'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry['transaction_date']?.toString().substring(0, 10) ?? '',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...filtered
                .take(3)
                .map(
                  (li) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            li['product_name'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
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
            if (filtered.length > 3)
              Text(
                '+${filtered.length - 3} more items',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
