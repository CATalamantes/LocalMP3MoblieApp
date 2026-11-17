import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/design_widgets.dart';
import '../widgets/draft_editors.dart';
import '../widgets/presentation.dart';
import '../widgets/unknown_meter.dart';
import '../widgets/application_binding.dart';
import '../../backend/services/device/device_contracts.dart';
import '../../backend/controllers/device_controller.dart';
import '../../backend/controllers/controller_state.dart';

class DeviceStatePanel extends StatelessWidget {
  const DeviceStatePanel({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) {
    final state = data.deviceData;
    final trust = state?.trustedDevice;
    final verified = state?.hardwareAuthenticated == true;
    final label = state?.testOnly == true
        ? 'Test-only state · Not authenticated hardware'
        : verified
        ? 'Authenticated hardware'
        : switch (state?.phase) {
            DevicePhase.noTrustedDevice => 'No trusted device',
            DevicePhase.trustedDeviceSaved => 'Saved trust · Not connected',
            DevicePhase.connecting ||
            DevicePhase.reconnecting => 'Connecting · Not authenticated',
            DevicePhase.forgetting => 'Removing local trust…',
            DevicePhase.error => 'Device connection error',
            _ => 'Device unavailable · Not authenticated',
          };
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('MP3 Capsule', style: titleStyle),
          const SizedBox(height: 8),
          Text(label, style: mutedStyle),
          if (trust != null) ...[
            const SizedBox(height: 8),
            Text('Saved device ID: ${trust.deviceId}', style: mutedStyle),
            Text('HTTPS host: ${trust.baseUri.host}', style: mutedStyle),
          ],
          if (verified && data.device != null)
            Text(
              'Verified capabilities: ${data.device!.capabilities.operations.join(', ')}',
              style: mutedStyle,
            ),
          if (data.device != null)
            Text(
              'Battery: ${data.device!.batteryPercent == null ? 'Unavailable' : '${data.device!.batteryPercent}%'} · Storage: ${_bytes(data.device!.storageBytes)}',
              style: mutedStyle,
            ),
          if (data.errorMessage != null)
            Text(data.errorMessage!, style: mutedStyle),
          if (!verified)
            const Text(
              'Production pairing and authenticated connections remain unavailable.',
              style: mutedStyle,
            ),
        ],
      ),
    );
  }
}

String _bytes(int? value) => value == null
    ? 'Unavailable'
    : '${(value / 1000000000).toStringAsFixed(1)} GB';

