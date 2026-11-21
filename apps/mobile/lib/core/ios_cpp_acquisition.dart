import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool get supportsIosCppAcquisition =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// A CPP supplies a static marketing URL, not a receipt or an install referrer.
/// Uri canonicalizes equivalent scheme/host spellings before this boundary.
String? iosCppVariant(Uri uri) =>
    uri.toString() == 'io.dopmi.app://acquire/personal-a' ? 'personal-a' : null;

enum IosCppClaimResult { recorded, alreadyRecorded, ineligible, consentChanged }

class IosCppAcquisition {
  IosCppAcquisition(
    this.preferences,
    this.namespace, {
    this.now = DateTime.now,
    bool? supported,
  }) : supported = supported ?? supportsIosCppAcquisition;

  final SharedPreferences preferences;
  final String namespace;
  final DateTime Function() now;
  final bool supported;

  Future<void> _pending = Future.value();
  String? _currentOwner;
  bool _ownerObserved = false;
  bool _terminal = false;
  bool _terminalCleanupPending = false;
  bool _storageUnsafe = false;
  _PendingCpp? _receiptCandidate;
  _PendingCpp? _ownerReservation;
  bool _bindingNeedsFence = false;
  bool _bindingDurable = false;
  int _generation = 0;
  final _revokedOwners = <String>{};

  String get _pendingKey => 'dopmi.$namespace.ios_cpp.v1.pending';
  String get _seenKey => 'dopmi.$namespace.ios_cpp.v1.seen';
  String get _terminalKey => 'dopmi.$namespace.ios_cpp.v1.terminal';
  static const _pendingLifetime = Duration(hours: 24);

  Future<void> _queue(Future<void> Function() operation) {
    _pending = _pending
        .then((_) async {
          if (_storageUnsafe) {
            await preferences.reload();
            _storageUnsafe = false;
          }
          if (_terminalCleanupPending) await _finish();
          await operation();
        })
        .catchError((Object _) {
          // Optional attribution must not interrupt consent, login or actions.
          // In particular, an uncertain request stays tied to its saved owner.
        });
    return _pending;
  }

  bool get _finished => _terminal || preferences.getBool(_terminalKey) == true;

  static bool _validOwner(String owner) =>
      owner.isNotEmpty && owner.length <= 128;

