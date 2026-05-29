import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/core/providers/evm_providers.dart';

class InventoryIssuePage extends ConsumerStatefulWidget {
  const InventoryIssuePage({super.key});

  @override
  ConsumerState<InventoryIssuePage> createState() => _InventoryIssuePageState();
}

class _InventoryIssuePageState extends ConsumerState<InventoryIssuePage> {
  int? _selectedApuId;

  @override
  Widget build(BuildContext context) {
    final apusAsync = ref.watch(apusListProvider);
    final capitulosAsync = ref.watch(capitulosListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Salida de Almacén')),
      body: apusAsync.when(
        data: (apus) => capitulosAsync.when(
          data: (capitulos) {
            List<DropdownMenuItem<int>> buildDropdownItems() {
              if (capitulos.isEmpty) {
                return apus.map((apu) {
                  return DropdownMenuItem<int>(
                    value: apu['id'] as int,
                    child: Text('${apu['code']} - ${apu['description']}'),
                  );
                }).toList();
              }

              List<DropdownMenuItem<int>> items = [];
              for (var cap in capitulos) {
                items.add(
                  DropdownMenuItem<int>(
                    value: null,
                    enabled: false,
                    child: Text(
                      '${cap.numero}. ${cap.nombre}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ),
                );
                final apusCapitulo = apus.where((a) => a['capituloId'] == cap.id).toList();
                for (var apu in apusCapitulo) {
                  items.add(
                    DropdownMenuItem<int>(
                      value: apu['id'] as int,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text('${apu['code']} - ${apu['description']}'),
                      ),
                    ),
                  );
                }
              }
              return items;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _selectedApuId,
                    items: buildDropdownItems(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedApuId = val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar Actividad (APU)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_selectedApuId != null)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _ApuInsumosList(activityId: _selectedApuId!),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 1,
                          child: _DraftPurchasesList(activityId: _selectedApuId!),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ApuInsumosList extends ConsumerWidget {
  final int activityId;

  const _ApuInsumosList({required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insumosAsync = ref.watch(apuInsumosProvider(activityId));
    final sharedAsync = ref.watch(sharedInsumosProvider);

    return Card(
      elevation: 2,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('Insumos de la APU', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: insumosAsync.when(
              data: (insumos) {
                if (insumos.isEmpty) {
                  return const Center(child: Text('No hay insumos para esta APU.'));
                }

                final sharedMap = sharedAsync.value ?? {};

                return ListView.builder(
                  itemCount: insumos.length,
                  itemBuilder: (context, index) {
                    final insumo = insumos[index];
                    final desc = insumo['descripcion'] as String;
                    final sharedActivities = sharedMap[desc];

                    return _InsumoListItem(
                      activityId: activityId,
                      insumo: insumo,
                      sharedActivities: sharedActivities,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsumoListItem extends ConsumerWidget {
  final int activityId;
  final Map<String, dynamic> insumo;
  final List<SharedInsumoActivity>? sharedActivities;

  const _InsumoListItem({
    required this.activityId,
    required this.insumo,
    this.sharedActivities,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isShared = sharedActivities != null && sharedActivities!.length > 1;
    final insumoDesc = insumo['descripcion'] as String;

    InsumoStock? stock;
    if (isShared) {
      final sharedStockAsync = ref.watch(sharedStockProvider(insumoDesc));
      stock = sharedStockAsync.value;
    } else {
      final activityStockAsync = ref.watch(apuStockProvider(activityId));
      stock = activityStockAsync.value?[insumoDesc];
    }

    final stockSobrante = stock?.totalQuantity ?? 0.0;

    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(insumoDesc)),
          if (isShared)
            Tooltip(
              message: 'Compartido con: ${sharedActivities!.where((a) => a.activityId != activityId).map((a) => "${a.activityCode} ${a.activityName}").join(", ")}',
              child: Icon(Icons.share, size: 18, color: Colors.orange.shade700),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PPto: \$${insumo['valorUnitario'] ?? insumo['precioUnitario']} x ${insumo['cantidad']} ${insumo['unidad']}'),
          Text(
            isShared
                ? 'Stock Compartido: ${stockSobrante.toStringAsFixed(2)} ${insumo['unidad']}'
                : 'Sobrante en Almacén: ${stockSobrante.toStringAsFixed(2)} ${insumo['unidad']}',
            style: TextStyle(
              color: stockSobrante > 0 ? Colors.green : Colors.grey,
              fontWeight: isShared ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _AddPurchaseDialog(
            activityId: activityId,
            insumo: insumo,
            insumoStock: stock,
            sharedActivities: isShared ? sharedActivities : null,
          ),
        ),
      ),
    );
  }
}

class _AddPurchaseDialog extends ConsumerStatefulWidget {
  final int activityId;
  final Map<String, dynamic> insumo;
  final InsumoStock? insumoStock;
  final List<SharedInsumoActivity>? sharedActivities;

  const _AddPurchaseDialog({
    required this.activityId,
    required this.insumo,
    this.insumoStock,
    this.sharedActivities,
  });

  @override
  ConsumerState<_AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _AddPurchaseDialogState extends ConsumerState<_AddPurchaseDialog> {
  late TextEditingController priceController;
  late TextEditingController purchasedQtyController;
  late TextEditingController consumedQtyController;

  // Shared allocation
  Map<int, TextEditingController> allocationControllers = {};

  bool get isShared =>
      widget.sharedActivities != null && widget.sharedActivities!.length > 1;

  @override
  void initState() {
    super.initState();
    final suggestedPrice = widget.insumoStock?.lastPrice ??
        widget.insumo['valorUnitario'] ??
        widget.insumo['precioUnitario'];
    priceController =
        TextEditingController(text: suggestedPrice?.toString() ?? '0');
    purchasedQtyController = TextEditingController();
    consumedQtyController = TextEditingController();

    if (isShared) {
      _initAllocationControllers();
    }
  }

  void _initAllocationControllers() {
    final activities = widget.sharedActivities!;
    final totalBudget =
        activities.fold<double>(0.0, (sum, a) => sum + a.budgetQuantity);

    double assignedTotal = 0;
    for (int i = 0; i < activities.length; i++) {
      final act = activities[i];
      double pct;
      if (i < activities.length - 1) {
        pct = totalBudget > 0
            ? (act.budgetQuantity / totalBudget * 100).roundToDouble()
            : (100.0 / activities.length).roundToDouble();
        assignedTotal += pct;
      } else {
        pct = 100 - assignedTotal;
      }
      allocationControllers[act.activityId] =
          TextEditingController(text: pct.toStringAsFixed(0));
    }
  }

  void _resetToAutoAllocation() {
    final activities = widget.sharedActivities!;
    final totalBudget =
        activities.fold<double>(0.0, (sum, a) => sum + a.budgetQuantity);

    double assignedTotal = 0;
    for (int i = 0; i < activities.length; i++) {
      final act = activities[i];
      double pct;
      if (i < activities.length - 1) {
        pct = totalBudget > 0
            ? (act.budgetQuantity / totalBudget * 100).roundToDouble()
            : (100.0 / activities.length).roundToDouble();
        assignedTotal += pct;
      } else {
        pct = 100 - assignedTotal;
      }
      allocationControllers[act.activityId]!.text = pct.toStringAsFixed(0);
    }
    setState(() {});
  }

  double get _allocationTotal {
    double total = 0;
    for (var ctrl in allocationControllers.values) {
      total += double.tryParse(ctrl.text) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final stockSobrante = widget.insumoStock?.totalQuantity ?? 0.0;
    final purchased = double.tryParse(purchasedQtyController.text) ?? 0.0;
    final consumed = double.tryParse(consumedQtyController.text) ?? 0.0;
    final double maxAuthorized = purchased + stockSobrante;

    final bool showWarning = consumed > maxAuthorized;
    final bool needsPrice = purchased > 0 || consumed > stockSobrante;
    final bool allocationValid =
        !isShared || consumed <= 0 || (_allocationTotal - 100).abs() < 0.01;

    return AlertDialog(
      title: Text('Agregar: ${widget.insumo['descripcion']}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: isShared ? 420 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isShared
                    ? 'Stock Compartido: ${stockSobrante.toStringAsFixed(2)} ${widget.insumo['unidad']}'
                    : 'Sobrante Actual: ${stockSobrante.toStringAsFixed(2)} ${widget.insumo['unidad']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: purchasedQtyController,
                decoration: InputDecoration(
                    labelText:
                        'Cantidad Comprada (${widget.insumo['unidad']})'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: consumedQtyController,
                decoration: InputDecoration(
                    labelText:
                        'Cantidad Consumida (${widget.insumo['unidad']})'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: needsPrice
                      ? 'Precio Unitario Real (\$)'
                      : 'Precio Automático (FIFO)',
                  hintText: needsPrice
                      ? 'Ingrese el precio de compra o estimado'
                      : 'Calculado desde stock',
                ),
                enabled: needsPrice,
                keyboardType: TextInputType.number,
              ),
              if (showWarning) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Consumo no registrado: Te faltan ${(consumed - maxAuthorized).toStringAsFixed(2)} comprados para cubrir este consumo.',
                          style: const TextStyle(
                              color: Colors.deepOrange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // --- DISTRIBUCIÓN PARA INSUMOS COMPARTIDOS ---
              if (isShared && consumed > 0) ...[
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Distribución del Consumo',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    TextButton.icon(
                      onPressed: _resetToAutoAllocation,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Auto',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...widget.sharedActivities!.map((act) {
                  final ctrl = allocationControllers[act.activityId]!;
                  final isOrigin = act.activityId == widget.activityId;
                  final pctVal = double.tryParse(ctrl.text) ?? 0;
                  final portionQty = consumed * pctVal / 100;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${act.activityCode} - ${act.activityName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isOrigin
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${portionQty.toStringAsFixed(2)} ${widget.insumo['unidad']}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: ctrl,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              suffixText: '%',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Text(
                  'Total: ${_allocationTotal.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: allocationValid ? Colors.green : Colors.red,
                  ),
                ),
                if (!allocationValid)
                  const Text(
                    'Los porcentajes deben sumar 100%',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (purchased > 0 || consumed > 0) && allocationValid
              ? () {
                  final price =
                      double.tryParse(priceController.text) ?? 0.0;

                  if (isShared && consumed > 0) {
                    Map<int, double> fractions = {};
                    for (var entry in allocationControllers.entries) {
                      final pctVal =
                          double.tryParse(entry.value.text) ?? 0.0;
                      fractions[entry.key] = pctVal / 100.0;
                    }

                    ref
                        .read(draftPurchasesProvider.notifier)
                        .addSharedPurchase(
                          widget.activityId,
                          widget.insumo['descripcion'],
                          price,
                          purchased,
                          consumed,
                          widget.insumoStock,
                          fractions,
                        );
                  } else {
                    ref
                        .read(draftPurchasesProvider.notifier)
                        .addPurchase(
                          widget.activityId,
                          widget.insumo['descripcion'],
                          price,
                          purchased,
                          consumed,
                          widget.insumoStock,
                        );
                  }

                  Navigator.pop(context);
                }
              : null,
          child: const Text('Agregar al Borrador'),
        ),
      ],
    );
  }
}

  class _DraftPurchasesList extends ConsumerWidget {
    final int activityId;

    const _DraftPurchasesList({required this.activityId});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final draftsMap = ref.watch(draftPurchasesProvider);
      final purchases = draftsMap[activityId] ?? [];

      double totalCost = 0.0;
      for (var p in purchases) {
        totalCost += p['realPrice'] * p['consumedQuantity'];
      }

      return Card(
        elevation: 2,
        color: Colors.blue.shade50,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Compras Preparadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: purchases.isEmpty
                  ? const Center(child: Text('Agrega compras desde la lista de insumos.', style: TextStyle(color: Colors.black54)))
                  : ListView.builder(
                      itemCount: purchases.length,
                      itemBuilder: (context, index) {
                        final p = purchases[index];
                        final cost = p['realPrice'] * p['consumedQuantity'];
                        return ListTile(
                          title: Text(p['insumoDescription']),
                          subtitle: Text('Comp: ${p['purchasedQuantity']} | Cons: ${p['consumedQuantity']}\n\$${p['realPrice']} x ${p['consumedQuantity']} (Cons) = \$${cost.toStringAsFixed(2)}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              ref.read(draftPurchasesProvider.notifier).removePurchase(activityId, index);
                            },
                          ),
                        );
                      },
                    ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal Insumos:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('\$${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ve a la pestaña "Avance" para registrar la actividad y cerrar este corte.')),
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Ir a Avance para Cerrar Corte'),
            ),
          ),
        ],
      ),
    );
  }
}
