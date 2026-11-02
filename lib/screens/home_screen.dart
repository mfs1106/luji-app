import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_db.dart';
import '../models/trip.dart';
import '../models/reminder.dart';
import '../services/location_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'planner_screen.dart';
import 'map_explore_screen.dart';
import 'trip_editor_dialog.dart';

/// Empty-first home. The feature grid is always available; trip content comes
/// only from the user's local database.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Trip? _trip;
  List<Trip> _trips = [];
  double _spent = 0;
  int _pending = 0;
  List<int> _order = List.generate(7, (i) => i);
  String? _loadError;
  int? _selectedTripId;

  @override
  void initState() {
    super.initState();
    _load().then((_) => _resyncActiveReminders());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationService.instance.start();
    });
  }

  Future<void> _load() async {
    try {
      final db = AppDb.instance;
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // The SQLite trip remains usable if preferences are unavailable.
      }
      final trips = await db.trips().timeout(const Duration(seconds: 10));
      final selectedId = _selectedTripId ?? prefs?.getInt('active_trip_id');
      Trip? trip;
      for (final t in trips) {
        if (t.id == selectedId) trip = t;
      }
      trip ??= trips.isEmpty ? null : trips.first;
      final costs = trip == null
          ? 0.0
          : (await db.expenses(trip.id!))
              .fold<double>(0, (sum, e) => sum + e.amount);
      final pending = trip == null
          ? 0
          : (await db.spots(trip.id!))
              .where((s) => s.ticketStatus == 'pending')
              .length;
      final savedOrder =
          prefs?.getStringList('feature_order')?.map(int.tryParse).toList();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _trip = trip;
        _spent = costs;
        _pending = pending;
        _order = savedOrder != null &&
                savedOrder.length == 7 &&
                savedOrder.toSet().length == 7 &&
                savedOrder.every((e) => e != null && e >= 0 && e < 7)
            ? savedOrder.cast<int>()
            : List.generate(7, (i) => i);
        _loadError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = '行程读取失败：$error');
    }
  }

  Future<void> _selectTrip(Trip trip) async {
    _selectedTripId = trip.id;
    try {
      await (await SharedPreferences.getInstance())
          .setInt('active_trip_id', trip.id!);
    } catch (_) {}
    await _load();
    await _resyncActiveReminders();
  }

  Future<void> _resyncActiveReminders() async {
    final active = _trip;
    try {
      final independent = await AppDb.instance.reminders(0);
      final linked = active == null
          ? <Reminder>[]
          : await AppDb.instance.reminders(active.id!);
      await ReminderService.instance.resyncAll([...independent, ...linked]);
    } catch (_) {
      // Reminder sync must never block the home screen.
    }
  }

  Future<void> _editTrip([Trip? old]) async {
    final result = await showDialog<Trip>(
        context: context, builder: (_) => TripEditorDialog(original: old));
    if (result == null) return;
    try {
      final id = old == null
          ? await AppDb.instance
              .insertTrip(result)
              .timeout(const Duration(seconds: 10))
          : old.id!;
      if (id <= 0) throw StateError('数据库未返回有效行程编号');
      if (old != null) await AppDb.instance.updateTrip(result);
      _selectedTripId = id;
      try {
        await (await SharedPreferences.getInstance())
            .setInt('active_trip_id', id);
      } catch (_) {
        // The trip itself is already persisted in SQLite.
      }
      await _load();
      if (mounted && old == null && _loadError == null && _trip?.id == id) {
        _open(PlannerSection.itinerary);
      } else if (mounted && old == null && _loadError == null) {
        setState(() => _loadError = '行程已保存，但暂时无法显示，请点“重试”');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = '行程保存失败：$error');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  Future<void> _chooseTrip() async {
    await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
                const ListTile(title: Text('我的行程')),
                ..._trips.map((trip) => ListTile(
                      title: Text(trip.title),
                      subtitle: Text('${trip.city} · ${trip.days} 天'),
                      selected: trip.id == _trip?.id,
                      onTap: () {
                        Navigator.pop(ctx);
                        _selectTrip(trip);
                      },
                      trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final yes = await showDialog<bool>(
                                context: ctx,
                                builder: (dialog) => AlertDialog(
                                      title: Text('删除“${trip.title}”？'),
                                      content:
                                          const Text('关联的地点、账目、提醒和笔记也会删除。'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, false),
                                            child: const Text('取消')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, true),
                                            child: const Text('删除')),
                                      ],
                                    ));
                            if (yes == true) {
                              for (final reminder
                                  in await AppDb.instance.reminders(trip.id!)) {
                                if (reminder.id != null) {
                                  await ReminderService.instance
                                      .cancel(reminder.id!);
                                }
                              }
                              await AppDb.instance.deleteTrip(trip.id!);
                              if (ctx.mounted) Navigator.pop(ctx);
                              (await SharedPreferences.getInstance())
                                  .remove('active_trip_id');
                              _selectedTripId = null;
                              await _load();
                              await _resyncActiveReminders();
                            }
                          }),
                    )),
                ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('创建新行程'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _editTrip();
                    }),
              ]),
            ));
  }

  Future<void> _reorderFeatures() async {
    final order = List<int>.from(_order);
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
                child: SizedBox(
              height: 470,
              child: StatefulBuilder(
                  builder: (ctx, update) => Column(children: [
                        const ListTile(title: Text('拖动调整功能顺序')),
                        Expanded(
                            child: ReorderableListView(
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex--;
                            update(() {
                              order.insert(newIndex, order.removeAt(oldIndex));
                            });
                          },
                          children: [
                            for (final id in order)
                              ListTile(
                                  key: ValueKey(id),
                                  leading: Icon(_features[id].icon),
                                  title: Text(_features[id].name),
                                  trailing: const Icon(Icons.drag_handle))
                          ],
                        )),
                        FilledButton(
                            onPressed: () async {
                              await (await SharedPreferences.getInstance())
                                  .setStringList('feature_order',
                                      order.map((e) => '$e').toList());
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _load();
                            },
                            child: const Text('保存顺序')),
                      ])),
            )));
  }

  void _open(PlannerSection section) {
    if (section == PlannerSection.map) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MapExploreScreen(tripId: _trip?.id)));
      return;
    }
    if (section == PlannerSection.reminder) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const PlannerScreen(
              section: PlannerSection.reminder, tripId: 0)));
      return;
    }
    if (_trip == null) {
      _editTrip();
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => PlannerScreen(section: section, tripId: _trip!.id),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final progress = trip == null || trip.budgetTotal <= 0
        ? 0.0
        : (_spent / trip.budgetTotal).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.travel_explore,
                  color: Colors.white, size: 27)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('旅记',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('一体化旅行笔记本'),
          ]),
          const Spacer(),
          IconButton(
              onPressed: _chooseTrip,
              icon: const Icon(Icons.menu),
              tooltip: '我的行程'),
        ]),
        const SizedBox(height: 18),
        if (_loadError != null)
          AppCard(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_loadError!, style: const TextStyle(color: Colors.red)),
              TextButton(onPressed: _load, child: const Text('重试')),
            ],
          )),
        if (trip == null)
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('无行程',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('添加城市、日期与预算，再自由规划地点和路线。'),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: () => _editTrip(),
                    icon: const Icon(Icons.add),
                    label: const Text('创建行程')),
              ]))
        else
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Text('当前行程'),
                  const Spacer(),
                  TextButton(
                      onPressed: () => _editTrip(trip), child: const Text('编辑'))
                ]),
                Text(
                    '${trip.city} · ${trip.days} 天 ${trip.days > 0 ? trip.days - 1 : 0} 晚',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(
                    '${trip.startDate.month}.${trip.startDate.day} - ${trip.endDate.month}.${trip.endDate.day} · ¥${_spent.toStringAsFixed(0)} / ¥${trip.budgetTotal.toStringAsFixed(0)}'),
                const SizedBox(height: 12),
                AppProgressBar(value: progress),
                const SizedBox(height: 8),
                Text('$_pending 项待购票'),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => _open(PlannerSection.itinerary),
                        child: const Text('查看行程 ›'))),
              ])),
        const SizedBox(height: 18),
        Row(children: [
          const Text('全部功能',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton(onPressed: _reorderFeatures, child: const Text('调整顺序'))
        ]),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            for (final id in _order)
              AppCard(
                onTap: () => _open(_features[id].section),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBubble(
                          icon: _features[id].icon,
                          color: _featureColor(id),
                          background: _featureTint(id)),
                      const Spacer(),
                      Text(_features[id].name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_features[id].subtitle,
                          style: const TextStyle(fontSize: 11)),
                    ]),
              )
          ],
        ),
      ])),
    );
  }

  static const _features = [
    _Feature('智能地图', '实时定位与导航', Icons.map_outlined, PlannerSection.map),
    _Feature('景点行程', '地点与电子票', Icons.calendar_month_outlined,
        PlannerSection.itinerary),
    _Feature('旅行记账', '预算与明细', Icons.account_balance_wallet_outlined,
        PlannerSection.budget),
    _Feature(
        '美团直订', '门票与出行预订', Icons.local_offer_outlined, PlannerSection.meituan),
    _Feature('路线规划', '自定义路线', Icons.alt_route_outlined, PlannerSection.route),
    _Feature('时间提醒', '定时闹钟与通知', Icons.notifications_active_outlined,
        PlannerSection.reminder),
    _Feature('旅行笔记', '旅途记录', Icons.menu_book_outlined, PlannerSection.notes),
  ];

  static Color _featureColor(int id) => switch (id) {
        1 || 6 => AppColors.green,
        2 || 3 => AppColors.amber,
        4 => AppColors.purple,
        _ => AppColors.primary,
      };

  static Color _featureTint(int id) => switch (id) {
        1 || 6 => AppColors.greenTint,
        2 || 3 => AppColors.amberTint,
        4 => AppColors.purpleTint,
        _ => AppColors.blueTint,
      };
}

class _Feature {
  const _Feature(this.name, this.subtitle, this.icon, this.section);
  final String name;
  final String subtitle;
  final IconData icon;
  final PlannerSection section;
}
