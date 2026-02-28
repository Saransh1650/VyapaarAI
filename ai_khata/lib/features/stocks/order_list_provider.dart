import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';

/// A single item the shopkeeper intends to order.
class OrderItem {
  /// Backend UUID — null until the server has confirmed the row.
  final String? id;
  final String name;
  String unit; // mutable — shopkeeper can correct it
  final String reason; // e.g. "Running low", "Holi is in 5 days"
  int qty;

  OrderItem({
    this.id,
    required this.name,
    this.unit = 'units',
    this.reason = '',
    this.qty = 1,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'reason': reason,
        'qty': qty,
      };

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: j['id'] as String?,
        name: j['name'] as String,
        unit: j['unit'] as String? ?? 'units',
        reason: j['reason'] as String? ?? '',
        qty: (j['qty'] as num?)?.toInt() ?? 1,
      );

  OrderItem copyWith({String? id, String? unit, int? qty}) => OrderItem(
        id: id ?? this.id,
        name: name,
        unit: unit ?? this.unit,
        reason: reason,
        qty: qty ?? this.qty,
      );
}

/// Shared state for the "To Order" list.
/// Persisted in the backend — survives app reinstalls and device changes.
class OrderListProvider extends ChangeNotifier {
  String? _storeId;
  final List<OrderItem> _items = [];

  List<OrderItem> get items => List.unmodifiable(_items);
  int get count => _items.length;

  // ── Called by ChangeNotifierProxyProvider whenever AuthService changes ──

  void setStoreId(String? storeId) {
    if (_storeId == storeId) return;
    _storeId = storeId;
    _items.clear();
    notifyListeners();
    if (storeId != null) _load();
  }

  // ── Remote load ────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (_storeId == null) return;
    try {
      final res = await ApiClient.instance.dio.get(
        '/order-items',
        queryParameters: {'storeId': _storeId},
      );
      final list = (res.data['items'] as List? ?? [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _items
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {
      // Silent — list stays empty; will retry next launch
    }
  }

  // ── Mutations (optimistic UI + background API sync) ────────────────────

  bool contains(String name) =>
      _items.any((i) => i.name.trim().toLowerCase() == name.trim().toLowerCase());

  Future<void> add(OrderItem item) async {
    if (contains(item.name) || _storeId == null) return;
    // Optimistic
    _items.add(item);
    notifyListeners();
    try {
      final res = await ApiClient.instance.dio.post('/order-items', data: {
        'storeId': _storeId,
        ...item.toJson(),
      });
      final saved = OrderItem.fromJson(res.data['item'] as Map<String, dynamic>);
      final idx = _items.indexWhere(
        (i) => i.name.trim().toLowerCase() == item.name.trim().toLowerCase(),
      );
      if (idx != -1) {
        _items[idx] = saved; // replace with server version (has real UUID)
        notifyListeners();
      }
    } catch (_) {
      // Revert
      _items.removeWhere(
        (i) => i.name.trim().toLowerCase() == item.name.trim().toLowerCase(),
      );
      notifyListeners();
    }
  }

  Future<void> remove(String name) async {
    final idx = _items.indexWhere(
      (i) => i.name.trim().toLowerCase() == name.trim().toLowerCase(),
    );
    if (idx == -1) return;
    final removed = _items[idx];
    _items.removeAt(idx);
    notifyListeners();
    if (removed.id != null) {
      try {
        await ApiClient.instance.dio.delete('/order-items/${removed.id}');
      } catch (_) {
        _items.insert(idx, removed); // Revert
        notifyListeners();
      }
    }
  }

  Future<void> updateQty(String name, int qty) async {
    final idx = _items.indexWhere(
      (i) => i.name.trim().toLowerCase() == name.trim().toLowerCase(),
    );
    if (idx == -1) return;
    if (qty <= 0) {
      await remove(name);
      return;
    }
    final old = _items[idx];
    _items[idx] = old.copyWith(qty: qty);
    notifyListeners();
    if (old.id != null) {
      try {
        await ApiClient.instance.dio
            .patch('/order-items/${old.id}', data: {'qty': qty});
      } catch (_) {
        _items[idx] = old; // Revert
        notifyListeners();
      }
    }
  }

  Future<void> updateUnit(String name, String unit) async {
    final idx = _items.indexWhere(
      (i) => i.name.trim().toLowerCase() == name.trim().toLowerCase(),
    );
    if (idx == -1) return;
    final u = unit.trim().isEmpty ? 'units' : unit.trim();
    final old = _items[idx];
    _items[idx] = old.copyWith(unit: u);
    notifyListeners();
    if (old.id != null) {
      try {
        await ApiClient.instance.dio
            .patch('/order-items/${old.id}', data: {'unit': u});
      } catch (_) {
        _items[idx] = old; // Revert
        notifyListeners();
      }
    }
  }

  /// Clears the entire list (e.g. after a trip to the supplier).
  Future<void> markAllOrdered() async {
    if (_storeId == null) return;
    final snapshot = List<OrderItem>.from(_items);
    _items.clear();
    notifyListeners();
    try {
      await ApiClient.instance.dio.delete(
        '/order-items',
        queryParameters: {'storeId': _storeId},
      );
    } catch (_) {
      _items.addAll(snapshot); // Revert
      notifyListeners();
    }
  }
}

