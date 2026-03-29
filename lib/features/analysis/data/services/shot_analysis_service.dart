import 'dart:math' as math;

import '../../../../core/utils/logger.dart';
import '../../domain/entities/shot_pattern.dart';

/// Pure-computation service that analyses a set of shot positions.
///
/// All methods are synchronous and free of side effects.  No I/O is performed;
/// the class may be instantiated as a `const` singleton.
///
/// ## Coordinate system
/// The origin (0, 0) represents the target centre.
/// Positive x → right, positive y → down (image / screen convention).
/// [angleDeg] therefore matches standard atan2 with no axis inversion.
///
/// ## Algorithm overview
/// 1. Compute per-shot: dx, dy, distance, angle, clock hour.
/// 2. Compute variance of dx values and dy values separately.
/// 3. Classify pattern:
///    - `horizontal` if varianceX / varianceY > [_kVarianceRatioThreshold]
///    - `vertical`   if varianceY / varianceX > [_kVarianceRatioThreshold]
///    - `bifocal`    if k-means(k=2) produces well-separated clusters
///    - `scattered`  otherwise
/// 4. Compute circular mean of all shot angles.
/// 5. Map mean clock hour to a [ShooterError].
class ShotAnalysisService {
  const ShotAnalysisService();

  // ── Tuning constants ────────────────────────────────────────────────────────

  /// Variance ratio required for horizontal / vertical classification.
  static const double _kVarianceRatioThreshold = 3.0;

  /// Minimum inter-cluster / mean-intra-cluster distance ratio for bifocal.
  static const double _kBifocalSeparationRatio = 1.5;

  /// Each cluster must contain at least this many shots for bifocal to apply.
  static const int _kMinClusterSize = 2;

  /// Number of k-means restarts — best (lowest inertia) run is kept.
  static const int _kKMeansRestarts = 5;

  /// Maximum iterations per k-means run.
  static const int _kKMeansMaxIter = 100;

  /// Convergence threshold: centroid shift in coordinate units.
  static const double _kKMeansConvergence = 1e-4;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Analyses [shots] relative to [center] and returns a [ShotPattern].
  ///
  /// Returns [ShotPattern.empty] when [shots] is empty.
  /// Returns a `scattered` pattern with metrics when only 1 shot is provided.
  ShotPattern analyse({
    required ShotPoint center,
    required List<ShotPoint> shots,
  }) {
    if (shots.isEmpty) {
      AppLogger.d('ShotAnalysisService: no shots — returning empty pattern.');
      return const ShotPattern.empty();
    }

    AppLogger.i('ShotAnalysisService: analysing ${shots.length} shots.');

    // ── 1. Per-shot metrics ───────────────────────────────────────────────────
    final analysed = shots
        .map((s) => _computeShotMetrics(s, center))
        .toList(growable: false);

    // ── 2. Variance ───────────────────────────────────────────────────────────
    final (varX, varY) = _computeVariances(analysed);

    AppLogger.d('Variance X=${varX.toStringAsFixed(4)}, '
        'Y=${varY.toStringAsFixed(4)}');

    // ── 3. Pattern ────────────────────────────────────────────────────────────
    final (pattern, clusters) = _classifyPattern(analysed, varX, varY);

    AppLogger.i('Pattern classified: ${pattern.name}');

    // ── 4. Mean direction ─────────────────────────────────────────────────────
    int? meanClock;
    ShooterError? error;

    if (analysed.length >= 2) {
      final meanAngle =
          _circularMeanDeg(analysed.map((s) => s.angleDeg).toList());
      meanClock = _angleToClock(meanAngle);
      error = _mapError(meanClock);

      AppLogger.d(
        'Mean angle: ${meanAngle.toStringAsFixed(1)}° → '
        '$meanClock o\'clock → ${error?.name ?? 'no error'}',
      );
    }

    return ShotPattern(
      shots: analysed,
      pattern: pattern,
      varianceX: varX,
      varianceY: varY,
      meanClockHour: meanClock,
      error: error,
      clusters: clusters,
    );
  }

