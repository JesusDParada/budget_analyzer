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

    await repo.saveFieldProgress(_selectedApuId!, qty, DateTime.now());
    
    // Invalida para refrescar datos
    ref.invalidate(apuMetricsProvider(_selectedApuId!));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avance registrado')));
      _quantityController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final apusAsync = ref.watch(apuListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de Avance')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: apusAsync.when(
          data: (apus) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Qué ejecutamos hoy?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
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
                  labelText: 'Seleccionar APU',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _quantityController,
                style: const TextStyle(fontSize: 32),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Cantidad Ejecutada',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
                onPressed: _submit,
                child: const Text('Guardar Avance (Suma al EV)', style: TextStyle(fontSize: 18)),
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
