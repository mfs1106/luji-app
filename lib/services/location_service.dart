import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Device position is never replaced with a demo coordinate.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final instance = LocationService._();

  Position? position;
  String? error;
  StreamSubscription<Position>? _subscription;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!await Geolocator.isLocationServiceEnabled()) {
      error = '请开启手机定位服务';
      notifyListeners();
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      error = '未获得定位权限，可在系统设置中开启';
      notifyListeners();
      return;
    }
    error = null;
    try {
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12));
      notifyListeners();
    } catch (e) {
      error = '暂时无法获取当前位置';
      notifyListeners();
    }
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((next) {
      position = next;
      error = null;
      notifyListeners();
    }, onError: (_) {
      error = '定位更新失败，请检查权限或网络';
      notifyListeners();
    });
  }

  Future<void> retry() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
    await start();
  }

  double? distanceMeters(double lat, double lon) {
    final current = position;
    if (current == null) return null;
    final mapped = _toGcj02(current.latitude, current.longitude);
    return Geolocator.distanceBetween(mapped.$1, mapped.$2, lat, lon);
  }

  /// High-level phone GPS uses WGS-84; AMap POIs use GCJ-02 in mainland China.
  double? get mapLatitude => position == null
      ? null
      : _toGcj02(position!.latitude, position!.longitude).$1;
  double? get mapLongitude => position == null
      ? null
      : _toGcj02(position!.latitude, position!.longitude).$2;

  (double, double) _toGcj02(double lat, double lon) {
    if (lat < 0.8293 || lat > 55.8271 || lon < 72.004 || lon > 137.8347) {
      return (lat, lon);
    }
    const a = 6378245.0;
    const ee = 0.006693421622965943;
    final x = lon - 105.0;
    final y = lat - 35.0;
    var dLat = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    dLat += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    dLat +=
        (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
            2.0 /
            3.0;
    dLat += (160.0 * math.sin(y / 12.0 * math.pi) +
            320.0 * math.sin(y * math.pi / 30.0)) *
        2.0 /
        3.0;
    var dLon = 300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * math.sqrt(x.abs());
    dLon += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    dLon +=
        (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
            2.0 /
            3.0;
    dLon += (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) *
        2.0 /
        3.0;
    final radLat = lat / 180.0 * math.pi;
    var magic = math.sin(radLat);
    magic = 1 - ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat = dLat * 180.0 / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
    dLon = dLon * 180.0 / (a / sqrtMagic * math.cos(radLat) * math.pi);
    return (lat + dLat, lon + dLon);
  }

  (double, double) mapToGps(double lat, double lon) {
    final shifted = _toGcj02(lat, lon);
    return (lat * 2 - shifted.$1, lon * 2 - shifted.$2);
  }

  String distanceLabel(double lat, double lon) {
    final meters = distanceMeters(lat, lon);
    if (meters == null) return '距离待定位';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
