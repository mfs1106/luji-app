import 'package:flutter/material.dart';

import '../models/trip.dart';

/// The number of days is chosen directly by the user. The end date follows it.
class TripEditorDialog extends StatefulWidget {
  const TripEditorDialog({super.key, this.original});
  final Trip? original;

  @override
  State<TripEditorDialog> createState() => _TripEditorDialogState();
}

class _TripEditorDialogState extends State<TripEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _city;
  late final TextEditingController _days;
  late final TextEditingController _budget;
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    final old = widget.original;
    _title = TextEditingController(text: old?.title ?? '');
    _city = TextEditingController(text: old?.city ?? '');
    _days = TextEditingController(text: '${old?.days ?? 1}');
    _budget = TextEditingController(text: '${old?.budgetTotal ?? 0}');
    _start = old?.startDate ?? DateTime.now();
    _days.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _days.removeListener(_refresh);
    _title.dispose();
    _city.dispose();
    _days.dispose();
    _budget.dispose();
    super.dispose();
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final days = int.tryParse(_days.text.trim()) ?? 1;
    final end = _start.add(Duration(days: days > 0 ? days - 1 : 0));
    return AlertDialog(
      title: Text(widget.original == null ? '创建新行程' : '编辑行程'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: '行程名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入行程名称' : null,
              ),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: '目的地城市'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入目的地城市' : null,
              ),
              TextFormField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '行程天数'),
                validator: (value) {
                  final count = int.tryParse(value?.trim() ?? '');
                  return count == null || count < 1 || count > 365
                      ? '请输入 1～365 天'
                      : null;
                },
              ),
              TextFormField(
                controller: _budget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '总预算（元，可填 0）'),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  return amount == null || amount < 0 ? '请输入有效预算' : null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _start = picked);
                },
                icon: const Icon(Icons.date_range),
                label: Text('开始日期：${_date(_start)}'),
              ),
              Text('结束日期自动计算：${_date(end)}'),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final count = int.parse(_days.text.trim());
            Navigator.pop(
                context,
                Trip(
                  id: widget.original?.id,
                  title: _title.text.trim(),
                  city: _city.text.trim(),
                  startDate: _start,
                  endDate: _start.add(Duration(days: count - 1)),
                  days: count,
                  budgetTotal: double.parse(_budget.text.trim()),
                  status: widget.original?.status ?? 'planned',
                ));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
