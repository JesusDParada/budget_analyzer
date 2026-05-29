import 'package:flutter/material.dart';
import 'package:budget_analyzer/core/utils/number_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/features/apu_loader/providers/apu_provider.dart';
import 'package:budget_analyzer/core/providers/project_providers.dart';
import 'package:budget_analyzer/domain/models/project.dart';

class ApuLoaderScreen extends ConsumerWidget {
  const ApuLoaderScreen({super.key});

  void _showProjectNameDialog(BuildContext context, WidgetRef ref, ApuLoaderNotifier notifier) {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.create_new_folder, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Nuevo Proyecto'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el nombre del proyecto para catalogar las APUs que vas a importar.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: textController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Proyecto',
                    hintText: 'Ej. Edificio Omega, Tramo Sur',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa un nombre válido.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final name = textController.text.trim();
                  Navigator.pop(context);
                  // Disparar la carga con el nombre del proyecto
                  notifier.pickAndLoadExcel(name);
                }
              },
              child: const Text('Continuar a Excel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(apuLoaderProvider);
    final notifier = ref.read(apuLoaderProvider.notifier);
    
    final activeProject = ref.watch(activeProjectProvider);
    final projectsListAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Presupuestos (APUs)'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección del Proyecto Activo y Selector de Proyectos
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.business_center, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text(
                          'Proyecto Seleccionado',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (activeProject != null)
                      Text(
                        activeProject.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      )
                    else
                      const Text(
                        'Ninguno. ¡Por favor selecciona o carga un proyecto!',
                        style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.black54),
                      ),
                    const SizedBox(height: 16),
                    // Dropdown para cambiar de proyectos
                    projectsListAsync.when(
                      data: (projects) {
                        if (projects.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return DropdownButtonFormField<Project>(
                          initialValue: activeProject != null && projects.any((p) => p.id == activeProject.id)
                              ? projects.firstWhere((p) => p.id == activeProject.id)
                              : null,
                          hint: const Text('Cambiar a otro proyecto existente'),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: projects.map((proj) {
                            return DropdownMenuItem<Project>(
                              value: proj,
                              child: Text(proj.name),
                            );
                          }).toList(),
                          onChanged: (newProj) {
                            if (newProj != null) {
                              ref.read(activeProjectProvider.notifier).selectProject(newProj);
                              // Invalidar loaders para recargar con las APUs del nuevo proyecto
                              ref.invalidate(apuLoaderProvider);
                            }
                          },
                        );
                      },
                      loading: () => const Center(child: LinearProgressIndicator()),
                      error: (e, s) => Text('Error al leer proyectos: $e', style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Botón de Carga de Excel
            ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => _showProjectNameDialog(context, ref, notifier),
              icon: const Icon(Icons.upload_file),
              label: const Text('Importar Nuevo Presupuesto (.xlsx)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Procesando hojas de presupuesto y memorias...'),
                    ],
                  ),
                ),
              )
            else if (state.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (state.apusCargados.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '¡Presupuesto activo cargado! Se encontraron ${state.apusCargados.length} APUs.',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'APUs del Proyecto:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: state.capitulosCargados.isNotEmpty 
                        ? ListView.builder(
                            itemCount: state.capitulosCargados.length,
                            itemBuilder: (context, index) {
                              final cap = state.capitulosCargados[index];
                              final apusCapitulo = state.apusCargados.where((a) => a.capituloId == cap.id).toList();
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ExpansionTile(
                                  title: Text('${cap.numero}. ${cap.nombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${apusCapitulo.length} APUs'),
                                  children: apusCapitulo.map((apu) {
                                    final unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                                        child: Text(
                                          apu.codigo,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                        ),
                                      ),
                                      title: Text(apu.nombre),
                                      subtitle: Text('Cantidad: ${formatQuantity(apu.cantidad)} ${apu.unidad}'),
                                      trailing: Text(
                                        '\$${formatCurrency(unitPrice)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            itemCount: state.apusCargados.length,
                            itemBuilder: (context, index) {
                              final apu = state.apusCargados[index];
                              final unitPrice = apu.valorUnitario > 0 ? apu.valorUnitario : apu.costoTotal;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                                    child: Text(
                                      apu.codigo,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                    ),
                                  ),
                                  title: Text(apu.nombre),
                                  subtitle: Text('Cantidad: ${formatQuantity(apu.cantidad)} ${apu.unidad}'),
                                  trailing: Text(
                                    '\$${formatCurrency(unitPrice)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
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
