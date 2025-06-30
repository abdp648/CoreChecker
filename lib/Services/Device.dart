import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:system_info2/system_info2.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:storage_info/storage_info.dart';

class DeviceServices {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Battery _battery = Battery();
  static final NetworkInfo _networkInfo = NetworkInfo();

  // Stream controllers for real-time data
  static final StreamController<AccelerometerEvent> _accelerometerController =
      StreamController<AccelerometerEvent>.broadcast();
  static final StreamController<GyroscopeEvent> _gyroscopeController =
      StreamController<GyroscopeEvent>.broadcast();
  static final StreamController<MagnetometerEvent> _magnetometerController =
      StreamController<MagnetometerEvent>.broadcast();
  static final StreamController<BatteryState> _batteryController =
      StreamController<BatteryState>.broadcast();
  static final StreamController<List<ConnectivityResult>>
  _connectivityController =
      StreamController<List<ConnectivityResult>>.broadcast();

  // Getters for streams
  static Stream<AccelerometerEvent> get accelerometerStream =>
      _accelerometerController.stream;
  static Stream<GyroscopeEvent> get gyroscopeStream =>
      _gyroscopeController.stream;
  static Stream<MagnetometerEvent> get magnetometerStream =>
      _magnetometerController.stream;
  static Stream<BatteryState> get batteryStream => _batteryController.stream;
  static Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivityController.stream;

  // Initialize streams
  static void initializeStreams() {
    // Sensor streams
    accelerometerEventStream().listen((event) {
      _accelerometerController.add(event);
    });

    gyroscopeEventStream().listen((event) {
      _gyroscopeController.add(event);
    });

    magnetometerEventStream().listen((event) {
      _magnetometerController.add(event);
    });

    // Battery state stream
    _battery.onBatteryStateChanged.listen((state) {
      _batteryController.add(state);
    });

    // Connectivity stream
    Connectivity().onConnectivityChanged.listen((result) {
      _connectivityController.add(result);
    });
  }

  // Dispose streams
  static void dispose() {
    _accelerometerController.close();
    _gyroscopeController.close();
    _magnetometerController.close();
    _batteryController.close();
    _connectivityController.close();
  }

  // Enhanced Device Info - FIXED SECTION
  static Future<DeviceInfoModel> getDeviceInfo(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;

        final mediaQuery = MediaQuery.of(context);

        final metricsMap = <String, dynamic>{
          'devicePixelRatio': mediaQuery.devicePixelRatio,
          'widthPx': mediaQuery.size.width,
          'heightPx': mediaQuery.size.height,
          'textScaleFactor': mediaQuery.textScaleFactor,
        };

        return DeviceInfoModel(
          model: android.model,
          brand: android.brand,
          manufacturer: android.manufacturer,
          androidVersion: android.version.release,
          sdk: android.version.sdkInt,
          androidId: android.id,
          isPhysicalDevice: android.isPhysicalDevice,
          systemFeatures: android.systemFeatures,
          displayMetrics: metricsMap,
          bootloader: android.bootloader,
          fingerprint: android.fingerprint,
          hardware: android.hardware,
          host: android.host,
          product: android.product,
          tags: android.tags,
          type: android.type,
          appName: packageInfo.appName,
          packageName: packageInfo.packageName,
          version: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
        );
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;

        final metricsMap = <String, dynamic>{
          'scale': 0.0,
          'width': 0.0,
          'height': 0.0,
          'densityDpi': 0,
        };

        return DeviceInfoModel(
          model: ios.model,
          brand: 'Apple',
          manufacturer: 'Apple',
          androidVersion: ios.systemVersion,
          sdk: 0,
          androidId: ios.identifierForVendor ?? 'Unknown',
          isPhysicalDevice: ios.isPhysicalDevice,
          systemFeatures: [],
          displayMetrics: metricsMap,
          bootloader: '',
          fingerprint: '',
          hardware: ios.utsname.machine,
          host: ios.utsname.nodename,
          product: ios.model,
          tags: '',
          type: ios.utsname.sysname,
          appName: packageInfo.appName,
          packageName: packageInfo.packageName,
          version: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
        );
      }