class DeviceOverviewPage extends StatelessWidget {
  const DeviceOverviewPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.device,
    children: [
      if (data.integrated) DeviceStatePanel(data: data),
      const Text('Hardware status and playback pipeline', style: mutedStyle),
      const SizedBox(height: 20),
      if (!data.integrated)
        const SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsRow(
                title: 'MP3 Capsule',
                subtitle: 'No authenticated device connected',
                icon: Icons.memory,
              ),
              StatusPill('Device unavailable'),
            ],
          ),
        ),
      const SectionTitle('CONNECTIVITY & STORAGE'),
      const SurfaceCard(
        child: Column(
          children: [
            ScreenLink(
              screen: AppScreen.connections,
              label: 'Connections',
              subtitle: 'Wi-Fi, Bluetooth, USB-C',
              icon: Icons.wifi,
            ),
            Divider(),
            ScreenLink(
              screen: AppScreen.sync,
              label: 'Music Sync',
              subtitle: 'Synchronization unavailable',
              icon: Icons.sync,
            ),
            Divider(),
            ScreenLink(
              screen: AppScreen.storage,
              label: 'Storage',
              subtitle: 'Capacity and free space unknown',
              icon: Icons.storage,
            ),
            Divider(),
            ScreenLink(
              screen: AppScreen.files,
              label: 'File Manager',
              subtitle: 'Browse device files when available',
              icon: Icons.folder_open,
            ),
          ],
        ),
      ),
      const SectionTitle('HARDWARE & AUDIO'),
      const SurfaceCard(
        child: Column(
          children: [
            ScreenLink(
              screen: AppScreen.bluetoothAudio,
              label: 'Bluetooth Audio',
              subtitle: 'Headphone output unavailable',
              icon: Icons.headphones,
            ),
            Divider(),
            ScreenLink(
              screen: AppScreen.batteryDisplay,
              label: 'Battery & Display',
              subtitle: 'Telemetry unavailable',
              icon: Icons.battery_unknown,
            ),
            Divider(),
            ScreenLink(
              screen: AppScreen.aboutDevice,
              label: 'About Device',
              subtitle: 'Hardware and service information',
              icon: Icons.info_outline,
            ),
          ],
        ),
      ),
      PresentationNotice(
        data: data,
        empty: 'No device information',
        unconnected:
            'Connect a supported device when integration is available.',
      ),
    ],
  );
}

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.connections,
    children: [
      if (data.integrated) DeviceStatePanel(data: data),
      if (!data.integrated)
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsRow(
                title: 'MP3 Capsule',
                subtitle: 'No authenticated connection',
                icon: Icons.memory,
              ),
              const StatusPill('Single trusted device'),
              const SizedBox(height: 12),
              Text(
                data.device == null
                    ? 'No trusted-device information loaded.'
                    : 'Design sample · ${data.device!.deviceId}',
                style: mutedStyle,
              ),
            ],
          ),
        ),
      const SectionTitle('CONNECTION METHODS'),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              title: 'Wi-Fi',
              subtitle: 'Preferred transport · Unavailable',
              icon: Icons.wifi,
              trailing: IconButton(
                tooltip: 'Configure Wi-Fi draft',
                icon: const Icon(Icons.tune),
                onPressed: () => showDraftEditor(
                  context,
                  title: 'Connection settings',
                  fields: {
                    'HTTPS endpoint':
                        data.deviceData?.trustedDevice?.baseUri.toString() ??
                        '',
                  },
                  onSave:
                      !data.integrated || data.deviceData?.trustedDevice == null
                      ? null
                      : (fields) async {
                          final a = ApplicationScope.of(context)!;
                          final trust = data.deviceData!.trustedDevice!;
                          final endpoint = Uri.tryParse(
                            fields['HTTPS endpoint']!,
                          );
                          if (endpoint == null ||
                              endpoint.scheme != 'https' ||
                              endpoint.host.isEmpty ||
                              endpoint.userInfo.isNotEmpty) {
                            throw const ControllerFailure(
                              ControllerFailureKind.invalidInput,
                              'Enter a valid HTTPS endpoint without credentials.',
                            );
                          }
                          await a.dependencies.device.updateConnectionSettings(
                            DeviceSettings(
                              deviceId: trust.deviceId,
                              baseUri: endpoint,
                              autoReconnect: trust.autoReconnect,
                            ),
                          );
                        },
                ),
              ),
            ),
            const Divider(),
            const SettingsRow(
              title: 'Bluetooth LE',
              subtitle: 'Phone-to-player control · Pairing unavailable',
              icon: Icons.bluetooth,
            ),
            const Divider(),
            const SettingsRow(
              title: 'USB-C',
              subtitle: 'Device operations unavailable',
              icon: Icons.usb,
            ),
          ],
        ),
      ),
      const SectionTitle('DISCOVERY & PAIRING'),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No nearby devices loaded. Discovery and secure pairing are unavailable.',
              style: mutedStyle,
            ),
            SizedBox(height: 14),
            ActionPill('Discover Devices', icon: Icons.radar),
            SizedBox(height: 10),
            ActionPill('Enter Pairing Code', icon: Icons.pin_outlined),
          ],
        ),
      ),
      const SectionTitle('CONNECTION PREFERENCES'),
      SurfaceCard(
        child: Column(
          children: [
            SettingsRow(
              title: 'Automatically reconnect',
              subtitle:
                  data.integrated && data.deviceData?.trustedDevice != null
                  ? 'Saved preference; startup does not initiate authentication.'
                  : 'Preference not loaded',
              trailing: Switch(
                value: data.deviceData?.trustedDevice?.autoReconnect ?? false,
                onChanged:
                    !data.integrated ||
                        data.deviceData?.trustedDevice == null ||
                        data.mode == PresentationMode.loading
                    ? null
                    : (value) {
                        final a = ApplicationScope.of(context)!;
                        final trust = data.deviceData!.trustedDevice!;
                        a.quietly(
                          () => a.dependencies.device.updateConnectionSettings(
                            DeviceSettings(
                              deviceId: trust.deviceId,
                              baseUri: trust.baseUri,
                              autoReconnect: value,
                            ),
                          ),
                        );
                      },
              ),
            ),
            const Divider(),
            const SettingsRow(
              title: 'Prefer Wi-Fi when available',
              subtitle: 'Setting unavailable',
              trailing: Switch(value: false, onChanged: null),
            ),
            const Divider(),
            const SettingsRow(
              title: 'Allow Bluetooth connection',
              subtitle: 'Authenticated control only · Unavailable',
              trailing: Switch(value: false, onChanged: null),
            ),
            const Divider(),
            const SettingsRow(
              title: 'Automatic device discovery',
              subtitle: 'Discovery unavailable',
              trailing: Switch(value: false, onChanged: null),
            ),
          ],
        ),
      ),
      const SectionTitle('HARDWARE UTILITIES'),
      const ActionPill('Find My MP3 Player', icon: Icons.volume_up_outlined),
      const SizedBox(height: 12),
      if (!data.integrated)
        const ActionPill('Force Reconnect', icon: Icons.sync)
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionPill(
              'Reload saved device',
              icon: Icons.refresh,
              onPressed: data.mode == PresentationMode.loading
                  ? null
                  : () {
                      final a = ApplicationScope.of(context)!;
                      a.quietly(a.dependencies.device.loadSavedDevice);
                    },
            ),
            ActionPill(
              'Force Reconnect',
              icon: Icons.sync,
              onPressed:
                  data.deviceData?.trustedDevice == null ||
                      data.mode == PresentationMode.loading
                  ? null
                  : () {
                      final a = ApplicationScope.of(context)!;
                      a.quietly(a.dependencies.device.connect);
                    },
            ),
            ActionPill(
              'Disconnect',
              icon: Icons.link_off,
              onPressed: data.mode == PresentationMode.loading
                  ? null
                  : () {
                      final a = ApplicationScope.of(context)!;
                      a.quietly(a.dependencies.device.disconnect);
                    },
            ),
            ActionPill(
              'Refresh verified status',
              icon: Icons.info_outline,
              onPressed:
                  data.deviceData?.hardwareAuthenticated != true ||
                      data.mode == PresentationMode.loading
                  ? null
                  : () {
                      final a = ApplicationScope.of(context)!;
                      a.quietly(a.dependencies.device.refreshDeviceInfo);
                    },
            ),
          ],
        ),
      const SizedBox(height: 12),
      ActionPill(
        'Forget Device',
        icon: Icons.link_off,
        onPressed: data.integrated
            ? data.mode == PresentationMode.loading
                  ? null
                  : () {
                      final a = ApplicationScope.of(context)!;
                      confirmAction(
                        context,
                        title: 'Forget local device trust?',
                        message: 'Remove locally saved trust and credentials. This does not guarantee removal of remote authorization or operating-system Bluetooth bonding.',
                        action: 'Forget',
                        onConfirm: () async {
                          await a.dependencies.device.forgetDevice();
                          return 'Local device trust removed. Remote authorization and OS Bluetooth bonding were not verified or revoked.';
                        },
                      );
                    }
            : () => showUnavailableConfirmation(
                context,
                title: 'Forget device?',
                message: 'Forgetting is not connected. No trust or credentials will be removed. Local forgetting cannot prove remote revocation.',
                action: 'Forget',
                enabled: data.device != null,
              ),
      ),
      const SizedBox(height: 16),
      PresentationNotice(
        data: data,
        empty: 'No trusted device',
        unconnected: 'Production pairing and authenticated device connections are unavailable.',
      ),
    ],
  );
}

