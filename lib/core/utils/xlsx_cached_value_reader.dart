import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads cached formula results directly from the xlsx XML.
///
/// The Dart `excel` package only exposes formula strings (e.g. "'1.1'!$G$38"),
/// not the pre-calculated cached values. However, the .xlsx format (which is
/// a ZIP of XML files) stores cached values in the `<v>` element of each cell.
/// This class reads those cached values directly.
class XlsxCachedValueReader {
  /// Shared strings table (for cells with type="s")
  final List<String> _sharedStrings = [];
  
  /// Map of sheet name -> { cellRef -> cachedValue }
  /// e.g. { "PRESUPUESTO DE OBRA": { "E15": 75429.204, "F15": 75.0 } }
  final Map<String, Map<String, dynamic>> _sheetData = {};

  XlsxCachedValueReader(List<int> bytes) {
    _parse(bytes);
  }

  void _parse(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Read shared strings
    final ssFile = archive.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      ssFile.decompress();
      final ssXml = XmlDocument.parse(utf8.decode(ssFile.content));
      for (var si in ssXml.findAllElements('si')) {
        _sharedStrings.add(si.findAllElements('t').map((t) => t.innerText).join(''));
      }
    }

    // 2. Read workbook.xml to get sheet names and rIds
    final workbookFile = archive.findFile('xl/workbook.xml')!;
    workbookFile.decompress();
    final workbookXml = XmlDocument.parse(utf8.decode(workbookFile.content));
    
    Map<String, String> sheetNameToRid = {};
    for (var sheet in workbookXml.findAllElements('sheet')) {
      final name = sheet.getAttribute('name') ?? '';
      final rId = sheet.getAttribute('r:id') ?? '';
      sheetNameToRid[name] = rId;
    }

    // 3. Read workbook.xml.rels to map rId to file path
    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels')!;
    relsFile.decompress();
    final relsXml = XmlDocument.parse(utf8.decode(relsFile.content));
    
    Map<String, String> rIdToPath = {};
    for (var rel in relsXml.findAllElements('Relationship')) {
      rIdToPath[rel.getAttribute('Id') ?? ''] = rel.getAttribute('Target') ?? '';
    }

    // 4. Parse each sheet XML and extract cached values
    for (var entry in sheetNameToRid.entries) {
      final sheetName = entry.key;
      final rId = entry.value;
      final path = rIdToPath[rId];
      if (path == null) continue;

      final sheetPath = 'xl/$path';
      final sheetFile = archive.findFile(sheetPath);
      if (sheetFile == null) continue;

      sheetFile.decompress();
      final sheetXml = XmlDocument.parse(utf8.decode(sheetFile.content));
      
      Map<String, dynamic> cellValues = {};
      final sheetData = sheetXml.findAllElements('sheetData');
      if (sheetData.isEmpty) continue;

      for (var row in sheetData.first.findAllElements('row')) {
        for (var cell in row.findAllElements('c')) {
          final cellRef = cell.getAttribute('r') ?? '';
          final cellType = cell.getAttribute('t') ?? 'n';
          final vElements = cell.findElements('v');
          
          if (vElements.isEmpty) continue;
          final rawValue = vElements.first.innerText;

          if (cellType == 's') {
            // Shared string reference
            final idx = int.tryParse(rawValue);
            if (idx != null && idx < _sharedStrings.length) {
              cellValues[cellRef] = _sharedStrings[idx];
            }
          } else if (cellType == 'str') {
            // Inline string (cached string formula result)
            cellValues[cellRef] = rawValue;
          } else {
            // Numeric value
            final numVal = double.tryParse(rawValue);
            cellValues[cellRef] = numVal ?? rawValue;
          }
        }
      }
      
      _sheetData[sheetName] = cellValues;
    }
  }

  /// Get the cached value of a cell as a double.
  /// Returns null if the cell has no cached value.
  double? getCachedDouble(String sheetName, String cellRef) {
    final sheet = _sheetData[sheetName];
    if (sheet == null) return null;
    final val = sheet[cellRef];
    if (val == null) return null;
    if (val is double) return val;
    if (val is String) return double.tryParse(val.replaceAll(',', '.'));
    return null;
  }

  /// Get the cached value of a cell as a string.
  /// Returns null if the cell has no cached value.
  String? getCachedString(String sheetName, String cellRef) {
    final sheet = _sheetData[sheetName];
    if (sheet == null) return null;
    return sheet[cellRef]?.toString();
  }

  /// Get all cached cell values for a sheet.
  Map<String, dynamic>? getSheetData(String sheetName) {
    return _sheetData[sheetName];
  }
}
