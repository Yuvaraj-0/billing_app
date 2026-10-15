import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_to_words.dart';
import '../../core/utils/pdf_generator.dart';
import '../../models/invoice/bill.dart';
import '../../viewmodels/settings_viewmodel.dart';

import '../generate_bill/generate_bill_page.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../core/services/mongo_service.dart';
import '../../core/utils/currency_formatter.dart';

class BillDetailsPage extends StatefulWidget {
  final Bill bill;

  const BillDetailsPage({super.key, required this.bill});

  @override
  State<BillDetailsPage> createState() => _BillDetailsPageState();
}

class _BillDetailsPageState extends State<BillDetailsPage> {
  late Bill _bill;
  bool _isGeneratingPdf = false;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
  }

  Future<void> _editBill() async {
    final updated = await Navigator.push<Bill>(
      context,
      MaterialPageRoute(builder: (_) => GenerateBillPage(billToEdit: _bill)),
    );
    if (updated != null && mounted) {
      setState(() {
        _bill = updated;
      });
      context.read<HistoryViewModel>().loadBills();
    }
  }

  Future<void> _showUpdatePaymentDialog() async {
    final controller = TextEditingController(
      text: _bill.advancePayment > 0 ? _bill.advancePayment.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final symbol = context.read<SettingsViewModel>().currencySymbol;
        return AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Update Advance / Payment',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grand Total: ${CurrencyFormatter.formatWithDecimals(_bill.grandTotal, symbol: symbol)}',
                  style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Total Advance Paid ($symbol)',
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter amount';
                  final val = double.tryParse(v);
                  if (val == null || val < 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Full Paid', style: TextStyle(fontSize: 11)),
                    backgroundColor: AppTheme.surfaceDark,
                    side: const BorderSide(color: AppTheme.teal),
                    labelStyle: const TextStyle(color: AppTheme.teal),
                    onPressed: () {
                      controller.text = _bill.grandTotal.toStringAsFixed(0);
                    },
                  ),
                  ActionChip(
                    label: const Text('Clear', style: TextStyle(fontSize: 11)),
                    backgroundColor: AppTheme.surfaceDark,
                    side: const BorderSide(color: AppTheme.divider),
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    onPressed: () {
                      controller.text = '0';
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final val = double.parse(controller.text.trim());
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Update'),
          ),
        ],
      );
    },
  );

    if (result != null && mounted) {
      _bill.advancePayment = result;
      await _bill.save();
      MongoService.instance.saveBill(_bill);
      if (mounted) {
        context.read<HistoryViewModel>().loadBills();
        setState(() {});
        final symbol = context.read<SettingsViewModel>().currencySymbol;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment updated! Remaining balance: ${CurrencyFormatter.formatWithDecimals(_bill.remainingAmount, symbol: symbol)}',
            ),
            backgroundColor: AppTheme.cardDark,
          ),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final settings = context.read<SettingsViewModel>();
      final file = await PdfGenerator.generateBillPdf(
        _bill,
        settings.shopName,
        logoImagePath: settings.settings.logoImagePath,
      );
      await Share.shareXFiles([XFile(file.path)],
          text: 'Bill ${_bill.billNumber} from ${settings.shopName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _printPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final settings = context.read<SettingsViewModel>();
      final file = await PdfGenerator.generateBillPdf(
        _bill,
        settings.shopName,
        logoImagePath: settings.settings.logoImagePath,
      );
      await Printing.layoutPdf(onLayout: (_) async => await file.readAsBytes());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final symbol = settings.currencySymbol;
    final bill = _bill;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bill ${bill.billNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _editBill,
            tooltip: 'Edit Bill',
          ),
          if (_isGeneratingPdf)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: AppTheme.gold, strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.print_rounded),
              onPressed: _printPdf,
              tooltip: 'Print',
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _sharePdf,
              tooltip: 'Share PDF',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bill header card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A237E), Color(0xFF0D0D2E)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final logoFile = settings.logoFile;
                          return Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.gold.withValues(alpha: 0.6), width: 2),
                            ),
                            child: ClipOval(
                              child: logoFile != null
                                  ? Image.file(
                                      logoFile,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                          Image.asset(
                                            'asserts/logo-CWXXw7Ao.png',
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.contain,
                                          ),
                                    )
                                  : Image.asset(
                                      'asserts/logo-CWXXw7Ao.png',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.shopName,
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            'Photography Services',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const Text(
                            'INVOICE',
                            style: TextStyle(
                              color: AppTheme.goldLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bill meta info
            _InfoCard(
              child: Column(
                children: [
                  _MetaRow(
                    icon: Icons.tag_rounded,
                    label: 'Bill Number',
                    value: bill.billNumber,
                    valueColor: AppTheme.gold,
                  ),
                  _divider(),
                  _MetaRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date & Time',
                    value: dateFormat.format(bill.dateTime),
                  ),
                  _divider(),
                  _MetaRow(
                    icon: Icons.person_rounded,
                    label: 'Customer',
                    value: bill.customerName,
                  ),
                  if (bill.customerPhone != null &&
                      bill.customerPhone!.isNotEmpty) ...[
                    _divider(),
                    _MetaRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone',
                      value: bill.customerPhone!,
                    ),
                  ],
                  _divider(),
                  _MetaRow(
                    icon: Icons.camera_enhance_rounded,
                    label: 'Service',
                    value: bill.serviceType,
                    valueColor: AppTheme.teal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Items table
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bill Items',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('Description',
                              style: TextStyle(
                                  color: AppTheme.gold,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                        Text('Amount',
                            style: TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...bill.items.asMap().entries.map((entry) {
                    final isEven = entry.key % 2 == 0;
                    final item = entry.value;
                    final hasPrice = item.price != null && item.price! > 0;
                    return Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            isEven ? AppTheme.surfaceDark : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName,
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                ),
                                if (!hasPrice)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.teal.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Combo Event / Included',
                                      style: TextStyle(color: AppTheme.teal, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            hasPrice ? CurrencyFormatter.formatWithDecimals(item.price!, symbol: symbol) : 'Included',
                            style: TextStyle(
                              color: hasPrice ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: hasPrice ? 13 : 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Totals card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A237E).withValues(alpha: 0.7),
                    const Color(0xFF0D0D1A),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (bill.hasComboItems && bill.comboPrice > 0 && bill.individualItemsTotal > 0) ...[
                    _TotalRow('Individual Items', CurrencyFormatter.formatWithDecimals(bill.individualItemsTotal, symbol: symbol)),
                    const SizedBox(height: 6),
                    _TotalRow('Combo Price', CurrencyFormatter.formatWithDecimals(bill.comboPrice, symbol: symbol), valueColor: AppTheme.teal),
                    Divider(color: AppTheme.divider, height: 16),
                  ] else if (bill.hasComboItems && bill.comboPrice > 0) ...[
                    _TotalRow('Combo Package', CurrencyFormatter.formatWithDecimals(bill.comboPrice, symbol: symbol), valueColor: AppTheme.teal),
                    Divider(color: AppTheme.divider, height: 16),
                  ],
                  _TotalRow('Subtotal', CurrencyFormatter.formatWithDecimals(bill.subtotal, symbol: symbol)),
                  Divider(color: AppTheme.gold.withValues(alpha: 0.5), height: 20),
                  _TotalRow(
                    'Grand Total',
                    CurrencyFormatter.formatWithDecimals(bill.grandTotal, symbol: symbol),
                    isTotal: true,
                  ),
                  Divider(color: AppTheme.divider, height: 20),
                  _TotalRow(
                    'Advance Paid',
                    CurrencyFormatter.formatWithDecimals(bill.advancePayment, symbol: symbol),
                    valueColor: AppTheme.teal,
                  ),
                  const SizedBox(height: 8),
                  _TotalRow(
                    'Remaining Balance',
                    CurrencyFormatter.formatWithDecimals(bill.remainingAmount, symbol: symbol),
                    isTotal: true,
                    valueColor: bill.remainingAmount <= 0 ? AppTheme.success : Colors.orangeAccent,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: bill.remainingAmount <= 0
                              ? AppTheme.success.withValues(alpha: 0.2)
                              : Colors.orangeAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: bill.remainingAmount <= 0 ? AppTheme.success : Colors.orangeAccent,
                          ),
                        ),
                        child: Text(
                          bill.remainingAmount <= 0
                              ? 'PAID IN FULL'
                              : 'DUE: ${CurrencyFormatter.format(bill.remainingAmount, symbol: symbol)}',
                          style: TextStyle(
                            color: bill.remainingAmount <= 0 ? AppTheme.success : Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showUpdatePaymentDialog,
                        icon: const Icon(Icons.edit_note_rounded, color: AppTheme.gold, size: 16),
                        label: const Text('Update Advance', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.gold),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Amount in words
            _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount in Words',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    NumberToWords.convert(bill.grandTotal),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _sharePdf,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _printPdf,
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(color: AppTheme.divider, height: 16);
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
              Text(value,
                  style: TextStyle(
                    color: valueColor ?? AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;

  const _TotalRow(this.label, this.value, {this.isTotal = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
            fontSize: isTotal ? 17 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isTotal ? AppTheme.gold : AppTheme.textPrimary),
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
            fontSize: isTotal ? 20 : 14,
          ),
        ),
      ],
    );
  }
}
