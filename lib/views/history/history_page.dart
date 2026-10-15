import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/invoice/bill.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../bill_details/bill_details_page.dart';
import '../generate_bill/generate_bill_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _searchController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Bill',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete bill ${bill.billNumber} for ${bill.customerName}?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<HistoryViewModel>().deleteBill(bill);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill ${bill.billNumber} deleted'),
            backgroundColor: AppTheme.cardDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    final bills = vm.filteredBills;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${bills.length} bills',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textPrimary),
              onChanged: vm.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search by bill no. or name...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          vm.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Date filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: DateFilter.values.map((filter) {
                final labels = {
                  DateFilter.all: 'All',
                  DateFilter.today: 'Today',
                  DateFilter.thisWeek: 'This Week',
                  DateFilter.thisMonth: 'This Month',
                };
                final isSelected = vm.dateFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      labels[filter]!,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryDark : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => vm.setDateFilter(filter),
                    backgroundColor: AppTheme.surfaceDark,
                    selectedColor: AppTheme.gold,
                    checkmarkColor: AppTheme.primaryDark,
                    side: BorderSide(
                      color: isSelected ? AppTheme.gold : AppTheme.divider,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // Bill list
          Expanded(
            child: bills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 64,
                            color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'No bills found',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a new bill or adjust your filters',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: bills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return Slidable(
                        key: ValueKey(bill.key),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.45,
                          children: [
                            SlidableAction(
                              onPressed: (_) async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GenerateBillPage(billToEdit: bill),
                                  ),
                                );
                                if (context.mounted) {
                                  context.read<HistoryViewModel>().loadBills();
                                }
                              },
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.white,
                              icon: Icons.edit_rounded,
                              label: 'Edit',
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                            ),
                            SlidableAction(
                              onPressed: (_) => _confirmDelete(context, bill),
                              backgroundColor: AppTheme.error,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_rounded,
                              label: 'Delete',
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                            ),
                          ],
                        ),
                        child: _BillListTile(
                          bill: bill,
                          currencySymbol: context.watch<SettingsViewModel>().currencySymbol,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BillDetailsPage(bill: bill),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GenerateBillPage()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Bill'),
      ),
    );
  }
}

class _BillListTile extends StatelessWidget {
  final Bill bill;
  final String currencySymbol;
  final VoidCallback onTap;

  const _BillListTile({
    required this.bill,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.remainingAmount <= 0;
    final hasPartial = bill.advancePayment > 0 && !isPaid;
    final statusColor = isPaid
        ? AppTheme.success
        : (hasPartial ? Colors.orangeAccent : Colors.amber);

    return Material(
      color: AppTheme.cardDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Left colored indicator
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              // Bill info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bill.customerName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(bill.grandTotal, symbol: currencySymbol),
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bill.billNumber,
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(bill.dateTime),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bill.serviceType,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            isPaid
                                ? 'PAID'
                                : (hasPartial
                                    ? 'BAL: ${CurrencyFormatter.formatCompact(bill.remainingAmount, symbol: currencySymbol)}'
                                    : 'UNPAID'),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
