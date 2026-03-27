import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../data/datasources/soldier_local_datasource.dart';
import '../../data/repositories/soldier_repository_impl.dart';
import '../../domain/entities/shot_record.dart';
import '../../domain/entities/soldier.dart';
import '../../domain/repositories/soldier_repository.dart';
import '../../domain/usecases/get_shot_history_usecase.dart';
import '../../domain/usecases/save_shot_records_usecase.dart';
import '../../domain/usecases/upsert_soldier_usecase.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final soldierLocalDatasourceProvider = Provider<SoldierLocalDatasource>(
  (ref) => const SoldierLocalDatasource(),
);

final soldierRepositoryProvider = Provider<SoldierRepository>(
  (ref) =>
      SoldierRepositoryImpl(ref.watch(soldierLocalDatasourceProvider)),
);

// ── Use-case providers ────────────────────────────────────────────────────────

final upsertSoldierUseCaseProvider = Provider<UpsertSoldierUseCase>(
  (ref) => UpsertSoldierUseCase(ref.watch(soldierRepositoryProvider)),
);

final saveShotRecordsUseCaseProvider = Provider<SaveShotRecordsUseCase>(
  (ref) => SaveShotRecordsUseCase(ref.watch(soldierRepositoryProvider)),
);

final getShotHistoryUseCaseProvider = Provider<GetShotHistoryUseCase>(
  (ref) => GetShotHistoryUseCase(ref.watch(soldierRepositoryProvider)),
);

// ── Soldier list notifier ─────────────────────────────────────────────────────

/// Manages the full list of soldiers stored in the database.
///
/// Use [upsert] to add or update a soldier (creates the row if absent).
/// Use [delete] to remove a soldier and cascade-delete all their shots.
class SoldierListNotifier extends AsyncNotifier<List<Soldier>> {
  @override
  Future<List<Soldier>> build() => _fetchAll();

  Future<List<Soldier>> _fetchAll() async {
    final result =
        await ref.read(soldierRepositoryProvider).getAllSoldiers();
    return result.when(
      onSuccess: (soldiers) => soldiers,
      onFailure: (f) => throw Exception(f.message),
    );
  }

  Future<Result<void>> upsert(Soldier soldier) async {
    final result =
        await ref.read(upsertSoldierUseCaseProvider)(soldier);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> delete(String soldierId) async {
    final result =
        await ref.read(soldierRepositoryProvider).deleteSoldier(soldierId);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }
}

final soldierListProvider =
    AsyncNotifierProvider<SoldierListNotifier, List<Soldier>>(
  SoldierListNotifier.new,
);

// ── Single soldier provider ───────────────────────────────────────────────────

/// Resolves a single [Soldier] by [id] from the already-loaded list.
///
/// Returns `null` when no matching soldier is found.
final soldierByIdProvider =
    FutureProvider.family<Soldier?, String>((ref, id) async {
  final soldiers = await ref.watch(soldierListProvider.future);
  try {
    return soldiers.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});

// ── Shot history notifier ─────────────────────────────────────────────────────

/// State for a paginated shot-history view for one soldier.
class ShotHistoryState {
  const ShotHistoryState({
    required this.records,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<ShotRecord> records;
  final bool hasMore;
  final bool isLoadingMore;

  ShotHistoryState copyWith({
    List<ShotRecord>? records,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      ShotHistoryState(
        records: records ?? this.records,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

const _kPageSize = 50;

/// Loads and paginates shot history for a single soldier.
///
/// ```dart
/// final notifier = ref.read(shotHistoryProvider('S001').notifier);
/// await notifier.loadMore();
/// await notifier.saveShotRecords([record1, record2]);
/// await notifier.clearAll();
/// ```
class ShotHistoryNotifier
    extends FamilyAsyncNotifier<ShotHistoryState, String> {
  @override
  Future<ShotHistoryState> build(String arg) => _loadPage(offset: 0);

  String get _soldierId => arg;

  Future<ShotHistoryState> _loadPage({required int offset}) async {
    final result = await ref.read(getShotHistoryUseCaseProvider)(
      ShotHistoryQuery(
        soldierId: _soldierId,
        limit: _kPageSize,
        offset: offset,
      ),
    );
    final records = result.when(
      onSuccess: (r) => r,
      onFailure: (f) => throw Exception(f.message),
    );
    return ShotHistoryState(
      records: records,
      hasMore: records.length == _kPageSize,
    );
  }

  /// Appends the next page to the existing list.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final result = await ref.read(getShotHistoryUseCaseProvider)(
      ShotHistoryQuery(
        soldierId: _soldierId,
        limit: _kPageSize,
        offset: current.records.length,
      ),
    );

    result.when(
      onSuccess: (more) {
        final merged = [...current.records, ...more];
        state = AsyncData(ShotHistoryState(
          records: merged,
          hasMore: more.length == _kPageSize,
        ));
      },
      onFailure: (f) {
        // Restore previous state without the loading flag on error.
        state = AsyncData(current.copyWith(isLoadingMore: false));
      },
    );
  }

  /// Persists [records] and prepends them to the top of the list (newest first).
  Future<Result<List<int>>> saveShotRecords(
    List<ShotRecord> records,
  ) async {
    final result =
        await ref.read(saveShotRecordsUseCaseProvider)(records);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  /// Deletes all shots for this soldier and resets the list.
  Future<Result<void>> clearAll() async {
    final result = await ref
        .read(soldierRepositoryProvider)
        .clearHistory(_soldierId);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }
}

final shotHistoryProvider = AsyncNotifierProvider.family<ShotHistoryNotifier,
    ShotHistoryState, String>(
  ShotHistoryNotifier.new,
);

// ── Shot count provider ───────────────────────────────────────────────────────

/// Total number of shots stored for a given soldier id.
///
/// Re-evaluated whenever [shotHistoryProvider] for the same soldier invalidates.
final shotCountProvider =
    FutureProvider.family<int, String>((ref, soldierId) async {
  // Depend on history so count refreshes after saves / clears.
  ref.watch(shotHistoryProvider(soldierId));
  final result =
      await ref.read(soldierRepositoryProvider).countShots(soldierId);
  return result.when(
    onSuccess: (n) => n,
    onFailure: (f) => throw Exception(f.message),
  );
});
