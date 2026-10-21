import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/invoice/bill.dart';
import '../models/invoice/bill_item.dart';
import '../models/package_model.dart';
import '../constants/app_constants.dart';
import '../core/services/mongo_service.dart';

class BillFormViewModel extends ChangeNotifier {
  final List<BillItem> _items = [];
  String _customerName = '';
  String _customerPhone = '';
  String _serviceType = AppConstants.serviceTypes.first;
  String _billNumber = '';
  double _advancePayment = 0.0;
  double _comboPrice = 0.0;
  bool _isLoading = false;
  String? _error;
  Bill? _editingBill;
  String? _appliedPackageName;

  List<BillItem> get items => List.unmodifiable(_items);
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String get serviceType => _serviceType;
  String get billNumber => _billNumber;
  double get advancePayment => _advancePayment;
  double get comboPrice => _comboPrice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEditing => _editingBill != null;
  Bill? get editingBill => _editingBill;
  String? get appliedPackageName => _appliedPackageName;

  bool get hasComboItems => _items.any((item) => item.price == null || item.price == 0);
  double get individualItemsTotal => _items.fold(0.0, (sum, item) => sum + (item.price ?? 0.0));
  double get subtotal => individualItemsTotal + (hasComboItems ? _comboPrice : 0.0);
  double get grandTotal => subtotal;
  double get remainingAmount => (grandTotal - _advancePayment).clamp(0.0, double.infinity);

  void setBillNumber(String number) {
    _billNumber = number;
    notifyListeners();
  }

  void setCustomerName(String name) {
    _customerName = name;
    _error = null;
    notifyListeners();
  }

  void setCustomerPhone(String phone) {
    _customerPhone = phone;
    notifyListeners();
  }

  void setServiceType(String type) {
    _serviceType = type;
    notifyListeners();
  }

  void setAdvancePayment(double amount) {
    _advancePayment = amount;
    notifyListeners();
  }

  void setComboPrice(double price) {
    _comboPrice = price;
    notifyListeners();
  }

  void addItem(String name, double? price) {
    _items.add(BillItem(itemName: name, price: price));
    _error = null;
    notifyListeners();
  }

  void updateItem(int index, String name, double? price) {
    if (index >= 0 && index < _items.length) {
      _items[index] = BillItem(itemName: name, price: price);
      _error = null;
      notifyListeners();
    }
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void applyPackage(PackageModel package, {bool replace = false}) {
    if (replace) {
      _items.clear();
    }
    for (final item in package.items) {
      _items.add(BillItem(itemName: item.itemName, price: item.price));
    }
    if (package.comboPrice != null && package.comboPrice! > 0) {
      _comboPrice = package.comboPrice!;
    }
    _serviceType = package.name;
    _appliedPackageName = package.name;
    _error = null;
    notifyListeners();
  }

  void initForEdit(Bill bill) {
    _editingBill = bill;
    _items.clear();
    _items.addAll(bill.items.map((i) => BillItem(itemName: i.itemName, price: i.price, showPrice: i.showPrice)));
    _customerName = bill.customerName;
    _customerPhone = bill.customerPhone ?? '';
    _serviceType = bill.serviceType;
    _billNumber = bill.billNumber;
    _advancePayment = bill.advancePayment;
    _comboPrice = bill.comboPrice;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _editingBill = null;
    _items.clear();
    _customerName = '';
    _customerPhone = '';
    _serviceType = AppConstants.serviceTypes.first;
    _advancePayment = 0.0;
    _comboPrice = 0.0;
    _error = null;
    notifyListeners();
  }

  String? validate() {
    if (_customerName.trim().isEmpty) return 'Customer name is required';
    if (_items.isEmpty) return 'Please add at least one item or combo event';
    if (_advancePayment < 0) return 'Advance payment cannot be negative';
    if (hasComboItems && _comboPrice < 0) return 'Combo price cannot be negative';
    return null;
  }

  Future<Bill?> saveBill({String? userId}) async {
    final validationError = validate();
    if (validationError != null) {
      _error = validationError;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (_editingBill != null) {
        _editingBill!.customerName = _customerName.trim();
        _editingBill!.customerPhone = _customerPhone.trim().isEmpty ? null : _customerPhone.trim();
        _editingBill!.serviceType = _serviceType;
        _editingBill!.subtotal = subtotal;
        _editingBill!.grandTotal = grandTotal;
        _editingBill!.advancePayment = _advancePayment;
        _editingBill!.comboPrice = _comboPrice;
        _editingBill!.items = List<BillItem>.from(_items);
        if (userId != null && (_editingBill!.userId == null || _editingBill!.userId!.isEmpty)) {
          _editingBill!.userId = userId;
        }
        await _editingBill!.save();
        MongoService.instance.saveBill(_editingBill!);

        _isLoading = false;
        notifyListeners();
        return _editingBill;
      }

      final bill = Bill(
        billNumber: _billNumber,
        customerName: _customerName.trim(),
        customerPhone: _customerPhone.trim().isEmpty ? null : _customerPhone.trim(),
        serviceType: _serviceType,
        dateTime: DateTime.now(),
        subtotal: subtotal,
        grandTotal: grandTotal,
        items: List<BillItem>.from(_items),
        advancePayment: _advancePayment,
        comboPrice: _comboPrice,
        userId: userId,
      );

      final box = Hive.box<Bill>(AppConstants.billsBoxName);
      await box.add(bill);
      MongoService.instance.saveBill(bill);

      _isLoading = false;
      notifyListeners();
      return bill;
    } catch (e) {
      _error = 'Failed to save bill: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
