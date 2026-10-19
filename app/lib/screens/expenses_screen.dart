import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../services/app_state.dart';

const expenseCategories = <(String, IconData)>[
  ('transport', Icons.directions_car_rounded),
  ('hotels', Icons.hotel_rounded),
  ('food', Icons.restaurant_rounded),
  ('tickets', Icons.confirmation_number_rounded),
  ('shopping', Icons.shopping_bag_rounded),
  ('other', Icons.more_horiz_rounded),
];

/// Budget + expense tracker in SAR with an optional user-entered PKR rate.
/// We show when the rate was entered and never invent live exchange rates —
/// automatic rates arrive with the backend sync phase.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = S.of(context);
    final total = app.totalSpentSar;
    final today = DateTime.now();
    final todaySpent = app.spentOn(today);
    final rate = app.pkrPerSar;

    return Scaffold(
      appBar: AppBar(title: Text(s.budget)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExpense(context, app),
        icon: const Icon(Icons.add_rounded),
        label: const Text('SAR'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.emerald, AppColors.emeraldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total spent',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                  Text('${total.toStringAsFixed(0)} SAR',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                  if (rate != null)
                    Text(
                      '≈ ${(total * rate).toStringAsFixed(0)} PKR  ·  rate ${rate.toStringAsFixed(2)} (entered ${app.rateUpdatedAt == null ? '' : DateFormat('d MMM HH:mm').format(app.rateUpdatedAt!)})',
                      style: TextStyle(color: AppColors.goldLight.withValues(alpha: 0.95), fontSize: 12.5),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MiniStat(label: 'Today', value: '${todaySpent.toStringAsFixed(0)} SAR'),
                      const SizedBox(width: 10),
                      _MiniStat(
                          label: 'Budget',
                          value: app.budgetSar == null
                              ? '—'
                              : '${app.budgetSar!.toStringAsFixed(0)} SAR'),
                      if (app.budgetSar != null) ...[
                        const SizedBox(width: 10),
                        _MiniStat(
                            label: s.remaining,
                            value: '${(app.budgetSar! - total).toStringAsFixed(0)} SAR'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editNumber(context, 'Budget (SAR)', app.budgetSar,
                      (v) => app.setBudget(v)),
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: const Text('Set budget'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editNumber(context, 'PKR per 1 SAR', app.pkrPerSar,
                      (v) => app.setPkrRate(v)),
                  icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                  label: const Text('PKR rate'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...app.expenses.map((e) {
            final icon = expenseCategories
                .firstWhere((c) => c.$1 == e.category,
                    orElse: () => expenseCategories.last)
                .$2;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(icon, color: AppColors.emerald),
                title: Text(
                    '${e.amountSar.toStringAsFixed(0)} SAR · ${e.category[0].toUpperCase()}${e.category.substring(1)}'),
                subtitle: Text(
                    '${DateFormat('d MMM yyyy').format(e.date)}${e.note == null ? '' : ' · ${e.note}'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => app.deleteExpense(e.id),
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _editNumber(BuildContext context, String title, double? current,
      Future<void> Function(double?) save) async {
    final ctrl = TextEditingController(text: current?.toStringAsFixed(2) ?? '');
    final s = S.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              save(double.tryParse(ctrl.text.trim()));
              Navigator.pop(ctx);
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense(BuildContext context, AppState app) async {
    final s = S.of(context);
    String category = 'transport';
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StatefulBuilder(
          builder: (ctx, setState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add expense',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: expenseCategories
                        .map((c) => ChoiceChip(
                              avatar: Icon(c.$2, size: 17),
                              label: Text(c.$1),
                              selected: category == c.$1,
                              onSelected: (_) => setState(() => category = c.$1),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Amount (SAR)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                        labelText: s.notes, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () {
                      final amt = double.tryParse(amountCtrl.text.trim());
                      if (amt == null || amt <= 0) return;
                      app.addExpense(category, amt,
                          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
                      Navigator.pop(ctx);
                    },
                    child: Text(s.save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      );
}
