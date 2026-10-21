import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/mongo_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/package_model.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _shopNameController;
  bool _editing = false;
  bool _isSyncingCloud = false;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsViewModel>();
      _shopNameController.text = settings.shopName;
    });
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final vm = context.read<SettingsViewModel>();
    final shopName = _shopNameController.text.trim();

    if (shopName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name cannot be empty')),
      );
      return;
    }

    await vm.updateShopName(shopName);
    setState(() => _editing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success),
              SizedBox(width: 8),
              Text('Settings saved!'),
            ],
          ),
          backgroundColor: AppTheme.cardDark,
        ),
      );
    }
  }

  Future<void> _syncCloud() async {
    setState(() => _isSyncingCloud = true);
    try {
      final authVm = context.read<AuthViewModel>();
      final historyVm = context.read<HistoryViewModel>();
      final newCount =
          await historyVm.syncWithMongo(userId: authVm.currentUser?.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: AppTheme.success),
                const SizedBox(width: 8),
                Text('Cloud synced! ($newCount bills updated)'),
              ],
            ),
            backgroundColor: AppTheme.cardDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingCloud = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to log out from MK Star?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<HistoryViewModel>().clearBills();
      await context.read<AuthViewModel>().logout();
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Data',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will permanently delete ALL bills from local storage and cloud, and reset the bill counter. This action cannot be undone!',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Clear All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SettingsViewModel>().clearAllData();
      if (mounted) {
        context.read<HistoryViewModel>().loadBills();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared locally and from cloud')),
        );
      }
    }
  }

  Future<void> _exportData() async {
    final json = await context.read<SettingsViewModel>().exportAsJson();
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Exported Data',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(
                json,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: const Text('Copy to Clipboard',
                  style: TextStyle(color: AppTheme.gold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      );
    }
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Choose Logo Source',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: AppTheme.teal,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _ImageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppTheme.gold,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final vm = context.read<SettingsViewModel>();
    final path = await vm.pickAndSaveLogoImage(source);
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success),
              SizedBox(width: 8),
              Text('Logo updated successfully!'),
            ],
          ),
          backgroundColor: AppTheme.cardDark,
        ),
      );
    }
  }

  // ==================== PACKAGE DIALOGS ====================

  void _showCreatePackageDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final comboCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Package',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Package Name *',
                  hintText: 'e.g. Marriage Package, Reception Shoot',
                  prefixIcon: Icon(Icons.stars_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comboCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Package Total Price (₹) *',
                  hintText: 'e.g. 80000',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'e.g. 2 Days photo + video + drone',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Package name cannot be empty')),
                );
                return;
              }
              final combo = double.tryParse(comboCtrl.text.trim());
              final desc = descCtrl.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              final vm = context.read<SettingsViewModel>();
              final pkg = await vm.addPackage(
                name,
                description: desc.isNotEmpty ? desc : null,
                comboPrice: combo,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Created "${pkg.name}". Tap to add items!'),
                    backgroundColor: AppTheme.cardDark,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditPackageDialog(BuildContext context, PackageModel pkg) {
    final nameCtrl = TextEditingController(text: pkg.name);
    final comboCtrl = TextEditingController(
        text: pkg.comboPrice != null && pkg.comboPrice! > 0
            ? pkg.comboPrice!.toStringAsFixed(0)
            : '');
    final descCtrl = TextEditingController(text: pkg.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit ${pkg.name}',
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Package Name *',
                  prefixIcon: Icon(Icons.stars_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comboCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Package Total Price (₹) *',
                  hintText: 'e.g. 80000',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              pkg.name = name;
              pkg.comboPrice = double.tryParse(comboCtrl.text.trim());
              pkg.description = descCtrl.text.trim().isNotEmpty
                  ? descCtrl.text.trim()
                  : null;
              await context.read<SettingsViewModel>().updatePackage(pkg);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditPackageItemDialog(
      BuildContext context, PackageModel pkg, [int? itemIndex]) {
    final isEdit = itemIndex != null;
    final existingItem = isEdit ? pkg.items[itemIndex] : null;
    final nameCtrl =
        TextEditingController(text: existingItem?.itemName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Item' : 'Add Item to ${pkg.name}',
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter service or item name included in this package:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                hintText: 'e.g. Candid Photography, Drone Shoot',
                prefixIcon: Icon(Icons.camera_enhance_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final item = PackageItem(itemName: name);
              final vm = context.read<SettingsViewModel>();
              if (isEdit) {
                await vm.updatePackageItem(pkg.id, itemIndex, item);
              } else {
                await vm.addPackageItem(pkg.id, item);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Save' : 'Add Item'),
          ),
        ],
      ),
    );
  }

  void _showDeletePackageConfirm(BuildContext context, PackageModel pkg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Package',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${pkg.name}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<SettingsViewModel>().deletePackage(pkg.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final symbol = vm.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Save', style: TextStyle(color: AppTheme.gold)),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => setState(() => _editing = true),
              tooltip: 'Edit',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Profile Card
          Consumer<AuthViewModel>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              if (user == null) return const SizedBox.shrink();
              final initials = user.name.isNotEmpty
                  ? user.name
                      .split(' ')
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .take(2)
                      .join()
                      .toUpperCase()
                  : '?';
              return _SettingsCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.gold,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '🏢 ${user.shopName}',
                                style: const TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded,
                              color: AppTheme.error),
                          tooltip: 'Log Out',
                          onPressed: _confirmLogout,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Cloud Sync (Cleaned up from database branding)
          _SectionHeader('Cloud Sync'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<MongoConnectionStatus>(
                  valueListenable: MongoService.instance.statusNotifier,
                  builder: (context, status, _) {
                    Color statusColor;
                    String statusText;
                    IconData statusIcon;

                    switch (status) {
                      case MongoConnectionStatus.connected:
                        statusColor = AppTheme.success;
                        statusText = 'Cloud Sync Active';
                        statusIcon = Icons.cloud_done_rounded;
                        break;
                      case MongoConnectionStatus.connecting:
                        statusColor = AppTheme.gold;
                        statusText = 'Connecting to Cloud...';
                        statusIcon = Icons.cloud_sync_rounded;
                        break;
                      case MongoConnectionStatus.error:
                        statusColor = AppTheme.error;
                        statusText = 'Offline Mode (Local Storage)';
                        statusIcon = Icons.cloud_off_rounded;
                        break;
                      case MongoConnectionStatus.disconnected:
                        statusColor = AppTheme.textSecondary;
                        statusText = 'Offline Mode';
                        statusIcon = Icons.cloud_off_rounded;
                        break;
                    }

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                status == MongoConnectionStatus.connected
                                    ? 'Automatic real-time cloud backup'
                                    : 'Bills and settings saved securely on device',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'All bills, payments, packages, and settings are automatically backed up to the cloud with full offline support.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncingCloud ? null : _syncCloud,
                    icon: _isSyncingCloud
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.primaryDark),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(_isSyncingCloud ? 'Syncing...' : 'Sync Now'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Business info section
          _SectionHeader('Business Info'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: TextField(
              controller: _shopNameController,
              enabled: _editing,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Shop Name',
                prefixIcon: Icon(Icons.store_rounded),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Shop Logo
          _SectionHeader('Shop Logo'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Column(
              children: [
                // Logo preview (No third-party brand default image!)
                GestureDetector(
                  onTap: () => _showImageSourcePicker(context),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.gold, width: 2.5),
                          color: AppTheme.surfaceDark,
                        ),
                        child: ClipOval(
                          child: vm.logoFile != null
                              ? Image.file(
                                  vm.logoFile!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) =>
                                      const Center(
                                    child: Icon(Icons.storefront_rounded,
                                        size: 44, color: AppTheme.gold),
                                  ),
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          size: 38, color: AppTheme.gold),
                                      SizedBox(height: 6),
                                      Text(
                                        'Upload Logo',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.gold,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.cardDark, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppTheme.primaryDark, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  vm.logoFile != null
                      ? 'Tap to change logo'
                      : 'Tap to upload studio logo',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This logo will appear on bills and PDF invoices',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                if (vm.logoFile != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await vm.removeLogo();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Logo removed'),
                            backgroundColor: AppTheme.cardDark,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.error, size: 18),
                    label: const Text('Remove Logo',
                        style:
                            TextStyle(color: AppTheme.error, fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ==================== SERVICE PACKAGES SECTION ====================
          _SectionHeader('Service Packages (e.g. Marriage, Birthday)'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_rounded,
                              color: AppTheme.gold, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Packages (${vm.packages.length})',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const Text(
                              'Pre-set items for quick 1-tap billing',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showCreatePackageDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label:
                          const Text('Add Package', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (vm.packages.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('No packages created yet',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => vm.resetToDefaultPackages(),
                            icon: const Icon(Icons.restore_rounded,
                                size: 16, color: AppTheme.gold),
                            label: const Text('Restore Default Packages',
                                style: TextStyle(color: AppTheme.gold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  ...vm.packages.map((pkg) {
                    final hasCombo =
                        pkg.comboPrice != null && pkg.comboPrice! > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.photo_library_rounded,
                                color: AppTheme.gold, size: 20),
                          ),
                          title: Text(
                            pkg.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${pkg.items.length} items • Total: ${hasCombo ? CurrencyFormatter.formatWithDecimals(pkg.comboPrice!, symbol: symbol) : '₹0'}',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: AppTheme.textSecondary, size: 18),
                                tooltip: 'Edit Package',
                                onPressed: () =>
                                    _showEditPackageDialog(context, pkg),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppTheme.error, size: 18),
                                tooltip: 'Delete Package',
                                onPressed: () =>
                                    _showDeletePackageConfirm(context, pkg),
                              ),
                              const Icon(Icons.expand_more_rounded,
                                  color: AppTheme.textSecondary, size: 20),
                            ],
                          ),
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(
                                      color: AppTheme.divider, height: 1),
                                  const SizedBox(height: 10),
                                  if (pkg.items.isEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'No items in this package yet. Add items below.',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12),
                                      ),
                                    )
                                  else
                                    ...pkg.items.asMap().entries.map((itemEntry) {
                                      final idx = itemEntry.key;
                                      final item = itemEntry.value;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Row(
                                          children: [
                                            const Icon(
                                                Icons.check_circle_rounded,
                                                size: 16,
                                                color: AppTheme.teal),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                item.itemName,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 16,
                                                  color:
                                                      AppTheme.textSecondary),
                                              tooltip: 'Edit Item',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () =>
                                                  _showAddOrEditPackageItemDialog(
                                                      context, pkg, idx),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 16,
                                                  color: AppTheme.error),
                                              tooltip: 'Remove Item',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () => vm
                                                  .deletePackageItem(pkg.id, idx),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _showAddOrEditPackageItemDialog(
                                                context, pkg),
                                        icon: const Icon(Icons.add_rounded,
                                            size: 14),
                                        label: const Text('Add Item',
                                            style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.gold,
                                          side: const BorderSide(
                                              color: AppTheme.gold),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize
                                              .shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => vm.resetToDefaultPackages(),
                      icon: const Icon(Icons.restore_rounded,
                          size: 14, color: AppTheme.textSecondary),
                      label: const Text('Restore Default Packages',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Currency Display section
          _SectionHeader('Currency Display'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose currency display format (solves device font rendering issues):',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: const Text('₹ - Indian Rupee Symbol',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text(
                      'Default symbol (rendered with Noto/Roboto font fallbacks)',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                  value: '₹',
                  groupValue: vm.currencySymbol,
                  activeColor: AppTheme.gold,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) vm.updateCurrencySymbol(val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Rs. - Standard Text Format',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text(
                      '100% fail-safe on all mobile devices, custom ROMs & printers',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                  value: 'Rs.',
                  groupValue: vm.currencySymbol,
                  activeColor: AppTheme.gold,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) vm.updateCurrencySymbol(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Preferences
          _SectionHeader('Preferences'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: SwitchListTile(
              title: const Text('Auto-increment Bill Number',
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text('Automatically generate bill numbers',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              value: vm.autoIncrement,
              activeThumbColor: AppTheme.gold,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => vm.updateAutoIncrement(v),
            ),
          ),

          const SizedBox(height: 20),

          // Bill number info
          _SectionHeader('Bill Counter'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Row(
              children: [
                const Icon(Icons.numbers_rounded, color: AppTheme.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last Bill Number',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      Text(
                        'MK-${vm.settings.lastBillNumber.toString().padLeft(3, '0')}',
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${vm.settings.lastBillNumber} bills total',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Data management
          _SectionHeader('Data Management'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.download_rounded,
                        color: AppTheme.teal, size: 22),
                  ),
                  title: const Text('Export All Bills',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text('Export as JSON',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary),
                  onTap: _exportData,
                ),
                const Divider(color: AppTheme.divider, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_forever_rounded,
                        color: AppTheme.error, size: 22),
                  ),
                  title: const Text('Clear All Data',
                      style: TextStyle(color: AppTheme.error)),
                  subtitle: const Text(
                      'Delete all bills permanently from local and cloud storage',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary),
                  onTap: _clearAllData,
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // App version
          Center(
            child: Column(
              children: [
                const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.gold, size: 28),
                const SizedBox(height: 6),
                const Text('MK Star',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700)),
                const Text('Bill Generator v1.0.0 (Cloud Sync Enabled)',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.gold,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: child,
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
