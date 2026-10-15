import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../viewmodels/bill_form_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../bill_details/bill_details_page.dart';
import '../../models/invoice/bill.dart';
import '../../core/utils/currency_formatter.dart';

class GenerateBillPage extends StatefulWidget {
  final Bill? billToEdit;
  const GenerateBillPage({super.key, this.billToEdit});

  @override
  State<GenerateBillPage> createState() => _GenerateBillPageState();
}

class _GenerateBillPageState extends State<GenerateBillPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _advanceController = TextEditingController();
  final _comboPriceController = TextEditingController();

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  String _billNumber = '';
  late DateTime _billDate;
  bool get _isEditMode => widget.billToEdit != null;

  @override
  void initState() {
    super.initState();
    _billDate = widget.billToEdit?.dateTime ?? DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.billToEdit != null) {
        final bill = widget.billToEdit!;
        _billNumber = bill.billNumber;
        _nameController.text = bill.customerName;
        _phoneController.text = bill.customerPhone ?? '';
        if (bill.advancePayment > 0) {
          _advanceController.text = bill.advancePayment.toStringAsFixed(0);
        }
        if (bill.comboPrice > 0) {
          _comboPriceController.text = bill.comboPrice.toStringAsFixed(0);
        }
        context.read<BillFormViewModel>().initForEdit(bill);
        setState(() {});
      } else {
        final settings = context.read<SettingsViewModel>();
        _billNumber = settings.generateBillNumber();
        context.read<BillFormViewModel>().reset();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _advanceController.dispose();
    _comboPriceController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final priceText = _itemPriceController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item or combo event name')),
      );
      return;
    }

    double? price;
    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText);
      if (price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid price or leave empty')),
        );
        return;
      }
      if (price == 0) {
        price = null;
      }
    }

    context.read<BillFormViewModel>().addItem(name, price);
    _itemNameController.clear();
    _itemPriceController.clear();
  }

  Future<void> _generateBill() async {
    final vm = context.read<BillFormViewModel>();
    vm.setCustomerName(_nameController.text);
    vm.setCustomerPhone(_phoneController.text);
    vm.setBillNumber(_billNumber);

    final advance = double.tryParse(_advanceController.text.trim()) ?? 0.0;
    vm.setAdvancePayment(advance);

    final combo = double.tryParse(_comboPriceController.text.trim()) ?? 0.0;
    vm.setComboPrice(combo);

    final authVm = context.read<AuthViewModel>();
    final currentUserId = authVm.currentUser?.id;

    final bill = await vm.saveBill(userId: currentUserId);
    if (bill != null && mounted) {
      context.read<HistoryViewModel>().loadBills(userId: currentUserId);
      final message = _isEditMode
          ? 'Bill ${bill.billNumber} updated successfully!'
          : 'Bill ${bill.billNumber} generated successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.success),
              const SizedBox(width: 10),
              Text(message),
            ],
          ),
          backgroundColor: AppTheme.cardDark,
        ),
      );

      if (_isEditMode) {
        Navigator.pop(context, bill);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BillDetailsPage(bill: bill)),
        );
        _resetForm();
      }
    } else if (vm.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _resetForm() {
    _nameController.clear();
    _phoneController.clear();
    _itemNameController.clear();
    _itemPriceController.clear();
    _advanceController.clear();
    _comboPriceController.clear();
    context.read<BillFormViewModel>().reset();
    final settings = context.read<SettingsViewModel>();
    setState(() {
      _billDate = DateTime.now();
      _billNumber = settings.generateBillNumber();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BillFormViewModel>();
    final settings = context.watch<SettingsViewModel>();
    final symbol = settings.currencySymbol;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            leading: _isEditMode && Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.gold),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D0D2E), Color(0xFF1A237E)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final logoFile = settings.logoFile;
                                return Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5), width: 1.5),
                                  ),
                                  child: ClipOval(
                                    child: logoFile != null
                                        ? Image.file(
                                            logoFile,
                                            width: 28,
                                            height: 28,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) =>
                                                Image.asset('asserts/logo-CWXXw7Ao.png', width: 28, height: 28, fit: BoxFit.contain),
                                          )
                                        : Image.asset('asserts/logo-CWXXw7Ao.png', width: 28, height: 28, fit: BoxFit.contain),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              settings.shopName,
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEditMode ? 'Editing Bill $_billNumber' : 'Generate New Bill',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bill info card
                    _SectionCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: _InfoChip(
                              label: 'Bill No',
                              value: _billNumber,
                              icon: Icons.tag_rounded,
                              color: AppTheme.gold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoChip(
                              label: 'Date',
                              value: DateFormat('dd/MM/yy').format(_billDate),
                              icon: Icons.calendar_today_rounded,
                              color: AppTheme.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoChip(
                              label: 'Time',
                              value: DateFormat('hh:mm a').format(_billDate),
                              icon: Icons.access_time_rounded,
                              color: Colors.purpleAccent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Customer details
                    _sectionTitle('Customer Details'),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Customer Name *',
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Phone Number (Optional)',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Service Type
                    _sectionTitle('Service Type'),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(
                        children: AppConstants.serviceTypes.map((type) {
                          return RadioListTile<String>(
                            title: Text(type,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 14)),
                            value: type,
                            groupValue: vm.serviceType,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            fillColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? AppTheme.gold
                                  : AppTheme.textSecondary,
                            ),
                            onChanged: (v) => vm.setServiceType(v!),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Add Items
                    _sectionTitle('Bill Items & Combo Events'),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _itemNameController,
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                  decoration: const InputDecoration(
                                    labelText: 'Item / Combo Event',
                                    hintText: 'e.g. Wedding Shoot or Pre-wedding',
                                    prefixIcon: Icon(Icons.camera_enhance_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _itemPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Price ($symbol) (Optional)',
                                    hintText: 'Leave empty for combo',
                                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '* Tip: Leave price empty for combo / package events',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Item / Combo Event'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items list
                    if (vm.items.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...vm.items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final hasPrice = item.price != null && item.price! > 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 8, color: AppTheme.gold),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.itemName,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (!hasPrice)
                                        Container(
                                          margin: const EdgeInsets.only(top: 3),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.teal.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppTheme.teal.withValues(alpha: 0.4)),
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
                                    color: hasPrice ? AppTheme.gold : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: hasPrice ? 14 : 12,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: AppTheme.error, size: 20),
                                  onPressed: () => vm.removeItem(i),
                                  padding: const EdgeInsets.only(left: 8),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    if (vm.items.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.divider, style: BorderStyle.solid),
                        ),
                        child: const Center(
                          child: Text('No items added yet',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                      ),

                    // Combo / Package Price Section (only shown if there are items with no individual price)
                    if (vm.hasComboItems) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Combo / Package Pricing'),
                      const SizedBox(height: 10),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.teal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.inventory_2_rounded, color: AppTheme.teal, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Some items have no individual price. Enter the combined combo package price below:',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _comboPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                              ],
                              decoration: InputDecoration(
                                labelText: 'Combo / Package Price ($symbol) *',
                                hintText: 'e.g. 25000',
                                prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppTheme.teal),
                              ),
                              onChanged: (val) {
                                final c = double.tryParse(val.trim()) ?? 0.0;
                                vm.setComboPrice(c);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Advance Payment Section
                    _sectionTitle('Advance Payment & Balance'),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _advanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppTheme.textPrimary),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                            ],
                            decoration: InputDecoration(
                              labelText: 'Advance Payment Received ($symbol)',
                              hintText: 'e.g. 5000',
                              prefixIcon: const Icon(Icons.payments_rounded),
                            ),
                            onChanged: (val) {
                              final adv = double.tryParse(val.trim()) ?? 0.0;
                              vm.setAdvancePayment(adv);
                            },
                          ),
                          const SizedBox(height: 10),
                          // Quick percentage / full paid chips
                          Wrap(
                            spacing: 8,
                            children: [
                              ActionChip(
                                label: const Text('Full Paid', style: TextStyle(fontSize: 12)),
                                backgroundColor: AppTheme.surfaceDark,
                                side: const BorderSide(color: AppTheme.teal),
                                labelStyle: const TextStyle(color: AppTheme.teal),
                                onPressed: () {
                                  _advanceController.text = vm.grandTotal.toStringAsFixed(0);
                                  vm.setAdvancePayment(vm.grandTotal);
                                },
                              ),
                              ActionChip(
                                label: const Text('50% Advance', style: TextStyle(fontSize: 12)),
                                backgroundColor: AppTheme.surfaceDark,
                                side: const BorderSide(color: AppTheme.gold),
                                labelStyle: const TextStyle(color: AppTheme.gold),
                                onPressed: () {
                                  final half = (vm.grandTotal * 0.5).roundToDouble();
                                  _advanceController.text = half.toStringAsFixed(0);
                                  vm.setAdvancePayment(half);
                                },
                              ),
                              ActionChip(
                                label: const Text('Clear', style: TextStyle(fontSize: 12)),
                                backgroundColor: AppTheme.surfaceDark,
                                side: const BorderSide(color: AppTheme.divider),
                                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                onPressed: () {
                                  _advanceController.clear();
                                  vm.setAdvancePayment(0.0);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Totals summary
                    if (vm.items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Bill Summary'),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1A237E).withValues(alpha: 0.8),
                              const Color(0xFF0D0D2E),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            if (vm.hasComboItems && vm.comboPrice > 0 && vm.individualItemsTotal > 0) ...[
                              _SummaryRow('Individual Items', CurrencyFormatter.formatWithDecimals(vm.individualItemsTotal, symbol: symbol)),
                              const SizedBox(height: 6),
                              _SummaryRow('Combo Price', CurrencyFormatter.formatWithDecimals(vm.comboPrice, symbol: symbol), customColor: AppTheme.teal),
                              const Divider(color: AppTheme.divider, height: 16),
                            ],
                            _SummaryRow('Subtotal', CurrencyFormatter.formatWithDecimals(vm.subtotal, symbol: symbol)),
                            const Divider(color: AppTheme.divider, height: 20),
                            _SummaryRow(
                              'Grand Total',
                              CurrencyFormatter.formatWithDecimals(vm.grandTotal, symbol: symbol),
                              isTotal: true,
                            ),
                            const Divider(color: AppTheme.divider, height: 20),
                            _SummaryRow(
                              'Advance Paid',
                              CurrencyFormatter.formatWithDecimals(vm.advancePayment, symbol: symbol),
                              customColor: AppTheme.teal,
                            ),
                            const SizedBox(height: 8),
                            _SummaryRow(
                              'Remaining Balance',
                              CurrencyFormatter.formatWithDecimals(vm.remainingAmount, symbol: symbol),
                              isTotal: true,
                              customColor: vm.remainingAmount <= 0 ? AppTheme.success : Colors.orangeAccent,
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: vm.remainingAmount <= 0
                                      ? AppTheme.success.withValues(alpha: 0.2)
                                      : Colors.orangeAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: vm.remainingAmount <= 0 ? AppTheme.success : Colors.orangeAccent,
                                  ),
                                ),
                                child: Text(
                                  vm.remainingAmount <= 0
                                      ? 'STATUS: FULLY PAID'
                                      : 'STATUS: PENDING ${CurrencyFormatter.formatCompact(vm.remainingAmount, symbol: symbol)}',
                                  style: TextStyle(
                                    color: vm.remainingAmount <= 0 ? AppTheme.success : Colors.orangeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action buttons
                    if (vm.isLoading)
                      const Center(child: CircularProgressIndicator(color: AppTheme.gold))
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generateBill,
                          icon: Icon(_isEditMode ? Icons.check_circle_rounded : Icons.receipt_long_rounded),
                          label: Text(_isEditMode ? 'Save Changes' : 'Generate Bill'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isEditMode ? () => Navigator.pop(context) : _resetForm,
                          icon: Icon(_isEditMode ? Icons.close_rounded : Icons.refresh_rounded),
                          label: Text(_isEditMode ? 'Cancel Edit' : 'Reset Form'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11)),
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final Color? customColor;

  const _SummaryRow(this.label, this.value, {this.isTotal = false, this.customColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: customColor ?? (isTotal ? AppTheme.textPrimary : AppTheme.textSecondary),
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: customColor ?? (isTotal ? AppTheme.gold : AppTheme.textPrimary),
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            fontSize: isTotal ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
