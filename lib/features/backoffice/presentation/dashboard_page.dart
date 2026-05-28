import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/core/providers/evm_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apusAsync = ref.watch(apuListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard EVM')),
      body: apusAsync.when(
        data: (apus) {
          if (apus.isEmpty) {
            return const Center(child: Text('No hay APUs cargadas o seleccionadas.'));
          }
          return ListView.builder(
            itemCount: apus.length,
            itemBuilder: (context, index) {
              final apu = apus[index];
              return _ApuMetricsCard(apuId: apu['id'], apuName: apu['description']);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ApuMetricsCard extends ConsumerWidget {
  final String apuId;
  final String apuName;

  const _ApuMetricsCard({required this.apuId, required this.apuName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(apuMetricsProvider(apuId));

    return Card(
      margin: const EdgeInsets.all(12),
      child: metricsAsync.when(
        data: (metrics) {
          final isGood = metrics.cpi >= 1.0;
          return ExpansionTile(
            title: Text(apuName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            metrics.cpi == double.infinity ? 'N/A' : metrics.cpi.toStringAsFixed(2),
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
                title: const Text('Historial de Cortes Temporales', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: metrics.evRecords.isEmpty
                    ? const Text('No hay cortes registrados')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: metrics.evRecords.map((cut) {
                          final dateStr = cut['date']?.toString().split('T').first ?? '';
                          final cutNumber = cut['cutNumber'];
                          final actQty = cut['activityQuantity'];
                          final insumosCost = cut['insumosCost'];
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Actividad Ejecutada: $actQty'),
                                  Text('AC del Corte (Σ Insumos P×Q): \$${(cutAc as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (purchases.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    const Text('Compras:', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                                    ...purchases.map((p) => Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        '- ${p['insumoDescription']}: \$${p['realPrice']} x ${p['purchasedQuantity']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )),
                                  ]
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
