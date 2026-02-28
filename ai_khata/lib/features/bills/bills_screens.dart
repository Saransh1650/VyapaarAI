import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../auth/auth_service.dart';
import 'package:provider/provider.dart';

// ── Bills List Screen ─────────────────────────────────────────────────────────

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<dynamic> _bills = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/bills');
      setState(() => _bills = res.data['bills'] ?? []);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddOptions() {
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
                'Add a new bill',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.primary,
                ),
              ),
              title: const Text(
                'Scan a Bill',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Take a photo — we read it for you',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                context.go(AppConstants.routeBillScanner);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_rounded, color: AppTheme.success),
              ),
              title: const Text(
                'Type it in',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Enter bill details manually',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
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

  String _statusLabel(String? s) => switch (s) {
    'COMPLETED' => 'Done',
    'FAILED' => 'Failed',
    'PROCESSING' => 'Reading...',
    _ => 'Pending',
  };

  Color _statusColor(String? s) => switch (s) {
    'COMPLETED' => AppTheme.success,
    'FAILED' => AppTheme.error,
    'PROCESSING' => AppTheme.warning,
    _ => AppTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _load,
            child: _bills.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
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
                                Icons.receipt_long_outlined,
                                color: AppTheme.textSecondary,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No bills yet',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add your first bill to start tracking sales',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _bills.length,
                    itemBuilder: (_, i) {
                      final b = _bills[i];
                      return _BillCard(
                        bill: b,
                        statusLabel: _statusLabel(b['status']),
                        statusColor: _statusColor(b['status']),
                      );
                    },
                  ),
          ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showAddOptions,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Add Bill',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  final String statusLabel;
  final Color statusColor;
  const _BillCard({
    required this.bill,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isManual = bill['source'] == 'manual';
    final dateStr = bill['created_at']?.toString().substring(0, 10) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isManual ? Icons.edit_rounded : Icons.camera_alt_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill['merchant'] ??
                      (isManual ? 'Manual Bill' : 'Scanned Bill'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (bill['total'] != null)
                Text(
                  '₹${double.tryParse(bill['total'].toString())?.toStringAsFixed(0) ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bill Scanner Screen ───────────────────────────────────────────────────────

class BillScannerScreen extends StatefulWidget {
  const BillScannerScreen({super.key});
  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen> {
  File? _image;
  bool _uploading = false;
  bool _done = false;
  String? _error;

  Future<void> _pickImage(ImageSource src) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: src, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _error = null;
        _done = false;
      });
    }
  }

  Future<void> _upload() async {
    if (_image == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(_image!.path),
        if (auth.storeId != null) 'storeId': auth.storeId,
      });
      await ApiClient.instance.dio.post(
        '/bills/upload',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      if (mounted) {
        setState(() => _done = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/dashboard/bills');
      }
    } catch (e) {
      setState(() => _error = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan a Bill'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.go('/dashboard/bills'),
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _image == null ? _buildPickerPrompt() : _buildPreview(),
          ),
          const SizedBox(height: 16),
          if (_done)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.success),
                  SizedBox(width: 10),
                  Text(
                    'Bill uploaded! Taking you back...',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),
          if (_image != null && !_done) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                _uploading ? 'Reading your bill...' : 'Save this Bill',
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildPickerPrompt() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: AppTheme.primary,
          size: 52,
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Take a photo of your bill',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'We will automatically read the items and total',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 36),
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Camera'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Gallery'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildPreview() => Column(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(_image!, fit: BoxFit.contain),
        ),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => setState(() => _image = null),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Use a different image'),
      ),
    ],
  );
}

// ── Manual Bill Entry ─────────────────────────────────────────────────────────

// Represents one line item chosen from inventory (or newly initialised).
class _BillLineItem {
  final String name;
  final String unit;
  double qty;
  double unitPrice;
  /// null  → item exists in inventory (stock known)
  /// false → item was NOT in inventory; user chose to set initial stock
  /// The initial stock value is stored separately and sent alongside the bill.
  double? initialStock; // only set when user added a brand-new sale item

  _BillLineItem({
    required this.name,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    this.initialStock,
  });
}

class BillManualEntryScreen extends StatefulWidget {
  const BillManualEntryScreen({super.key});
  @override
  State<BillManualEntryScreen> createState() => _BillManualEntryScreenState();
}