class MusicSyncPage extends StatefulWidget {
  const MusicSyncPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  State<MusicSyncPage> createState() => _MusicSyncPageState();
}

class _MusicSyncPageState extends State<MusicSyncPage> {
  String _scope = 'All Music';
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.sync,
    children: [
      if (widget.data.integrated) DeviceStatePanel(data: widget.data),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.sync_disabled, color: AppTheme.muted, size: 44),
            SizedBox(height: 16),
            Text('No synchronization is running', style: headingStyle),
            SizedBox(height: 12),
            Text(
              'No supported device connected. Transfer details are unavailable.',
              style: mutedStyle,
            ),
          ],
        ),
      ),
      const SurfaceCard(
        emphasis: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Transfer Status', style: titleStyle),
            SizedBox(height: 18),
            UnknownMeter(label: 'Transfer progress unavailable'),
            SizedBox(height: 18),
            Text('No queued transfers', style: mutedStyle),
            SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                ActionPill('Pause', icon: Icons.pause),
                ActionPill('Cancel Sync', icon: Icons.close),
              ],
            ),
          ],
        ),
      ),
      const SectionTitle('What Gets Synced'),
      RadioGroup<String>(
        groupValue: _scope,
        onChanged: (value) => setState(() => _scope = value!),
        child: Column(
          children: [
            for (final scope in [
              'All Music',
              'Selected Playlists',
              'Selected Albums',
            ])
              SurfaceCard(
                padding: 8,
                child: RadioListTile<String>(
                  value: scope,
                  title: Text(scope, style: titleStyle),
                  subtitle: const Text(
                    'Draft selection only · Sync unavailable',
                    style: mutedStyle,
                  ),
                ),
              ),
          ],
        ),
      ),
      const ActionPill('Sync Now', icon: Icons.sync, primary: true),
      const SizedBox(height: 16),
      const Text('Device free storage: unavailable', style: mutedStyle),
      const SizedBox(height: 16),
      PresentationNotice(
        data: widget.data,
        empty: 'No transfers available',
        unconnected: 'Music synchronization is not connected.',
      ),
    ],
  );
}

