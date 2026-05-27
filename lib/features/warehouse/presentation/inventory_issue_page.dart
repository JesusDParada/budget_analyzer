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
  final _materialController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();

  Future<void> _submit() async {
    if (_selectedApuId == null) return;
    
    final repo = ref.read(evmRepositoryProvider);
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final cost = double.tryParse(_costController.text) ?? 0.0;

    await repo.saveInventoryIssue(_selectedApuId!, _materialController.text, qty, cost);
    
    // Invalida para refrescar datos
    ref.invalidate(apuMetricsProvider(_selectedApuId!));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salida de almacén registrada')));
      _materialController.clear();
      _quantityController.clear();
      _costController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final apusAsync = ref.watch(apuListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Salida de Almacén')),
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
                decoration: const InputDecoration(labelText: 'Seleccionar APU destino'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _materialController,
                decoration: const InputDecoration(labelText: 'Nombre del Material'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Cantidad a Entregar'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(labelText: 'Costo Total de Salida (\$)'),
                keyboardType: TextInputType.number,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Registrar Salida (Suma al AC)'),
              )
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
