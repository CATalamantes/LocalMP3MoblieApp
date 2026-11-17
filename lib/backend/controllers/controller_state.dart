import 'dart:math';

import 'package:flutter/foundation.dart';

import '../services/database/local_music_repository.dart';

enum ControllerStatus { idle, loading, success, empty, error }

enum ControllerFailureKind {
  invalidInput,
  notFound,
  storage,
  unavailable,
  disposed,
}

class ControllerFailure implements Exception {
  const ControllerFailure(this.kind, this.message);
  final ControllerFailureKind kind;
  final String message;
  @override
  String toString() => 'ControllerFailure(${kind.name}: $message)';
}

class ControllerState<T> {
  const ControllerState(this.data, this.status, {this.error});
  final T data;
  final ControllerStatus status;
  final ControllerFailure? error;
}

class ControllerResult<T, R> {
  const ControllerResult(this.data, this.value);
  final T data;
  final R value;
}

/// Generation guards cover success, failure and loading cleanup. Writes are
/// serialized, but a superseded write may still commit: only publication is
/// suppressed. An already-running SQLite transaction is never half-cancelled.
abstract class MusicController<T> extends ChangeNotifier {
  MusicController(T initial)
    : _state = ControllerState(initial, ControllerStatus.idle);
  ControllerState<T> _state;
  ControllerState<T> get state => _state;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _writes = Future<void>.value();

  bool isEmpty(T data);
  T prepareData(T data) => data;
  ControllerFailure? failureForData(T data) => null;
  T prepareErrorData(T data, ControllerFailure failure) => data;
  ControllerFailure mapFailure(Object error) => error is ControllerFailure
      ? error
      : error is MusicRecordNotFound
      ? ControllerFailure(
          ControllerFailureKind.notFound,
          '${error.entity} not found',
        )
      : const ControllerFailure(
          ControllerFailureKind.storage,
          'The local data operation failed',
        );

  /// Engine events update data without changing the active command generation
  /// or clearing a newer loading/error status. Late events after disposal drop.
  @protected
  void publishEventData(T data, {ControllerFailure? failure}) {
    if (_disposed) return;
    _state = ControllerState(
      data,
      failure == null ? state.status : ControllerStatus.error,
      error: failure ?? state.error,
    );
    notifyListeners();
  }

  void ensureActive() {
    if (_disposed) {
      throw const ControllerFailure(
        ControllerFailureKind.disposed,
        'Controller is disposed',
      );
    }
  }

  void changeData(T data, {bool invalidatePending = true}) {
    ensureActive();
    if (invalidatePending) ++_generation;
    _state = ControllerState(
      data,
      isEmpty(data) ? ControllerStatus.empty : ControllerStatus.success,
    );
    notifyListeners();
  }

  Future<R> execute<R>(
    Future<ControllerResult<T, R>> Function() action, {
    bool mutation = false,
  }) async {
    ensureActive();
    final generation = ++_generation;
    _state = ControllerState(state.data, ControllerStatus.loading);
    notifyListeners();
    try {
      Future<ControllerResult<T, R>> invoke() {
        ensureActive();
        return Future.sync(action);
      }

      final Future<ControllerResult<T, R>> work;
      if (mutation) {
        work = _writes.then((_) => invoke());
        _writes = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      } else {
        // Reads following submitted writes see their committed result.
        work = _writes.then((_) => invoke());
      }
      final result = await work;
      if (!_disposed && generation == _generation) {
        final data = prepareData(result.data);
        final failure = failureForData(data);
        _state = ControllerState(
          data,
          failure != null
              ? ControllerStatus.error
              : isEmpty(data)
              ? ControllerStatus.empty
              : ControllerStatus.success,
          error: failure,
        );
        notifyListeners();
      }
      return result.value;
    } catch (error, stack) {
      final failure = mapFailure(error);
      if (!_disposed && generation == _generation) {
        _state = ControllerState(
          prepareErrorData(state.data, failure),
          ControllerStatus.error,
          error: failure,
        );
        notifyListeners();
      }
      Error.throwWithStackTrace(failure, stack);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}

void requireIdentifier(String value) {
  if (value.trim().isEmpty) {
    throw const ControllerFailure(
      ControllerFailureKind.invalidInput,
      'Identifier is required',
    );
  }
}

String requireName(String value) {
  if (value.trim().isEmpty) {
    throw const ControllerFailure(
      ControllerFailureKind.invalidInput,
      'A nonblank name is required',
    );
  }
  return value.trim();
}

String newMusicIdentifier() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
