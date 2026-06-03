import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/core/providers/evm_providers.dart';
import 'package:budget_analyzer/core/utils/number_formatters.dart';

class GlobalExpenseEntryPage extends ConsumerStatefulWidget {
  const GlobalExpenseEntryPage({super.key});

  @override
  ConsumerState<GlobalExpenseEntryPage> createState() => _GlobalExpenseEntryPageState();
}

class InsumoEntry {
  final String description;
  final double cost;
  final double quantity;
  InsumoEntry({required this.description, required this.cost, required this.quantity});
}

class _GlobalExpenseEntryPageState extends ConsumerState<GlobalExpenseEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _costController = TextEditingController();
  final _qtyController = TextEditingController();
  
  List<InsumoEntry> _insumosList = [];
  Set<int> _selectedActivities = {};
  bool _includesIva = false;

  void _addInsumoToList() {
    if (!_formKey.currentState!.validate()) return;
    
    var cost = double.tryParse(_costController.text) ?? 0.0;
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    
    if (_includesIva) {
      cost = cost * 1.19;
    }
    
    setState(() {
      _insumosList.add(InsumoEntry(
        description: _descController.text.trim(),
        cost: cost,
        quantity: qty,
      ));
      _descController.clear();
      _costController.clear();
      _qtyController.clear();
    });
  }

  void _submitExpense() async {
    if (_insumosList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe agregar al menos un insumo a la lista.')),
      );
      return;
    }
    if (_selectedActivities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar al menos una actividad.')),
      );
      return;
    }

    final repo = ref.read(evmRepositoryProvider);
    
    final insumosToProcess = List.from(_insumosList);
    final activitiesToProcess = _selectedActivities.toList();

    for (var insumo in insumosToProcess) {
      await repo.saveGlobalExpense(
        insumo.description,
        insumo.cost,
        insumo.quantity,
        activitiesToProcess,
      );
    }

    // Invalida todo lo relacionado a las actividades afectadas
    for (var actId in _selectedActivities) {
      ref.invalidate(openCutPurchasesProvider(actId));
      ref.invalidate(apuMetricsProvider(actId));
    }

    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¡Éxito!'),
          content: const Text('La información se cargó correctamente a la base de datos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      if (mounted) {
        setState(() {
          _insumosList.clear();
          _selectedActivities.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apusAsync = ref.watch(apusListProvider);
    final capitulosAsync = ref.watch(capitulosListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Gastos de Insumos')),
      body: Row(
        children: [
          // Left panel: Form
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text('Detalles del Gasto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Descripción del Insumo', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(labelText: 'Costo Total (\$)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Monto inválido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _qtyController,
                      decoration: const InputDecoration(labelText: 'Cantidad Consumida', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Cantidad inválida' : null,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Aplica IVA (19%)'),
                      subtitle: const Text('Si se marca, el costo total se aumentará en un 19% automáticamente.'),
                      value: _includesIva,
                      onChanged: (val) {
                        setState(() {
                          _includesIva = val ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _addInsumoToList,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Insumo a la Lista'),
                    ),
                    const SizedBox(height: 24),
                    if (_insumosList.isNotEmpty) ...[
                      const Text('Lista de Insumos a Registrar:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._insumosList.asMap().entries.map((entry) {
                        int idx = entry.key;
                        InsumoEntry insumo = entry.value;
                        return ListTile(
                          title: Text(insumo.description),
                          subtitle: Text('Costo: \$${formatCurrency(insumo.cost)} | Cantidad: ${insumo.quantity}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _insumosList.removeAt(idx);
                              });
                            },
                          ),
                        );
                      }),
                      const Divider(),
                      Text(
                        'Total a Distribuir: \$${formatCurrency(_insumosList.fold<double>(0, (sum, item) => sum + item.cost))}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(20),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _submitExpense,
                        child: const Text('Registrar y Distribuir Gastos', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Right panel: Activity Selection and Preview
          Expanded(
            flex: 2,
            child: apusAsync.when(
              data: (apus) => capitulosAsync.when(
                data: (capitulos) {
                  double totalBacSelected = 0;
                  final selectedApusList = apus.where((a) => _selectedActivities.contains(a['id'])).toList();
                  for (var a in selectedApusList) {
                     totalBacSelected += (a['bac'] as double? ?? 0) > 0 ? (a['bac'] as double) : ((a['unit_price'] as double) * (a['total_quantity'] as double));
                  }
                  if (totalBacSelected <= 0) totalBacSelected = 1;

                  return Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Seleccionar Actividades a Distribuir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: capitulos.length,
                          itemBuilder: (context, cIndex) {
                            final cap = capitulos[cIndex];
                            final capApus = apus.where((a) => a['capituloId'] == cap.id).toList();
                            if (capApus.isEmpty) return const SizedBox.shrink();

                            final allSelected = capApus.every((a) => _selectedActivities.contains(a['id']));
                            return ExpansionTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text('${cap.numero}. ${cap.nombre}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        if (allSelected) {
                                          for (var a in capApus) {
                                            _selectedActivities.remove(a['id']);
                                          }
                                        } else {
                                          for (var a in capApus) {
                                            _selectedActivities.add(a['id']);
                                          }
                                        }
                                      });
                                    },
                                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 18),
                                    label: Text(allSelected ? 'Deseleccionar' : 'Seleccionar Todo'),
                                  ),
                                ],
                              ),
                              initiallyExpanded: true,
                              children: capApus.map((apu) {
                                final id = apu['id'] as int;
                                final isSelected = _selectedActivities.contains(id);
                                
                                final bac = (apu['bac'] as double? ?? 0) > 0 ? (apu['bac'] as double) : ((apu['unit_price'] as double) * (apu['total_quantity'] as double));
                                
                                double displayPct = 0;
                                double displayCost = 0;
                                if (isSelected) {
                                  displayPct = (bac / totalBacSelected) * 100;
                                  final totalListCost = _insumosList.fold<double>(0, (sum, item) => sum + item.cost);
                                  displayCost = totalListCost * (bac / totalBacSelected);
                                }

                                return CheckboxListTile(
                                  title: Text('${apu['code']} - ${apu['description']}'),
                                  subtitle: Text(
                                    'BAC: \$${formatCurrency(bac)}' + 
                                    (isSelected ? ' | Se asignará: ${displayPct.toStringAsFixed(1)}% (\$${formatCurrency(displayCost)})' : '')
                                  ),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedActivities.add(id);
                                      } else {
                                        _selectedActivities.remove(id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            );
                          },
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
          ),
        ],
      ),
    );
  }
}
