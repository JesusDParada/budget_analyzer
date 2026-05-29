import 'package:flutter/material.dart';
import 'package:budget_analyzer/core/utils/number_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/core/providers/evm_providers.dart';

class ProgressEntryPage extends ConsumerStatefulWidget {
  const ProgressEntryPage({super.key});

  @override
  ConsumerState<ProgressEntryPage> createState() => _ProgressEntryPageState();
}

class _ProgressEntryPageState extends ConsumerState<ProgressEntryPage> {
  int? _selectedApuId;
  final TextEditingController _qtyController = TextEditingController();

  void _submitProgress() async {
    if (_selectedApuId == null) return;
    
    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) return;

    final repo = ref.read(evmRepositoryProvider);
    final drafts = ref.read(draftPurchasesProvider)[_selectedApuId!] ?? [];
    
    await repo.saveCutRecord(_selectedApuId!, qty, DateTime.now(), drafts);

    // Limpiar borrador y refrescar
    ref.read(draftPurchasesProvider.notifier).clearPurchases(_selectedApuId!);
    _qtyController.clear();
    
    ref.invalidate(apuMetricsProvider(_selectedApuId!));
    ref.invalidate(apuStockProvider(_selectedApuId!));
    ref.invalidate(sharedStockProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avance físico registrado correctamente')),
      );
      setState(() {
        _selectedApuId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final apusAsync = ref.watch(apusListProvider);
    final capitulosAsync = ref.watch(capitulosListProvider);
    final drafts = _selectedApuId != null ? (ref.watch(draftPurchasesProvider)[_selectedApuId!] ?? []) : [];
    
    double insumosCost = 0.0;
    for (var draft in drafts) {
      final p = draft['realPrice'] as double;
      final q = draft['consumedQuantity'] as double;
      insumosCost += (p * q);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Avance Físico')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: apusAsync.when(
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
                  DropdownButtonFormField<int>(
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
                        Text('Subtotal Costo Insumos: \$${formatCurrency(insumosCost)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  controller: _qtyController,
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
                  onPressed: _submitProgress,
                  child: const Text('Cerrar Corte (Guarda Almacén y Avance)', style: TextStyle(fontSize: 18)),
                )
                ]
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    ),
  );
}
}
