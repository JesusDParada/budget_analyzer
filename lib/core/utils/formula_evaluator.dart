import 'package:excel/excel.dart';

class FormulaEvaluator {
  final Excel excel;

  final Map<String, double> _cache = {};

  FormulaEvaluator(this.excel);

  double evaluateCell(String sheetName, String cellAddress) {
    final cacheKey = '$sheetName!$cellAddress';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    var sheet = excel.tables[sheetName];
    if (sheet == null) return 0.0;
    try {
      var index = CellIndex.indexByString(cellAddress);
      // Ensure row and column indices are within bounds
      if (index.rowIndex >= sheet.maxRows || index.columnIndex >= sheet.maxColumns) {
        _cache[cacheKey] = 0.0;
        return 0.0;
      }
      var cell = sheet.cell(CellIndex.indexByColumnRow(rowIndex: index.rowIndex, columnIndex: index.columnIndex));
      if (cell.value == null) {
        _cache[cacheKey] = 0.0;
        return 0.0;
      }
      
      final result = evaluateValue(sheetName, cell.value!);
      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      _cache[cacheKey] = 0.0;
      return 0.0;
    }
  }

  double evaluateValue(String sheetName, CellValue val) {
    if (val is IntCellValue) {
      return val.value.toDouble();
    } else if (val is DoubleCellValue) {
      return val.value;
    } else if (val is FormulaCellValue) {
      return evaluateFormula(sheetName, val.formula);
    } else if (val is TextCellValue) {
      // Clean comma separators commonly used in Spanish formats (e.g. 1,2)
      var clean = val.value.text?.replaceAll(',', '.') ?? '';
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  double evaluateFormula(String sheetName, String formula) {
    var clean = formula.trim().replaceAll(r'$', '');
    if (clean.startsWith('=')) clean = clean.substring(1);
    if (clean.startsWith('+')) clean = clean.substring(1);
    
    // 1. Check if it's a direct sheet reference, e.g. '1.1'!G38 or M-1.1!H32
    var sheetRefRegex = RegExp(r"^'?(M-[0-9\.]+|[0-9\.]+)'?!([A-Z]+[0-9]+)$");
    var match = sheetRefRegex.firstMatch(clean);
    if (match != null) {
      var refSheetName = match.group(1)!;
      var refCell = match.group(2)!;
      return evaluateCell(refSheetName, refCell);
    }

    // 2. Check SUM(H17:H31)
    var sumRegex = RegExp(r"^SUM\(([A-Z]+)(\d+):([A-Z]+)(\d+)\)$", caseSensitive: false);
    match = sumRegex.firstMatch(clean);
    if (match != null) {
      var startColStr = match.group(1)!;
      var startRowInt = int.parse(match.group(2)!);
      var endColStr = match.group(3)!;
      var endRowInt = int.parse(match.group(4)!);

      var startCol = _colIndex(startColStr);
      var endCol = _colIndex(endColStr);

      double sum = 0;
      var sheet = excel.tables[sheetName];
      if (sheet != null) {
        for (int r = startRowInt - 1; r <= endRowInt - 1; r++) {
          for (int c = startCol; c <= endCol; c++) {
            if (r < sheet.maxRows && c < sheet.maxColumns) {
              var cell = sheet.cell(CellIndex.indexByColumnRow(rowIndex: r, columnIndex: c));
              if (cell.value != null) {
                sum += evaluateValue(sheetName, cell.value!);
              }
            }
          }
        }
      }
      return sum;
    }

    // 3. Check ROUND(X*Y, N)
    var roundRegex = RegExp(r"^ROUND\(([^,]+),\s*(\d+)\)$", caseSensitive: false);
    match = roundRegex.firstMatch(clean);
    if (match != null) {
      var expr = match.group(1)!;
      var decimals = int.parse(match.group(2)!);
      var val = evaluateExpression(sheetName, expr);
      return double.parse(val.toStringAsFixed(decimals));
    }

    // 4. Evaluate standard expressions
    return evaluateExpression(sheetName, clean);
  }

  double evaluateExpression(String sheetName, String cleanExpr) {
    // If it's a simple number
    var numVal = double.tryParse(cleanExpr.replaceAll(',', '.'));
    if (numVal != null) return numVal;

    // Check additions (+G35+G29+G23+G17)
    if (cleanExpr.contains('+')) {
      var terms = cleanExpr.split('+');
      double sum = 0;
      for (var t in terms) {
        sum += evaluateExpression(sheetName, t);
      }
      return sum;
    }

    // Check multiplications (G17*F17*E17*D17)
    if (cleanExpr.contains('*')) {
      var terms = cleanExpr.split('*');
      double prod = 1;
      for (var t in terms) {
        prod *= evaluateExpression(sheetName, t);
      }
      return prod;
    }

    // Otherwise it must be a cell reference in the current sheet, e.g. G37
    var cellRegex = RegExp(r"^([A-Z]+)(\d+)$");
    var match = cellRegex.firstMatch(cleanExpr);
    if (match != null) {
      return evaluateCell(sheetName, cleanExpr);
    }

    return 0.0;
  }

  int _colIndex(String colStr) {
    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 65 + 1);
    }
    return col - 1;
  }
}