  // ── Step 1: per-shot metrics ─────────────────────────────────────────────────

  AnalysedShot _computeShotMetrics(ShotPoint shot, ShotPoint center) {
    final dx = shot.x - center.x;
    final dy = shot.y - center.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final angleDeg = math.atan2(dy, dx) * (180.0 / math.pi);
    final clockHour = _angleToClock(angleDeg);

    return AnalysedShot(
      x: shot.x,
      y: shot.y,
      dx: dx,
      dy: dy,
      distance: distance,
      angleDeg: angleDeg,
      clockHour: clockHour,
    );
  }

  // ── Step 2: variance ──────────────────────────────────────────────────────────

  /// Returns (varianceX, varianceY) of the shot dx / dy populations.
  (double, double) _computeVariances(List<AnalysedShot> shots) {
    if (shots.length < 2) return (0.0, 0.0);

    final n = shots.length.toDouble();

    final meanDx = shots.fold(0.0, (s, a) => s + a.dx) / n;
    final meanDy = shots.fold(0.0, (s, a) => s + a.dy) / n;

    final varX = shots.fold(0.0, (s, a) {
          final d = a.dx - meanDx;
          return s + d * d;
        }) /
        n;

    final varY = shots.fold(0.0, (s, a) {
          final d = a.dy - meanDy;
          return s + d * d;
        }) /
        n;

    return (varX, varY);
  }

  // ── Step 3: pattern classification ───────────────────────────────────────────

  (PatternType, List<ClusterInfo>?) _classifyPattern(
    List<AnalysedShot> shots,
    double varX,
    double varY,
  ) {
    // Need at least 2 shots to classify meaningfully.
    if (shots.length < 2) return (PatternType.scattered, null);

    // ── Axis dominance check ──────────────────────────────────────────────────
    final safeVarY = varY < 1e-9 ? 1e-9 : varY;
    final safeVarX = varX < 1e-9 ? 1e-9 : varX;

    if (varX / safeVarY > _kVarianceRatioThreshold) {
      return (PatternType.horizontal, null);
    }
    if (varY / safeVarX > _kVarianceRatioThreshold) {
      return (PatternType.vertical, null);
    }

    // ── K-means clustering (k = 2) ────────────────────────────────────────────
    // Only meaningful when we have enough shots.
    if (shots.length >= _kMinClusterSize * 2) {
      final points = shots
          .map((s) => _Vec2(s.dx, s.dy))
          .toList(growable: false);

      final rawClusters = _bestKMeans(points, k: 2);

      if (_isBifocal(rawClusters)) {
        final clusterInfos = rawClusters.asMap().entries.map((entry) {
          final idx = entry.key;
          final c = entry.value;
          final cx = c.centroid.x;
          final cy = c.centroid.y;
          final centAngle = math.atan2(cy, cx) * (180.0 / math.pi);
          final meanR = c.points.isEmpty
              ? 0.0
              : c.points.fold(0.0, (s, p) {
                    final ddx = p.x - cx;
                    final ddy = p.y - cy;
                    return s + math.sqrt(ddx * ddx + ddy * ddy);
                  }) /
                  c.points.length;

          return ClusterInfo(
            index: idx,
            centroidX: cx,
            centroidY: cy,
            centroidClockHour: _angleToClock(centAngle),
            shotCount: c.points.length,
            meanRadius: meanR,
          );
        }).toList();

        return (PatternType.bifocal, clusterInfos);
      }
    }

    return (PatternType.scattered, null);
  }

  // ── Step 4: circular mean ─────────────────────────────────────────────────────

  /// Computes the circular (angular) mean of [anglesDeg].
  ///
  /// Uses the unit-vector approach to handle the 360°→0° wrap correctly:
  ///   mean = atan2(Σsin(θ), Σcos(θ))
  double _circularMeanDeg(List<double> anglesDeg) {
    assert(anglesDeg.isNotEmpty);

    var sinSum = 0.0;
    var cosSum = 0.0;

    for (final deg in anglesDeg) {
      final rad = deg * math.pi / 180.0;
      sinSum += math.sin(rad);
      cosSum += math.cos(rad);
    }

    return math.atan2(sinSum, cosSum) * 180.0 / math.pi;
  }

