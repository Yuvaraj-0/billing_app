import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/services/mongo_service.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../bill_details/bill_details_page.dart';
import '../generate_bill/generate_bill_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  String _selectedPeriod = 'month'; // 'today', 'week', 'month', 'year', 'all'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      context.read<HistoryViewModel>().loadBills(userId: auth.currentUser?.id);
    });
  }

  double _getRevenue(HistoryViewModel history) {
    switch (_selectedPeriod) {
      case 'today': return history.todayRevenue;
      case 'week': return history.weekRevenue;
      case 'month': return history.monthRevenue;
      case 'year': return history.yearRevenue;
      default: return history.totalRevenue;
    }
  }

  double _getAdvance(HistoryViewModel history) {
    switch (_selectedPeriod) {
      case 'today': return history.todayAdvance;
      case 'week': return history.weekAdvance;
      case 'month': return history.monthAdvance;
      case 'year': return history.yearAdvance;
      default: return history.totalAdvance;
    }
  }

  double _getRemaining(HistoryViewModel history) {
    switch (_selectedPeriod) {
      case 'today': return history.todayRemaining;
      case 'week': return history.weekRemaining;
      case 'month': return history.monthRemaining;
      case 'year': return history.yearRemaining;
      default: return history.totalRemaining;
    }
  }

  int _getCount(HistoryViewModel history) {
    switch (_selectedPeriod) {
      case 'today': return history.todayCount;
      case 'week': return history.weekCount;
      case 'month': return history.monthCount;
      case 'year': return history.yearCount;
      default: return history.totalCount;
    }
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'today': return "Today's";
      case 'week': return "This Week's";
      case 'month': return "This Month's";
      case 'year': return "This Year's";
      default: return "All Time";
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryViewModel>();
    final settings = context.watch<SettingsViewModel>();

    final revenue = _getRevenue(history);
    final advance = _getAdvance(history);
    final remaining = _getRemaining(history);
    final count = _getCount(history);
    final periodLabel = _getPeriodLabel();
    final symbol = settings.currencySymbol;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Gradient app bar
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D0D2E),
                      Color(0xFF1A237E),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.gold.withValues(alpha: 0.5)),
                              ),
                              child: Builder(
                                builder: (context) {
                                  final logoFile = settings.logoFile;
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: logoFile != null
                                        ? Image.file(
                                            logoFile,
                                            width: 42,
                                            height: 42,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) =>
                                                const Center(
                                              child: Icon(Icons.camera_alt_rounded,
                                                  color: AppTheme.gold, size: 24),
                                            ),
                                          )
                                        : const Center(
                                            child: Icon(Icons.camera_alt_rounded,
                                                color: AppTheme.gold, size: 24),
                                          ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  settings.shopName,
                                  style: const TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Consumer<AuthViewModel>(
                                  builder: (context, auth, _) {
                                    final user = auth.currentUser;
                                    return Text(
                                      user != null
                                          ? 'Owner: ${user.name}'
                                          : 'Photography Services & Invoicing',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            ValueListenableBuilder<MongoConnectionStatus>(
                              valueListenable: MongoService.instance.statusNotifier,
                              builder: (context, status, _) {
                                final isConnected = status == MongoConnectionStatus.connected;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isConnected ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                                      size: 13,
                                      color: isConnected ? AppTheme.success : Colors.white38,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isConnected ? 'Cloud Synced' : 'Offline Mode',
                                      style: TextStyle(
                                        color: isConnected ? AppTheme.success : Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Analytics header with period switcher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Financial Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.analytics_rounded, size: 14, color: AppTheme.gold),
                            const SizedBox(width: 4),
                            Text(
                              periodLabel,
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Period selector chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _periodChip('today', 'Today'),
                        _periodChip('week', 'This Week'),
                        _periodChip('month', 'This Month'),
                        _periodChip('year', 'This Year'),
                        _periodChip('all', 'All Time'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4 Main analytics cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: "$periodLabel Billed",
                          value: CurrencyFormatter.format(revenue, symbol: symbol),
                          icon: Icons.account_balance_wallet_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A237E), Color(0xFF283593)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: "Advance Paid",
                          value: CurrencyFormatter.format(advance, symbol: symbol),
                          icon: Icons.payments_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00695C), Color(0xFF00897B)],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: "Balance Due",
                          value: CurrencyFormatter.format(remaining, symbol: symbol),
                          icon: Icons.pending_actions_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE65100), Color(0xFFF57C00)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: "$periodLabel Bills",
                          value: "$count invoices",
                          icon: Icons.receipt_long_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick Comparison Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.compare_arrows_rounded, color: AppTheme.gold, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Revenue Comparison Overview',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _comparisonColumn('Week', CurrencyFormatter.format(history.weekRevenue, symbol: symbol), history.weekCount),
                            Container(width: 1, height: 35, color: AppTheme.divider),
                            _comparisonColumn('Month', CurrencyFormatter.format(history.monthRevenue, symbol: symbol), history.monthCount),
                            Container(width: 1, height: 35, color: AppTheme.divider),
                            _comparisonColumn('Year', CurrencyFormatter.format(history.yearRevenue, symbol: symbol), history.yearCount),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Generate New Bill',
                          icon: Icons.add_circle_rounded,
                          color: AppTheme.gold,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GenerateBillPage()),
                            );
                            if (context.mounted) {
                              context.read<HistoryViewModel>().loadBills();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          label: 'View All History',
                          icon: Icons.history_rounded,
                          color: AppTheme.teal,
                          onTap: () => _navigateToTab(context, 2),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Recent Bills preview
                  if (history.allBills.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Invoices',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _navigateToTab(context, 2),
                          child: const Text('View All', style: TextStyle(color: AppTheme.gold, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...history.allBills.reversed.take(4).map((bill) {
                      final isPaid = bill.remainingAmount <= 0;
                      final hasPartial = bill.advancePayment > 0 && !isPaid;
                      final statusColor = isPaid
                          ? AppTheme.success
                          : (hasPartial ? Colors.orangeAccent : Colors.amber);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => BillDetailsPage(bill: bill)),
                              );
                              if (context.mounted) {
                                context.read<HistoryViewModel>().loadBills();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textPrimary,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              CurrencyFormatter.format(bill.grandTotal, symbol: symbol),
                                              style: const TextStyle(
                                                color: AppTheme.gold,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${bill.billNumber} • ${bill.serviceType}',
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isPaid
                                                    ? 'PAID'
                                                    : (hasPartial
                                                        ? 'BAL: ${CurrencyFormatter.formatCompact(bill.remainingAmount, symbol: symbol)}'
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
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text(
                              'No bills yet.\nCreate your first bill!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String key, String label) {
    final isSelected = _selectedPeriod == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedPeriod = key),
        backgroundColor: AppTheme.surfaceDark,
        selectedColor: AppTheme.gold,
        checkmarkColor: AppTheme.primaryDark,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryDark : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.gold : AppTheme.divider,
        ),
      ),
    );
  }

  Widget _comparisonColumn(String label, String amount, int count) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          amount,
          style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 13),
        ),
        Text(
          '$count bills',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(index == 1 ? 'Tap "New Bill" in bottom menu' : 'Tap "History" in bottom menu'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.cardDark,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
