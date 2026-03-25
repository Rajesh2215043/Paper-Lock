import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/backup_helper.dart';
import '../utils/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  const SettingsScreen({super.key, required this.themeProvider});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isAppLockEnabled = false;
  bool _isLoadingLockSettings = true;
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadLockSettings();
  }

  Future<void> _loadLockSettings() async {
    final value = await _secureStorage.read(key: 'auth_required');
    if (mounted) {
      setState(() {
        _isAppLockEnabled = value == 'true';
        _isLoadingLockSettings = false;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    // If trying to turn ON app lock, authenticate first to verify user
    if (value) {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device does not support authentication.'),
            ),
          );
        }
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to enable app lock',
      );

      if (!didAuthenticate) {
        return; // User cancelled
      }
    } else {
      // Authenticate to disable lock as well for security
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to disable app lock',
      );

      if (!didAuthenticate) {
        return; // User cancelled
      }
    }

    await _secureStorage.write(key: 'auth_required', value: value.toString());
    setState(() {
      _isAppLockEnabled = value;
    });
  }

  void _exportBackup() {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final bg = theme.scaffoldBackgroundColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: fg.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.download_rounded, color: fg),
                title: Text(
                  'Save to Downloads',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Save ZIP to your Downloads folder',
                  style: TextStyle(color: fg.withOpacity(0.5), fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _doExport(saveLocally: true);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.share_outlined, color: fg),
                title: Text(
                  'Share',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Send via WhatsApp, Gmail, etc.',
                  style: TextStyle(color: fg.withOpacity(0.5), fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _doExport(saveLocally: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doExport({required bool saveLocally}) async {
    setState(() => _isExporting = true);
    try {
      final zipFile = await BackupHelper.exportBackup();

      if (saveLocally) {
        // Save to Downloads folder
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final destPath =
            '${downloadsDir.path}/doc_wallet_backup_$timestamp.zip';
        await zipFile.copy(destPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to Downloads folder!')),
          );
        }
      } else {
        // Share via apps
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zipFile.path, mimeType: 'application/zip')],
            subject: 'Document Wallet Backup',
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup shared successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importBackup() async {
    // Pick any file — user selects the ZIP backup
    final result = await FilePicker.platform.pickFiles();

    if (result == null || result.files.first.path == null) return;

    final filePath = result.files.first.path!;
    if (!filePath.toLowerCase().endsWith('.zip')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a .zip backup file')),
        );
      }
      return;
    }

    setState(() => _isImporting = true);
    try {
      final zipFile = File(result.files.first.path!);
      final count = await BackupHelper.importBackup(zipFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count documents successfully!')),
        );
        Navigator.of(context).pop(true); // signal home to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final isDark = widget.themeProvider.isDark;
    final borderColor = fg.withOpacity(0.12);
    final chipBg = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade50;

    return Scaffold(
      appBar: AppBar(title: Icon(Icons.settings_outlined, size: 24, color: fg)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Appearance ──
          _sectionLabel('Appearance', fg),
          const SizedBox(height: 8),
          _settingTile(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            title: 'Invert Colors',
            subtitle: isDark ? 'White on Black' : 'Black on White',
            fg: fg,
            borderColor: borderColor,
            trailing: Switch.adaptive(
              value: isDark,
              onChanged: (_) => widget.themeProvider.toggle(),
              activeColor: theme.scaffoldBackgroundColor,
              activeTrackColor: fg,
              inactiveThumbColor: fg,
              inactiveTrackColor: fg.withOpacity(0.2),
            ),
          ),

          const SizedBox(height: 24),

          // ── Security ──
          _sectionLabel('Security', fg),
          const SizedBox(height: 8),
          _isLoadingLockSettings
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _settingTile(
                  icon: Icons.lock_outline,
                  title: 'App Lock',
                  subtitle: 'Require biometric or passcode to open',
                  fg: fg,
                  borderColor: borderColor,
                  trailing: Switch.adaptive(
                    value: _isAppLockEnabled,
                    onChanged: _toggleAppLock,
                    activeColor: theme.scaffoldBackgroundColor,
                    activeTrackColor: fg,
                    inactiveThumbColor: fg,
                    inactiveTrackColor: fg.withOpacity(0.2),
                  ),
                ),

          const SizedBox(height: 24),

          // ── Backup ──
          _sectionLabel('Backup', fg),
          const SizedBox(height: 8),

          // Export
          _settingTile(
            icon: Icons.upload_outlined,
            title: 'Export Backup',
            subtitle: 'Save or share as ZIP',
            fg: fg,
            borderColor: borderColor,
            trailing: _isExporting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: fg, strokeWidth: 2),
                  )
                : Icon(Icons.chevron_right, color: fg.withOpacity(0.4)),
            onTap: _isExporting ? null : _exportBackup,
          ),
          const SizedBox(height: 10),

          // Import
          _settingTile(
            icon: Icons.download_outlined,
            title: 'Import Backup',
            subtitle: 'Restore from ZIP file',
            fg: fg,
            borderColor: borderColor,
            trailing: _isImporting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: fg, strokeWidth: 2),
                  )
                : Icon(Icons.chevron_right, color: fg.withOpacity(0.4)),
            onTap: _isImporting ? null : _importBackup,
          ),

          const SizedBox(height: 24),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: fg.withOpacity(0.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Export creates a ZIP with all documents & files. Import restores them on any device.',
                    style: TextStyle(fontSize: 12, color: fg.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color fg) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: fg.withOpacity(0.4),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color fg,
    required Color borderColor,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: fg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: fg.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
