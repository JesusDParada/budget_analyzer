import 'dart:convert';

class InsumoApu {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double precioUnitario;
  final double cantidad;

  InsumoApu({
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.precioUnitario,
    required this.cantidad,
  });

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'unidad': unidad,
      'precioUnitario': precioUnitario,
      'cantidad': cantidad,
    };
  }
}

class ApuInsumosParser {
  static List<InsumoApu> parse(String? detalleJson) {
    if (detalleJson == null || detalleJson.isEmpty) return [];
    
    try {
      final List<dynamic> rows = jsonDecode(detalleJson);
      final List<InsumoApu> insumos = [];
      
      bool isParsingInsumos = false;
      
      for (var row in rows) {
        if (row is! List) continue;
        
        // Ensure row has at least up to index 5
        if (row.length < 6) continue;
        
        final col1 = row[1]?.toString().trim() ?? '';
        final col2 = row[2]?.toString().trim() ?? '';
        
        // Skip empty or purely structural rows
        if (col1.isEmpty && col2.isEmpty) continue;
        
        // Detect headers like "Código | Descripción | U.M. ..."
        if (col1.toLowerCase() == 'código' || col2.toLowerCase() == 'descripción') {
          isParsingInsumos = true;
          continue;
        }
        
        // Stop parsing if we hit a total row
        if (col1.toLowerCase().startsWith('total ') || col2.toLowerCase().startsWith('total ')) {
          isParsingInsumos = false;
          continue;
        }
        
        if (isParsingInsumos) {
          // If col1 is 'null' string, skip
          if (col1.toLowerCase() == 'null' && col2.toLowerCase() == 'null') continue;
          
          if (col1.isNotEmpty && col2.isNotEmpty && col1.toLowerCase() != 'null') {
            // This looks like an insumo
            final unidad = row[3]?.toString().trim() ?? '';
            final precioStr = row[4]?.toString().trim() ?? '0';
            final cantidadStr = row[5]?.toString().trim() ?? '0';
            
            final precio = double.tryParse(precioStr.replaceAll(',', '.')) ?? 0.0;
            final cantidad = double.tryParse(cantidadStr.replaceAll(',', '.')) ?? 0.0;
            
            insumos.add(InsumoApu(
              codigo: col1,
              descripcion: col2,
              unidad: unidad,
              precioUnitario: precio,
              cantidad: cantidad,
            ));
          }
        }
      }
      return insumos;
    } catch (e) {
      print('Error parsing detalleJson: $e');
      return [];
    }
  }
}
