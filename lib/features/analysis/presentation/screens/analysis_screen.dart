import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/extensions.dart';
import '../../../audio/presentation/providers/audio_provider.dart';
import '../../../processing/domain/entities/processed_image.dart';
import '../../../storage/presentation/providers/storage_provider.dart';
import '../providers/analysis_provider.dart';
import '../widgets/analysis_result_card.dart';
import '../widgets/shot_scatter_chart.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({
    required this.sessionId,
    this.processedImage,
    super.key,
  });

  final String sessionId;

  /// Provided when arriving directly from [ProcessingScreen] for a new shot.
  final ProcessedImage? processedImage;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.processedImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runAnalysis());
    }
  }

  Future<void> _runAnalysis() async {
    final result = await ref.read(analysisProvider.notifier).analyseAndSave(
          processedImage: widget.processedImage!,
          sessionId: widget.sessionId,
        );

    if (!mounted) return;

    result.when(
      onSuccess: (shot) {
        ref.read(audioProvider.notifier).playShotFeedback(shot.score);
        context.showSnackBar('Shot scored: ${shot.score}');
      },
      onFailure: (f) => context.showSnackBar(f.message, isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(analysisProvider);
    final sessionAsync = ref.watch(sessionByIdProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
        actions: [
          if (widget.processedImage != null && !analysisState.hasResult)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Processed image
            if (widget.processedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(widget.processedImage!.processedPath),
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),

            // Latest shot result card
            if (analysisState.hasResult) ...[
              const SizedBox(height: 16),
              AnalysisResultCard(shot: analysisState.latestShot!),
            ],

            if (analysisState.error != null) ...[
              const SizedBox(height: 16),
              Text(
                analysisState.error!,
                style: TextStyle(color: context.colors.error),
              ),
            ],

            // Session scatter chart
            const SizedBox(height: 24),
            Text('Session Shots', style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            sessionAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(e.toString()),
              data: (session) {
                if (session == null || session.shots.isEmpty) {
                  return const Text('No shots recorded yet.');
                }
                return Column(
                  children: [
                    ShotScatterChart(shots: session.shots),
                    const SizedBox(height: 12),
                    _SessionStats(session: session),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.session});
  final dynamic session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(label: 'Shots', value: session.totalShots.toString()),
            _Stat(
              label: 'Avg Score',
              value: session.averageScore.toStringAsFixed(1),
            ),
            _Stat(
              label: 'Total',
              value: session.totalScore.toStringAsFixed(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colors.primary,
          ),
        ),
        Text(label, style: context.textTheme.labelSmall),
      ],
    );
  }
}

// Suppress unused import lint — AppConstants is available for future expansion.
// ignore: unused_import
const _maxShots = AppConstants.maxShotsPerSession;
