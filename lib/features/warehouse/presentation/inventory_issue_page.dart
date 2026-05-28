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
                return ListView.builder(
                  itemCount: insumos.length,
                  itemBuilder: (context, index) {
                    final insumo = insumos[index];
                    return ListTile(
                      title: Text(insumo['descripcion']),
                      subtitle: Text('PPto: \$${insumo['precioUnitario']} x ${insumo['cantidad']} ${insumo['unidad']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                        onPressed: () => _showAddPurchaseDialog(context, ref, apuId, insumo),
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

  void _showAddPurchaseDialog(BuildContext context, WidgetRef ref, String apuId, Map<String, dynamic> insumo) {
    final priceController = TextEditingController(text: insumo['precioUnitario'].toString());
    final qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Agregar Compra: ${insumo['descripcion']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Precio Unitario Real (\$)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyController,
                decoration: InputDecoration(labelText: 'Cantidad Comprada (${insumo['unidad']})'),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceController.text) ?? 0.0;
                final qty = double.tryParse(qtyController.text) ?? 0.0;
                if (price > 0 && qty > 0) {
                  ref.read(draftPurchasesProvider.notifier).addPurchase(apuId, insumo['descripcion'], price, qty);
                  Navigator.pop(context);
                }
              },
              child: const Text('Agregar al Borrador'),
            ),
          ],
        );
      },
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
      totalCost += p['realPrice'] * p['purchasedQuantity'];
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
                      final cost = p['realPrice'] * p['purchasedQuantity'];
                      return ListTile(
                        title: Text(p['insumoDescription']),
                        subtitle: Text('\$${p['realPrice']} x ${p['purchasedQuantity']} = \$${cost.toStringAsFixed(2)}'),
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