class StoragePage extends StatelessWidget {
  const StoragePage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) {
    final total = data.device?.storageBytes, free = data.device?.freeBytes;
    final used = total != null && free != null ? total - free : null;
    return PageBody(
      screen: AppScreen.storage,
      children: [
        if (data.integrated) DeviceStatePanel(data: data),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Device Storage', style: titleStyle),
              const SizedBox(height: 18),
              Text(
                used == null ? 'Capacity unavailable' : '${_bytes(used)} used',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Total: ${_bytes(total)} · Free: ${_bytes(free)}',
                style: mutedStyle,
              ),
              const SizedBox(height: 22),
              UnknownMeter(
                label: used == null
                    ? 'Storage allocation unavailable'
                    : 'Received storage allocation',
                fraction: total == null || total == 0 || used == null
                    ? null
                    : used / total,
              ),
            ],
          ),
        ),
        const SectionTitle('Storage Breakdown'),
        const SurfaceCard(
          child: Column(
            children: [
              SettingsRow(
                title: 'Music',
                subtitle: 'Track count and size unavailable',
                icon: Icons.music_note,
              ),
              Divider(),
              SettingsRow(
                title: 'Recordings',
                subtitle: 'Recording storage unavailable',
                icon: Icons.mic_none,
              ),
              Divider(),
              SettingsRow(
                title: 'Other Files',
                subtitle: 'Artwork and system size unavailable',
                icon: Icons.folder_outlined,
              ),
            ],
          ),
        ),
        ActionPill(
          'Manage Files',
          key: const ValueKey('open-files'),
          primary: true,
          icon: Icons.folder_open,
          onPressed: () => openScreen(context, AppScreen.files),
        ),
        const SizedBox(height: 16),
        const Text(
          'Audio is stored on the physical player. Storage details require a supported device.',
          style: mutedStyle,
        ),
        const SizedBox(height: 16),
        PresentationNotice(
          data: data,
          empty: 'No storage information',
          unconnected: 'Device storage telemetry is unavailable.',
        ),
      ],
    );
  }
}

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  final _search = TextEditingController();
  String _category = 'Music', _sort = 'Name';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.files,
    children: [
      if (widget.data.integrated) DeviceStatePanel(data: widget.data),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MP3 Capsule', style: headingStyle),
            SizedBox(height: 18),
            UnknownMeter(label: 'Used / free storage unavailable'),
          ],
        ),
      ),
      TextField(
        key: const ValueKey('file-search'),
        controller: _search,
        decoration: InputDecoration(
          labelText: 'Search files on MP3 Capsule',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: 'Clear file search',
            onPressed: _search.clear,
            icon: const Icon(Icons.close),
          ),
        ),
      ),
      const SizedBox(height: 16),
      ChoicePills(
        labels: const ['Music', 'Recordings', 'Other'],
        selected: _category,
        onSelected: (value) => setState(() => _category = value),
      ),
      const SizedBox(height: 8),
      DropdownButton<String>(
        value: _sort,
        isExpanded: true,
        items: [
          for (final value in ['Name', 'Size', 'Date'])
            DropdownMenuItem(value: value, child: Text('Sort: $value')),
        ],
        onChanged: (value) => setState(() => _sort = value!),
      ),
      const Text(
        'Search and sort selections are drafts. Device files are not connected.',
        style: mutedStyle,
      ),
      const SectionTitle('Files & Folders'),
      for (final folder in widget.data.folders)
        SurfaceCard(
          child: SettingsRow(
            title: folder,
            subtitle: 'Folder navigation not connected',
            icon: Icons.folder_outlined,
            onTap: () => explainUnavailable(context, 'Folder navigation'),
          ),
        ),
      if (widget.data.files.isEmpty && widget.data.folders.isEmpty)
        const SurfaceCard(
          child: Text('No files or folders available.', style: mutedStyle),
        ),
      for (final file in widget.data.files)
        SurfaceCard(
          child: Row(
            children: [
              const Checkbox(value: false, onChanged: null),
              const IconTile(Icons.audio_file_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.name, style: titleStyle),
                    Text(
                      file.sizeBytes == null
                          ? 'Size unavailable'
                          : '${file.sizeBytes} bytes',
                      style: mutedStyle,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'File actions',
                icon: const Icon(Icons.more_vert),
                onPressed: () => showUnavailableConfirmation(
                  context,
                  title: 'File actions',
                  message: 'Remote file operations are unavailable. No file will be changed.',
                  action: 'Delete',
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      const SurfaceCard(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ActionPill('Select', icon: Icons.checklist),
            ActionPill('Delete', icon: Icons.delete_outline),
            ActionPill('Transfer to Phone', icon: Icons.phone_android),
          ],
        ),
      ),
      PresentationNotice(
        data: widget.data,
        empty: 'Empty folder',
        unconnected: 'Remote file listing and actions are unavailable.',
      ),
    ],
  );
}

