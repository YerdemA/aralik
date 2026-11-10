import 'package:flutter/material.dart';

import '../../core/mascot_look.dart';
import '../../core/strings.dart';
import '../../data/settings_store.dart';
import '../../widgets/mascot_portrait.dart';

/// Ayarlar → Maskotun: the player dresses up their philosopher. One
/// action, "Kaydet"; the first choice is free, then it waits three days
/// ([mascotChangeEvery]), like the user name.
class MascotScreen extends StatefulWidget {
  const MascotScreen({super.key, required this.settings, this.now});

  final SettingsStore settings;

  /// For tests.
  final DateTime Function()? now;

  @override
  State<MascotScreen> createState() => _MascotScreenState();
}

/// One row of options: its title, the names and how each option dresses
/// a look.
class _Feature {
  const _Feature(this.title, this.names, this.apply, this.selected);

  final String title;
  final List<String> names;
  final MascotLook Function(MascotLook look, int i) apply;
  final int Function(MascotLook look) selected;
}

final _features = [
  _Feature(
    AppStrings.mascotGender,
    AppStrings.mascotGenderNames,
    (l, i) => l.copyWith(gender: MascotGender.values[i]),
    (l) => l.gender.index,
  ),
  _Feature(
    AppStrings.mascotSkin,
    AppStrings.mascotSkinNames,
    (l, i) => l.copyWith(skin: MascotSkin.values[i]),
    (l) => l.skin.index,
  ),
  _Feature(
    AppStrings.mascotHair,
    AppStrings.mascotHairNames,
    (l, i) => l.copyWith(hair: MascotHair.values[i]),
    (l) => l.hair.index,
  ),
  _Feature(
    AppStrings.mascotHairColor,
    AppStrings.mascotHairColorNames,
    (l, i) => l.copyWith(hairColor: MascotHairColor.values[i]),
    (l) => l.hairColor.index,
  ),
  _Feature(
    AppStrings.mascotBeard,
    AppStrings.mascotBeardNames,
    (l, i) => l.copyWith(beard: MascotBeard.values[i]),
    (l) => l.beard.index,
  ),
  _Feature(
    AppStrings.mascotMoustache,
    AppStrings.mascotMoustacheNames,
    (l, i) => l.copyWith(moustache: MascotMoustache.values[i]),
    (l) => l.moustache.index,
  ),
  _Feature(
    AppStrings.mascotEyes,
    AppStrings.mascotEyesNames,
    (l, i) => l.copyWith(eyes: MascotEyes.values[i]),
    (l) => l.eyes.index,
  ),
  _Feature(
    AppStrings.mascotGlasses,
    AppStrings.mascotGlassesNames,
    (l, i) => l.copyWith(glasses: MascotGlasses.values[i]),
    (l) => l.glasses.index,
  ),
  _Feature(
    AppStrings.mascotHat,
    AppStrings.mascotHatNames,
    (l, i) => l.copyWith(hat: MascotHat.values[i]),
    (l) => l.hat.index,
  ),
];

class _MascotScreenState extends State<MascotScreen> {
  late MascotLook _look = widget.settings.mascot;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  bool _hidden(_Feature f) =>
      _look.isWoman &&
      (f.title == AppStrings.mascotBeard ||
          f.title == AppStrings.mascotMoustache);

  void _pick(_Feature f, int i) {
    setState(() {
      // A woman starts from a woman's look the first time she is picked.
      if (f.title == AppStrings.mascotGender &&
          i == MascotGender.woman.index &&
          !_look.isWoman &&
          _look.hair == MascotHair.tufts) {
        _look = _look.copyWith(
          gender: MascotGender.woman,
          hair: MascotHair.long,
          hairColor: _look.hairColor == MascotHairColor.white
              ? MascotHairColor.brown
              : null,
        );
      } else {
        _look = f.apply(_look, i);
      }
    });
  }

  Future<void> _save() async {
    final settings = widget.settings;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // The first choice is free; a change starts the wait, so ask.
    if (settings.mascotCode != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(AppStrings.mascotConfirmTitle),
          content: const Text(AppStrings.mascotConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await settings.setMascot(_look, now: _now());
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.mascotSaved)),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.settings;
    final next = settings.nextMascotChange(_now());
    final saved = settings.mascotCode;
    final changed = saved == null || _look.code != saved;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.mascotTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: MascotPortrait(
                  key: ValueKey(_look.code),
                  look: _look,
                  size: 150,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                children: [
                  for (final f in _features)
                    if (!_hidden(f))
                      _FeatureRow(
                        feature: f,
                        look: _look,
                        enabled: next == null,
                        onPick: (i) => _pick(f, i),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                children: [
                  Text(
                    next == null
                        ? AppStrings.mascotBody
                        : AppStrings.mascotLocked(next),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: next == null && changed ? _save : null,
                      child: const Text(AppStrings.save),
                    ),
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

/// A feature's title and its options side by side, each a small portrait
/// wearing it.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.feature,
    required this.look,
    required this.enabled,
    required this.onPick,
  });

  final _Feature feature;
  final MascotLook look;
  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = feature.selected(look);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text(feature.title, style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: 114,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: feature.names.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final on = i == selected;
              return Semantics(
                selected: on,
                button: true,
                label: '${feature.title}: ${feature.names[i]}',
                excludeSemantics: true,
                child: Material(
                  // A light tint and a bold frame: the label stays legible.
                  color: on
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: on
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enabled ? () => onPick(i) : null,
                    child: SizedBox(
                      width: 88,
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          // Close on the face: small differences show.
                          MascotPortrait(
                            look: feature.apply(look, i),
                            size: 76,
                            zoom: true,
                          ),
                          Text(
                            feature.names[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: on ? theme.colorScheme.primary : null,
                              fontWeight: on ? FontWeight.w800 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
