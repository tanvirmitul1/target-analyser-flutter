import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/async_value_widget.dart';
import '../../../../core/utils/extensions.dart';
import '../../../analysis/presentation/screens/analysis_screen.dart';
import '../providers/storage_provider.dart';
import '../widgets/session_list_tile.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: AsyncValueWidget(
        value: sessionsAsync,
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: context.colors.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions yet.\nStart by capturing a target!',
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colors.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sessionListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return SessionListTile(
                  session: session,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AnalysisScreen(sessionId: session.id),
                    ),
                  ),
                  onDelete: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Session'),
                        content: Text(
                          'Delete "${session.name}" and all its shots?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      final result = await ref
                          .read(sessionListProvider.notifier)
                          .removeSession(session.id);
                      result.when(
                        onSuccess: (_) =>
                            context.showSnackBar('Session deleted.'),
                        onFailure: (f) =>
                            context.showSnackBar(f.message, isError: true),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
