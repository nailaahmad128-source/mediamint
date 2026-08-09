import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/output_location_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../premium/premium_screen.dart';
import '../premium/subscription_service.dart';
import '../privacy/privacy_screen.dart';
import 'widgets/licenses_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  final OutputLocationService _outputLocation = OutputLocationService();
  late final SubscriptionService _subscription;

  AppThemeMode _themeMode = AppThemeMode.system;
  String _defaultFormat = AppConstants.defaultOutputFormat;
  int _defaultBitrate = AppConstants.defaultBitrateKbps;
  String _saveLocation = 'app';
  bool _autoDeleteTemp = true;
  bool _hapticFeedback = true;
  bool _devPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscription = SubscriptionService(_storage);
    _load();
  }

  Future<void> _load() async {
    final themeMode = await _storage.getThemeMode();
    final format = await _storage.getDefaultOutputFormat();
    final bitrate = await _storage.getDefaultBitrate();
    final saveLocation = await _storage.getSaveLocation();
    final autoDelete = await _storage.getAutoDeleteTemp();
    final haptic = await _storage.getHapticFeedback();
    final devPremium = await _storage.getDevPremiumOverride();

    if (!mounted) return;
    setState(() {
      _themeMode = themeMode;
      _defaultFormat = format;
      _defaultBitrate = bitrate;
      _saveLocation = saveLocation;
      _autoDeleteTemp = autoDelete;
      _hapticFeedback = haptic;
      _devPremium = devPremium;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: AppTheme.pagePadding,
                children: [
                  _SectionCard(
                    title: 'Appearance',
                    children: [
                      _RadioRow<AppThemeMode>(
                        title: 'System',
                        value: AppThemeMode.system,
                        groupValue: _themeMode,
                        onChanged: (v) async {
                          setState(() => _themeMode = v!);
                          await themeController.update(v!);
                        },
                      ),
                      _RadioRow<AppThemeMode>(
                        title: 'Light',
                        value: AppThemeMode.light,
                        groupValue: _themeMode,
                        onChanged: (v) async {
                          setState(() => _themeMode = v!);
                          await themeController.update(v!);
                        },
                      ),
                      _RadioRow<AppThemeMode>(
                        title: 'Dark',
                        value: AppThemeMode.dark,
                        groupValue: _themeMode,
                        onChanged: (v) async {
                          setState(() => _themeMode = v!);
                          await themeController.update(v!);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Defaults',
                    children: [
                      ListTile(
                        title: const Text('Default output format'),
                        trailing: DropdownButton<String>(
                          value: _defaultFormat,
                          underline: const SizedBox.shrink(),
                          items: AppConstants.audioOutputFormats
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _defaultFormat = v);
                            await _storage.setDefaultOutputFormat(v);
                          },
                        ),
                      ),
                      if (_defaultFormat != 'WAV')
                        ListTile(
                          title: const Text('Default quality'),
                          trailing: DropdownButton<int>(
                            value: _defaultBitrate,
                            underline: const SizedBox.shrink(),
                            items: AppConstants.bitrateOptionsKbps
                                .map((b) => DropdownMenuItem(value: b, child: Text('$b kbps')))
                                .toList(),
                            onChanged: (v) async {
                              if (v == null) return;
                              setState(() => _defaultBitrate = v);
                              await _storage.setDefaultBitrate(v);
                            },
                          ),
                        ),
                      ListTile(
                        title: const Text('Save location'),
                        subtitle: Text(
                          _saveLocation == 'downloads'
                              ? 'Downloads/MediaMint'
                              : 'App storage (MediaMint)',
                        ),
                        trailing: DropdownButton<String>(
                          value: _saveLocation,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'app', child: Text('App storage')),
                            DropdownMenuItem(value: 'downloads', child: Text('Downloads')),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _saveLocation = v);
                            await _storage.setSaveLocation(v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Storage',
                    children: [
                      SwitchListTile(
                        title: const Text('Auto-delete temporary files'),
                        subtitle: const Text('Clears working files after each conversion'),
                        value: _autoDeleteTemp,
                        onChanged: (v) async {
                          setState(() => _autoDeleteTemp = v);
                          await _storage.setAutoDeleteTemp(v);
                        },
                      ),
                      ListTile(
                        title: const Text('Clear temporary files now'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await _outputLocation.clearTempDirectory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Temporary files cleared')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Feedback',
                    children: [
                      SwitchListTile(
                        title: const Text('Haptic feedback'),
                        value: _hapticFeedback,
                        onChanged: (v) async {
                          setState(() => _hapticFeedback = v);
                          await _storage.setHapticFeedback(v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'About',
                    children: [
                      ListTile(
                        title: const Text('MediaMint Pro'),
                        subtitle: const Text('Unlock higher quality exports and more'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PremiumScreen()),
                        ),
                      ),
                      ListTile(
                        title: const Text('Privacy'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                        ),
                      ),
                      ListTile(
                        title: const Text('Licenses'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LicensesScreen()),
                        ),
                      ),
                      const ListTile(
                        title: Text('Version'),
                        trailing: Text('1.0.0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Developer options',
                    children: [
                      SwitchListTile(
                        title: const Text('Simulate Premium (test mode)'),
                        subtitle: const Text(
                          'For development/QA only — this is not a real purchase and has no effect on billing.',
                        ),
                        value: _devPremium,
                        onChanged: (v) async {
                          setState(() => _devPremium = v);
                          await _subscription.setDevPremiumOverride(v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RadioRow<T> extends StatelessWidget {
  final String title;
  final T value;
  final T groupValue;
  final ValueChanged<T?> onChanged;

  const _RadioRow({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }
}
