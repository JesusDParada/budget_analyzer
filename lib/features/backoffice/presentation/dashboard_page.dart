import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/core/providers/evm_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apusAsync = ref.watch(apusListProvider);
    final capitulosAsync = ref.watch(capitulosListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard EVM')),
      body: apusAsync.when(
        data: (apus) {
          if (apus.isEmpty) {
            return const Center(
              child: Text('No hay APUs cargadas o seleccionadas.'),
            );
          }
          
          return capitulosAsync.when(
            data: (capitulos) {
               if (capitulos.isEmpty) {
                  return ListView.builder(
                    itemCount: apus.length,
                    itemBuilder: (context, index) {
                      final apu = apus[index];
                      return _ApuMetricsCard(
                        activityId: apu['id'],
                        apuName: apu['description'],
                      );
                    },
                  );
               }
               
               return ListView.builder(
                 itemCount: capitulos.length,
                 itemBuilder: (context, index) {
                    final cap = capitulos[index];
                    final apusCapitulo = apus.where((a) => a['capituloId'] == cap.id).toList();
                    
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Text('${cap.numero}. ${cap.nombre}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        children: apusCapitulo.map((apu) => _ApuMetricsCard(
                          activityId: apu['id'],
                          apuName: '${apu['code']} - ${apu['description']}',
                        )).toList(),
                      ),
                    );
                 },
               );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ApuMetricsCard extends ConsumerWidget {
  final int activityId;
  final String apuName;

  const _ApuMetricsCard({required this.activityId, required this.apuName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(apuMetricsProvider(activityId));

    return Card(
      margin: const EdgeInsets.all(12),
      child: metricsAsync.when(
        data: (metrics) {
          final isGood = metrics.cpi >= 1.0;
          return ExpansionTile(
            title: Text(
              apuName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BAC: \$${metrics.bac.toStringAsFixed(2)}'),
                      Text('EV: \$${metrics.ev.toStringAsFixed(2)}'),
                      Text('AC: \$${metrics.ac.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('CPI: '),
                          Text(
                            metrics.cpi == double.infinity
                                ? 'N/A'
                                : metrics.cpi.toStringAsFixed(2),
                            style: TextStyle(
                              color: isGood ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text('EAC: \$${metrics.eac.toStringAsFixed(2)}'),
                      Text('ETC: \$${metrics.etc.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              ),
            ),
            children: [
              const Divider(),
              ListTile(
                title: const Text(
                  'Historial de Cortes Temporales',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: metrics.evRecords.isEmpty
                    ? const Text('No hay cortes registrados')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: metrics.evRecords.map((cut) {
                          final dateStr =
                              cut['date']?.toString().split('T').first ?? '';
                          final cutNumber = cut['cutNumber'];
                          final actQty = cut['activityQuantity'];
                          final cutAc = cut['cutAc'];
                          final purchases = cut['purchases'] as List<dynamic>;

                          return Card(
                            color: Colors.grey.shade50,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Corte #$cutNumber - $dateStr',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Actividad Ejecutada: $actQty'),
                                  Text(
                                    'AC del Corte (Σ Insumos P×Q): \$${(cutAc as num).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (purchases.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Compras:',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                      ),
                                    ),
                                    ...purchases.map(
                                      (p) => Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Text(
                                          '- ${p['insumoDescription']}: \$${p['realPrice']} | Comp: ${p['purchasedQuantity']} | Cons: ${p['consumedQuantity']} (AC \$${((p['realPrice'] as num) * (p['consumedQuantity'] as num)).toStringAsFixed(2)})',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $err'),
        ),
      ),
    );
  }
}
