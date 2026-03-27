import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';
import '../../domain/entities/shot_result.dart';

class AnalysisResultCard extends StatelessWidget {
  const AnalysisResultCard({required this.shot, super.key});
  final ShotResult shot;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(context, shot.score);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _ScoreCircle(score: shot.score, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shot.isBullseye ? 'Bullseye! (X)' : 'Ring ${shot.ring}',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Offset: (${shot.offsetX.toStringAsFixed(2)}, '
                    '${shot.offsetY.toStringAsFixed(2)})',
                    style: context.textTheme.bodySmall,
                  ),
                  Text(
                    shot.timestamp.toDisplayDateTime(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.outline,
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

  Color _scoreColor(BuildContext context, double score) {
    if (score >= 10) return Colors.amber;
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    return context.colors.error;
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.score, required this.color});
  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: Text(
        score >= 10.5 ? 'X' : score.toStringAsFixed(1),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
