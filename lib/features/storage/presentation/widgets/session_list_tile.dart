import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';
import '../../domain/entities/session.dart';

class SessionListTile extends StatelessWidget {
  const SessionListTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Session session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        child: Text(
          session.totalShots.toString(),
          style: TextStyle(color: colors.onPrimaryContainer),
        ),
      ),
      title: Text(session.name),
      subtitle: Text(session.date.toDisplayDate()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScoreBadge(score: session.totalScore),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete session',
            color: colors.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colors.onSecondaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
