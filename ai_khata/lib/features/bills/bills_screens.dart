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
  bool _loading = false;

  final List<Map<String, TextEditingController>> _items = [];

  void _addItem() => setState(
    () => _items.add({
      'name': TextEditingController(),
      'qty': TextEditingController(text: '1'),
      'price': TextEditingController(),
    }),
  );

  void _removeItem(int i) => setState(() {
    for (var c in _items[i].values) c.dispose();
    _items.removeAt(i);
  });

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _totalCtrl.dispose();
    for (final item in _items) {
      for (final c in item.values) c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final lineItems = _items
          .map(
            (item) => {
              'name': item['name']!.text,
              'qty': double.tryParse(item['qty']!.text) ?? 1,
              'unitPrice': double.tryParse(item['price']!.text) ?? 0,
            },
          )
          .toList();

      await ApiClient.instance.dio.post(
        '/bills/manual',
        data: {
          'storeId': auth.storeId,
          'merchant': _merchantCtrl.text.trim(),
          'date': _date.toIso8601String(),
          'total': double.tryParse(_totalCtrl.text) ?? 0,
          'lineItems': lineItems,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bill saved!')));
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
          TextFormField(
            controller: _merchantCtrl,
            decoration: const InputDecoration(
              labelText: 'Where did you buy (shop name)?',
              hintText: 'e.g. City Wholesale Market',
              prefixIcon: Icon(Icons.store_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please enter the shop name' : null,
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
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date of Purchase',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${_date.day}/${_date.month}/${_date.year}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                  ),
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
              hintText: 'e.g. 1500',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Please enter the total amount'
                : null,
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Text(
                'Items Purchased',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ),

          if (_items.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: const Text(
                'Optional — tap "Add Item" to list what you bought',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          ..._items.asMap().entries.map(
            (e) => _ItemRow(
              index: e.key,
              controllers: e.value,
              onRemove: () => _removeItem(e.key),
            ),
          ),

          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_loading ? 'Saving...' : 'Save Bill'),
          ),
        ],
      ),
    ),
  );
}

class _ItemRow extends StatelessWidget {
  final int index;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onRemove;
  const _ItemRow({
    required this.index,
    required this.controllers,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              'Item ${index + 1}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controllers['name'],
          decoration: const InputDecoration(
            labelText: 'Item Name',
            hintText: 'e.g. Rice 5kg',
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers['qty'],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: controllers['price'],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price per item (₹)',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
