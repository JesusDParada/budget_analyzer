import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/features/apu_loader/providers/apu_provider.dart';
import 'package:budget_analyzer/domain/models/insumo.dart';

void showCreateProjectDialog(BuildContext context, WidgetRef ref, ApuLoaderNotifier notifier) {
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
            Text('Nuevo Proyecto Manual'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa el nombre del proyecto.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Proyecto',
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
                notifier.createProject(name);
              }
            },
            child: const Text('Crear Proyecto'),
          ),
        ],
      );
    },
  );
}

void showCreateCapituloDialog(BuildContext context, int projectId, ApuLoaderNotifier notifier) {
  final numeroController = TextEditingController();
  final nombreController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Nuevo Capítulo'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: numeroController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número (ej. 1, 2, 3)'),
                validator: (value) {
                  if (value == null || int.tryParse(value) == null) {
                    return 'Ingresa un número válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre del Capítulo'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Ingresa un nombre.';
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
                final numero = int.parse(numeroController.text);
                final nombre = nombreController.text.trim();
                Navigator.pop(context);
                notifier.createCapitulo(projectId, numero, nombre);
              }
            },
            child: const Text('Crear Capítulo'),
          ),
        ],
      );
    },
  );
}

void showCreateActivityDialog(BuildContext context, int capituloId, ApuLoaderNotifier notifier) {
  showDialog(
    context: context,
    builder: (context) {
      return _CreateActivityDialog(capituloId: capituloId, notifier: notifier);
    },
  );
}

class _CreateActivityDialog extends StatefulWidget {
  final int capituloId;
  final ApuLoaderNotifier notifier;

  const _CreateActivityDialog({required this.capituloId, required this.notifier});

  @override
  State<_CreateActivityDialog> createState() => _CreateActivityDialogState();
}

class _CreateActivityDialogState extends State<_CreateActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _valorUnitarioCtrl = TextEditingController();
  
  List<Insumo> _insumos = [];

  void _addInsumo() {
    showDialog(
      context: context,
      builder: (context) {
        final descCtrl = TextEditingController();
        final unitCtrl = TextEditingController();
        final qtyCtrl = TextEditingController();
        final priceCtrl = TextEditingController();
        final insumoFormKey = GlobalKey<FormState>();
        
        return AlertDialog(
          title: const Text('Añadir Insumo'),
          content: Form(
            key: insumoFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'Unidad (ej. UN, KG)'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad por Actividad'),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'Número válido' : null,
                ),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor Unitario del Insumo'),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'Número válido' : null,
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
                if (insumoFormKey.currentState!.validate()) {
                  final newInsumo = Insumo(
                    activityId: 0,
                    descripcion: descCtrl.text.trim(),
                    unidad: unitCtrl.text.trim(),
                    cantidad: double.parse(qtyCtrl.text),
                    valorUnitario: double.parse(priceCtrl.text),
                  );
                  setState(() {
                    _insumos.add(newInsumo);
                    // Update main activity unit price if insumos are added
                    double totalInsumos = _insumos.fold(0, (sum, item) => sum + (item.cantidad * item.valorUnitario));
                    _valorUnitarioCtrl.text = totalInsumos.toStringAsFixed(2);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Añadir'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Actividad (APU)'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _codigoCtrl,
                        decoration: const InputDecoration(labelText: 'Código (ej. 1.1)'),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _unidadCtrl,
                        decoration: const InputDecoration(labelText: 'Unidad'),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de Actividad'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cantidadCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cantidad'),
                        validator: (v) => double.tryParse(v ?? '') == null ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _valorUnitarioCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Valor Unitario'),
                        validator: (v) => double.tryParse(v ?? '') == null ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Insumos', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _addInsumo,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir Insumo'),
                    ),
                  ],
                ),
                if (_insumos.isEmpty)
                  const Text(
                    'Si no añades insumos, se creará uno automáticamente con el nombre y valor de la actividad.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _insumos.length,
                    itemBuilder: (ctx, idx) {
                      final ins = _insumos[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(ins.descripcion),
                        subtitle: Text('${ins.cantidad} ${ins.unidad} x \$${ins.valorUnitario}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() {
                              _insumos.removeAt(idx);
                              // Update main activity unit price if insumos are added
                              double totalInsumos = _insumos.fold(0, (sum, item) => sum + (item.cantidad * item.valorUnitario));
                              _valorUnitarioCtrl.text = totalInsumos > 0 ? totalInsumos.toStringAsFixed(2) : '';
                            });
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final cantidad = double.parse(_cantidadCtrl.text);
              final valorUnitario = double.parse(_valorUnitarioCtrl.text);
              final bac = cantidad * valorUnitario;
              
              widget.notifier.createActivity(
                widget.capituloId,
                _codigoCtrl.text.trim(),
                _nombreCtrl.text.trim(),
                _unidadCtrl.text.trim(),
                cantidad,
                valorUnitario,
                bac,
                _insumos,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Crear Actividad'),
        ),
      ],
    );
  }
}
