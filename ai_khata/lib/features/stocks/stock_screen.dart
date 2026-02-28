import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';
import 'order_list_provider.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<dynamic> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadStock();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      final res = await ApiClient.instance.dio.get(
        '/stocks',
        queryParameters: {'storeId': auth.storeId},
      );
      if (mounted) setState(() => _items = res.data['items'] ?? []);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load stock. Pull to refresh.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await ApiClient.instance.dio.delete('/stocks/$id');
      await _loadStock();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove item')),
        );
      }
    }
  }

  Future<void> _updateQty(Map<String, dynamic> item, double newQty) async {
    try {
      final auth = context.read<AuthService>();
      await ApiClient.instance.dio.put(
        '/stocks/${item['id']}',
        data: {
          'storeId': auth.storeId,
          'productName': item['product_name'],
          'quantity': newQty,
          'unit': item['unit'] ?? 'units',
          'costPrice': item['cost_price'],
        },
      );
      await _loadStock();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update quantity')),
        );
      }
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddEditStockSheet(existing: existing, onSaved: _loadStock),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Remove Item?'),
        content: const Text('This will remove the item from your stock list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(dialogContext); _deleteItem(id); },
            child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  List<dynamic> get _sortedItems {
    final out   = _items.where((i) => (double.tryParse(i['quantity'].toString()) ?? 0) <= 0).toList();
    final low   = _items.where((i) { final q = double.tryParse(i['quantity'].toString()) ?? 0; return q > 0 && q <= 5; }).toList();
    final good  = _items.where((i) => (double.tryParse(i['quantity'].toString()) ?? 0) > 5).toList();
    return [...out, ...low, ...good];
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderListProvider>();
    final orderCount = orderProvider.count;

    return Scaffold(
      body: Column(
        children: [
          // ── Tab bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                const Tab(text: 'In Stock'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('To Order'),
                      if (orderCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$orderCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInStockTab(),
                _buildToOrderTab(orderProvider),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // In Stock tab
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildInStockTab() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppTheme.textHint, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _loadStock, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) return _EmptyState(onAdd: () => _showAddEditDialog());

    final sorted = _sortedItems;
    final outCount = sorted.where((i) => (double.tryParse(i['quantity'].toString()) ?? 0) <= 0).length;
    final lowCount = sorted.where((i) { final q = double.tryParse(i['quantity'].toString()) ?? 0; return q > 0 && q <= 5; }).length;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadStock,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: sorted.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _StockSummaryRow(total: sorted.length, outCount: outCount, lowCount: lowCount),
            );
          }
          final item = sorted[i - 1];
          return _InStockItemCard(
            item: item,
            onEdit: () => _showAddEditDialog(existing: item),
            onDelete: () => _confirmDelete(item['id'] as String),
            onUpdateQty: (newQty) => _updateQty(item, newQty),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // To Order tab
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildToOrderTab(OrderListProvider provider) {
    if (provider.items.isEmpty) return const _EmptyOrderState();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            itemCount: provider.items.length,
            itemBuilder: (_, i) {
              final item = provider.items[i];
              return _OrderItemCard(
                item: item,
                onRemove: () => provider.remove(item.name),
                onQtyChanged: (qty) => provider.updateQty(item.name, qty),
                onUnitChanged: (unit) => provider.updateUnit(item.name, unit),
              );
            },
          ),
        ),
        // Bottom action bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.divider)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart_rounded, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${provider.count} item${provider.count > 1 ? 's' : ''} to order',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmClearOrders(provider),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.divider),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Clear List', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _markAllOrdered(provider),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Ordered — Update Stock'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmClearOrders(OrderListProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Clear order list?'),
        content: const Text('This removes all items from your list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async { Navigator.pop(dialogContext); await provider.markAllOrdered(); },
            child: const Text('Clear', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllOrdered(OrderListProvider provider) async {
    final items = List<OrderItem>.from(provider.items);
    bool anyUpdated = false;
    for (final order in items) {
      final stockItem = _items.firstWhere(
        (s) => (s['product_name'] as String?)?.toLowerCase() == order.name.toLowerCase(),
        orElse: () => null,
      );
      if (stockItem != null) {
        final currentQty = double.tryParse(stockItem['quantity'].toString()) ?? 0;
        await _updateQty(stockItem, currentQty + order.qty);
        anyUpdated = true;
      }
    }
    await provider.markAllOrdered();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(anyUpdated
              ? 'Stock updated! ${items.length} item${items.length > 1 ? 's' : ''} added.'
              : 'Order list cleared.'),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stock Summary Row
// ─────────────────────────────────────────────────────────────────────────────

class _StockSummaryRow extends StatelessWidget {
  final int total, outCount, lowCount;
  const _StockSummaryRow({required this.total, required this.outCount, required this.lowCount});

  @override
  Widget build(BuildContext context) {
    final isGood = outCount == 0 && lowCount == 0;
    return Wrap(
      spacing: 8,
      children: [
        _SummaryChip(label: '$total items', color: AppTheme.textSecondary),
        if (outCount > 0) _SummaryChip(label: '$outCount out of stock', color: AppTheme.error, dot: true),
        if (lowCount > 0) _SummaryChip(label: '$lowCount running low', color: AppTheme.warning, dot: true),
        if (isGood) _SummaryChip(label: 'All healthy', color: AppTheme.success, dot: true),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;
  const _SummaryChip({required this.label, required this.color, this.dot = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// In-Stock Item Card
// ─────────────────────────────────────────────────────────────────────────────

class _InStockItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<double> onUpdateQty;

  const _InStockItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateQty,
  });

  Color _qtyColor(double qty) {
    if (qty <= 0) return AppTheme.error;
    if (qty <= 5) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(item['quantity'].toString()) ?? 0;
    final unit = item['unit'] ?? 'units';
    final qtyColor = _qtyColor(qty);
    final orderProvider = context.watch<OrderListProvider>();
    final isInOrder = orderProvider.contains(item['product_name'] ?? '');
    final isLow = qty <= 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: qtyColor, width: 3.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: qtyColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '${qty % 1 == 0 ? qty.toInt() : qty} $unit',
                          style: TextStyle(color: qtyColor, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      if (qty <= 0) ...[
                        const SizedBox(width: 8),
                        const Text('Out of stock', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                      ] else if (qty <= 5) ...[
                        const SizedBox(width: 8),
                        const Text('Running low', style: TextStyle(color: AppTheme.warning, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuickQtyButton(icon: Icons.add_rounded, onTap: () => onUpdateQty(qty + 1), color: AppTheme.success),
                const SizedBox(width: 6),
                _QuickQtyButton(icon: Icons.remove_rounded, onTap: qty > 0 ? () => onUpdateQty(qty - 1) : null, color: AppTheme.error),
                const SizedBox(width: 10),
                if (isLow)
                  GestureDetector(
                    onTap: isInOrder
                        ? null
                        : () {
                            orderProvider.add(OrderItem(
                              name: item['product_name'] ?? '',
                              unit: unit,
                              reason: qty <= 0 ? 'Out of stock' : 'Running low',
                              qty: qty <= 0 ? 10 : 5,
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppTheme.primary,
                                content: Text('Added to order list', style: TextStyle(color: Colors.white)),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isInOrder ? AppTheme.success.withOpacity(0.12) : AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isInOrder ? AppTheme.success.withOpacity(0.3) : AppTheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isInOrder ? Icons.check_rounded : Icons.shopping_cart_outlined,
                            size: 14,
                            color: isInOrder ? AppTheme.success : AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isInOrder ? 'In list' : 'Order',
                            style: TextStyle(
                              color: isInOrder ? AppTheme.success : AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isLow) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 18),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Qty Button
// ─────────────────────────────────────────────────────────────────────────────

class _QuickQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  const _QuickQtyButton({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: onTap != null ? color.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: onTap != null ? color : AppTheme.textHint),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Item Card (To Order tab)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderItemCard extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChanged;
  final ValueChanged<String> onUnitChanged;
  const _OrderItemCard({
    required this.item,
    required this.onRemove,
    required this.onQtyChanged,
    required this.onUnitChanged,
  });

  void _showUnitEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: item.unit);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Unit for ${item.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'kg, pcs, L, bags…',
            isDense: true,
          ),
          onSubmitted: (_) {
            onUnitChanged(ctrl.text);
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onUnitChanged(ctrl.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (item.reason.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(item.reason, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepperBtn(icon: Icons.remove_rounded, onTap: () => onQtyChanged(item.qty - 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
                  ),
                  _StepperBtn(icon: Icons.add_rounded, onTap: () => onQtyChanged(item.qty + 1)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Tappable unit chip
            GestureDetector(
              onTap: () => _showUnitEditDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.unit,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.edit_rounded,
                      size: 10,
                      color: AppTheme.textHint,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: AppTheme.textHint, size: 18),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: Icon(icon, size: 16, color: AppTheme.primary),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddEditStockSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _AddEditStockSheet({this.existing, required this.onSaved});
  @override
  State<_AddEditStockSheet> createState() => _AddEditStockSheetState();
}

class _AddEditStockSheetState extends State<_AddEditStockSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _priceCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl  = TextEditingController(text: e?['product_name'] ?? '');
    _qtyCtrl   = TextEditingController(text: e?['quantity']?.toString() ?? '');
    _unitCtrl  = TextEditingController(text: e?['unit'] ?? 'units');
    _priceCtrl = TextEditingController(text: e?['cost_price']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _qtyCtrl.dispose(); _unitCtrl.dispose(); _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final body = {
        'storeId': auth.storeId,
        'productName': _nameCtrl.text.trim(),
        'quantity': double.tryParse(_qtyCtrl.text) ?? 0,
        'unit': _unitCtrl.text.trim().isEmpty ? 'units' : _unitCtrl.text.trim(),
        'costPrice': _priceCtrl.text.trim().isEmpty ? null : double.tryParse(_priceCtrl.text),
      };
      final existing = widget.existing;
      if (existing != null && existing['id'] != null) {
        await ApiClient.instance.dio.put('/stocks/${existing['id']}', data: body);
      } else {
        await ApiClient.instance.dio.post('/stocks', data: body);
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppTheme.textHint, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(isEditing ? 'Edit Item' : 'Add Stock Item', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              enabled: !isEditing,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Basmati Rice',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit', hintText: 'kg, pcs…'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cost Price ₹ (optional)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? 'Save Changes' : 'Add to Stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty States
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.primarySurface, shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_rounded, color: AppTheme.primary, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('No items yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Add the items you sell in your shop.\nWe\'ll tell you when to reorder.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Your First Item'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyOrderState extends StatelessWidget {
  const _EmptyOrderState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, color: AppTheme.textHint, size: 48),
          SizedBox(height: 16),
          Text('Nothing to order yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            'When stock runs low or a sale is coming,\nrecommended items will appear here.\nYou can also tap "Order" on any low stock item.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.55),
          ),
        ],
      ),
    ),
  );
}
