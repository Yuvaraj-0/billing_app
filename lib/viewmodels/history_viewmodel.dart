import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/invoice/bill.dart';
import '../constants/app_constants.dart';
import '../core/services/mongo_service.dart';

enum DateFilter { all, today, thisWeek, thisMonth }

class HistoryViewModel extends ChangeNotifier {
  List<Bill> _allBills = [];
  String _searchQuery = '';
  DateFilter _dateFilter = DateFilter.all;

  List<Bill> get filteredBills {
    final now = DateTime.now();
    List<Bill> result = List<Bill>.from(_allBills.reversed.toList());

    // Date filter
    result = result.where((bill) {
      switch (_dateFilter) {
        case DateFilter.today:
          return bill.dateTime.year == now.year &&
              bill.dateTime.month == now.month &&
              bill.dateTime.day == now.day;
        case DateFilter.thisWeek:
          final weekAgo = now.subtract(const Duration(days: 7));
          return bill.dateTime.isAfter(weekAgo);
        case DateFilter.thisMonth:
          return bill.dateTime.year == now.year &&
              bill.dateTime.month == now.month;
        case DateFilter.all:
          return true;
      }
    }).toList();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((bill) =>
          bill.billNumber.toLowerCase().contains(q) ||
          bill.customerName.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  String get searchQuery => _searchQuery;
  DateFilter get dateFilter => _dateFilter;

  List<Bill> get allBills => List.unmodifiable(_allBills);

  // Dashboard stats
  double get todayRevenue {
    final now = DateTime.now();
    return _allBills
        .where((b) =>
            b.dateTime.year == now.year &&
            b.dateTime.month == now.month &&
            b.dateTime.day == now.day)
        .fold(0.0, (sum, b) => sum + b.grandTotal);
  }

  double get todayAdvance {
    final now = DateTime.now();
    return _allBills
        .where((b) =>
            b.dateTime.year == now.year &&
            b.dateTime.month == now.month &&
            b.dateTime.day == now.day)
        .fold(0.0, (sum, b) => sum + b.advancePayment);
  }

  double get todayRemaining {
    final now = DateTime.now();
    return _allBills
        .where((b) =>
            b.dateTime.year == now.year &&
            b.dateTime.month == now.month &&
            b.dateTime.day == now.day)
        .fold(0.0, (sum, b) => sum + b.remainingAmount);
  }

  int get todayCount {
    final now = DateTime.now();
    return _allBills
        .where((b) =>
            b.dateTime.year == now.year &&
            b.dateTime.month == now.month &&
            b.dateTime.day == now.day)
        .length;
  }

  // Week stats
  double get weekRevenue {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _allBills
        .where((b) => b.dateTime.isAfter(weekAgo))
        .fold(0.0, (sum, b) => sum + b.grandTotal);
  }

  double get weekAdvance {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _allBills
        .where((b) => b.dateTime.isAfter(weekAgo))
        .fold(0.0, (sum, b) => sum + b.advancePayment);
  }

  double get weekRemaining {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _allBills
        .where((b) => b.dateTime.isAfter(weekAgo))
        .fold(0.0, (sum, b) => sum + b.remainingAmount);
  }

  int get weekCount {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _allBills.where((b) => b.dateTime.isAfter(weekAgo)).length;
  }

  // Month stats
  double get monthRevenue {
    final now = DateTime.now();
    return _allBills
        .where((b) => b.dateTime.year == now.year && b.dateTime.month == now.month)
        .fold(0.0, (sum, b) => sum + b.grandTotal);
  }

  double get monthAdvance {
    final now = DateTime.now();
    return _allBills
        .where((b) => b.dateTime.year == now.year && b.dateTime.month == now.month)
        .fold(0.0, (sum, b) => sum + b.advancePayment);
  }

  double get monthRemaining {
    final now = DateTime.now();
    return _allBills
        .where((b) => b.dateTime.year == now.year && b.dateTime.month == now.month)
        .fold(0.0, (sum, b) => sum + b.remainingAmount);
  }

  int get monthCount {
    final now = DateTime.now();
    return _allBills
        .where((b) => b.dateTime.year == now.year && b.dateTime.month == now.month)
        .length;
  }

  // Year stats
  double get yearRevenue {
    final now = DateTime.now();
    return _allBills
        .where((b) => b.dateTime.year == now.year)
        .fold(0.0, (sum, b) => sum + b.grandTotal);
  }

  double get yearAdvance {
    final now = DateTime.now();
    return _allBills
        .where((b) => b.dateTime.year == now.year)
        .fold(0.0, (sum, b) => sum + b.advancePayment);
  }

  double get yearRemaining {
    final now = DateTime.now();
    return _allBills
        .where((b) => b.dateTime.year == now.year)
        .fold(0.0, (sum, b) => sum + b.remainingAmount);
  }

  int get yearCount {
    final now = DateTime.now();
    return _allBills.where((b) => b.dateTime.year == now.year).length;
  }

  // All-time stats
  double get totalRevenue => _allBills.fold(0.0, (sum, b) => sum + b.grandTotal);
  double get totalAdvance => _allBills.fold(0.0, (sum, b) => sum + b.advancePayment);
  double get totalRemaining => _allBills.fold(0.0, (sum, b) => sum + b.remainingAmount);
  int get totalCount => _allBills.length;

  String? _currentUserId;

  String? get currentUserId => _currentUserId;

  void setCurrentUser(String? userId) {
    _currentUserId = userId;
    loadBills();
  }

  void loadBills({String? userId}) {
    if (userId != null) _currentUserId = userId;
    final box = Hive.box<Bill>(AppConstants.billsBoxName);
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      // Assign legacy bills with no userId to current user
      for (final b in box.values) {
        if (b.userId == null || b.userId!.isEmpty) {
          b.userId = _currentUserId;
          b.save();
        }
      }
      _allBills = box.values.where((b) => b.userId == _currentUserId).toList();
    } else {
      _allBills = box.values.toList();
    }
    notifyListeners();
  }

  void clearBills() {
    _allBills = [];
    _currentUserId = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDateFilter(DateFilter filter) {
    _dateFilter = filter;
    notifyListeners();
  }

  Future<void> deleteBill(Bill bill) async {
    final billNumber = bill.billNumber;
    final uid = bill.userId ?? _currentUserId;
    await bill.delete();
    MongoService.instance.deleteBill(billNumber, userId: uid);
    loadBills();
  }

  Future<int> syncWithMongo({String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) return 0;
    final box = Hive.box<Bill>(AppConstants.billsBoxName);
    final count = await MongoService.instance.syncAllBills(box, userId: uid);
    loadBills(userId: uid);
    return count;
  }
}
