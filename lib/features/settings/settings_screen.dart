import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../data/moderation.dart';
import '../../data/leaderboard.dart';
import '../../data/settings_store.dart';
import '../../widgets/link_text.dart';
import '../leaderboard/join_sheet.dart';
import 'attributions_screen.dart';
import 'connection_test_screen.dart';
import 'user_name_sheet.dart';

/// Settings: the player's one name (the only place it is typed), the
/// theme, sound effects, the leaderboard while joined, and "Hakkında" with
/// data sources and licenses, open-source licenses and the privacy policy.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings, this.leaderboard});

  final SettingsStore settings;

  /// The leaderboard: a name change goes there too while joined, and its
  /// section shows then. Null when there is no server.
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
            const _SectionTitle(AppStrings.userNameSection),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListenableBuilder(
                listenable: settings,
                builder: (context, _) {
                  final name = settings.userName;
                  final next = settings.nextNameChange();
                  return ListTile(
                    leading: const Icon(Icons.badge_rounded),
                    title: Text(name ?? AppStrings.userNameUnset),
                    subtitle: Text(
                      next == null
                          ? AppStrings.userNameSubtitle
                          : AppStrings.userNameNextChange(next),
                    ),
                    trailing: const Icon(Icons.edit_rounded),
                    onTap: () =>
                        showUserNameSheet(context, settings, leaderboard),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
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
                  if (leaderboard?.serviceUri case final service?) ...[
                    ListTile(
                      leading: const Icon(Icons.network_check_rounded),
                      title: const Text(AppStrings.netTest),
                      subtitle: const Text(AppStrings.netTestHint),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ConnectionTestScreen(service: service),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  ListTile(
                    leading: const Icon(Icons.tour_rounded),
                    title: const Text(AppStrings.tourReplay),
                    subtitle: const Text(AppStrings.tourReplayHint),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await settings.replayTours();
                      // Back home, where the tour starts.
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                  ),
                  const Divider(height: 1),
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
                  const Divider(height: 1),
                  ListenableBuilder(
                    listenable: Moderation.instance,
                    builder: (context, _) => ListTile(
                      leading: const Icon(Icons.block_rounded),
                      title: const Text(AppStrings.blockedPlayers),
                      subtitle: Text(
                        AppStrings.blockedPlayersHint(
                          Moderation.instance.blocked.length,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: Moderation.instance.blocked.isEmpty
                          ? null
                          : () => _showBlocked(context),
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.mail_outline_rounded),
                    title: Text(AppStrings.contact),
                    subtitle: Text(AppStrings.contactHint),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(72, 0, 8, 8),
                    child: LinkText(url: AppStrings.contactUrl),
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

/// The blocked names, each with "Engeli kaldır".
Future<void> _showBlocked(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: ListenableBuilder(
      listenable: Moderation.instance,
      builder: (context, _) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              AppStrings.blockedPlayers,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final name in Moderation.instance.blocked)
            ListTile(
              leading: const Icon(Icons.person_off_rounded),
              title: Text(name),
              trailing: TextButton(
                onPressed: () => Moderation.instance.unblock(name),
                child: const Text(AppStrings.unblockPlayer),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  ),
);

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

/// Leaving the leaderboard: the scores on the server are deleted, the name
/// stays in the app (duels and tournaments keep using it).
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
              const ListTile(
                leading: Icon(Icons.emoji_events_rounded),
                title: Text(AppStrings.leaderboardJoined),
                subtitle: Text(AppStrings.leaderboardResets),
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
