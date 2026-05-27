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
        data: (apus) => ListView.builder(
          itemCount: apus.length,
          itemBuilder: (context, index) {
            final apu = apus[index];
            return _ApuMetricsCard(apuId: apu['id'], apuName: apu['description']);
          },
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: metricsAsync.when(
          data: (metrics) {
            final isGood = metrics.cpi >= 1.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(apuName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BAC: \$${metrics.bac.toStringAsFixed(2)}'),
                    Text('EV: \$${metrics.ev.toStringAsFixed(2)}'),
                    Text('AC: \$${metrics.ac.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 10),
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
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error: $err'),
        ),
      ),
    );
  }
}
