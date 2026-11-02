import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_db.dart';
import '../models/spot.dart';
import '../services/location_service.dart';
import '../services/map_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/amap_view.dart';

/// Map browsing works independently of trips and GPS availability.
class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({super.key, this.tripId});
  final int? tripId;

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  final _search = TextEditingController();
  final _location = LocationService.instance;
  List<Spot> _spots = [];
  int? _selectedSpotId;

  Spot? get _destination {
    if (_spots.isEmpty) return null;
    for (final spot in _spots) {
      if (spot.id == _selectedSpotId) return spot;
    }
    return _spots.first;
  }

  @override
  void initState() {
    super.initState();
    _location.addListener(_changed);
    _location.start();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    if (widget.tripId == null) return;
    try {
      final spots = await AppDb.instance.spots(widget.tripId!);
      if (mounted) setState(() => _spots = spots);
    } catch (_) {}
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _location.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  Future<void> _find({bool baidu = false}) async {
    final query =
        _search.text.trim().isEmpty && baidu ? '附近' : _search.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先输入要查找的地点')));
      return;
    }
    final lon = _location.mapLongitude;
    final lat = _location.mapLatitude;
    final uri = baidu
        ? Uri.parse(
            'baidumap://map/place/search?query=${Uri.encodeComponent(query)}'
            '&coord_type=gcj02&src=andr.luji.app'
            '${lat != null && lon != null ? '&location=$lat,$lon' : ''}')
        : Uri.https('uri.amap.com', '/search', {
            'keyword': query,
            'view': 'map',
            'src': 'luji',
            'callnative': '1',
            if (lon != null && lat != null) 'center': '$lon,$lat',
          });
    if (baidu) {
      await MapLauncher.launchOrGuide(context, uri,
          appName: '百度地图', storeUrl: MapLauncher.baiduStore);
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开地图搜索，请检查网络或浏览器')));
    }
  }

  Future<void> _openWeb() async {
    final keyword = _search.text.trim().isEmpty ? '附近' : _search.text.trim();
    final uri = Uri.https('uri.amap.com', '/search',
        {'keyword': keyword, 'view': 'map', 'src': 'luji'});
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开网页版地图')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _location.mapLatitude;
    final lon = _location.mapLongitude;
    final destination = _destination;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('智能地图'),
        actions: [TextButton(onPressed: _openWeb, child: const Text('网页版'))],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AmapRouteMap(
                height: 360,
                myLat: lat ?? destination?.lat,
                myLon: lon ?? destination?.lon,
                showMyLocation: lat != null && lon != null,
                spots: [
                  for (final spot in _spots)
                    AmapSpot(spot.name, spot.lat, spot.lon,
                        isDestination: spot.id == destination?.id)
                ],
                summaryText:
                    '${_spots.length} 个地点 · ${lat == null ? '尚未定位' : '实时定位'}',
              ),
              const SizedBox(height: 10),
              Text(
                  lat == null
                      ? (_location.error ?? '正在获取当前位置；地图可先浏览')
                      : '已获取当前位置，可直接在地图上查看并导航',
                  style: const TextStyle(color: AppColors.secondary)),
              TextButton.icon(
                onPressed: _location.retry,
                icon: const Icon(Icons.my_location),
                label: const Text('重新定位'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (_spots.isNotEmpty)
          Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButton<int>(
                          isExpanded: true,
                          value: destination?.id,
                          items: [
                            for (final spot in _spots)
                              DropdownMenuItem(
                                  value: spot.id, child: Text(spot.name))
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedSpotId = value),
                        ),
                        Text(
                            '距 ${destination!.name}：${_location.distanceLabel(destination.lat, destination.lon)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        if (destination.desc?.isNotEmpty == true)
                          Text(destination.desc!,
                              style:
                                  const TextStyle(color: AppColors.secondary)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          OutlinedButton(
                              onPressed: () => MapLauncher.launchOrGuide(
                                  context,
                                  MapLauncher.amapRoute(
                                      toLat: destination.lat,
                                      toLon: destination.lon,
                                      toName: destination.name),
                                  appName: '高德地图',
                                  storeUrl: MapLauncher.amapStore),
                              child: const Text('高德导航')),
                          OutlinedButton(
                              onPressed: () => MapLauncher.launchOrGuide(
                                  context,
                                  MapLauncher.baiduRoute(
                                      toLat: destination.lat,
                                      toLon: destination.lon),
                                  appName: '百度地图',
                                  storeUrl: MapLauncher.baiduStore),
                              child: const Text('百度地图')),
                          OutlinedButton(
                              onPressed: () => launchUrl(
                                  MapLauncher.amapWeb(
                                      toLat: destination.lat,
                                      toLon: destination.lon,
                                      toName: destination.name),
                                  mode: LaunchMode.externalApplication),
                              child: const Text('网页版')),
                        ]),
                      ]))),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _find(),
          decoration: InputDecoration(
            labelText: '搜索地点',
            hintText: '输入城市、景点或地址',
            suffixIcon:
                IconButton(onPressed: _find, icon: const Icon(Icons.search)),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
            onPressed: _find,
            icon: const Icon(Icons.map_outlined),
            label: const Text('高德搜索'),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () => _find(baidu: true),
            icon: const Icon(Icons.alt_route),
            label: const Text('百度地图'),
          )),
        ]),
        const SizedBox(height: 12),
        const Text('地图与地点搜索无需创建行程。定位失败时仍可浏览地图、搜索地点或切换到其他地图。',
            style: TextStyle(color: AppColors.secondary, fontSize: 12)),
      ]),
    );
  }
}
