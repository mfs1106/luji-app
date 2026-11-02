import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';

import '../data/app_db.dart';
import '../models/coupon.dart';
import '../models/expense.dart';
import '../models/itinerary_item.dart';
import '../models/reminder.dart';
import '../models/spot.dart';
import '../models/ticket.dart';
import '../models/travel_note.dart';
import '../models/trip.dart';
import '../services/location_service.dart';
import '../services/bill_import_service.dart';
import '../services/map_launcher.dart';
import '../services/meituan_launcher.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/amap_view.dart';
import '../widgets/donut_chart.dart';
import 'trip_editor_dialog.dart';

enum PlannerSection { map, itinerary, budget, meituan, route, reminder, notes }

/// All seven features use the same persisted trip data. No screen creates demo data.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.section, this.tripId});
  final PlannerSection section;
  final int? tripId;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with WidgetsBindingObserver {
  final _db = AppDb.instance;
  Trip? trip;
  List<Spot> spots = [];
  List<ItineraryItem> items = [];
  List<Expense> expenses = [];
  List<Reminder> reminders = [];
  List<TravelNote> notes = [];
  List<Ticket> tickets = [];
  List<Coupon> coupons = [];
  int day = 1;
  int? destinationId;
  bool loading = true;
  String? loadError;
  String? budgetCity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocationService.instance.addListener(_locationChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationService.instance.removeListener(_locationChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.section == PlannerSection.reminder) {
      _load();
    }
  }

  void _locationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final allTrips = await _db.trips();
      Trip? active;
      if (widget.section == PlannerSection.reminder) {
        final now = DateTime.now();
        active = Trip(
            id: 0,
            title: '独立提醒',
            city: '',
            startDate: now,
            endDate: now,
            days: 1,
            budgetTotal: 0);
      } else {
        for (final t in allTrips) {
          if (t.id == widget.tripId) active = t;
        }
        active ??= allTrips.isEmpty ? null : allTrips.first;
      }
      if (active == null) {
        if (mounted)
          setState(() {
            trip = null;
            loading = false;
            loadError = null;
          });
        return;
      }
      final id = active.id!;
      if (day > active.days) day = active.days;
      final result = await Future.wait<Object>([
        _db.spots(id),
        _db.items(id, day),
        _db.expenses(id),
        _db.reminders(id),
        _db.notes(id),
        _db.tickets(id),
        _db.coupons(id),
      ]);
      if (widget.section == PlannerSection.reminder) {
        for (final old in (result[3] as List<Reminder>).where((r) => r.isGeo)) {
          if (old.id != null) {
            await ReminderService.instance.cancel(old.id!);
            await _db.deleteReminder(old.id!);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        trip = active;
        spots = result[0] as List<Spot>;
        items = result[1] as List<ItineraryItem>;
        expenses = result[2] as List<Expense>;
        reminders =
            (result[3] as List<Reminder>).where((r) => !r.isGeo).toList();
        notes = result[4] as List<TravelNote>;
        tickets = result[5] as List<Ticket>;
        coupons = result[6] as List<Coupon>;
        loading = false;
        loadError = null;
      });
      if (widget.section == PlannerSection.reminder) {
        await ReminderService.instance.resyncAll(reminders);
      }
    } catch (error) {
      if (mounted)
        setState(() {
          loading = false;
          loadError = '读取失败：$error';
        });
    }
  }

  String get _title => switch (widget.section) {
        PlannerSection.map => '智能地图',
        PlannerSection.itinerary => '景点行程',
        PlannerSection.budget => '旅行记账',
        PlannerSection.meituan => '美团直订',
        PlannerSection.route => '路线规划',
        PlannerSection.reminder => '时间提醒',
        PlannerSection.notes => '旅行笔记',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (widget.section == PlannerSection.itinerary)
            TextButton(onPressed: _ticketDrawer, child: const Text('电子票夹')),
          if (widget.section == PlannerSection.route)
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成')),
        ],
      ),
      body: loadError != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(loadError!),
              TextButton(onPressed: _load, child: const Text('重试')),
            ]))
          : loading
              ? const Center(child: CircularProgressIndicator())
              : trip == null
                  ? const Center(child: Text('还没有行程，请先回首页创建行程'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        children: _content(),
                      ),
                    ),
    );
  }

  List<Widget> _content() => switch (widget.section) {
        PlannerSection.map => _mapContent(),
        PlannerSection.itinerary => _itineraryContent(),
        PlannerSection.budget => _budgetContent(),
        PlannerSection.meituan => _meituanContent(),
        PlannerSection.route => _routeContent(),
        PlannerSection.reminder => _reminderContent(),
        PlannerSection.notes => _notesContent(),
      };

  Widget _card(Widget child, {Key? key}) => Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [AppShadows.card]),
        child: child,
      );

  Widget _action(String text, VoidCallback onTap,
          {IconData icon = Icons.add}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.icon(
            onPressed: onTap, icon: Icon(icon), label: Text(text)),
      );

  Widget _empty(String message) => _card(Text(message));

  void _message(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDelete(String name) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('删除$name？'),
          content: const Text('删除后无法恢复。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除')),
          ],
        ),
      ) ??
      false;

  List<Widget> _daySelector() => [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: List.generate(trip!.days, (index) {
            final value = index + 1;
            return Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 12),
              child: ChoiceChip(
                label: Text('第 $value 天'),
                selected: day == value,
                onSelected: (_) {
                  setState(() => day = value);
                  _load();
                },
              ),
            );
          })),
        ),
      ];

  Spot? get _destination {
    if (spots.isEmpty) return null;
    for (final s in spots) {
      if (s.id == destinationId) return s;
    }
    return spots.first;
  }

  List<Widget> _mapContent() {
    final location = LocationService.instance;
    final destination = _destination;
    return [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(location.position == null
            ? (location.error ?? '正在获取当前位置…')
            : '已获取当前位置，可查看与目的地的实时距离'),
        TextButton.icon(
            onPressed: () => location.retry(),
            icon: const Icon(Icons.my_location),
            label: const Text('刷新定位')),
      ])),
      if (spots.isNotEmpty)
        _card(Column(children: [
          DropdownButton<int>(
            isExpanded: true,
            value: destination?.id,
            items: spots
                .map((s) =>
                    DropdownMenuItem(value: s.id, child: Text('目的地：${s.name}')))
                .toList(),
            onChanged: (id) => setState(() => destinationId = id),
          ),
          AmapRouteMap(
            height: 230,
            myLat: location.mapLatitude ?? destination!.lat,
            myLon: location.mapLongitude ?? destination!.lon,
            showMyLocation: location.mapLatitude != null,
            spots: spots
                .map((s) => AmapSpot(s.name, s.lat, s.lon,
                    isDestination: s.id == destination!.id))
                .toList(),
            summaryText: '${spots.length} 个地点',
          ),
          const SizedBox(height: 8),
          Text(
              '距 ${destination!.name}：${location.distanceLabel(destination.lat, destination.lon)}'),
          if (location.position == null)
            const Text('未定位时地图以目的地为中心；距离将在定位后显示。'),
        ])),
      if (spots.isEmpty) _empty('还没有地点。添加地点后可查看地图、实时距离和导航。'),
      _action('添加地点', () => _editSpot()),
      ...spots.map((s) => _card(ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.name),
            subtitle:
                Text('${s.city} · ${location.distanceLabel(s.lat, s.lon)}'),
            trailing: PopupMenuButton<String>(
              onSelected: (choice) async {
                if (choice == 'edit') _editSpot(s);
                if (choice == 'delete' && await _confirmDelete(s.name)) {
                  await _db.deleteSpot(s.id!);
                  await _load();
                }
                if (choice == 'navigate') _navigate(s);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'navigate', child: Text('去这里')),
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ))),
      if (destination != null)
        Wrap(spacing: 8, children: [
          OutlinedButton(
              onPressed: () => _navigate(destination),
              child: const Text('高德导航')),
          OutlinedButton(
              onPressed: () => MapLauncher.launchOrGuide(
                  context,
                  MapLauncher.baiduRoute(
                      toLat: destination.lat, toLon: destination.lon),
                  appName: '百度地图',
                  storeUrl: MapLauncher.baiduStore),
              child: const Text('百度地图')),
          OutlinedButton(
              onPressed: () => MapLauncher.launchOrGuide(
                  context,
                  MapLauncher.amapWeb(
                      toLat: destination.lat,
                      toLon: destination.lon,
                      toName: destination.name),
                  appName: '网页版地图',
                  storeUrl: MapLauncher.amapStore),
              child: const Text('网页版')),
        ]),
    ];
  }

  void _navigate(Spot s) => MapLauncher.launchOrGuide(context,
      MapLauncher.amapRoute(toLat: s.lat, toLon: s.lon, toName: s.name),
      appName: '高德地图', storeUrl: MapLauncher.amapStore);

  void _navigateLeg(ItineraryItem item) {
    final index = items.indexOf(item);
    final target = spots.where((s) => s.id == item.spotId).firstOrNull;
    if (target == null) return;
    final previous = index > 0
        ? spots.where((s) => s.id == items[index - 1].spotId).firstOrNull
        : null;
    MapLauncher.launchOrGuide(
      context,
      MapLauncher.amapRoute(
        fromLat: previous?.lat,
        fromLon: previous?.lon,
        fromName: previous?.name,
        toLat: target.lat,
        toLon: target.lon,
        toName: target.name,
        mode: item.transport == 'walk'
            ? 2
            : item.transport == 'bus'
                ? 1
                : 0,
      ),
      appName: '高德地图',
      storeUrl: MapLauncher.amapStore,
    );
  }

  Future<void> _bookSpot(Spot spot) async {
    final direct = spot.bookingUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      try {
        if (await launchUrl(Uri.parse(direct),
            mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(text: spot.name));
    final opened = await MeituanLauncher.open(MeituanLauncher.typeTicket,
        city: spot.city, spot: spot.name);
    if (!opened) _message('无法打开美团门票，请检查网络或在地点编辑中填写具体商品链接');
  }

  Future<void> _ticketDrawer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
          child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .7,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('电子票夹 · ${tickets.length} 张',
              style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _editTicket();
              },
              icon: const Icon(Icons.add),
              label: const Text('添加电子票')),
          if (tickets.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('还没有电子票。购票后可在这里保存票号和二维码。')),
          ...tickets.map((t) => ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: Text(t.name),
                subtitle: Text('${t.typeLabel} · ${_date(t.useTime)}'),
                onTap: () => _showTicket(t),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      Navigator.pop(ctx);
                      _editTicket(t);
                    }
                    if (v == 'delete' && await _confirmDelete(t.name)) {
                      await _db.deleteTicket(t.id!);
                      await _load();
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              )),
        ]),
      )),
    );
  }

  List<Widget> _itineraryContent() {
    final todaySpots = spots.where((s) => s.dayIndex == day).toList();
    final byId = {for (final s in todaySpots) s.id: s};
    return [
      ..._daySelector(),
      _card(AmapRouteMap(
        height: 180,
        myLat: todaySpots.isEmpty ? null : todaySpots.first.lat,
        myLon: todaySpots.isEmpty ? null : todaySpots.first.lon,
        spots: [
          for (final item in items)
            if (byId[item.spotId] != null)
              AmapSpot(byId[item.spotId]!.name, byId[item.spotId]!.lat,
                  byId[item.spotId]!.lon,
                  isDestination: item == items.last)
        ],
        summaryText: 'Day $day · ${todaySpots.length} 个地点',
      )),
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('第 $day 天 · ${items.length} 个安排',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      if (items.isEmpty) _empty('第 $day 天还没有地点。点击下方添加，路线会同步建立。'),
      ...items.map((item) {
        final spot = byId[item.spotId];
        final status = spot?.ticketStatus;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 55,
              child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(item.startTime,
                      style: const TextStyle(fontWeight: FontWeight.w600)))),
          Column(children: [
            Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 14),
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle)),
            Container(width: 2, height: 76, color: AppColors.border),
          ]),
          const SizedBox(width: 10),
          Expanded(
              child: _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(item.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600))),
                  if (status == 'pending')
                    TextButton(
                        onPressed: () => _bookSpot(spot!),
                        child: const Text('去购票')),
                  PopupMenuButton<String>(
                    onSelected: (choice) async {
                      if (choice == 'edit' && spot != null) _editSpot(spot);
                      if (choice == 'route') _editItem(item);
                      if (choice == 'navigate' && spot != null) _navigate(spot);
                      if (choice == 'delete' &&
                          spot != null &&
                          await _confirmDelete(spot.name)) {
                        await _db.deleteSpot(spot.id!);
                        await _load();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'route', child: Text('编辑时间与路线')),
                      if (spot != null) ...const [
                        PopupMenuItem(value: 'edit', child: Text('编辑地点')),
                        PopupMenuItem(value: 'navigate', child: Text('导航到这里')),
                        PopupMenuItem(value: 'delete', child: Text('删除地点')),
                      ],
                    ],
                  ),
                ]),
                Text(
                    '${item.startTime}–${item.endTime} · ${item.transportLabel}'
                    '${spot == null ? '' : ' · ${spot.ticketStatus == 'pending' ? '待购票' : spot.ticketStatus == 'paid' ? '已购票' : '无需购票'}'}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.secondary)),
                if (spot?.desc?.isNotEmpty == true)
                  Text(spot!.desc!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.secondary)),
              ]))),
        ]);
      }),
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () => _editSpot(),
                icon: const Icon(Icons.add),
                label: const Text('添加景点'))),
        const SizedBox(width: 10),
        Expanded(
            child: FilledButton.icon(
                onPressed: items.length > 1 ? _optimizeRoute : null,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('优化路线'))),
      ]),
    ];
  }

  List<Widget> _budgetContent() {
    final spent = expenses
        .where((e) => !e.isEstimated)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final planned = expenses
        .where((e) => e.isEstimated)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final cities = expenses.map((e) => e.city).toSet().toList()..sort();
    final visible = budgetCity == null
        ? expenses
        : expenses.where((e) => e.city == budgetCity).toList();
    final categories = <String, double>{};
    for (final e in visible.where((e) => !e.isEstimated)) {
      categories[e.categoryLabel] =
          (categories[e.categoryLabel] ?? 0) + e.amount;
    }
    return [
      Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('行程总支出', style: TextStyle(color: Colors.white70)),
            Text('¥${spent.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            Text(
                '剩余 ¥${(trip!.budgetTotal - spent).toStringAsFixed(2)}  ·  预算 ¥${trip!.budgetTotal.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('计划支出 ¥${planned.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
                value: trip!.budgetTotal <= 0
                    ? 0
                    : (spent / trip!.budgetTotal).clamp(0.0, 1.0),
                color: Colors.white,
                backgroundColor: Colors.white24),
            const SizedBox(height: 5),
            Text(
                spent > trip!.budgetTotal && trip!.budgetTotal > 0
                    ? '已超出预算'
                    : '预算正常',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
      if (cities.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('全部城市'),
                selected: budgetCity == null,
                onSelected: (_) => setState(() => budgetCity = null)),
            ...cities.map((city) => ChoiceChip(
                label: Text(city),
                selected: budgetCity == city,
                onSelected: (_) => setState(() => budgetCity = city))),
          ]),
        ),
      if (categories.isNotEmpty)
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('消费构成',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            DonutChart(size: 110, strokeWidth: 14, segments: [
              for (var index = 0; index < categories.length; index++)
                DonutSegment(
                    categories.values.elementAt(index),
                    [
                      AppColors.primary,
                      AppColors.green,
                      AppColors.amber,
                      AppColors.purple,
                      AppColors.red,
                      const Color(0xFF16A085),
                      const Color(0xFFE67E22),
                      const Color(0xFFE84393),
                      const Color(0xFF2C3E50),
                      const Color(0xFF00B8D4),
                    ][index % 10])
            ]),
            const SizedBox(width: 16),
            Expanded(
                child: Column(children: [
              for (var index = 0; index < categories.length; index++)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: [
                                AppColors.primary,
                                AppColors.green,
                                AppColors.amber,
                                AppColors.purple,
                                AppColors.red,
                                const Color(0xFF16A085),
                                const Color(0xFFE67E22),
                                const Color(0xFFE84393),
                                const Color(0xFF2C3E50),
                                const Color(0xFF00B8D4),
                              ][index % 10],
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(categories.keys.elementAt(index),
                              style: const TextStyle(fontSize: 12))),
                      Text(
                          '¥${categories.values.elementAt(index).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ]))
            ])),
          ]),
        ])),
      if (expenses.isEmpty) _empty('还没有账目。'),
      ...visible.map((e) => _card(ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
                '${e.isEstimated ? '预算' : '实付'} · ${e.itemName.isEmpty ? e.categoryLabel : e.itemName} · ¥${e.amount.toStringAsFixed(2)}'),
            subtitle: Text(
                '${e.city} · ${e.placeName.isEmpty ? '未填写商家' : e.placeName} · ${e.paymentMethod.isEmpty ? '未填写支付方式' : e.paymentMethod}\n${e.note ?? e.sourceLabel} · ${_date(e.spentAt)}'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (choice) async {
                if (choice == 'edit') _editExpense(e);
                if (choice == 'delete' && await _confirmDelete('这笔账')) {
                  await _db.deleteExpense(e.id!);
                  await _load();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ))),
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: _importBill,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('导入账单'))),
        const SizedBox(width: 10),
        Expanded(
            child: FilledButton.icon(
                onPressed: () => _editExpense(),
                icon: const Icon(Icons.add),
                label: const Text('记一笔'))),
      ]),
    ];
  }

  List<Widget> _meituanContent() {
    final pending = spots.where((s) => s.ticketStatus == 'pending').toList();
    return [
      if (pending.isNotEmpty)
        Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.amberTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.amber)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.amber),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('还有 ${pending.length} 项未购买',
                      style: const TextStyle(
                          color: AppColors.amber,
                          fontWeight: FontWeight.bold))),
              TextButton(
                  onPressed: () => _bookSpot(pending.first),
                  child: const Text('去购买')),
            ])),
      if (pending.isNotEmpty)
        ...pending.map((s) => _card(ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.confirmation_number_outlined,
                  color: AppColors.primary),
              title: Text(s.name),
              subtitle: Text('${s.city} · 第 ${s.dayIndex} 天 · 待购门票'),
              trailing: FilledButton(
                  onPressed: () => _bookSpot(s), child: const Text('去购票')),
            ))),
      _card(ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.local_activity_outlined,
              color: AppColors.primary),
          title: const Text('景点门票'),
          subtitle: const Text('进入美团门票搜索与预订'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => MeituanLauncher.open(MeituanLauncher.typeTicket,
              city: trip!.city))),
      _card(ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.train_outlined, color: AppColors.green),
          title: const Text('火车票'),
          subtitle: const Text('进入美团火车票查询与预订'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => MeituanLauncher.open(MeituanLauncher.typeTrain,
              city: trip!.city))),
      _card(ListTile(
          contentPadding: EdgeInsets.zero,
          leading:
              const Icon(Icons.restaurant_outlined, color: AppColors.amber),
          title: const Text('美食团购'),
          subtitle: const Text('进入美团选择餐饮产品'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => MeituanLauncher.open(MeituanLauncher.typeFood,
              city: trip!.city))),
      _card(ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('美团订单'),
          subtitle: const Text('查看已购门票与待使用电子券'),
          trailing: const Icon(Icons.open_in_new),
          onTap: MeituanLauncher.openOrderCenter)),
      _card(ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.share_outlined, color: AppColors.green),
        title: const Text('分享到微信'),
        subtitle: const Text('将景点名称和购票入口发给同行人'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final first = pending.isEmpty ? null : pending.first;
          final link = first?.bookingUrl?.isNotEmpty == true
              ? first!.bookingUrl!
              : 'https://i.meituan.com/awp/hfe/travel-merchant/index.html';
          final ok = await MeituanLauncher.shareToWeChat(
              '${first == null ? trip!.city : first.name} 门票：$link');
          if (!ok) _message('微信未安装或无法唤起');
        },
      )),
      Row(children: [
        const Expanded(
            child: Text('我的优惠券',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        TextButton(onPressed: _scanCoupon, child: const Text('OCR 识别')),
      ]),
      if (coupons.isEmpty) _empty('还没有保存优惠券。购票功能不依赖优惠券。'),
      ...coupons.map((c) => _card(ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${c.name} ${c.value}'),
            subtitle: Text('${c.scope} · 有效期至 ${_date(c.validTo)}'),
            onTap: () => c.deepLink == null || c.deepLink!.isEmpty
                ? MeituanLauncher.openOrderCenter()
                : MeituanLauncher.openCoupon(c.deepLink!),
            trailing: PopupMenuButton<String>(
              onSelected: (choice) async {
                if (choice == 'edit') _editCoupon(c);
                if (choice == 'delete' && await _confirmDelete(c.name)) {
                  await _db.deleteCoupon(c.id!);
                  await _load();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ))),
      _action('添加优惠券', () => _editCoupon()),
      const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('购买与支付在美团完成。',
              style: TextStyle(color: AppColors.secondary, fontSize: 12))),
    ];
  }

  List<Widget> _routeContent() => [
        _card(Row(children: [
          const Icon(Icons.place_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(trip!.city,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                Text(
                    '${trip!.days} 天 ${trip!.days - 1} 晚 · ${_date(trip!.startDate)}–${_date(trip!.endDate)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.secondary)),
              ])),
          TextButton(onPressed: _editTrip, child: const Text('编辑')),
        ])),
        ..._daySelector(),
        Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.blueTint,
                borderRadius: BorderRadius.circular(10)),
            child: Text(
                'Day $day · ${items.length} 个安排 · 交通约 ${items.fold<int>(0, (sum, item) => sum + item.transportMinutes)} 分钟',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600))),
        if (items.isNotEmpty)
          _card(AmapRouteMap(
            height: 180,
            spots: [
              for (final item in items)
                for (final spot in spots)
                  if (spot.id == item.spotId)
                    AmapSpot(spot.name, spot.lat, spot.lon,
                        isDestination: item == items.last)
            ],
            summaryText: 'Day $day · 地点顺序',
          )),
        if (items.length > 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('图中蓝线表示地点顺序。点击安排右侧菜单的“查看这一段道路路线”，可在高德查看实际道路规划。',
                style: TextStyle(fontSize: 12, color: AppColors.secondary)),
          ),
        _action('添加路线安排', () => _editItem()),
        _action('从地图新增地点', () => _editSpot(),
            icon: Icons.add_location_alt_outlined),
        if (items.isEmpty) _empty('这一天还没有安排，添加地点后即可规划路线。'),
        if (items.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final sorted = [...items];
              sorted.insert(newIndex, sorted.removeAt(oldIndex));
              await _db.updateItemsOrder(sorted);
              await _load();
            },
            children: items
                .map((i) => _card(
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.drag_indicator),
                      title: Text('${i.startTime}  ${i.name}'),
                      subtitle: Text('${i.transportLabel} · ${i.note ?? ''}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (choice) async {
                          if (choice == 'edit') _editItem(i);
                          if (choice == 'delete' &&
                              await _confirmDelete(i.name)) {
                            await _db.deleteItem(i.id!);
                            await _load();
                          }
                          if (choice == 'navigate') {
                            for (final s in spots) {
                              if (s.id == i.spotId) {
                                _navigate(s);
                                break;
                              }
                            }
                          }
                          if (choice == 'leg') _navigateLeg(i);
                        },
                        itemBuilder: (_) => [
                          if (i.spotId != null)
                            const PopupMenuItem(
                                value: 'navigate', child: Text('去这里')),
                          if (i.spotId != null)
                            const PopupMenuItem(
                                value: 'leg', child: Text('查看这一段道路路线')),
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('删除')),
                        ],
                      ),
                    ),
                    key: ValueKey(i.id)))
                .toList(),
          ),
        if (items.length > 1)
          _action('按地点距离优化顺序', _optimizeRoute, icon: Icons.auto_fix_high),
      ];

  List<Widget> _reminderContent() => [
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('时间提醒 · ${reminders.length} 项',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold))),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('到点由系统发出高优先级通知和提醒音。请允许通知权限。'),
          TextButton(
              onPressed: Geolocator.openAppSettings,
              child: const Text('打开应用权限设置')),
        ])),
        _action('添加时间提醒', () => _editReminder()),
        if (reminders.isEmpty) _empty('还没有时间提醒。'),
        ...reminders.map((r) => _card(SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.title),
              subtitle: Text(
                '${r.repeatRule == 'daily' ? '每天' : (r.triggerTime == null ? '未设置时间' : _date(r.triggerTime!))} '
                '${r.triggerTime == null ? '' : '${r.triggerTime!.hour.toString().padLeft(2, '0')}:${r.triggerTime!.minute.toString().padLeft(2, '0')}'}'
                '${r.subtitle.isEmpty ? '' : ' · ${r.subtitle}'}',
              ),
              value: r.enabled,
              onChanged: (v) async {
                final next = r.copyWith(enabled: v);
                await _db.updateReminder(next);
                await ReminderService.instance.register(next);
                await _load();
              },
              secondary: PopupMenuButton<String>(
                onSelected: (choice) async {
                  if (choice == 'edit') _editReminder(r);
                  if (choice == 'delete' && await _confirmDelete(r.title)) {
                    await ReminderService.instance.cancel(r.id!);
                    await _db.deleteReminder(r.id!);
                    await _load();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ))),
      ];

  List<Widget> _notesContent() => [
        _card(Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat(
              '${spots.map((s) => s.city).where((s) => s.isNotEmpty).toSet().length}',
              '城市'),
          _stat('${trip!.days}', '天行程'),
          _stat('${spots.length}', '地点'),
          _stat(
              '¥${expenses.where((e) => !e.isEstimated).fold<double>(0, (sum, e) => sum + e.amount).toStringAsFixed(0)}',
              '实付'),
        ])),
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('今日待办 · 防错乱',
                style: Theme.of(context).textTheme.titleMedium)),
        if (spots.where((s) => s.ticketStatus == 'pending').isEmpty)
          _empty('当前没有待购门票。'),
        ...spots
            .where((s) => s.ticketStatus == 'pending')
            .map((s) => _card(ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.amber),
                  title: Text('${s.name} · 待购票'),
                  subtitle: Text('第 ${s.dayIndex} 天 · ${s.city}'),
                  trailing: TextButton(
                      onPressed: () => _bookSpot(s), child: const Text('去购买')),
                ))),
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(
                  child: Text('旅途随手记 · ${notes.length}',
                      style: Theme.of(context).textTheme.titleMedium)),
              TextButton(
                  onPressed: () => _editNote(), child: const Text('新建笔记')),
            ])),
        if (notes.isEmpty) _empty('还没有笔记。写下旅途中的见闻吧。'),
        ...notes.map((n) => _card(Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(n.content,
                    maxLines: 4, overflow: TextOverflow.ellipsis),
                subtitle: Text('第 ${n.dayIndex} 天 · ${_date(n.createdAt)}'),
                onTap: () => _editNote(n),
                trailing: PopupMenuButton<String>(
                  onSelected: (choice) async {
                    if (choice == 'photo') _addNotePhoto(n);
                    if (choice == 'edit') _editNote(n);
                    if (choice == 'delete' && await _confirmDelete('这篇笔记')) {
                      await _db.deleteNote(n.id!);
                      await _load();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'photo', child: Text('添加照片')),
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ),
              if (n.photos.isNotEmpty)
                SizedBox(
                    height: 80,
                    child:
                        ListView(scrollDirection: Axis.horizontal, children: [
                      for (final photo in n.photos)
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Image.file(File(photo),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_outlined))),
                    ])),
            ]))),
        _card(ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_activity_outlined,
                color: AppColors.primary),
            title: const Text('美团门票与出行'),
            subtitle: const Text('按需浏览当前城市的商品'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => MeituanLauncher.open(MeituanLauncher.typeTicket,
                city: trip!.city))),
      ];

  Widget _stat(String value, String label) => Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.secondary)),
      ]);

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _editTrip() async {
    final updated = await showDialog<Trip>(
        context: context, builder: (_) => TripEditorDialog(original: trip));
    if (updated == null) return;
    await _db.updateTrip(updated);
    if (updated.days < trip!.days) {
      await _db.reassignDaysAfterTripResize(updated.id!, updated.days);
    }
    if (day > updated.days) day = updated.days;
    await _load();
  }

  Future<Map<String, String>?> _ask(String title, List<_Field> fields) async {
    final key = GlobalKey<FormState>();
    final controllers = {
      for (final f in fields.where((f) => f.options == null))
        f.name: TextEditingController(text: f.initial),
    };
    final choices = {
      for (final f in fields.where((f) => f.options != null)) f.name: f.initial,
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                      child: Form(
                    key: key,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final f in fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: f.options == null
                              ? TextFormField(
                                  controller: controllers[f.name],
                                  maxLines: f.name == 'content' ? 5 : 1,
                                  readOnly: f.locked ||
                                      const {'date', 'start', 'end', 'time'}
                                          .contains(f.name),
                                  onTap: const {'date', 'start', 'end', 'time'}
                                          .contains(f.name)
                                      ? () async {
                                          final current = controllers[f.name]!;
                                          if (f.name == 'date') {
                                            final picked = await showDatePicker(
                                              context: ctx,
                                              initialDate: DateTime.tryParse(
                                                      current.text) ??
                                                  trip!.startDate,
                                              firstDate: trip!.startDate,
                                              lastDate: trip!.endDate,
                                            );
                                            if (picked != null)
                                              current.text = _date(picked);
                                          } else {
                                            DateTime? pickedDate;
                                            if (f.name == 'time') {
                                              pickedDate = await showDatePicker(
                                                context: ctx,
                                                initialDate: DateTime.tryParse(
                                                        current.text
                                                            .replaceFirst(
                                                                ' ', 'T')) ??
                                                    DateTime.now(),
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2100),
                                              );
                                              if (pickedDate == null) return;
                                            }
                                            final parts =
                                                current.text.split(':');
                                            final initial = TimeOfDay(
                                              hour: int.tryParse(parts.first
                                                      .split(' ')
                                                      .last) ??
                                                  9,
                                              minute: int.tryParse(
                                                      parts.length > 1
                                                          ? parts.last
                                                          : '') ??
                                                  0,
                                            );
                                            if (!ctx.mounted) return;
                                            final picked = await showTimePicker(
                                              context: ctx,
                                              initialTime: initial,
                                              builder: (context, child) =>
                                                  MediaQuery(
                                                data: MediaQuery.of(context)
                                                    .copyWith(
                                                        alwaysUse24HourFormat:
                                                            true),
                                                child: child!,
                                              ),
                                            );
                                            if (picked != null) {
                                              final clock =
                                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                              current.text = pickedDate == null
                                                  ? clock
                                                  : '${_date(pickedDate)} $clock';
                                            }
                                          }
                                        }
                                      : null,
                                  keyboardType: f.numeric
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true, signed: true)
                                      : TextInputType.text,
                                  decoration: InputDecoration(
                                      labelText: f.label,
                                      border: const OutlineInputBorder()),
                                  validator: (v) => f.required &&
                                          (v == null || v.trim().isEmpty)
                                      ? '请填写${f.label}'
                                      : null,
                                )
                              : DropdownButtonFormField<String>(
                                  value: choices[f.name],
                                  decoration: InputDecoration(
                                      labelText: f.label,
                                      border: const OutlineInputBorder()),
                                  items: f.options!.entries
                                      .map((e) => DropdownMenuItem(
                                          value: e.key, child: Text(e.value)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null)
                                      update(() => choices[f.name] = v);
                                  },
                                ),
                        ),
                    ]),
                  )),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        if (!key.currentState!.validate()) return;
                        Navigator.pop(ctx, {
                          for (final entry in controllers.entries)
                            entry.key: entry.value.text.trim(),
                          ...choices,
                        });
                      },
                      child: const Text('保存')),
                ],
              )),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<AMapPoi?> _pickNamedPlace() async {
    AMapPoi? selected;
    final nameCtl = TextEditingController();
    final result = await showDialog<AMapPoi>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: const Text('选择地点'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AmapRouteMap(
                height: 300,
                myLat: LocationService.instance.mapLatitude ??
                    (spots.isEmpty ? null : spots.first.lat),
                myLon: LocationService.instance.mapLongitude ??
                    (spots.isEmpty ? null : spots.first.lon),
                spots: const [],
                summaryText: selected?.name ?? '点击地图上标有名称的地点',
                onPoiTap: (poi) {
                  if (poi.name?.trim().isNotEmpty == true &&
                      poi.latLng != null) {
                    refresh(() {
                      selected = poi;
                      nameCtl.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              Text(
                  selected == null
                      ? '可在地图上点击已有名称的地点，或在下方手动输入地点名称。'
                      : '已选：${selected!.name}',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: '手动输入地点名称（选填）',
                  hintText: '如：鼓浪屿、曾厝垵',
                  prefixIcon: Icon(Icons.edit_location_alt_outlined),
                ),
                onChanged: (_) => refresh(() {}),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('取消')),
            FilledButton(
              onPressed: (selected == null && nameCtl.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(
                      dialog,
                      selected ??
                          AMapPoi(name: nameCtl.text.trim(), latLng: null)),
              child: const Text('使用此地点'),
            ),
          ],
        ),
      ),
    );
    nameCtl.dispose();
    return result;
  }

  Future<void> _editSpot([Spot? old]) async {
    final poi = await _pickNamedPlace();
    if (poi == null && old == null) return;
    final selectedDate = trip!.startDate.add(
        Duration(days: old?.dayIndex == null ? day - 1 : old!.dayIndex - 1));
    final existingItems = old == null
        ? <ItineraryItem>[]
        : await _db.items(trip!.id!, old.dayIndex);
    final matching =
        existingItems.where((item) => item.spotId == old?.id).firstOrNull;
    final result = await _ask(old == null ? '添加地点' : '编辑地点', [
      _Field('name', '地图地点', poi?.name ?? old?.name ?? '', locked: true),
      _Field('city', '城市', old?.city ?? trip!.city),
      _Field('date', '行程日期', _date(selectedDate)),
      _Field('start', '开始时间（24 小时制）', matching?.startTime ?? '09:00'),
      _Field('end', '结束时间（24 小时制）', matching?.endTime ?? '10:00'),
      _Field('category', '类型', old?.category ?? 'spot', options: const {
        'spot': '景点',
        'food': '餐饮',
        'hotel': '住宿',
        'other': '其他'
      }),
      _Field('ticket', '门票', old?.ticketStatus ?? 'none',
          options: const {'none': '无需购票', 'pending': '待购票', 'paid': '已购票'}),
      _Field('open', '开放时间（可选）', old?.openTime ?? '', required: false),
      _Field('price', '门票价格（可选）', old?.ticketPrice?.toString() ?? '',
          required: false, numeric: true),
      _Field('booking', '门票购买链接（可选）', old?.bookingUrl ?? '', required: false),
      _Field('desc', '备注', old?.desc ?? '', required: false),
    ]);
    if (result == null) return;
    final date = DateTime.tryParse(result['date']!);
    final newDay = date == null
        ? null
        : date
                .difference(DateTime(trip!.startDate.year,
                    trip!.startDate.month, trip!.startDate.day))
                .inDays +
            1;
    final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    final start = result['start']!;
    final end = result['end']!;
    final stay = timePattern.hasMatch(start) && timePattern.hasMatch(end)
        ? (int.parse(end.substring(0, 2)) * 60 + int.parse(end.substring(3))) -
            (int.parse(start.substring(0, 2)) * 60 +
                int.parse(start.substring(3)))
        : -1;
    final price =
        result['price']!.isEmpty ? null : double.tryParse(result['price']!);
    final booking = result['booking']!.trim();
    if (newDay == null || newDay < 1 || newDay > trip!.days) {
      _message('请选择行程日期范围内的有效日期');
      return;
    }
    if (stay <= 0) {
      _message('结束时间需晚于开始时间');
      return;
    }
    if ((result['price']!.isNotEmpty && (price == null || price < 0)) ||
        (booking.isNotEmpty &&
            !booking.startsWith('https://') &&
            !booking.startsWith('http://') &&
            !booking.startsWith('imeituan://'))) {
      _message('请检查价格（需 ≥ 0）与购票链接（需为 http/https/imeituan 链接）');
      return;
    }
    final spot = Spot(
      id: old?.id,
      tripId: trip!.id!,
      name: result['name']!,
      city: result['city']!,
      poiId: poi?.id ?? old?.poiId,
      lat: poi?.latLng?.latitude ??
          old?.lat ??
          LocationService.instance.mapLatitude ??
          0.0,
      lon: poi?.latLng?.longitude ??
          old?.lon ??
          LocationService.instance.mapLongitude ??
          0.0,
      dayIndex: newDay,
      category: result['category']!,
      ticketStatus: result['ticket']!,
      openTime: result['open']!,
      stayMinutes: stay,
      ticketPrice: price,
      desc: result['desc'],
      bookingUrl: booking.isEmpty ? null : booking,
    );
    if (old == null) {
      final spotId = await _db.insertSpot(spot);
      final dayItems = await _db.items(trip!.id!, newDay);
      await _db.insertItem(ItineraryItem(
        tripId: trip!.id!,
        dayIndex: newDay,
        spotId: spotId,
        name: spot.name,
        startTime: start,
        endTime: end,
        transport: 'walk',
        transportMinutes: 0,
        sortOrder: dayItems.length,
      ));
    } else {
      await _db.updateSpot(spot);
      await _db.syncItemsForSpot(spot);
      if (matching != null) {
        await _db.updateItem(matching.copyWith(
            dayIndex: newDay, name: spot.name, startTime: start, endTime: end));
      }
    }
    await _load();
  }

  Future<void> _editItem([ItineraryItem? old]) async {
    if (spots.isEmpty) {
      await _editSpot();
      return;
    }
    final options = {for (final s in spots) '${s.id}': s.name};
    final selected = old?.spotId?.toString();
    final result = await _ask(old == null ? '添加路线安排' : '编辑路线安排', [
      _Field('spot', '地点',
          options.containsKey(selected) ? selected! : options.keys.first,
          options: options),
      _Field(
          'date',
          '行程日期',
          _date(trip!.startDate.add(Duration(
              days: old?.dayIndex == null ? day - 1 : old!.dayIndex - 1)))),
      _Field('start', '开始时间（HH:mm）', old?.startTime ?? '09:00'),
      _Field('end', '结束时间（HH:mm）', old?.endTime ?? '10:00'),
      _Field('transport', '出行方式', old?.transport ?? 'walk', options: const {
        'walk': '步行',
        'bus': '公交',
        'car': '驾车',
        'train': '火车'
      }),
      _Field('minutes', '交通分钟数', '${old?.transportMinutes ?? 0}',
          numeric: true),
      _Field('note', '备注', old?.note ?? '', required: false),
    ]);
    if (result == null) return;
    final minutes = int.tryParse(result['minutes']!);
    final chosenDate = DateTime.tryParse(result['date']!);
    final chosenDay = chosenDate == null
        ? 0
        : chosenDate
                .difference(DateTime(trip!.startDate.year,
                    trip!.startDate.month, trip!.startDate.day))
                .inDays +
            1;
    final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (minutes == null || minutes < 0) {
      _message('交通分钟数需为非负整数');
      return;
    }
    if (chosenDay < 1 || chosenDay > trip!.days) {
      _message('请选择行程日期范围内的有效日期');
      return;
    }
    if (!timePattern.hasMatch(result['start']!) ||
        !timePattern.hasMatch(result['end']!) ||
        result['end']!.compareTo(result['start']!) <= 0) {
      _message('结束时间需晚于开始时间（格式 HH:mm）');
      return;
    }
    final spot = spots.firstWhere((s) => s.id.toString() == result['spot']);
    final item = ItineraryItem(
      id: old?.id,
      tripId: trip!.id!,
      dayIndex: chosenDay,
      spotId: spot.id,
      name: spot.name,
      startTime: result['start']!,
      endTime: result['end']!,
      transport: result['transport']!,
      transportMinutes: minutes,
      sortOrder:
          old?.sortOrder ?? (await _db.items(trip!.id!, chosenDay)).length,
      note: result['note'],
    );
    if (old == null) {
      await _db.insertItem(item);
    } else {
      await _db.updateItem(item);
    }
    await _load();
  }

  Future<void> _optimizeRoute() async {
    final located = <ItineraryItem>[];
    final rest = List<ItineraryItem>.from(items);
    var lat = LocationService.instance.position?.latitude;
    var lon = LocationService.instance.position?.longitude;
    while (rest.isNotEmpty) {
      if (lat == null || lon == null) {
        final first = rest.removeAt(0);
        located.add(first);
        final spot = spots.where((s) => s.id == first.spotId).firstOrNull;
        lat = spot?.lat;
        lon = spot?.lon;
        continue;
      }
      rest.sort((a, b) {
        final sa = spots.where((s) => s.id == a.spotId).firstOrNull;
        final sb = spots.where((s) => s.id == b.spotId).firstOrNull;
        final da = sa == null
            ? double.infinity
            : Geolocator.distanceBetween(lat!, lon!, sa.lat, sa.lon);
        final db = sb == null
            ? double.infinity
            : Geolocator.distanceBetween(lat!, lon!, sb.lat, sb.lon);
        return da.compareTo(db);
      });
      final next = rest.removeAt(0);
      located.add(next);
      final spot = spots.where((s) => s.id == next.spotId).firstOrNull;
      if (spot != null) {
        lat = spot.lat;
        lon = spot.lon;
      }
    }
    await _db.updateItemsOrder(located);
    await _load();
    _message('已按地点直线距离重排；实际道路路线请在地图 App 中确认');
  }

  Future<void> _editExpense([Expense? old]) async {
    final result = await _ask(old == null ? '记一笔' : '编辑账目', [
      _Field('kind', '记录类型', old?.isEstimated == true ? 'planned' : 'paid',
          options: const {'paid': '实际支出', 'planned': '计划预算'}),
      _Field('amount', '金额（元）', old?.amount.toString() ?? '', numeric: true),
      _Field('category', '类别', old?.category ?? 'food', options: const {
        'ticket': '门票',
        'food': '餐饮',
        'hotel': '住宿',
        'transport': '交通',
        'other': '其他'
      }),
      _Field('city', '城市', old?.city ?? trip!.city),
      _Field('place', '餐厅／酒店／商店／地点名称', old?.placeName ?? ''),
      _Field('item', '商品或服务名称', old?.itemName ?? ''),
      _Field('payment', '支付方式',
          old?.paymentMethod.isNotEmpty == true ? old!.paymentMethod : '微信支付',
          options: const {
            '微信支付': '微信支付',
            '支付宝': '支付宝',
            '银行卡': '银行卡',
            '现金': '现金',
            '其他': '其他'
          }),
      _Field('note', '用途与详细说明', old?.note ?? '', required: false),
    ]);
    if (result == null) return;
    final amount = double.tryParse(result['amount']!);
    if (amount == null || amount <= 0) {
      _message('金额必须大于 0');
      return;
    }
    final expense = Expense(
      id: old?.id,
      tripId: trip!.id!,
      city: result['city']!,
      category: result['category']!,
      amount: amount,
      isEstimated: result['kind'] == 'planned',
      source: old?.source ?? 'manual',
      tradeNo: old?.tradeNo,
      spentAt: old?.spentAt ?? DateTime.now(),
      note: result['note'],
      placeName: result['place']!,
      itemName: result['item']!,
      paymentMethod: result['payment']!,
    );
    if (old == null) {
      await _db.insertExpense(expense);
    } else {
      await _db.updateExpense(expense);
    }
    await _load();
  }

  Future<void> _importBill() async {
    final source = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(title: const Text('导入账单'), children: [
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                      '微信：我 → 服务 → 钱包 → 账单 → 常见问题 → 下载账单。\n支付宝：我的 → 账单 → 导出交易记录。\n选择导出的 CSV 文件后，仅导入当前行程日期内的支出。',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.secondary))),
              SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, 'wechat'),
                  child: const Text('微信支付 CSV')),
              SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, 'alipay'),
                  child: const Text('支付宝 CSV')),
            ]));
    if (source == null) return;
    try {
      final count = await BillImportService.pickAndImport(
          tripId: trip!.id!,
          city: trip!.city,
          source: source,
          startDate: trip!.startDate,
          endDate: trip!.endDate);
      if (count == null) return;
      await _load();
      _message('已导入 $count 笔支出；重复交易已跳过');
    } catch (error) {
      _message('导入失败：$error');
    }
  }

  Future<void> _editNote([TravelNote? old]) async {
    final result = await _ask(old == null ? '写笔记' : '编辑笔记', [
      _Field('content', '笔记内容', old?.content ?? ''),
      _Field('day', '行程第几天', '${old?.dayIndex ?? day}', numeric: true),
    ]);
    if (result == null) return;
    final newDay = int.tryParse(result['day']!);
    if (newDay == null || newDay < 1 || newDay > trip!.days) {
      _message('天数超出行程范围');
      return;
    }
    final note = TravelNote(
        id: old?.id,
        tripId: trip!.id!,
        dayIndex: newDay,
        content: result['content']!,
        photos: old?.photos ?? const [],
        createdAt: old?.createdAt ?? DateTime.now());
    if (old == null) {
      await _db.insertNote(note);
    } else {
      await _db.updateNote(note);
    }
    await _load();
  }

  Future<void> _addNotePhoto(TravelNote note) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = await File(image.path).copy(
          '${dir.path}${Platform.pathSeparator}note_${note.id}_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await _db.updateNote(TravelNote(
        id: note.id,
        tripId: note.tripId,
        dayIndex: note.dayIndex,
        content: note.content,
        photos: [...note.photos, file.path],
        createdAt: note.createdAt,
      ));
      await _load();
    } catch (error) {
      _message('照片保存失败：$error');
    }
  }

  Future<void> _editTicket([Ticket? old]) async {
    final result = await _ask(old == null ? '添加电子票' : '编辑电子票', [
      _Field('name', '票据名称', old?.name ?? ''),
      _Field('type', '类型', old?.type ?? 'ticket', options: const {
        'ticket': '景点门票',
        'train': '火车票',
        'flight': '机票',
        'hotel': '酒店'
      }),
      _Field(
          'time',
          '使用时间（YYYY-MM-DD HH:mm）',
          old == null
              ? '${_date(DateTime.now())} 09:00'
              : '${_date(old.useTime)} ${old.useTime.hour.toString().padLeft(2, '0')}:${old.useTime.minute.toString().padLeft(2, '0')}'),
      _Field('code', '票号', old?.code ?? '', required: false),
      _Field('qr', '二维码原文（可选）', old?.qrContent ?? '', required: false),
      _Field('link', '订单网址（可选）', old?.deepLink ?? '', required: false),
      _Field('status', '状态', old?.status ?? 'pending',
          options: const {'pending': '待使用', 'used': '已使用', 'refunded': '已退票'}),
    ]);
    if (result == null) return;
    final when = DateTime.tryParse(result['time']!);
    if (when == null) {
      _message('使用时间格式应为 YYYY-MM-DD HH:mm');
      return;
    }
    final link = result['link']!;
    if (link.isNotEmpty && Uri.tryParse(link)?.hasScheme != true) {
      _message('订单网址需要包含 https:// 等协议');
      return;
    }
    final ticket = Ticket(
      id: old?.id,
      tripId: trip!.id!,
      name: result['name']!,
      type: result['type']!,
      useTime: when,
      code: result['code']!,
      qrContent: result['qr']!,
      deepLink: link.isEmpty ? null : link,
      status: result['status']!,
    );
    if (old == null) {
      await _db.insertTicket(ticket);
    } else {
      await _db.updateTicket(ticket);
    }
    await _load();
  }

  void _showTicket(Ticket ticket) {
    showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(ticket.name),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                if (ticket.qrContent.isNotEmpty)
                  QrImageView(data: ticket.qrContent, size: 190),
                Text('票号：${ticket.code ?? '未填写'}'),
                Text('使用时间：${_date(ticket.useTime)}'),
                if (ticket.qrContent.isEmpty)
                  const Text('未保存二维码内容；请打开原始订单出示票据。'),
              ]),
              actions: [
                if (ticket.deepLink != null)
                  TextButton(
                      onPressed: () => launchUrl(Uri.parse(ticket.deepLink!),
                          mode: LaunchMode.externalApplication),
                      child: const Text('打开原订单')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭')),
              ],
            ));
  }

  Future<void> _scanCoupon() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final raw = await const MethodChannel('luji/files')
          .invokeMethod<String>('recognizeCoupon', {'path': image.path});
      if (raw == null || raw.trim().isEmpty) {
        _message('图片中未识别到文字，请手动添加优惠券');
        return;
      }
      await _editCoupon(null, raw);
    } catch (error) {
      _message('图片识别失败：$error');
    }
  }

  Future<void> _editCoupon([Coupon? old, String? recognizedText]) async {
    final lines = recognizedText
        ?.split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final detectedName = lines == null || lines.isEmpty ? '' : lines.first;
    final detectedValue = RegExp(r'(?:¥|￥)\s*\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*元')
            .firstMatch(recognizedText ?? '')
            ?.group(0) ??
        '';
    final result = await _ask(old == null ? '添加优惠券' : '编辑优惠券', [
      _Field('name', '券名称', old?.name ?? detectedName),
      _Field('value', '面额或折扣', old?.value ?? detectedValue),
      _Field('scope', '适用范围（请核对识别结果）', old?.scope ?? ''),
      _Field(
          'from', '有效期开始（YYYY-MM-DD）', _date(old?.validFrom ?? DateTime.now())),
      _Field('to', '有效期结束（YYYY-MM-DD）',
          _date(old?.validTo ?? DateTime.now().add(const Duration(days: 30)))),
      _Field('code', '券码', old?.code ?? '', required: false),
      _Field('link', '使用链接（可选）', old?.deepLink ?? '', required: false),
    ]);
    if (result == null) return;
    final from = DateTime.tryParse(result['from']!);
    final to = DateTime.tryParse(result['to']!);
    if (from == null || to == null || to.isBefore(from)) {
      _message('请填写有效的优惠券日期');
      return;
    }
    final coupon = Coupon(
      id: old?.id,
      tripId: trip!.id!,
      name: result['name']!,
      value: result['value']!,
      scope: result['scope']!,
      validFrom: from,
      validTo: to,
      code: result['code'],
      deepLink: result['link']!.isEmpty ? null : result['link'],
    );
    if (old == null) {
      await _db.insertCoupon(coupon);
    } else {
      await _db.updateCoupon(coupon);
    }
    await _load();
  }

  Future<void> _editReminder([Reminder? old]) async {
    final now = DateTime.now().add(const Duration(hours: 1));
    final result = await _ask(old == null ? '添加提醒' : '编辑提醒', [
      _Field('title', '提醒标题', old?.title ?? ''),
      _Field('subtitle', '提醒内容', old?.subtitle ?? '', required: false),
      _Field('repeat', '重复', old?.repeatRule ?? 'once',
          options: const {'once': '仅一次', 'daily': '每天'}),
      _Field(
          'time',
          '提醒日期和时间',
          old?.triggerTime == null
              ? '${_date(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
              : '${_date(old!.triggerTime!)} ${old.triggerTime!.hour.toString().padLeft(2, '0')}:${old.triggerTime!.minute.toString().padLeft(2, '0')}',
          required: true),
    ]);
    if (result == null) return;
    final when = DateTime.tryParse(result['time']!.replaceFirst(' ', 'T'));
    if (when == null ||
        (result['repeat'] == 'once' && !when.isAfter(DateTime.now()))) {
      _message('请选择将来的提醒时间');
      return;
    }
    final reminder = Reminder(
      id: old?.id,
      tripId: trip!.id!,
      type: 'alarm',
      title: result['title']!,
      subtitle: result['subtitle']!,
      triggerTime: when,
      repeatRule: result['repeat'] == 'daily' ? 'daily' : null,
    );
    final permitted = await ReminderService.instance.requestPermission();
    if (!permitted) {
      _message('请在系统设置中允许通知，否则到点无法提醒');
    }
    await ReminderService.instance.requestExactPermission();
    if (old != null) await ReminderService.instance.cancel(old.id!);
    final id = old == null ? await _db.insertReminder(reminder) : old.id!;
    if (old != null) await _db.updateReminder(reminder);
    await ReminderService.instance.register(reminder.copyWith(id: id));
    await _load();
  }
}

class _Field {
  const _Field(this.name, this.label, this.initial,
      {this.required = true,
      this.numeric = false,
      this.options,
      this.locked = false});
  final String name;
  final String label;
  final String initial;
  final bool required;
  final bool numeric;
  final Map<String, String>? options;
  final bool locked;
}