  // ── Angle → clock hour ────────────────────────────────────────────────────────

  /// Maps [angleDeg] (atan2 convention: 0° = right) to a clock hour [1–12].
  ///
  /// Mapping (image coords, y-down):
  /// ```
  ///   0°  = right = 3 o'clock
  ///  90°  = down  = 6 o'clock
  /// 180°  = left  = 9 o'clock
  /// −90°  = up    = 12 o'clock
  /// ```
  ///
  /// Formula: normalize to [0°, 360°), then
  ///   raw  = (normalized / 30.0 + 3.0) % 12.0
  ///   hour = round(raw); if hour == 0 → 12
  int _angleToClock(double angleDeg) {
    final normalized = ((angleDeg % 360.0) + 360.0) % 360.0;
    final raw = (normalized / 30.0 + 3.0) % 12.0;
    final hour = raw.round();
    return hour == 0 ? 12 : hour;
  }

  // ── Step 5: error mapping ─────────────────────────────────────────────────────

  /// Maps a clock hour to a [ShooterError], or null if not diagnostic.
  ///
  /// | Hours  | Error  | Cause                              |
  /// |--------|--------|------------------------------------|
  /// | 3–5    | jerk   | Trigger finger pulling inward      |
  /// | 6–8    | buck   | Anticipating recoil (heeling)      |
  /// | 10–12  | flinch | Involuntary flinch before break    |
  /// | 1,2,9  | —      | Not categorised                    |
  ShooterError? _mapError(int clockHour) => switch (clockHour) {
        3 || 4 || 5 => ShooterError.jerk,
        6 || 7 || 8 => ShooterError.buck,
        10 || 11 || 12 => ShooterError.flinch,
        _ => null,
      };

  // ── K-means engine ────────────────────────────────────────────────────────────

  /// Runs k-means [_kKMeansRestarts] times and returns the solution with the
  /// lowest inertia (sum of squared distances to cluster centroid).
  List<_Cluster> _bestKMeans(List<_Vec2> points, {required int k}) {
    List<_Cluster>? best;
    var bestInertia = double.infinity;

    for (var attempt = 0; attempt < _kKMeansRestarts; attempt++) {
      // Deterministic but varied seeds: avoids non-reproducible results while
      // still exploring different initialisation orderings.
      final rng = math.Random(attempt * 31337 + points.length);
      final clusters = _runKMeans(points, k: k, rng: rng);
      final inertia = _inertia(clusters);

      if (inertia < bestInertia) {
        bestInertia = inertia;
        best = clusters;
      }
    }

    return best!;
  }

  /// Single k-means run with k-means++ initialisation.
  List<_Cluster> _runKMeans(
    List<_Vec2> points, {
    required int k,
    required math.Random rng,
  }) {
    // ── K-means++ initialisation ──────────────────────────────────────────────
    var centroids = _kMeansPlusPlusInit(points, k: k, rng: rng);

    // Assignment lists — reused across iterations.
    final assignments = List.generate(k, (_) => <_Vec2>[]);

    for (var iter = 0; iter < _kKMeansMaxIter; iter++) {
      // ── Assign ───────────────────────────────────────────────────────────
      for (final list in assignments) {
        list.clear();
      }
      for (final p in points) {
        assignments[_nearestCentroidIndex(p, centroids)].add(p);
      }

      // ── Recalculate centroids ─────────────────────────────────────────────
      final newCentroids = List<_Vec2>.generate(k, (i) {
        final group = assignments[i];
        if (group.isEmpty) return centroids[i]; // keep old centroid
        return _Vec2(
          group.fold(0.0, (s, p) => s + p.x) / group.length,
          group.fold(0.0, (s, p) => s + p.y) / group.length,
        );
      });

      // ── Convergence check ─────────────────────────────────────────────────
      var maxShift = 0.0;
      for (var i = 0; i < k; i++) {
        maxShift = math.max(maxShift, _dist(centroids[i], newCentroids[i]));
      }
      centroids = newCentroids;
      if (maxShift < _kKMeansConvergence) break;
    }

    return List.generate(
      k,
      (i) => _Cluster(points: List.unmodifiable(assignments[i]),
          centroid: centroids[i]),
    );
  }

