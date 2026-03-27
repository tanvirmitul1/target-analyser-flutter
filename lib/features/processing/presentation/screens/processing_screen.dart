import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/async_value_widget.dart';
import '../../../../core/utils/extensions.dart';
import '../../../analysis/presentation/screens/analysis_screen.dart';
import '../providers/processing_provider.dart';

class ProcessingScreen extends ConsumerWidget {
  const ProcessingScreen({
    required this.imagePath,
    required this.sessionId,
    super.key,
  });

  final String imagePath;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processedAsync = ref.watch(processingProvider(imagePath));

    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: AsyncValueWidget(
        value: processedAsync,
        loading: const _ProcessingIndicator(),
        data: (processed) => Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Image.file(File(processed.processedPath)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Shot detected at '
                    '(${processed.shotX.toStringAsFixed(1)}, '
                    '${processed.shotY.toStringAsFixed(1)})',
                    style: context.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => AnalysisScreen(
                          sessionId: sessionId,
                          processedImage: processed,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Analyse Shot'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(processingProvider(imagePath).notifier).retry(imagePath),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.error),
              const SizedBox(height: 12),
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(processingProvider(imagePath).notifier).retry(imagePath),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Analysing target image…',
            style: context.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
