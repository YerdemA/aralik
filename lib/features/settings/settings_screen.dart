import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../data/leaderboard.dart';
import '../../data/settings_store.dart';
import '../../widgets/link_text.dart';
import '../leaderboard/nickname_sheet.dart';
import 'attributions_screen.dart';

/// Settings: the theme, sound effects, and "Hakkında" with data sources and licenses,
/// open-source licenses and the privacy policy.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings, this.leaderboard});

  final SettingsStore settings;

  /// Shows the leaderboard section while joined; null hides it.
  final LeaderboardStore? leaderboard;

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
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListenableBuilder(
                listenable: settings,
                builder: (context, _) => SwitchListTile(
                  secondary: Icon(
                    settings.soundOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                  title: const Text(AppStrings.soundEffects),
                  subtitle: const Text(AppStrings.soundEffectsHint),
                  value: settings.soundOn,
                  onChanged: settings.setSoundOn,
                ),
              ),
            ),
            if (leaderboard != null)
              ListenableBuilder(
                listenable: leaderboard!,
                builder: (context, _) => leaderboard!.joined
                    ? _LeaderboardSection(store: leaderboard!)
                    : const SizedBox.shrink(),
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

/// Nickname and leaving the leaderboard (deletes the data on the server).
class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.store});

  final LeaderboardStore store;

  Future<void> _leave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.leaveConfirmTitle),
        content: const Text(AppStrings.leaveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.leave),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.leave();
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.leftLeaderboard)),
      );
    } on LeaderboardException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(leaderboardFailureText(e.failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const _SectionTitle(AppStrings.leaderboardSection),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_rounded),
                title: Text(store.account?.nickname ?? ''),
                subtitle: const Text(AppStrings.nicknameSubtitle),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () => showNicknameSheet(context, store),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text(AppStrings.leaveLeaderboard),
                subtitle: const Text(AppStrings.leaveLeaderboardHint),
                onTap: () => _leave(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
