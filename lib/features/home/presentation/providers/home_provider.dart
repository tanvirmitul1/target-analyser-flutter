import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/result.dart';
import '../../../storage/domain/entities/session.dart';
import '../../../storage/presentation/providers/storage_provider.dart';

class HomeNotifier extends Notifier<void> {
  static const _uuid = Uuid();

  @override
  void build() {}

  /// Creates a new session and returns its [id] on success.
  Future<Result<String>> createSession({
    required String name,
    String? notes,
  }) async {
    final session = Session(
      id: _uuid.v4(),
      name: name,
      date: DateTime.now(),
      createdAt: DateTime.now(),
      notes: notes,
    );

    return ref.read(sessionListProvider.notifier).addSession(session);
  }
}

final homeProvider = NotifierProvider<HomeNotifier, void>(HomeNotifier.new);
