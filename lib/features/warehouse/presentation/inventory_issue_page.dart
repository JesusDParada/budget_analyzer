import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/core/providers/evm_providers.dart';

class InventoryIssuePage extends ConsumerStatefulWidget {
  const InventoryIssuePage({super.key});

  @override
  ConsumerState<InventoryIssuePage> createState() => _InventoryIssuePageState();
}

class _InventoryIssuePageState extends ConsumerState<InventoryIssuePage> {
  String? _selectedApuId;

  @override
  Widget build(BuildContext context) {
    final apusAsync = ref.watch(apuListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Borrador de Almacén (Compras del Corte)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: apusAsync.when(
          data: (apus) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedApuId,
                items: apus.map((apu) {
                  return DropdownMenuItem(
                    value: apu['id'] as String,
                    child: Text(apu['description']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedApuId = val),
                decoration: const InputDecoration(
                  labelText: 'Seleccionar APU para el corte actual',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_selectedApuId != null)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Panel izquierdo: Insumos de la APU
                      Expanded(
                        flex: 1,
                        child: _ApuInsumosList(apuId: _selectedApuId!),
                      ),
                      const SizedBox(width: 16),
                      // Panel derecho: Borrador de compras
                      Expanded(
                        flex: 1,
                        child: _DraftPurchasesList(apuId: _selectedApuId!),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}

class _ApuInsumosList extends ConsumerWidget {
  final String apuId;

  const _ApuInsumosList({required this.apuId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insumosAsync = ref.watch(apuInsumosProvider(apuId));
    final stockAsync = ref.watch(apuStockProvider(apuId));

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
                
                final stockMap = stockAsync.value ?? {};

                return ListView.builder(
                  itemCount: insumos.length,
                  itemBuilder: (context, index) {
                    final insumo = insumos[index];
                    final insumoStock = stockMap[insumo['descripcion']];
                    final stockSobrante = insumoStock?.totalQuantity ?? 0.0;
                    
                    return ListTile(
                      title: Text(insumo['descripcion']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PPto: \$${insumo['precioUnitario']} x ${insumo['cantidad']} ${insumo['unidad']}'),
                          Text('Sobrante en Almacén: $stockSobrante ${insumo['unidad']}', style: TextStyle(color: stockSobrante > 0 ? Colors.green : Colors.grey)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => _AddPurchaseDialog(
                            apuId: apuId,
                            insumo: insumo,
                            insumoStock: insumoStock,
                          ),
                        ),
                      ),
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

class _AddPurchaseDialog extends ConsumerStatefulWidget {
  final String apuId;
  final Map<String, dynamic> insumo;
  final InsumoStock? insumoStock;

  const _AddPurchaseDialog({required this.apuId, required this.insumo, required this.insumoStock});

  @override
  ConsumerState<_AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _AddPurchaseDialogState extends ConsumerState<_AddPurchaseDialog> {
  late TextEditingController priceController;
  late TextEditingController purchasedQtyController;
  late TextEditingController consumedQtyController;

  @override
  void initState() {
    super.initState();
    final suggestedPrice = widget.insumoStock?.lastPrice ?? widget.insumo['precioUnitario'];
    priceController = TextEditingController(text: suggestedPrice.toString());
    purchasedQtyController = TextEditingController();
    consumedQtyController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    final stockSobrante = widget.insumoStock?.totalQuantity ?? 0.0;
    final purchased = double.tryParse(purchasedQtyController.text) ?? 0.0;
    final consumed = double.tryParse(consumedQtyController.text) ?? 0.0;
    final double maxAuthorized = purchased + stockSobrante;
    
    final bool showWarning = consumed > maxAuthorized;
    final bool needsPrice = purchased > 0 || consumed > stockSobrante;

    return AlertDialog(
      title: Text('Agregar: ${widget.insumo['descripcion']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sobrante Actual: $stockSobrante ${widget.insumo['unidad']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: purchasedQtyController,
              decoration: InputDecoration(labelText: 'Cantidad Comprada (${widget.insumo['unidad']})'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: consumedQtyController,
              decoration: InputDecoration(labelText: 'Cantidad Consumida (${widget.insumo['unidad']})'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: needsPrice ? 'Precio Unitario Real (\$)' : 'Precio Automático (FIFO)',
                hintText: needsPrice ? 'Ingrese el precio de compra o estimado' : 'Calculado desde stock',
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
                        'Consumo no registrado: Te faltan ${ (consumed - maxAuthorized).toStringAsFixed(2) } comprados para cubrir este consumo. El precio unitario de arriba se usará para este excedente.',
                        style: const TextStyle(color: Colors.deepOrange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final price = double.tryParse(priceController.text) ?? 0.0;
            if (purchased > 0 || consumed > 0) {
              ref.read(draftPurchasesProvider.notifier).addPurchase(
                widget.apuId, 
                widget.insumo['descripcion'], 
                price, 
                purchased,
                consumed,
                widget.insumoStock
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Agregar al Borrador'),
        ),
      ],
    );
  }
}

class _DraftPurchasesList extends ConsumerWidget {
  final String apuId;

  const _DraftPurchasesList({required this.apuId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsMap = ref.watch(draftPurchasesProvider);
    final purchases = draftsMap[apuId] ?? [];

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
                            ref.read(draftPurchasesProvider.notifier).removePurchase(apuId, index);
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
