import 'dart:developer' as developer;
import 'dart:isolate' as isolate;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Reads heap statistics of the current isolate through the VM service.
///
/// The VM service runs in debug and profile builds but not under
/// `flutter test` or in release builds; [connect] returns null there.
class AllocationProfiler {
  AllocationProfiler._(this._service, this._isolateId);

  final VmService _service;
  final String _isolateId;

  static Future<AllocationProfiler?> connect() async {
    final info = await developer.Service.getInfo();
    final uri = info.serverWebSocketUri;
    final isolateId = developer.Service.getIsolateId(isolate.Isolate.current);
    if (uri == null || isolateId == null) return null;
    final service = await vmServiceConnectUri(uri.toString());
    return AllocationProfiler._(service, isolateId);
  }

  /// Bytes reachable after a full garbage collection.
  Future<int> liveBytes() async {
    final profile = await _service.getAllocationProfile(_isolateId, gc: true);
    var total = 0;
    for (final stats in profile.members ?? const <ClassHeapStats>[]) {
      total += stats.bytesCurrent ?? 0;
    }
    return total;
  }

  /// Bytes allocated per call of [body].
  ///
  /// Heap usage only grows between collections, so the growth over a short
  /// window of [calls] calls is what they allocated, less the constant cost
  /// of asking. A collection inside a window shrinks that window's sample;
  /// the median over [windows] windows discards those.
  Future<double> allocatedPerCall(
    void Function() body, {
    int calls = 5,
    int windows = 9,
  }) async {
    final overhead = <double>[];
    for (var i = 0; i < 3; i++) {
      final before = await _heapUsage();
      overhead.add((await _heapUsage() - before).toDouble());
    }
    final cost = _median(overhead);
    final samples = <double>[];
    for (var w = 0; w < windows; w++) {
      final before = await _heapUsage();
      for (var i = 0; i < calls; i++) {
        body();
      }
      samples.add((await _heapUsage() - before - cost) / calls);
    }
    return _median(samples);
  }

  Future<int> _heapUsage() async =>
      (await _service.getMemoryUsage(_isolateId)).heapUsage ?? 0;

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  Future<void> dispose() => _service.dispose();
}
