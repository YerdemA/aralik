import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../data/settings_store.dart';
import '../../widgets/link_text.dart';
import 'attributions_screen.dart';

/// Settings: the theme, and "Hakkında" with data sources and licenses,
/// open-source licenses and the privacy policy.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _SectionTitle(AppStrings.appearance),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(AppStrings.theme, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: settings,
                      builder: (context, _) => SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded),
                            label: Text(AppStrings.themeSystem),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text(AppStrings.themeLight),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text(AppStrings.themeDark),
                          ),
                        ],
                        selected: {settings.themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            settings.setThemeMode(s.single),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(AppStrings.about),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dataset_rounded),
                    title: const Text(AppStrings.dataSources),
                    subtitle: const Text(AppStrings.dataSourcesHint),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AttributionsScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_rounded),
                    title: const Text(AppStrings.openSourceLicenses),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: AppStrings.appName,
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.privacy_tip_rounded),
                    title: Text(AppStrings.privacyPolicy),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(72, 0, 8, 8),
                    child: LinkText(url: AppStrings.privacyPolicyUrl),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}