class BluetoothAudioPage extends StatelessWidget {
  const BluetoothAudioPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.bluetoothAudio,
    children: [
      if (data.integrated) DeviceStatePanel(data: data),
      const SurfaceCard(
        child: Text(
          'Wireless headphones connect to the player’s audio output. This is separate from the phone-to-player BLE control connection.',
          style: mutedStyle,
        ),
      ),
      const SurfaceCard(
        child: SettingsRow(
          title: 'Bluetooth Audio',
          subtitle: 'Device setting unavailable',
          icon: Icons.bluetooth_audio,
          trailing: Switch(value: false, onChanged: null),
        ),
      ),
      const SectionTitle('CURRENTLY CONNECTED'),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              title: 'No connected headphones',
              subtitle: 'Connection and battery data unavailable',
              icon: Icons.headphones,
            ),
            ActionPill('Disconnect', icon: Icons.link_off),
            SizedBox(height: 12),
            ActionPill('Audio Output Settings', icon: Icons.tune),
          ],
        ),
      ),
      const SectionTitle('PAIRED DEVICES'),
      const SurfaceCard(
        child: Text(
          'No paired audio-device information loaded.',
          style: mutedStyle,
        ),
      ),
      const SectionTitle('AVAILABLE AUDIO DEVICES'),
      const SurfaceCard(
        child: Column(
          children: [
            Icon(Icons.bluetooth_searching, size: 40, color: AppTheme.muted),
            SizedBox(height: 16),
            Text(
              'Audio-device discovery unavailable. No scan is running.',
              style: mutedStyle,
            ),
          ],
        ),
      ),
      const ActionPill('Pair New Audio Device', icon: Icons.add),
      const SectionTitle('AUDIO OUTPUT MODE'),
      const SurfaceCard(
        child: Column(
          children: [
            SettingsRow(
              title: '3.5 mm Headphone Jack',
              subtitle: 'Direct audio output · Status unknown',
              icon: Icons.headphones_outlined,
            ),
            Divider(),
            SettingsRow(
              title: 'Bluetooth Wireless',
              subtitle: 'Wireless output · Status unknown',
              icon: Icons.bluetooth_audio,
            ),
            Divider(),
            SettingsRow(
              title: 'USB Audio Out',
              subtitle: 'External DAC · Status unknown',
              icon: Icons.usb,
            ),
          ],
        ),
      ),
      PresentationNotice(
        data: data,
        empty: 'No audio devices',
        unconnected: 'Headphone management requires the physical player.',
      ),
    ],
  );
}

