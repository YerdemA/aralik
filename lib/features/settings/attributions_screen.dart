import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../data/attributions.dart';
import '../../widgets/link_text.dart';

/// "Veri kaynakları ve lisanslar": every source the bank uses, with the
/// credit line and license it asks for.
class AttributionsScreen extends StatefulWidget {
  const AttributionsScreen({super.key, this.load = loadAttributions});

  /// Injectable for tests.
  final Future<List<Attribution>> Function() load;

  @override
  State<AttributionsScreen> createState() => _AttributionsScreenState();
}

class _AttributionsScreenState extends State<AttributionsScreen> {
  late final Future<List<Attribution>> _sources = widget.load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.dataSources)),
      body: SafeArea(
        child: FutureBuilder(
          future: _sources,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text(AppStrings.loadError));
            }
            final sources = snapshot.data;
            if (sources == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  AppStrings.dataSourcesIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final s in sources) ...[
                  _SourceCard(source: s),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source});

  final Attribution source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                source.attribution,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            LinkText(url: source.url),
            const SizedBox(height: 4),
            Text(
              '${AppStrings.license}: ${source.license}',
              style: theme.textTheme.labelLarge,
            ),
            LinkText(url: source.licenseUrl),
          ],
        ),
      ),
    );
  }
}
