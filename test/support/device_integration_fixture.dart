// Test-only adapters. Never imported by lib/ or used to establish hardware trust.
import 'dart:async';

import 'package:cta2000/backend/controllers/device_controller.dart';
import 'package:cta2000/backend/models/device_models.dart';
import 'package:cta2000/backend/services/device/connection_manager.dart';
import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:cta2000/backend/services/device/json_http_client.dart';
import 'package:cta2000/backend/services/device/pairing_service.dart';
import 'package:cta2000/backend/services/device/radxa_client.dart';

import 'device_fakes.dart';

class GatedCredentials extends MemoryCredentials {
  Completer<void>? gate;
  final writing = Completer<void>();
  bool failClear = false;
  @override
  Future<void> write(DeviceCredentials credentials) async {
    if (!writing.isCompleted) writing.complete();
    await gate?.future;
    await super.write(credentials);
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('test cleanup failure');
    await super.clear();
  }
}

class GatedSettings extends MemorySettings {
  Completer<void>? readGate, writeGate;
  final writing = Completer<void>();
  @override
  Future<DeviceSettings?> read() async {
    // Capture the read result to exercise an old completion after forgetting.
    final before = value;
    await readGate?.future;
    return before;
  }

  @override
  Future<void> write(DeviceSettings settings) async {
    if (!writing.isCompleted) writing.complete();
    await writeGate?.future;
    await super.write(settings);
  }
}

class ControlledProvisioning extends FakeProvisioning {
  PairingWindow? window = PairingWindow(
    open: true,
    expiresAt: DateTime.now().add(const Duration(minutes: 2)),
  );
  Completer<void>? gate;
  final started = Completer<void>();
  String? wrongIdentity;
  @override
  Future<PairingWindow?> inspectPairingWindow(
    String deviceId,
    RequestCancellation cancellation,
  ) async => window;
  @override
  Future<ProvisioningResult> provision({
    required String deviceId,
    required String passkey,
    RequestCancellation? cancellation,
  }) async {
    if (!started.isCompleted) started.complete();
    await gate?.future;
    final result = await super.provision(
      deviceId: deviceId,
      passkey: passkey,
      cancellation: cancellation,
    );
    return ProvisioningResult(
      deviceId: wrongIdentity ?? result.deviceId,
      baseUri: result.baseUri,
      credential: result.credential,
      pinnedIdentity: result.pinnedIdentity,
    );
  }
}

class ControlledDiscovery implements DeviceDiscoveryAdapter {
  Completer<void>? gate;
  @override
  Future<List<NearbyDevice>> discover(RequestCancellation cancellation) async {
    await gate?.future;
    return const [
      NearbyDevice(
        discoveryId: 'test-only-device',
        displayName: 'Untrusted test name',
      ),
    ];
  }
}

class ProtocolTransport extends FakeTransport {
  ProtocolTransport(super.kind) {
    operations = DeviceOperation.values.map((v) => v.name).toSet();
  }
  final requests = <Map<String, Object?>>[];
  Future<Object?> Function(
    String operation,
    Map<String, Object?> request,
    RequestCancellation cancellation,
  )?
  onSend;
  @override
  Future<Object?> send(
    String operation,
    Object? payload,
    RequestCancellation cancellation,
  ) async {
    sends++;
    final request = Map<String, Object?>.from(payload as Map);
    requests.add(request);
    if (onSend != null) return onSend!(operation, request, cancellation);
    final arguments = request['payload'] as Map;
    final result = switch (operation) {
      'status' => {
        'device_id': 'test-only-device',
        'capabilities': {'operations': operations.toList()},
      },
      'capabilities' => {'operations': operations.toList()},
      'playbackState' => {
        'phase': 'paused',
        'song_id': 'remote-test',
        'position_ms': 500,
        'duration_ms': 1000,
      },
      'recordingState' => {'phase': 'idle'},
      'recordingMetadata' => {
        'recording_id': arguments['recording_id'],
        'duration_ms': 1000,
      },
      'listFiles' => {
        'files': [
          {'file_id': 'file-test', 'name': 'Test only'},
        ],
      },
      'submitDownload' => {'job_id': 'job-test', 'phase': 'queued'},
      'downloadStatus' => {'job_id': arguments['job_id'], 'phase': 'running'},
      _ => {'accepted': true},
    };
    return response(request, result);
  }

  static Map<String, Object?> response(
    Map<String, Object?> request,
    Object? result,
  ) => {
    'protocol_version': 1,
    'request_id': request['request_id'],
    'result': result,
  };
}

class DeviceFixture {
  DeviceFixture({
    bool production = false,
    bool productionClient = false,
    ReconnectWait? waitForRetry,
  }) {
    connections = production
        ? ConnectionManager.production(
            settings: settings,
            credentials: credentials,
          )
        : ConnectionManager.forTesting(
            settings: settings,
            credentials: credentials,
            wifiTransport: wifi,
            bleTransport: ble,
            waitForRetry:
                waitForRetry ??
                (delay, _) async {
                  delays.add(delay);
                },
          );
    pairing = production
        ? PairingService.production(
            settings: settings,
            credentials: credentials,
            disconnect: connections.disconnect,
          )
        : PairingService.forTesting(
            settings: settings,
            credentials: credentials,
            bondingAdapter: bonding,
            identityVerifier: verifier,
            discoveryAdapter: discovery,
            disconnect: connections.disconnect,
          );
    client = production || productionClient
        ? RadxaClient.production(connections)
        : RadxaClient.forTesting(connections, requestId: () => 'test-${++_id}');
    controller = DeviceController(
      connections: connections,
      pairing: pairing,
      client: client,
    );
  }
  final settings = GatedSettings();
  final credentials = GatedCredentials();
  final bonding = ControlledProvisioning();
  final verifier = FakeVerifier();
  final discovery = ControlledDiscovery();
  final wifi = ProtocolTransport(TransportKind.wifi),
      ble = ProtocolTransport(TransportKind.ble);
  final delays = <Duration>[];
  int _id = 0;
  late final ConnectionManager connections;
  late final PairingService pairing;
  late final RadxaClient client;
  late final DeviceController controller;
  void saveTrust() {
    settings.value = testSettings;
    credentials.value = testCredentials;
  }

  Future<void> connect() async {
    saveTrust();
    await controller.connect();
    await controller.refreshDeviceInfo();
  }

  Future<void> close() => controller.close();
}
