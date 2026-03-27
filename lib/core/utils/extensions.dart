import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'result.dart';

// ── BuildContext extensions ───────────────────────────────────────────────────

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? colors.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

// ── AsyncValue extensions ─────────────────────────────────────────────────────

extension AsyncValueX<T> on AsyncValue<T> {
  /// Returns the data value or null without throwing.
  T? get valueOrNull => whenOrNull(data: (v) => v);

  bool get isLoading => this is AsyncLoading;
  bool get hasError => this is AsyncError;
}

// ── Result extensions ─────────────────────────────────────────────────────────

extension ResultX<T> on Result<T> {
  /// Converts to [AsyncValue] for direct use with Riverpod widgets.
  AsyncValue<T> toAsyncValue() => switch (this) {
        Success(:final value) => AsyncValue.data(value),
        Failure(:final failure) =>
          AsyncValue.error(failure, StackTrace.current),
      };
}

// ── DateTime extensions ───────────────────────────────────────────────────────

extension DateTimeX on DateTime {
  String toIso() => toIso8601String();

  String toDisplayDate() {
    return '$day/${month.toString().padLeft(2, '0')}/$year';
  }

  String toDisplayDateTime() {
    return '${toDisplayDate()} '
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}

// ── String extensions ─────────────────────────────────────────────────────────

extension StringX on String {
  DateTime toDateTime() => DateTime.parse(this);
  bool get isBlank => trim().isEmpty;
}