class BatteryDisplayPage extends StatelessWidget {
  const BatteryDisplayPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.batteryDisplay,
    children: [
      if (data.integrated) DeviceStatePanel(data: data),
      const SectionTitle('BATTERY STATUS & POWER'),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.battery_unknown, size: 64, color: AppTheme.muted),
            const SizedBox(height: 14),
            Text(
              data.device?.batteryPercent == null
                  ? 'Battery unavailable'
                  : '${data.device!.batteryPercent}%',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              data.device?.charging == null
                  ? 'Charging state unknown'
                  : data.device!.charging!
                  ? 'Charging'
                  : 'Not charging',
              style: mutedStyle,
            ),
            const SizedBox(height: 12),
            const Text(
              'Runtime, voltage, temperature and battery health unavailable.',
              style: mutedStyle,
            ),
          ],
        ),
      ),
      const SurfaceCard(
        child: Column(
          children: [
            SettingsRow(
              title: 'Battery Saver',
              subtitle: 'Device setting unavailable',
              trailing: Switch(value: false, onChanged: null),
            ),
            Divider(),
            SettingsRow(
              title: 'Auto Shutdown After Inactivity',
              subtitle: 'Unknown',
            ),
            Divider(),
            SettingsRow(
              title: 'Battery Health & Cycles',
              subtitle: 'Unavailable',
            ),
          ],
        ),
      ),
      const SectionTitle('DISPLAY & ATMOSPHERE'),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              title: 'Screen Brightness',
              subtitle: 'Brightness unknown',
              icon: Icons.brightness_6_outlined,
            ),
            Slider(value: 0, onChanged: null, semanticFormatterCallback: null),
            Divider(),
            SettingsRow(
              title: 'Screen Timeout',
              subtitle: 'Timeout unavailable',
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill('30s'),
                StatusPill('1m'),
                StatusPill('3m'),
                StatusPill('Never'),
              ],
            ),
            Divider(),
            SettingsRow(
              title: 'Always-On Display',
              subtitle: 'Device setting unavailable',
              trailing: Switch(value: false, onChanged: null),
            ),
            Divider(),
            SettingsRow(
              title: 'Auto-Dim During Playback',
              subtitle: 'Device setting unavailable',
              trailing: Switch(value: false, onChanged: null),
            ),
          ],
        ),
      ),
      const SurfaceCard(
        child: Text(
          'Display settings are not connected. No changes are sent to hardware.',
          style: mutedStyle,
        ),
      ),
      PresentationNotice(
        data: data,
        empty: 'No battery or display information',
        unconnected: 'Hardware telemetry is unavailable.',
      ),
    ],
  );
}

class AboutDevicePage extends StatelessWidget {
  const AboutDevicePage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.aboutDevice,
    children: [
      if (data.integrated) DeviceStatePanel(data: data),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              title: 'MP3 Capsule',
              subtitle: 'No authenticated device connected',
              icon: Icons.speaker_outlined,
            ),
            UnknownMeter(label: 'Storage allocation unavailable'),
          ],
        ),
      ),
      const SectionTitle('DEVICE INFORMATION'),
      SurfaceCard(
        child: Column(
          children: [
            const SettingsRow(title: 'Device Name', subtitle: 'Unavailable'),
            const Divider(),
            const SettingsRow(title: 'Hardware Model', subtitle: 'Unavailable'),
            const Divider(),
            SettingsRow(
              title: 'Software / Firmware Version',
              subtitle: data.device?.firmwareVersion ?? 'Unavailable',
            ),
            const Divider(),
            SettingsRow(
              title: 'Storage Capacity',
              subtitle: _bytes(data.device?.storageBytes),
            ),
            const Divider(),
            SettingsRow(
              title: 'Device Identifier',
              subtitle: data.device?.deviceId ?? 'Unavailable',
            ),
            const Divider(),
            const SettingsRow(title: 'Last Connected', subtitle: 'Unknown'),
          ],
        ),
      ),
      const SectionTitle('SYSTEM MAINTENANCE'),
      const SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ActionPill('Check for Updates', icon: Icons.system_update_alt),
            SizedBox(height: 14),
            Text('Audio engine status: unavailable', style: mutedStyle),
          ],
        ),
      ),
      const SectionTitle('HARDWARE POWER CONTROLS'),
      const Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ActionPill('Restart Device', icon: Icons.restart_alt),
          ActionPill('Shut Down', icon: Icons.power_settings_new),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'Power controls require authorized device communication.',
        style: mutedStyle,
      ),
      const SizedBox(height: 16),
      PresentationNotice(
        data: data,
        empty: 'No device information',
        unconnected: 'Device identity and firmware are not available.',
      ),
    ],
  );
}