class _BillManualEntryScreenState extends State<BillManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _transactionType = 'income';
  bool _loading = false;

  // Inventory items loaded once on init
  List<Map<String, dynamic>> _stockItems = [];
  bool _stockLoaded = false;

  final List<_BillLineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    try {
      final auth = context.read<AuthService>();
      final res = await ApiClient.instance.dio.get(
        '/stocks',
        queryParameters: {'storeId': auth.storeId},
      );
      if (mounted) {
        setState(() {
          _stockItems = List<Map<String, dynamic>>.from(res.data['items'] ?? []);
          _stockLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _stockLoaded = true);
    }
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  // ── Recalculate total from line items ──────────────────────────────────────
  void _recalcTotal() {
    final sum = _lineItems.fold<double>(0, (s, i) => s + i.qty * i.unitPrice);
    if (sum > 0) _totalCtrl.text = sum.toStringAsFixed(2);
  }

  // ── Show picker sheet to choose a stock item ───────────────────────────────
  void _showItemPicker() {
    // Already-added names (to filter them out)
    final added = _lineItems.map((i) => i.name.toLowerCase()).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ItemPickerSheet(
        stockItems: _stockItems,
        alreadyAdded: added,
        transactionType: _transactionType,
        onSelected: (name, unit) {
          Navigator.pop(ctx);
          _onItemSelected(name, unit, fromInventory: true);
        },
        onNewItem: (name, unit) {
          Navigator.pop(ctx);
          _onItemSelected(name, unit, fromInventory: false);
        },
      ),
    );
  }

  /// Called when user picks an item (from inventory or typed manually).
  /// For sales (income), if item is NOT in inventory, prompt to set initial stock.
  void _onItemSelected(String name, String unit, {required bool fromInventory}) {
    if (_transactionType == 'income' && !fromInventory) {
      // Item not in stock — ask user for current stock level
      _showSetInitialStockDialog(name, unit);
    } else {
      setState(() {
        _lineItems.add(_BillLineItem(name: name, unit: unit, qty: 1, unitPrice: 0));
      });
    }
  }

  /// Dialog: item not in inventory. Let user set how many they have in stock
  /// (we'll send this as initialStock alongside the sale line item).
  void _showSetInitialStockDialog(String name, String unit) {
    final stockCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('"$name" is not in your inventory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How many do you currently have in stock?\n'
              'We will track this item going forward.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stockCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Current stock ($unit)',
                hintText: 'e.g. 50',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Add without setting initial stock — backend will insert with qty 0
              setState(() => _lineItems.add(
                _BillLineItem(name: name, unit: unit, qty: 1, unitPrice: 0, initialStock: 0),
              ));
            },
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () {
              final stock = double.tryParse(stockCtrl.text.trim()) ?? 0;
              Navigator.pop(ctx);
              setState(() => _lineItems.add(
                _BillLineItem(name: name, unit: unit, qty: 1, unitPrice: 0, initialStock: stock),
              ));
            },
            child: const Text('Add to Inventory'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int i) => setState(() => _lineItems.removeAt(i));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to the bill.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();

      // If any item has initialStock set, upsert those stock entries FIRST
      // so the bill's stock deduction has something to work against.
      for (final item in _lineItems) {
        if (item.initialStock != null && item.initialStock! > 0) {
          await ApiClient.instance.dio.post('/stocks', data: {
            'storeId': auth.storeId,
            'productName': item.name,
            'quantity': item.initialStock,
            'unit': item.unit,
          });
        }
      }

      final lineItems = _lineItems
          .map((item) => {
                'name': item.name,
                'qty': item.qty,
                'unitPrice': item.unitPrice,
                'unit': item.unit,
              })
          .toList();

      await ApiClient.instance.dio.post(
        '/bills/manual',
        data: {
          'storeId': auth.storeId,
          'merchant': _merchantCtrl.text.trim(),
          'date': _date.toIso8601String(),
          'total': double.tryParse(_totalCtrl.text) ?? 0,
          'transactionType': _transactionType,
          'lineItems': lineItems,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill saved & inventory updated!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.go('/dashboard/bills');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Add a Bill'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.go('/dashboard/bills'),
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Transaction Type Toggle ───────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = 'income'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _transactionType == 'income'
                            ? AppTheme.success
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 16,
                              color: _transactionType == 'income' ? Colors.white : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text('Sale (Income)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                  color: _transactionType == 'income' ? Colors.white : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = 'expense'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _transactionType == 'expense'
                            ? AppTheme.error
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 16,
                              color: _transactionType == 'expense' ? Colors.white : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text('Purchase (Expense)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                  color: _transactionType == 'expense' ? Colors.white : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _merchantCtrl,
            decoration: const InputDecoration(
              labelText: 'Shop / Merchant name',
              hintText: 'e.g. City Wholesale Market',
              prefixIcon: Icon(Icons.store_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.isEmpty) ? 'Please enter the shop name' : null,
          ),
          const SizedBox(height: 16),

          // Date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      Text('${_date.day}/${_date.month}/${_date.year}',
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _totalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Total Amount (₹)',
              hintText: 'Auto-calculated or enter manually',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please enter the total amount' : null,
          ),
          const SizedBox(height: 24),

          // ── Items section header ───────────────────────────────────
          Row(
            children: [
              Text(
                _transactionType == 'income' ? 'Items Sold' : 'Items Purchased',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _stockLoaded ? _showItemPicker : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ),

          if (!_stockLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            )
          else if (_lineItems.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      color: AppTheme.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _stockItems.isEmpty
                          ? 'Tap "Add Item" to select items from your inventory.'
                          : 'Tap "Add Item" to pick from your ${_stockItems.length} inventory items.',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._lineItems.asMap().entries.map((e) => _InventoryItemRow(
              index: e.key,
              item: e.value,
              onRemove: () => _removeItem(e.key),
              onChanged: () {
                setState(() {});
                _recalcTotal();
              },
            )),

          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_loading ? 'Saving...' : 'Save Bill'),
          ),
        ],
      ),
    ),
  );
}

// ── Item Picker Sheet ─────────────────────────────────────────────────────────
/// Shows inventory items in a searchable list. Footer has a "type a new name"
/// option so the user can still add a brand-new item.

class _ItemPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> stockItems;
  final Set<String> alreadyAdded;
  final String transactionType;
  final void Function(String name, String unit) onSelected;   // existing inventory item
  final void Function(String name, String unit) onNewItem;    // brand-new item typed by user

  const _ItemPickerSheet({
    required this.stockItems,
    required this.alreadyAdded,
    required this.transactionType,
    required this.onSelected,
    required this.onNewItem,
  });

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.stockItems.where((s) {
      final name = (s['product_name'] as String? ?? '').toLowerCase();
      if (widget.alreadyAdded.contains(name)) return false;
      if (_query.isNotEmpty && !name.contains(_query.toLowerCase())) return false;
      return true;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.transactionType == 'income' ? 'Select item to sell' : 'Select item purchased',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search inventory…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 1),
          // Item list
          Expanded(
            child: available.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? (widget.stockItems.isEmpty
                              ? 'No inventory items yet.\nUse the option below to add one.'
                              : 'All inventory items already added.')
                          : 'No item matching "$_query"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: available.length,
                    itemBuilder: (_, i) {
                      final item = available[i];
                      final name = item['product_name'] as String? ?? '';
                      final unit = item['unit'] as String? ?? 'units';
                      final qty = item['quantity'];
                      final qtyStr = qty != null
                          ? '${double.tryParse(qty.toString())?.toStringAsFixed(0) ?? qty} $unit in stock'
                          : 'Stock unknown';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: AppTheme.primary, size: 18),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(qtyStr, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        onTap: () => widget.onSelected(name, unit),
                      );
                    },
                  ),
          ),
          // Footer — add new item not in inventory
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: TextButton.icon(
              onPressed: () => _showAddNewDialog(context),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(
                _query.isNotEmpty ? 'Add "$_query" as new item' : 'Add a new item not in inventory',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNewDialog(BuildContext sheetCtx) {
    final nameCtrl = TextEditingController(text: _query);
    final unitCtrl = TextEditingController(text: 'units');
    showDialog(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('New item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item name', isDense: true),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(labelText: 'Unit (kg, pcs, L…)', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx); // close dialog
              // onNewItem → triggers initialStock dialog for sales, adds directly for purchases
              widget.onNewItem(name, unitCtrl.text.trim().isEmpty ? 'units' : unitCtrl.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ── Inventory Item Row ─────────────────────────────────────────────────────────
/// Inline editable row for an item already chosen from the picker.

class _InventoryItemRow extends StatefulWidget {
  final int index;
  final _BillLineItem item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _InventoryItemRow({
    required this.index,
    required this.item,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_InventoryItemRow> createState() => _InventoryItemRowState();
}

class _InventoryItemRowState extends State<_InventoryItemRow> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: widget.item.qty == 1 ? '1' : widget.item.qty.toString());
    _priceCtrl = TextEditingController(
        text: widget.item.unitPrice == 0 ? '' : widget.item.unitPrice.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineTotal = widget.item.qty * widget.item.unitPrice;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: item name + remove button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (lineTotal > 0)
                Text(
                  '₹${lineTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Qty
              Expanded(
                child: TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Qty (${widget.item.unit})',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    widget.item.qty = double.tryParse(v) ?? 1;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Unit price
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price per item (₹)',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    widget.item.unitPrice = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          if (widget.item.initialStock != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  widget.item.initialStock! > 0
                      ? 'New item · ${widget.item.initialStock!.toStringAsFixed(0)} ${widget.item.unit} will be added to inventory'
                      : 'New item · will be added to inventory',
                  style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
