import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/features/apu_loader/providers/apu_provider.dart';

class ApuLoaderScreen extends ConsumerWidget {
  const ApuLoaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(apuLoaderProvider);
    final notifier = ref.read(apuLoaderProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga de APUs desde Excel'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.table_chart, size: 64, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text(
              'Selecciona un archivo Excel (.xlsx) que contenga las hojas "INSUMOS" y "DESGLOSE APUS".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: state.isLoading ? null : () => notifier.pickAndLoadExcel(),
              icon: const Icon(Icons.upload_file),
              label: const Text('Seleccionar y Cargar Excel'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (state.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Text(
                  state.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (state.apusCargados.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            '¡Carga exitosa! Se encontraron \${state.apusCargados.length} APUs.',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: state.apusCargados.length,
                        itemBuilder: (context, index) {
                          final apu = state.apusCargados[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(apu.nombre),
                              subtitle: Text('Código: \${apu.codigo} | Ítems: \${apu.items.length}'),
                              trailing: Text('\$\${apu.costoTotal.toStringAsFixed(2)}'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
