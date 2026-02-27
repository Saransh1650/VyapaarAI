import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<dynamic> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final res = await ApiClient.instance.dio.get(
        '/stocks',
        queryParameters: {'storeId': auth.storeId},
      );
      if (mounted) setState(() => _items = res.data['items'] ?? []);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not load stock. Pull to refresh.');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete item')));
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
      builder: (_) =>
          _AddEditStockSheet(existing: existing, onSaved: _loadStock),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _items
        .where((i) => (double.tryParse(i['quantity'].toString()) ?? 0) <= 0)
        .length;
    final low = _items.where((i) {
      final q = double.tryParse(i['quantity'].toString()) ?? 0;
      return q > 0 && q <= 5;
    }).length;
    final healthy = _items.length - urgent - low;

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadStock,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              )
            : _items.isEmpty
            ? _EmptyState(onAdd: () => _showAddEditDialog())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  // ── Inventory Health Card ──────────────────────────
                  _InventoryHealthCard(
                    urgent: urgent,
                    low: low,
                    healthy: healthy,
                  ),
                  const SizedBox(height: 16),
                  ..._items.map(
                    (item) => _StockItemCard(
                      item: item,
                      onEdit: () => _showAddEditDialog(existing: item),
                      onDelete: () => _confirmDelete(item['id'] as String),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Item',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Remove Item?'),
        content: const Text('This will remove the item from your stock list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(id);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inventory Health Card ──────────────────────────────────────────────────────

class _InventoryHealthCard extends StatelessWidget {
  final int urgent, low, healthy;
  const _InventoryHealthCard({
    required this.urgent,
    required this.low,
    required this.healthy,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = urgent == 0 && low == 0;
    final color = isGood
        ? AppTheme.success
        : (urgent > 0 ? AppTheme.error : AppTheme.warning);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            isGood ? '✅' : (urgent > 0 ? '🔴' : '🟡'),
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGood
                      ? 'Inventory Health: GOOD'
                      : 'Inventory Health: AT RISK',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (urgent > 0) '$urgent out of stock',
                    if (low > 0) '$low running low',
                    if (healthy > 0) '$healthy healthy',
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
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

// ── Stock Item Card ────────────────────────────────────────────────────────────

class _StockItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _StockItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
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
    final costPrice = item['cost_price'];
    final qtyColor = _qtyColor(qty);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: qtyColor, width: 3.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          item['product_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: qtyColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${qty % 1 == 0 ? qty.toInt() : qty} $unit',
                    style: TextStyle(
                      color: qtyColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (qty <= 0) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '⛔ Out of stock',
                    style: TextStyle(color: AppTheme.error, fontSize: 12),
                  ),
                ] else if (qty <= 5) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '⚠️ Runs out soon',
                    style: TextStyle(color: AppTheme.warning, fontSize: 12),
                  ),
                ],
              ],
            ),
            if (costPrice != null) ...[
              const SizedBox(height: 4),
              Text(
                'Cost: ₹${double.tryParse(costPrice.toString())?.toStringAsFixed(2) ?? costPrice}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.error,
                size: 20,
              ),
              onPressed: onDelete,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit Bottom Sheet ────────────────────────────────────────────────────

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
    _nameCtrl = TextEditingController(text: e?['product_name'] ?? '');
    _qtyCtrl = TextEditingController(text: e?['quantity']?.toString() ?? '');
    _unitCtrl = TextEditingController(text: e?['unit'] ?? 'units');
    _priceCtrl = TextEditingController(
      text: e?['cost_price']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
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
        'costPrice': _priceCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_priceCtrl.text),
      };

      final existing = widget.existing;
      if (existing != null && existing['id'] != null) {
        // Edit — use PUT with the item id
        await ApiClient.instance.dio.put(
          '/stocks/${existing['id']}',
          data: body,
        );
      } else {
        // Add — upsert
        await ApiClient.instance.dio.post('/stocks', data: body);
      }

      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save item. Please try again.'),
          ),
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
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'Edit Stock Item' : 'Add Stock Item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            // Product name
            TextFormField(
              controller: _nameCtrl,
              enabled: !isEditing, // can't rename when editing (unique key)
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Basmati Rice',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            // Quantity + Unit row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      hintText: 'kg, pcs...',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Cost price (optional)
            TextFormField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cost Price (₹) — optional',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Add to Stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

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
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppTheme.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Stock Items Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add the items you currently have in your shop so we can track what needs restocking.',
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
