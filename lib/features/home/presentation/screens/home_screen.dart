import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../camera/presentation/screens/camera_screen.dart';
import '../../../storage/presentation/providers/storage_provider.dart';
import '../../../storage/presentation/screens/history_screen.dart';
import '../providers/home_provider.dart';
import '../widgets/home_action_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Analyser'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Session History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats summary
            sessionsAsync.whenOrNull(
                  data: (sessions) => _SummaryBanner(
                    sessionCount: sessions.length,
                    totalShots: sessions.fold(0, (s, e) => s + e.totalShots),
                  ),
                ) ??
                const SizedBox.shrink(),

            const SizedBox(height: 32),

            Text(
              'What would you like to do?',
              style: context.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  HomeActionButton(
                    icon: Icons.add_a_photo_outlined,
                    label: 'New Session',
                    onTap: () => _showNewSessionDialog(context, ref),
                  ),
                  HomeActionButton(
                    icon: Icons.history,
                    label: 'History',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const HistoryScreen()),
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

  Future<void> _showNewSessionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Session'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Session name *',
                  hintText: 'e.g. Morning practice',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(homeProvider.notifier).createSession(
          name: nameController.text.trim(),
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );

    if (!context.mounted) return;

    result.when(
      onSuccess: (sessionId) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CameraScreen(sessionId: sessionId),
        ),
      ),
      onFailure: (f) => context.showSnackBar(f.message, isError: true),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.sessionCount,
    required this.totalShots,
  });

  final int sessionCount;
  final int totalShots;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BannerStat(label: 'Sessions', value: sessionCount.toString()),
            _BannerStat(label: 'Total Shots', value: totalShots.toString()),
          ],
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colors.primary,
          ),
        ),
        Text(label, style: context.textTheme.labelMedium),
      ],
    );
  }
}
