import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/mascot_look.dart';
import '../../core/ranked.dart';
import '../../core/strings.dart';
import '../../data/gallery.dart';
import '../../widgets/share_origin.dart';
import '../result/share_card.dart';
import 'ranked_screen.dart';

/// Shown once when a month ends, to a player who played ranked duels in
/// it: for each table (knowledge, math) their card (place, rating, duels,
/// wins, average, hit rate) to download or share, and the month's top 10.
class MonthEndScreen extends StatelessWidget {
  const MonthEndScreen({
    super.key,
    required this.tables,
    required this.look,
    this.render = renderRankedCard,
    this.save = saveImageToGallery,
  });

  /// The tables of the month that ended in which the player has a line.
  final List<RankedTable> tables;
  final MascotLook look;

  /// Injectable for tests.
  final Future<Uint8List> Function(RankedCardData) render;
  final Future<bool> Function(Uint8List png, String name) save;

  @override
  Widget build(BuildContext context) {
    final month = tables.first.month;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.monthEndTitle(rankedMonthLabel(month))),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            for (final table in tables)
              if (table.me case final me?)
                _TableRecap(
                  table: table,
                  card: RankedCardData(
                    month: table.month,
                    math: table.mode == RankedMode.math,
                    players: table.players,
                    me: me,
                    look: look,
                  ),
                  render: render,
                  save: save,
                ),
          ],
        ),
      ),
    );
  }
}

class _TableRecap extends StatefulWidget {
  const _TableRecap({
    required this.table,
    required this.card,
    required this.render,
    required this.save,
  });

  final RankedTable table;
  final RankedCardData card;
  final Future<Uint8List> Function(RankedCardData) render;
  final Future<bool> Function(Uint8List png, String name) save;

  @override
  State<_TableRecap> createState() => _TableRecapState();
}

class _TableRecapState extends State<_TableRecap> {
  late final Future<Uint8List> _png = widget.render(widget.card);

  Future<void> _share(Uint8List png) async {
    await SharePlus.instance.share(
      ShareParams(
        text: widget.card.shareText,
        subject: AppStrings.shareSubject,
        sharePositionOrigin: shareOrigin(context),
        files: [
          XFile.fromData(
            png,
            mimeType: 'image/png',
            name: widget.card.fileName,
          ),
        ],
      ),
    );
  }

  /// Into the gallery; where that is not possible (iOS, Android before
  /// 10) the share sheet, which can save the image too.
  Future<void> _download(Uint8List png) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await widget.save(png, widget.card.fileName)) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.monthEndSaved)),
      );
    } else if (mounted) {
      await _share(png);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = widget.card.me;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          AppStrings.rankedModeTitle(widget.card.math),
          style: theme.textTheme.titleLarge,
        ),
        Text(
          AppStrings.monthEndPlace(me.rank, widget.table.players),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        FutureBuilder<Uint8List>(
          future: _png,
          builder: (context, snapshot) {
            final png = snapshot.data;
            final height = MediaQuery.sizeOf(context).height * 0.5;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: height,
                  child: Center(
                    child: png == null
                        ? const CircularProgressIndicator()
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              png,
                              semanticLabel: widget.card.shareText,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: png == null ? null : () => _download(png),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text(AppStrings.monthEndDownload),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: png == null ? null : () => _share(png),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text(AppStrings.share),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(AppStrings.monthEndTop, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final row in widget.table.top.take(10))
          RankedRowTile(row: row, me: row.rank == me.rank),
        const SizedBox(height: 24),
      ],
    );
  }
}
