import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/core/providers/evm_providers.dart';

class ProgressEntryPage extends ConsumerStatefulWidget {
  const ProgressEntryPage({super.key});

  @override
  ConsumerState<ProgressEntryPage> createState() => _ProgressEntryPageState();
}

class _ProgressEntryPageState extends ConsumerState<ProgressEntryPage> {
  String? _selectedApuId;
  final _quantityController = TextEditingController();

  Future<void> _submit() async {
    if (_selectedApuId == null) return;
    
    final repo = ref.read(evmRepositoryProvider);
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    
    // Obtener las compras en borrador para este corte
    final drafts = ref.read(draftPurchasesProvider)[_selectedApuId] ?? [];

    await repo.saveCutRecord(_selectedApuId!, qty, DateTime.now(), drafts);
    
    // Limpiar borrador y formulario
    ref.read(draftPurchasesProvider.notifier).clearPurchases(_selectedApuId!);
    
    // Invalida para refrescar datos
    ref.invalidate(apuMetricsProvider(_selectedApuId!));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corte cerrado y guardado correctamente')));
      _quantityController.clear();
      setState(() {
        _selectedApuId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final apusAsync = ref.watch(apuListProvider);

    // Obtener información del borrador para la UI
    final drafts = _selectedApuId != null ? (ref.watch(draftPurchasesProvider)[_selectedApuId] ?? []) : [];
    double totalDraftCost = 0.0;
    for (var d in drafts) {
      totalDraftCost += d['realPrice'] * d['purchasedQuantity'];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cerrar Corte Temporal (Avance)')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: apusAsync.when(
          data: (apus) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Qué ejecutamos en este corte?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedApuId,
                items: apus.map((apu) {
                  return DropdownMenuItem(
                    value: apu['id'] as String,
                    child: Text(apu['description']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedApuId = val);
                  _quantityController.clear();
                },
                decoration: const InputDecoration(
                  labelText: 'Seleccionar APU',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              if (_selectedApuId != null) ...[
                Card(
                  color: drafts.isEmpty ? Colors.orange.shade50 : Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumen de Almacén para el Corte:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: drafts.isEmpty ? Colors.orange.shade800 : Colors.green.shade800),
                        ),
                        const SizedBox(height: 8),
                        Text('${drafts.length} compras preparadas.'),
                        Text('Subtotal Costo Insumos: \$${totalDraftCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (drafts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('Nota: Puedes cerrar el corte con 0 compras si solo hubo avance, o ve a Almacén para agregar compras.', style: TextStyle(fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _quantityController,
                  style: const TextStyle(fontSize: 32),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad Ejecutada (Incremental del Corte)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _submit,
                  child: const Text('Cerrar Corte (Guarda Almacén y Avance)', style: TextStyle(fontSize: 18)),
                )
              ]
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
