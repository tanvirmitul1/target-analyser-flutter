import 'package:equatable/equatable.dart';

// ── Input types ───────────────────────────────────────────────────────────────

/// Named record used as a lightweight 2-D coordinate throughout the analysis
/// domain.  Prefer this over Flutter's [Offset] to keep domain code framework
/// free.
typedef ShotPoint = ({double x, double y});

// ── Output enumerations ───────────────────────────────────────────────────────

/// Spatial grouping of shots around the aiming point.
enum PatternType {
  /// Shots form a horizontal band: variance_x >> variance_y.
  horizontal,

  /// Shots form a vertical band: variance_y >> variance_x.
  vertical,

  /// Shots cluster around two distinct aiming regions (detected via k-means).
  bifocal,

  /// No dominant axis or sub-grouping — shots are spread randomly.
  scattered,
}

/// Common shooter errors inferred from the mean clock-hour of the shot group.
enum ShooterError {
  /// Shots at 3–5 o'clock: trigger finger pulling inward.
  jerk,

  /// Shots at 6–8 o'clock: anticipating recoil (heeling/bucking).
  buck,

  /// Shots at 10–12 o'clock: involuntary flinch before break.
  flinch,
}

// ── Per-shot metrics ──────────────────────────────────────────────────────────

/// One shot enriched with computed geometric metrics.
class AnalysedShot extends Equatable {
  const AnalysedShot({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.distance,
    required this.angleDeg,
    required this.clockHour,
  });

  /// Original shot coordinates (same system as input center).
  final double x;
  final double y;

  /// Signed offset from target center (positive x = right, positive y = down).
  final double dx;
  final double dy;

  /// Euclidean distance from center: sqrt(dx² + dy²).
  final double distance;

  /// Angle in degrees from +x axis (atan2(dy, dx)), range [−180, 180].
  ///
  /// 0° = 3 o'clock, 90° = 6 o'clock, −90° = 12 o'clock.
  final double angleDeg;

  /// Clock-face hour [1-12] corresponding to [angleDeg].
  final int clockHour;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'dx': dx,
        'dy': dy,
        'distance': distance,
        'angle_deg': angleDeg,
        'clock_hour': clockHour,
      };

  @override
  List<Object?> get props => [x, y, dx, dy, distance, angleDeg, clockHour];
}

// ── Cluster (bifocal) ─────────────────────────────────────────────────────────

/// One of the two k-means clusters produced during [PatternType.bifocal]
/// classification.
class ClusterInfo extends Equatable {
  const ClusterInfo({
    required this.index,
    required this.centroidX,
    required this.centroidY,
    required this.centroidClockHour,
    required this.shotCount,
    required this.meanRadius,
  });

  /// Cluster index (0 or 1).
  final int index;

  /// Geometric centroid of this cluster.
  final double centroidX;
  final double centroidY;

  /// Clock hour of the centroid direction.
  final int centroidClockHour;

  final int shotCount;

  /// Mean distance from each shot in this cluster to its centroid.
  final double meanRadius;

  Map<String, dynamic> toJson() => {
        'index': index,
        'centroid': {'x': centroidX, 'y': centroidY},
        'centroid_clock_hour': centroidClockHour,
        'shot_count': shotCount,
        'mean_radius': meanRadius,
      };

  @override
  List<Object?> get props =>
      [index, centroidX, centroidY, centroidClockHour, shotCount, meanRadius];
}

// ── Main result ───────────────────────────────────────────────────────────────

/// Full output of [ShotAnalysisService.analyse].
///
/// Serialises to the agreed JSON schema:
/// ```json
/// {
///   "shots":   [ { "dx": …, "dy": …, "distance": …, "angle_deg": …,
///                 "clock_hour": …, "x": …, "y": … } ],
///   "pattern": "horizontal",
///   "error":   "jerk"          // or null
/// }
/// ```
class ShotPattern extends Equatable {
  const ShotPattern({
    required this.shots,
    required this.pattern,
    required this.varianceX,
    required this.varianceY,
    this.error,
    this.meanClockHour,
    this.clusters,
  });

  /// Enriched shot list (same order as input).
  final List<AnalysedShot> shots;

  final PatternType pattern;

  /// Identified shooter error, or null if direction is not diagnostic.
  final ShooterError? error;

  /// Clock hour of the circular mean angle (null when < 2 shots).
  final int? meanClockHour;

  /// Variance of shot x-coordinates around their mean.
  final double varianceX;

  /// Variance of shot y-coordinates around their mean.
  final double varianceY;

  /// Populated only when [pattern] == [PatternType.bifocal].
  final List<ClusterInfo>? clusters;

  bool get hasError => error != null;
  bool get isBifocal => pattern == PatternType.bifocal;

  // ── Factory ────────────────────────────────────────────────────────────────

  const ShotPattern.empty()
      : shots = const [],
        pattern = PatternType.scattered,
        varianceX = 0,
        varianceY = 0,
        error = null,
        meanClockHour = null,
        clusters = null;

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'shots': shots.map((s) => s.toJson()).toList(),
        'pattern': pattern.name,
        'error': error?.name,
        // Extra fields for debugging / UI — not part of the minimal spec.
        'mean_clock_hour': meanClockHour,
        'variance_x': varianceX,
        'variance_y': varianceY,
        if (clusters != null)
          'clusters': clusters!.map((c) => c.toJson()).toList(),
      };

  @override
  List<Object?> get props =>
      [shots, pattern, error, meanClockHour, varianceX, varianceY, clusters];
}