  /// K-means++ centroid seeding.
  ///
  /// 1. Pick first centroid uniformly at random.
  /// 2. For each subsequent centroid, pick a point with probability
  ///    proportional to D(x)² — its squared distance to the nearest
  ///    already-chosen centroid.  This biases selection toward distant points.
  List<_Vec2> _kMeansPlusPlusInit(
    List<_Vec2> points, {
    required int k,
    required math.Random rng,
  }) {
    final centroids = <_Vec2>[points[rng.nextInt(points.length)]];

    while (centroids.length < k) {
      // Squared distances to nearest centroid.
      final weights = points.map((p) {
        final nearest = centroids
            .map((c) => _dist(p, c))
            .reduce(math.min);
        return nearest * nearest;
      }).toList(growable: false);

      final total = weights.fold(0.0, (s, w) => s + w);

      // Handle degenerate case (all points coincide).
      if (total < 1e-12) {
        centroids.add(points[rng.nextInt(points.length)]);
        continue;
      }

      // Weighted random pick.
      var r = rng.nextDouble() * total;
      var chosen = points.last;
      for (var i = 0; i < points.length; i++) {
        r -= weights[i];
        if (r <= 0) {
          chosen = points[i];
          break;
        }
      }
      centroids.add(chosen);
    }

    return centroids;
  }

  // ── Bifocal quality gate ──────────────────────────────────────────────────────

  /// Returns true when the two clusters are well-separated.
  ///
  /// Criterion: inter-centroid distance ≥ [_kBifocalSeparationRatio] ×
  /// mean intra-cluster spread.
  bool _isBifocal(List<_Cluster> clusters) {
    assert(clusters.length == 2);
    final a = clusters[0];
    final b = clusters[1];

    if (a.points.length < _kMinClusterSize ||
        b.points.length < _kMinClusterSize) {
      return false;
    }

    final interDist = _dist(a.centroid, b.centroid);
    final intraA = _meanIntra(a);
    final intraB = _meanIntra(b);
    final avgIntra = (intraA + intraB) / 2.0;

    // If both clusters are tight single points, they're bifocal only if
    // they are meaningfully separated.
    if (avgIntra < 1e-9) return interDist > 1e-9;

    return (interDist / avgIntra) >= _kBifocalSeparationRatio;
  }

  // ── Private math helpers ──────────────────────────────────────────────────────

  double _dist(_Vec2 a, _Vec2 b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  int _nearestCentroidIndex(_Vec2 point, List<_Vec2> centroids) {
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < centroids.length; i++) {
      final d = _dist(point, centroids[i]);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  /// Sum of squared distances from each point to its cluster centroid.
  double _inertia(List<_Cluster> clusters) => clusters.fold(0.0, (s, c) {
        return s +
            c.points.fold(0.0, (cs, p) {
              final d = _dist(p, c.centroid);
              return cs + d * d;
            });
      });

  /// Mean distance from each point in [c] to its centroid.
  double _meanIntra(_Cluster c) {
    if (c.points.isEmpty) return 0.0;
    return c.points.fold(0.0, (s, p) => s + _dist(p, c.centroid)) /
        c.points.length;
  }
}

// ── Private data types ────────────────────────────────────────────────────────

/// Immutable 2-D vector used internally by the k-means engine.
final class _Vec2 {
  const _Vec2(this.x, this.y);
  final double x;
  final double y;
}

/// One k-means cluster.
final class _Cluster {
  const _Cluster({required this.points, required this.centroid});
  final List<_Vec2> points;
  final _Vec2 centroid;
}