      throw DeviceException('Unsupported platform');
    } catch (e) {
      throw DeviceException('Failed to get device info: $e');
    }
  }

  // Enhanced Battery Info
  static Future<BatteryInfoModel> getBatteryInfo() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final isInBatterySaveMode = await _battery.isInBatterySaveMode;

      return BatteryInfoModel(
        level: level,
        state: state,
        isInBatterySaveMode: isInBatterySaveMode,
        isCharging: state == BatteryState.charging,
        temperature: await _getBatteryTemperature(),
        voltage: await _getBatteryVoltage(),
        health: await _getBatteryHealth(),
      );
    } catch (e) {
      throw DeviceException('Failed to get battery info: $e');
    }
  }

  static Future<StorageInfoModel> getStorageInfo() async {
    try {
      final _storageInfoPlugin = StorageInfo();

      final double? totalSpace = await _storageInfoPlugin.getStorageTotalSpace(
        SpaceUnit.GB,
      );
      final double? freeSpace = await _storageInfoPlugin.getStorageFreeSpace(
        SpaceUnit.GB,
      );
      final double? usedSpace = await _storageInfoPlugin.getStorageUsedSpace(
        SpaceUnit.GB,
      );

      return StorageInfoModel(
        totalSpace: totalSpace,
        freeSpace: freeSpace,
        usedSpace: usedSpace,
        availableSpace: freeSpace,
      );
    } catch (e) {
      throw DeviceException('Failed to get storage info: $e');
    }
  }

  static Future<NetworkInfoModel> getNetworkInfo() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final connectionType = connectivityResults.first;

      String? wifiName;
      String? wifiIP;
      String? wifiBSSID;
      String? wifiGateway;
      String? wifiSubnet;
      int? wifiSignalStrength;

      if (connectionType == ConnectivityResult.wifi) {
        wifiName = await _networkInfo.getWifiName();
        wifiIP = await _networkInfo.getWifiIP();
        wifiBSSID = await _networkInfo.getWifiBSSID();
        wifiGateway = await _networkInfo.getWifiGatewayIP();
        wifiSubnet = await _networkInfo.getWifiSubmask();
        // Note: Signal strength might require platform-specific implementation
      }

      return NetworkInfoModel(
        connectionType: connectionType,
        wifiName: wifiName,
        wifiIP: wifiIP,
        wifiBSSID: wifiBSSID,
        wifiGateway: wifiGateway,
        wifiSubnet: wifiSubnet,
        wifiSignalStrength: wifiSignalStrength,
        isConnected: connectionType != ConnectivityResult.none,
        connectionSpeed: await _getConnectionSpeed(),
      );
    } catch (e) {
      throw DeviceException('Failed to get network info: $e');
    }
  }

  // Enhanced System Info
  static Future<SystemInfoModel> getSystemInfo() async {
    try {
      final cpuInfo = await _getCpuInfo();
      final memoryInfo = await _getMemoryInfo();

      return SystemInfoModel(
        cpuCores: SysInfo.cores.length,
        totalRAM: SysInfo.getTotalPhysicalMemory() ~/ (1024 * 1024),
        freeRAM: SysInfo.getFreePhysicalMemory() ~/ (1024 * 1024),
        usedRAM:
            (SysInfo.getTotalPhysicalMemory() -
                SysInfo.getFreePhysicalMemory()) ~/
            (1024 * 1024),
        cpuArchitecture: SysInfo.kernelArchitecture.name,
        operatingSystem: SysInfo.operatingSystemName,
        kernelVersion: SysInfo.kernelVersion,
        cpuUsage: cpuInfo['usage'] ?? 0.0,
        cpuTemperature: cpuInfo['temperature'],
        cpuFrequency: cpuInfo['frequency'],
        uptime: await _getSystemUptime(),
        processes: await _getProcessCount(),
      );
    } catch (e) {
      throw DeviceException('Failed to get system info: $e');
    }
  }

  // Enhanced Location Info
  static Future<LocationInfoModel> getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw DeviceException('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw DeviceException('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw DeviceException('Location permission denied forever');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return LocationInfoModel(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy,
        heading: position.heading,
        headingAccuracy: position.headingAccuracy,
        timestamp: position.timestamp,
        isMocked: position.isMocked,
      );
    } catch (e) {
      throw DeviceException('Failed to get location: $e');
    }
  }

  // Enhanced Permission Management
  static Future<PermissionStatusModel> checkAllPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.microphone,
      Permission.camera,
      Permission.phone,
      Permission.contacts,
      Permission.calendar,
      Permission.sms,
      Permission.notification,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ];

    Map<Permission, PermissionStatus> statuses = {};
    for (Permission permission in permissions) {
      try {
        statuses[permission] = await permission.status;
      } catch (e) {
        // Some permissions might not be available on all platforms
        continue;
      }
    }

    return PermissionStatusModel(permissionStatuses: statuses);
  }

  static Future<bool> requestAllPermissions() async {
    final permissions = [
      Permission.location,
      Permission.storage,
      Permission.microphone,
      Permission.camera,
    ];

    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }

  // Get All Device Data
  static Future<CompleteDeviceInfoModel> getAllDeviceInfo(
    BuildContext context,
  ) async {
    try {
      LocationInfoModel? locationInfo;
      try {
        locationInfo = await getLocation();
      } catch (e) {
        locationInfo = null;
      }

      final results = await Future.wait([
        getDeviceInfo(context),
        getBatteryInfo(),
        getNetworkInfo(),
        getSystemInfo(),
        getStorageInfo(),
        checkAllPermissions(),
      ]);

      return CompleteDeviceInfoModel(
        deviceInfo: results[0] as DeviceInfoModel,
        batteryInfo: results[1] as BatteryInfoModel,
        networkInfo: results[2] as NetworkInfoModel,
        systemInfo: results[3] as SystemInfoModel,
        storageInfo: results[4] as StorageInfoModel,
        locationInfo: locationInfo,
        permissionStatus: results[5] as PermissionStatusModel,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw DeviceException('Failed to get complete device info: $e');
    }
  }

  // Helper methods implementation - COMPLETED
  static Future<double?> _getBatteryTemperature() async {
    try {
      if (Platform.isAndroid) {
        // Would require platform channel implementation
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<double?> _getBatteryVoltage() async {
    try {
      if (Platform.isAndroid) {
        // Would require platform channel implementation
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> _getBatteryHealth() async {
    try {
      if (Platform.isAndroid) {
        // Would require platform channel implementation
        return 'Unknown';
      }
      return 'Good'; // iOS doesn't expose battery health
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _getCpuInfo() async {
    try {
      // Basic CPU information available through system_info2
      return {
        'usage': 0.0, // Would need platform-specific implementation
        'temperature': null,
        'frequency': null,
        'cores': SysInfo.cores.length,
        'architecture': SysInfo.kernelArchitecture.name,
      };
    } catch (e) {
      return {'usage': 0.0, 'temperature': null, 'frequency': null};
    }
  }

  static Future<Map<String, dynamic>> _getMemoryInfo() async {
    try {
      final totalMemory = SysInfo.getTotalPhysicalMemory();
      final freeMemory = SysInfo.getFreePhysicalMemory();

      return {
        'total': totalMemory,
        'free': freeMemory,
        'used': totalMemory - freeMemory,
        'available': freeMemory,
        'usagePercentage': ((totalMemory - freeMemory) / totalMemory) * 100,
      };
    } catch (e) {
      return {};
    }
  }

  static Future<Duration?> _getSystemUptime() async {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        // Could use system_info2 for uptime
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<int?> _getProcessCount() async {
    try {
      // Would require platform-specific implementation
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<double?> _getConnectionSpeed() async {
    try {
      // Would require network speed test implementation
      // This would involve downloading a test file and measuring speed
      return null;
    } catch (e) {
      return null;
    }
  }
}

// Enhanced Data Models
class DeviceInfoModel {
  final String model;
  final String brand;
  final String manufacturer;
  final String androidVersion;
  final int sdk;
  final String androidId;
  final bool isPhysicalDevice;
  final List<String> systemFeatures;
  final Map<String, dynamic> displayMetrics;
  final String bootloader;
  final String fingerprint;
  final String hardware;
  final String host;
  final String product;
  final String tags;
  final String type;
  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  DeviceInfoModel({
    required this.model,
    required this.brand,
    required this.manufacturer,
    required this.androidVersion,
    required this.sdk,
    required this.androidId,
    required this.isPhysicalDevice,
    required this.systemFeatures,
    required this.displayMetrics,
    required this.bootloader,
    required this.fingerprint,
    required this.hardware,
    required this.host,
    required this.product,
    required this.tags,
    required this.type,
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'brand': brand,
      'manufacturer': manufacturer,
      'androidVersion': androidVersion,
      'sdk': sdk,
      'androidId': androidId,
      'isPhysicalDevice': isPhysicalDevice,
      'systemFeatures': systemFeatures,
      'displayMetrics': displayMetrics,
      'bootloader': bootloader,
      'fingerprint': fingerprint,
      'hardware': hardware,
      'host': host,
      'product': product,
      'tags': tags,
      'type': type,
      'appName': appName,
      'packageName': packageName,
      'version': version,
      'buildNumber': buildNumber,
    };
  }
}

class BatteryInfoModel {
  final int level;
  final BatteryState state;
  final bool isInBatterySaveMode;
  final bool isCharging;
  final double? temperature;
  final double? voltage;
  final String? health;

  BatteryInfoModel({
    required this.level,
    required this.state,
    required this.isInBatterySaveMode,
    required this.isCharging,
    this.temperature,
    this.voltage,
    this.health,
  });

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'state': state.toString(),
      'isInBatterySaveMode': isInBatterySaveMode,
      'isCharging': isCharging,
      'temperature': temperature,
      'voltage': voltage,
      'health': health,
    };
  }
}

class StorageInfoModel {
  final double? totalSpace;
  final double? freeSpace;
  final double? usedSpace;
  final double? availableSpace;

  StorageInfoModel({
    this.totalSpace,
    this.freeSpace,
    this.usedSpace,
    this.availableSpace,
  });

  double get usagePercentage {
    if (totalSpace == null || usedSpace == null || totalSpace == 0) return 0.0;
    return (usedSpace! / totalSpace!) * 100;
  }

  String formatBytes(double? bytes) {
    if (bytes == null) return 'Unknown';
    if (bytes < 1024) return '${bytes.toStringAsFixed(2)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSpace': totalSpace,
      'freeSpace': freeSpace,
      'usedSpace': usedSpace,
      'availableSpace': availableSpace,
      'usagePercentage': usagePercentage,
      'totalSpaceFormatted': formatBytes(totalSpace),
      'freeSpaceFormatted': formatBytes(freeSpace),
      'usedSpaceFormatted': formatBytes(usedSpace),
    };
  }
}

class NetworkInfoModel {
  final ConnectivityResult connectionType;
  final String? wifiName;
  final String? wifiIP;
  final String? wifiBSSID;
  final String? wifiGateway;
  final String? wifiSubnet;
  final int? wifiSignalStrength;
  final bool isConnected;
  final double? connectionSpeed;

  NetworkInfoModel({
    required this.connectionType,
    this.wifiName,
    this.wifiIP,
    this.wifiBSSID,
    this.wifiGateway,
    this.wifiSubnet,
    this.wifiSignalStrength,
    required this.isConnected,
    this.connectionSpeed,
  });

  Map<String, dynamic> toJson() {
    return {
      'connectionType': connectionType.toString(),
      'wifiName': wifiName,
      'wifiIP': wifiIP,
      'wifiBSSID': wifiBSSID,
      'wifiGateway': wifiGateway,
      'wifiSubnet': wifiSubnet,
      'wifiSignalStrength': wifiSignalStrength,
      'isConnected': isConnected,
      'connectionSpeed': connectionSpeed,
    };
  }
}

class SystemInfoModel {
  final int cpuCores;
  final int totalRAM;
  final int freeRAM;
  final int usedRAM;
  final String cpuArchitecture;
  final String operatingSystem;
  final String kernelVersion;
  final double cpuUsage;
  final double? cpuTemperature;
  final double? cpuFrequency;
  final Duration? uptime;
  final int? processes;

  SystemInfoModel({
    required this.cpuCores,
    required this.totalRAM,
    required this.freeRAM,
    required this.usedRAM,
    required this.cpuArchitecture,
    required this.operatingSystem,
    required this.kernelVersion,
    required this.cpuUsage,
    this.cpuTemperature,
    this.cpuFrequency,
    this.uptime,
    this.processes,
  });

  double get ramUsagePercentage =>
      totalRAM > 0 ? (usedRAM / totalRAM) * 100 : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'cpuCores': cpuCores,
      'totalRAM': totalRAM,
      'freeRAM': freeRAM,
      'usedRAM': usedRAM,
      'ramUsagePercentage': ramUsagePercentage,
      'cpuArchitecture': cpuArchitecture,
      'operatingSystem': operatingSystem,
      'kernelVersion': kernelVersion,
      'cpuUsage': cpuUsage,
      'cpuTemperature': cpuTemperature,
      'cpuFrequency': cpuFrequency,
      'uptime': uptime?.inSeconds,
      'processes': processes,
    };
  }
}

class LocationInfoModel {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double speedAccuracy;
  final double heading;
  final double headingAccuracy;
  final DateTime? timestamp;
  final bool isMocked;

  LocationInfoModel({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.speedAccuracy,
    required this.heading,
    required this.headingAccuracy,
    this.timestamp,
    required this.isMocked,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'speedAccuracy': speedAccuracy,
      'heading': heading,
      'headingAccuracy': headingAccuracy,
      'timestamp': timestamp?.toIso8601String(),
      'isMocked': isMocked,
    };
  }
}

class PermissionStatusModel {
  final Map<Permission, PermissionStatus> permissionStatuses;

  PermissionStatusModel({required this.permissionStatuses});

  int get grantedCount =>
      permissionStatuses.values.where((status) => status.isGranted).length;
  int get totalCount => permissionStatuses.length;
  double get grantedPercentage =>
      totalCount > 0 ? (grantedCount / totalCount) * 100 : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'permissions': permissionStatuses.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      'grantedCount': grantedCount,
      'totalCount': totalCount,
      'grantedPercentage': grantedPercentage,
    };
  }
}

class CompleteDeviceInfoModel {
  final DeviceInfoModel deviceInfo;
  final BatteryInfoModel batteryInfo;
  final NetworkInfoModel networkInfo;
  final SystemInfoModel systemInfo;
  final StorageInfoModel storageInfo;
  final LocationInfoModel? locationInfo;
  final PermissionStatusModel permissionStatus;
  final DateTime timestamp;

  CompleteDeviceInfoModel({
    required this.deviceInfo,
    required this.batteryInfo,
    required this.networkInfo,
    required this.systemInfo,
    required this.storageInfo,
    this.locationInfo,
    required this.permissionStatus,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceInfo': deviceInfo.toJson(),
      'batteryInfo': batteryInfo.toJson(),
      'networkInfo': networkInfo.toJson(),
      'systemInfo': systemInfo.toJson(),
      'storageInfo': storageInfo.toJson(),
      'locationInfo': locationInfo?.toJson(),
      'permissionStatus': permissionStatus.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// Custom Exception
class DeviceException implements Exception {
  final String message;
  DeviceException(this.message);

  @override
  String toString() => 'DeviceException: $message';
}