  _PendingCpp? _read() {
    final reserved = _ownerReservation;
    if (reserved != null) return reserved;
    final stored = preferences.getString(_pendingKey);
    if (stored == null) return null;
    if (stored.length > 512) throw const FormatException('invalid_cpp_state');
    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 3 ||
        !decoded.keys.toSet().containsAll({
          'variant',
          'received_at_ms',
          'owner',
        })) {
      throw const FormatException('invalid_cpp_state');
    }
    final variant = decoded['variant'];
    final received = decoded['received_at_ms'];
    final owner = decoded['owner'];
    if (variant != 'personal-a' ||
        received is! int ||
        received <= 0 ||
        (owner != null && (owner is! String || !_validOwner(owner)))) {
      throw const FormatException('invalid_cpp_state');
    }
    return _PendingCpp(variant, received, owner as String?);
  }

  bool _fresh(_PendingCpp pending) {
    final current = now().toUtc().millisecondsSinceEpoch;
    return current >= pending.receivedAtMilliseconds &&
        current - pending.receivedAtMilliseconds <
            _pendingLifetime.inMilliseconds;
  }

  Future<bool> _save(_PendingCpp pending) async {
    // SharedPreferences can update its cache before an external write fails.
    // Never send using that cache until durable success or a successful reload.
    _storageUnsafe = true;
    final saved = await preferences.setString(
      _pendingKey,
      jsonEncode({
        'variant': pending.variant,
        'received_at_ms': pending.receivedAtMilliseconds,
        'owner': pending.owner,
      }),
    );
    if (!saved) await preferences.reload();
    _storageUnsafe = false;
    return saved;
  }

  Future<bool> _markReceiptSeen() async {
    if (preferences.getBool(_seenKey) == true) return true;
    _storageUnsafe = true;
    final saved = await preferences.setBool(_seenKey, true);
    if (!saved) await preferences.reload();
    _storageUnsafe = false;
    return saved;
  }

  Future<bool> _bind(_PendingCpp pending, String owner) async {
    // Reserve the first authenticated owner before storage can fail or yield to
    // another account. A failed write must not return this context to anonymity.
    final reserved = _ownerReservation ??= pending.withOwner(owner);
    if (reserved.owner != owner) return false;
    if (_bindingDurable) return true;
    if (pending.owner == null) _bindingNeedsFence = true;
    if (_bindingNeedsFence) {
      // Do not leave a durable anonymous record behind if the owner write fails.
      // A process restart in this gap loses attribution rather than assigning it
      // to the next account. Memory keeps the first owner eligible for a retry.
      _storageUnsafe = true;
      final removed = await preferences.remove(_pendingKey);
      if (!removed) await preferences.reload();
      _storageUnsafe = false;
      if (!removed) return false;
      _bindingNeedsFence = false;
    }
    _bindingDurable = await _save(reserved);
    return _bindingDurable;
  }

  Future<void> _finish() async {
    // Save the tombstone before removing context so duplicate initial/stream
    // deliveries and another account cannot revive a consumed installation.
    _terminal = true;
    _terminalCleanupPending = true;
    _storageUnsafe = true;
    final saved =
        preferences.getBool(_terminalKey) == true ||
        await preferences.setBool(_terminalKey, true);
    if (!saved) {
      await preferences.reload();
      _storageUnsafe = false;
      // The bound record is the remaining durable owner fence. Keep it until
      // the tombstone can be saved, including across a process restart.
      return;
    }
    final removed = await preferences.remove(_pendingKey);
    if (!removed) await preferences.reload();
    _storageUnsafe = false;
    _terminalCleanupPending = !removed;
    if (removed) {
      _ownerReservation = null;
      _receiptCandidate = null;
    }
  }

  Future<void> capture(Uri uri) {
    if (!supported || iosCppVariant(uri) == null) return Future.value();
    final generation = _generation;
    final received = now().toUtc().millisecondsSinceEpoch;
    final capturedOwner = _currentOwner;
    return _queue(() async {
      if (generation != _generation ||
          _finished ||
          received <= 0 ||
          _revokedOwners.contains(capturedOwner)) {
        return;
      }
      final previous = _read();
      if (previous != null) {
        // A duplicate must not move the local receipt or its expiration.
        if (!_fresh(previous)) await _finish();
        return;
      }
      if (_receiptCandidate == null) {
        // This survives removal of an anonymous record during binding. A new
        // process with a seen receipt but no context must not recreate it from
        // the same static URL and assign it to the next signed-in account.
        if (preferences.getBool(_seenKey) == true) return;
        _receiptCandidate = _PendingCpp(
          'personal-a',
          received,
          capturedOwner != null && _validOwner(capturedOwner)
              ? capturedOwner
              : null,
        );
      }
      final candidate = _receiptCandidate!;
      if (!_fresh(candidate) || _revokedOwners.contains(candidate.owner)) {
        return _finish();
      }
      // One bounded receipt fence is written first and is never removed. A
      // failed pending write can retry from memory within this process; after
      // process death, losing attribution is preferable to reviving context.
      if (!await _markReceiptSeen()) return;
      if (await _save(candidate)) _receiptCandidate = null;
    });
  }

  Future<void> observeOwner(String? owner) {
    // Change live eligibility now, including while an older storage/RPC awaits.
    _currentOwner = owner;
    _ownerObserved = true;
    if (!supported || owner == null || !_validOwner(owner)) {
      return Future.value();
    }
    return _queue(() async {
      if (_finished) return;
      final pending = _read();
      if (pending == null) {
        final candidate = _receiptCandidate;
        if (candidate != null && candidate.owner == null) {
          _receiptCandidate = candidate.withOwner(owner);
        }
        return;
      }
      if (pending.owner != null && pending.owner != owner) return;
      if (pending.owner == null ||
          (_ownerReservation != null && !_bindingDurable)) {
        if (!await _bind(pending, owner)) return;
      }
      if (!_fresh(pending)) return _finish();
      if (_revokedOwners.contains(owner)) return _finish();
    });
  }

  Future<void> revoke(String owner) {
    if (!supported || !_validOwner(owner)) return Future.value();
    _generation++;
    _revokedOwners.add(owner);
    return _queue(() async {
      if (_finished) return;
      final pending = _read() ?? _receiptCandidate;
      // A captured OFF can arrive after another owner has signed in. It cannot
      // delete that other owner's pending context or revoke their server data.
      if (pending?.owner == owner ||
          ((pending == null || pending.owner == null) &&
              _currentOwner == owner)) {
        await _finish();
      }
    });
  }

  Future<void> record({
    required String owner,
    required bool Function() sessionStillEligible,
    required Future<IosCppClaimResult> Function(String variant) send,
  }) {
    if (!supported || !_validOwner(owner)) return Future.value();
    final generation = _generation;
    bool eligible() =>
        generation == _generation &&
        _ownerObserved &&
        _currentOwner == owner &&
        !_revokedOwners.contains(owner) &&
        sessionStillEligible();
    return _queue(() async {
      if (_finished || !eligible()) return;
      var pending = _read();
      if (pending == null) return;
      if (pending.owner != null && pending.owner != owner) return;
      if (pending.owner == null) {
        if (!await _bind(pending, owner)) return;
        pending = _ownerReservation!;
      } else if (_ownerReservation != null && !_bindingDurable) {
        if (!await _bind(pending, owner)) return;
      }
      if (!_fresh(pending)) return _finish();
      if (pending.owner != owner || !eligible()) return;
      final result = await send(pending.variant);
      if (!eligible()) return;
      switch (result) {
        case IosCppClaimResult.recorded:
        case IosCppClaimResult.alreadyRecorded:
        case IosCppClaimResult.ineligible:
          await _finish();
          return;
        case IosCppClaimResult.consentChanged:
          // A later successful consent synchronization may retry for this owner.
          return;
      }
    });
  }
}

final iosCppAcquisitionProvider = Provider<IosCppAcquisition?>((ref) => null);

class _PendingCpp {
  const _PendingCpp(this.variant, this.receivedAtMilliseconds, this.owner);
  final String variant;
  final int receivedAtMilliseconds;
  final String? owner;

  _PendingCpp withOwner(String value) =>
      _PendingCpp(variant, receivedAtMilliseconds, value);
}
