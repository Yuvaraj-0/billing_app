import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/mongo_service.dart';
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
  bool _isSyncingMongo = false;

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
        SnackBar(
          content: const Row(
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

  Future<void> _syncMongo() async {
    setState(() => _isSyncingMongo = true);
    try {
      final authVm = context.read<AuthViewModel>();
      final historyVm = context.read<HistoryViewModel>();
      final newCount = await historyVm.syncWithMongo(userId: authVm.currentUser?.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: AppTheme.success),
                const SizedBox(width: 8),
                Text('MongoDB Atlas synced! ($newCount bills updated)'),
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
      if (mounted) setState(() => _isSyncingMongo = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to log out from MK Star?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
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
          'This will permanently delete ALL bills from local storage and MongoDB Atlas, and reset the bill counter. This action cannot be undone!',
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
          const SnackBar(content: Text('All data cleared locally and from MongoDB')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
              child: const Text('Copy',
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
        SnackBar(
          content: const Row(
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();

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
                  ? user.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
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
                          icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
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

          // Cloud Database (MongoDB Atlas)
          _SectionHeader('Cloud Database (MongoDB Atlas)'),
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
                        statusText = 'Connected to MongoDB Atlas';
                        statusIcon = Icons.cloud_done_rounded;
                        break;
                      case MongoConnectionStatus.connecting:
                        statusColor = AppTheme.gold;
                        statusText = 'Connecting to MongoDB Atlas...';
                        statusIcon = Icons.cloud_sync_rounded;
                        break;
                      case MongoConnectionStatus.error:
                        statusColor = AppTheme.error;
                        statusText = 'Connection Error (Offline Cache Active)';
                        statusIcon = Icons.cloud_off_rounded;
                        break;
                      case MongoConnectionStatus.disconnected:
                        statusColor = AppTheme.textSecondary;
                        statusText = 'Disconnected';
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
                              const Text(
                                'cluster0.kvv3uji.mongodb.net / mk_studio',
                                style: TextStyle(
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
                  'Every bill, payment update, and setting is automatically saved to MongoDB Atlas in the cloud with local offline fallback.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncingMongo ? null : _syncMongo,
                    icon: _isSyncingMongo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDark),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(_isSyncingMongo ? 'Syncing...' : 'Sync Now with MongoDB'),
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

          // Shop Logo / Profile Image
          _SectionHeader('Shop Logo / Profile Image'),
          const SizedBox(height: 10),
          _SettingsCard(
            child: Column(
              children: [
                // Logo preview
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
                                      Image.asset('asserts/logo-CWXXw7Ao.png',
                                          width: 120, height: 120, fit: BoxFit.contain),
                                )
                              : Image.asset('asserts/logo-CWXXw7Ao.png',
                                  width: 120, height: 120, fit: BoxFit.contain),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.cardDark, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppTheme.primaryDark, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  vm.logoFile != null ? 'Tap to change logo' : 'Tap to upload logo',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This logo will appear on bills and PDF invoices',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                        style: TextStyle(color: AppTheme.error, fontSize: 13)),
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
                  title: const Text('₹ - Indian Rupee Symbol', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text('Default symbol (rendered with Noto/Roboto font fallbacks)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  value: '₹',
                  groupValue: vm.currencySymbol,
                  activeColor: AppTheme.gold,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) vm.updateCurrencySymbol(val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Rs. - Standard Text Format', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text('100% fail-safe on all mobile devices, custom ROMs & printers', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
                  subtitle: const Text('Delete all bills permanently from local and MongoDB',
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
                const Text('MK Photo Studio',
                    style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                const Text('Bill Generator v1.0.0 (MongoDB Atlas Connected)',
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
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.gold,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
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
    );
  }
}

