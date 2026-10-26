import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../widgets/link_text.dart';
import 'attributions_screen.dart';

/// Settings. For now only "Hakkında": data sources and licenses,
/// open-source licenses and the privacy policy.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(AppStrings.about, style: theme.textTheme.titleLarge),
            ),
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
