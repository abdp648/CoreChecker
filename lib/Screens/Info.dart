import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../Services/Device.dart';

class DeviceInfoHomeScreen extends StatefulWidget {
  const DeviceInfoHomeScreen({Key? key}) : super(key: key);

  @override
  State<DeviceInfoHomeScreen> createState() => _DeviceInfoHomeScreenState();
}

class _DeviceInfoHomeScreenState extends State<DeviceInfoHomeScreen>
    with TickerProviderStateMixin {
  CompleteDeviceInfoModel? _deviceInfo;
  bool _isLoading = true;
  String? _error;

  // Real-time data
  AccelerometerEvent? _accelerometerData;
  GyroscopeEvent? _gyroscopeData;
  BatteryState? _batteryState;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Stream subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<BatteryState>? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    DeviceServices.initializeStreams();
    _loadDeviceInfo();
    _setupRealTimeStreams();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  void _setupRealTimeStreams() {
    _accelerometerSubscription = DeviceServices.accelerometerStream.listen((
      event,
    ) {
      if (mounted) {
        setState(() {
          _accelerometerData = event;
        });
      }
    });

    _gyroscopeSubscription = DeviceServices.gyroscopeStream.listen((event) {
      if (mounted) {
        setState(() {
          _gyroscopeData = event;
        });
      }
    });

    _batterySubscription = DeviceServices.batteryStream.listen((state) {
      if (mounted) {
        setState(() {
          _batteryState = state;
        });
      }
    });
  }

  Future<void> _loadDeviceInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Pass the context to getAllDeviceInfo method
      final deviceInfo = await DeviceServices.getAllDeviceInfo(context);

      if (mounted) {
        setState(() {
          _deviceInfo = deviceInfo;
          _isLoading = false;
        });

        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _batterySubscription?.cancel();
    DeviceServices.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver:
                _isLoading
                    ? _buildLoadingSliver()
                    : _error != null
                    ? _buildErrorSliver()
                    : _buildContentSliver(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadDeviceInfo,
        backgroundColor: const Color(0xFF6C5CE7),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0A0E27),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Device Monitor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C5CE7), Color(0xFF74B9FF)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading device information...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDeviceInfo,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSliver() {
    if (_deviceInfo == null) return const SliverToBoxAdapter(child: SizedBox());

    return SliverList(
      delegate: SliverChildListDelegate([
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildQuickStatsRow(),
                const SizedBox(height: 16),
                _buildDeviceInfoCard(),
                const SizedBox(height: 16),
                _buildBatteryCard(),
                const SizedBox(height: 16),
                _buildSystemCard(),
                const SizedBox(height: 16),
                _buildStorageCard(),
                const SizedBox(height: 16),
                _buildNetworkCard(),
                const SizedBox(height: 16),
                _buildLocationCard(),
                const SizedBox(height: 16),
                _buildSensorsCard(),
                const SizedBox(height: 16),
                _buildPermissionsCard(),
                const SizedBox(height: 100), // Space for FAB
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Battery',
            '${_deviceInfo!.batteryInfo.level}%',
            Icons.battery_full,
            _getBatteryColor(_deviceInfo!.batteryInfo.level),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            'RAM',
            '${_deviceInfo!.systemInfo.ramUsagePercentage.toStringAsFixed(1)}%',
            Icons.memory,
            _getRamColor(_deviceInfo!.systemInfo.ramUsagePercentage),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            'Storage',
            '${_deviceInfo!.storageInfo.usagePercentage.toStringAsFixed(1)}%',
            Icons.storage,
            _getStorageColor(_deviceInfo!.storageInfo.usagePercentage),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    final device = _deviceInfo!.deviceInfo;
    return _buildInfoCard(
      'Device Information',
      Icons.phone_android,
      const Color(0xFF6C5CE7),
      [
        _buildInfoRow('Model', device.model),
        _buildInfoRow('Brand', device.brand),
        _buildInfoRow('Manufacturer', device.manufacturer),
        _buildInfoRow('OS Version', device.androidVersion),
        _buildInfoRow('SDK Level', device.sdk.toString()),
        _buildInfoRow(
          'Physical Device',
          device.isPhysicalDevice ? 'Yes' : 'No',
        ),
        _buildInfoRow(
          'Screen Resolution',
          '${device.displayMetrics['widthPx']?.toStringAsFixed(0) ?? 'Unknown'} × ${device.displayMetrics['heightPx']?.toStringAsFixed(0) ?? 'Unknown'}',
        ),
        _buildInfoRow('App Name', device.appName),
        _buildInfoRow(
          'App Version',
          '${device.version} (${device.buildNumber})',
        ),
        _buildInfoRow('Package Name', device.packageName),
      ],
    );
  }

  Widget _buildBatteryCard() {
    final battery = _deviceInfo!.batteryInfo;
    return _buildInfoCard(
      'Battery Status',
      Icons.battery_full,
      _getBatteryColor(battery.level),
      [
        _buildInfoRow('Level', '${battery.level}%'),
        _buildInfoRow('State', battery.state.toString().split('.').last),
        _buildInfoRow('Charging', battery.isCharging ? 'Yes' : 'No'),
        _buildInfoRow(
          'Battery Saver',
          battery.isInBatterySaveMode ? 'On' : 'Off',
        ),
        if (battery.temperature != null)
          _buildInfoRow(
            'Temperature',
            '${battery.temperature!.toStringAsFixed(1)}°C',
          ),
        if (battery.voltage != null)
          _buildInfoRow('Voltage', '${battery.voltage!.toStringAsFixed(2)}V'),
        if (battery.health != null) _buildInfoRow('Health', battery.health!),
        if (_batteryState != null)
          _buildInfoRow(
            'Real-time State',
            _batteryState.toString().split('.').last,
          ),
        _buildProgressBar(
          'Battery Level',
          battery.level / 100,
          _getBatteryColor(battery.level),
        ),
      ],
    );
  }

  Widget _buildSystemCard() {
    final system = _deviceInfo!.systemInfo;
    return _buildInfoCard(
      'System Information',
      Icons.computer,
      const Color(0xFF00CEC9),
      [
        _buildInfoRow('Operating System', system.operatingSystem),
        _buildInfoRow('Kernel Version', system.kernelVersion),
        _buildInfoRow('CPU Cores', system.cpuCores.toString()),
        _buildInfoRow('Architecture', system.cpuArchitecture),
        _buildInfoRow('Total RAM', '${system.totalRAM} MB'),
        _buildInfoRow('Used RAM', '${system.usedRAM} MB'),
        _buildInfoRow('Free RAM', '${system.freeRAM} MB'),
        _buildInfoRow(
          'RAM Usage',
          '${system.ramUsagePercentage.toStringAsFixed(1)}%',
        ),
        if (system.cpuUsage > 0)
          _buildInfoRow('CPU Usage', '${system.cpuUsage.toStringAsFixed(1)}%'),
        if (system.cpuTemperature != null)
          _buildInfoRow(
            'CPU Temperature',
            '${system.cpuTemperature!.toStringAsFixed(1)}°C',
          ),
        if (system.uptime != null)
          _buildInfoRow(
            'Uptime',
            '${(system.uptime!.inHours)}h ${(system.uptime!.inMinutes % 60)}m',
          ),
        if (system.processes != null)
          _buildInfoRow('Processes', system.processes.toString()),
        _buildProgressBar(
          'RAM Usage',
          system.ramUsagePercentage / 100,
          _getRamColor(system.ramUsagePercentage),
        ),
      ],
    );
  }

  Widget _buildStorageCard() {
    final storage = _deviceInfo!.storageInfo;
    return _buildInfoCard(
      'Storage Information',
      Icons.storage,
      _getStorageColor(storage.usagePercentage),
      [
        _buildInfoRow('Total Space', storage.formatBytes(storage.totalSpace)),
        _buildInfoRow('Used Space', storage.formatBytes(storage.usedSpace)),
        _buildInfoRow('Free Space', storage.formatBytes(storage.freeSpace)),
        _buildInfoRow(
          'Usage',
          '${storage.usagePercentage.toStringAsFixed(1)}%',
        ),
        _buildProgressBar(
          'Storage Usage',
          storage.usagePercentage / 100,
          _getStorageColor(storage.usagePercentage),
        ),
      ],
    );
  }

  Widget _buildNetworkCard() {
    final network = _deviceInfo!.networkInfo;
    return _buildInfoCard(
      'Network Information',
      Icons.wifi,
      network.isConnected ? Colors.green : Colors.red,
      [
        _buildInfoRow(
          'Connection Type',
          network.connectionType.toString().split('.').last,
        ),
        _buildInfoRow(
          'Status',
          network.isConnected ? 'Connected' : 'Disconnected',
        ),
        if (network.wifiName != null)
          _buildInfoRow('WiFi Name', network.wifiName!),
        if (network.wifiIP != null)
          _buildInfoRow('IP Address', network.wifiIP!),
        if (network.wifiBSSID != null)
          _buildInfoRow('BSSID', network.wifiBSSID!),
        if (network.wifiGateway != null)
          _buildInfoRow('Gateway', network.wifiGateway!),
        if (network.wifiSubnet != null)
          _buildInfoRow('Subnet', network.wifiSubnet!),
        if (network.wifiSignalStrength != null)
          _buildInfoRow('Signal Strength', '${network.wifiSignalStrength} dBm'),
        if (network.connectionSpeed != null)
          _buildInfoRow(
            'Connection Speed',
            '${network.connectionSpeed!.toStringAsFixed(2)} Mbps',
          ),
      ],
    );
  }

  Widget _buildLocationCard() {
    final location = _deviceInfo!.locationInfo;
    return _buildInfoCard(
      'Location Information',
      Icons.location_on,
      const Color(0xFFE17055),
      location != null
          ? [
            _buildInfoRow('Latitude', location.latitude.toStringAsFixed(6)),
            _buildInfoRow('Longitude', location.longitude.toStringAsFixed(6)),
            _buildInfoRow(
              'Altitude',
              '${location.altitude.toStringAsFixed(2)} m',
            ),
            _buildInfoRow(
              'Accuracy',
              '${location.accuracy.toStringAsFixed(2)} m',
            ),
            _buildInfoRow('Speed', '${location.speed.toStringAsFixed(2)} m/s'),
            _buildInfoRow(
              'Speed Accuracy',
              '${location.speedAccuracy.toStringAsFixed(2)} m/s',
            ),
            _buildInfoRow('Heading', '${location.heading.toStringAsFixed(2)}°'),
            _buildInfoRow(
              'Heading Accuracy',
              '${location.headingAccuracy.toStringAsFixed(2)}°',
            ),
            _buildInfoRow('Is Mocked', location.isMocked ? 'Yes' : 'No'),
            if (location.timestamp != null)
              _buildInfoRow(
                'Last Update',
                location.timestamp!.toString().substring(0, 19),
              ),
          ]
          : [
            const Text(
              'Location access denied or unavailable',
              style: TextStyle(color: Colors.white70),
            ),
          ],
    );
  }

  Widget _buildSensorsCard() {
    return _buildInfoCard(
      'Sensors (Real-time)',
      Icons.sensors,
      const Color(0xFFFFB8B8),
      [
        if (_accelerometerData != null) ...[
          const Text(
            'Accelerometer:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          _buildInfoRow('X', _accelerometerData!.x.toStringAsFixed(2)),
          _buildInfoRow('Y', _accelerometerData!.y.toStringAsFixed(2)),
          _buildInfoRow('Z', _accelerometerData!.z.toStringAsFixed(2)),
          const SizedBox(height: 8),
        ],
        if (_gyroscopeData != null) ...[
          const Text(
            'Gyroscope:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          _buildInfoRow('X', _gyroscopeData!.x.toStringAsFixed(2)),
          _buildInfoRow('Y', _gyroscopeData!.y.toStringAsFixed(2)),
          _buildInfoRow('Z', _gyroscopeData!.z.toStringAsFixed(2)),
        ],
        if (_accelerometerData == null && _gyroscopeData == null)
          const Text(
            'Sensor data not available',
            style: TextStyle(color: Colors.white70),
          ),
      ],
    );
  }

  Widget _buildPermissionsCard() {
    final permissions = _deviceInfo!.permissionStatus;
    return _buildInfoCard(
      'Permissions',
      Icons.security,
      const Color(0xFFFFD93D),
      [
        _buildInfoRow(
          'Granted',
          '${permissions.grantedCount}/${permissions.totalCount}',
        ),
        _buildProgressBar(
          'Permission Status',
          permissions.grantedPercentage / 100,
          _getPermissionColor(permissions.grantedPercentage),
        ),
        const SizedBox(height: 8),
        ...permissions.permissionStatuses.entries.map((entry) {
          final permission = entry.key.toString().split('.').last;
          final status = entry.value.isGranted ? 'Granted' : 'Denied';
          final color = entry.value.isGranted ? Colors.green : Colors.red;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    permission,
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInfoCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 60) return Colors.green;
    if (level > 30) return Colors.orange;
    return Colors.red;
  }

  Color _getRamColor(double percentage) {
    if (percentage < 50) return Colors.green;
    if (percentage < 80) return Colors.orange;
    return Colors.red;
  }

  Color _getStorageColor(double percentage) {
    if (percentage < 50) return Colors.green;
    if (percentage < 80) return Colors.orange;
    return Colors.red;
  }

  Color _getPermissionColor(double percentage) {
    if (percentage == 100) return Colors.green;
    if (percentage > 70) return Colors.orange;
    return Colors.red;
  }
}
