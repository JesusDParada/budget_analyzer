import 'package:excel/excel.dart';

class FormulaEvaluator {
  final Excel excel;

  final Map<String, double> _cache = {};
  // Track cells currently being evaluated to prevent infinite recursion
  final Set<String> _evaluating = {};

  FormulaEvaluator(this.excel);

  double evaluateCell(String sheetName, String cellAddress) {
    final cacheKey = '$sheetName!$cellAddress';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Prevent circular references
    if (_evaluating.contains(cacheKey)) {
      return 0.0;
    }
    _evaluating.add(cacheKey);

    var sheet = excel.tables[sheetName];
    if (sheet == null) {
      _evaluating.remove(cacheKey);
      return 0.0;
    }
    try {
      var index = CellIndex.indexByString(cellAddress);
      // Ensure row and column indices are within bounds
      if (index.rowIndex >= sheet.maxRows || index.columnIndex >= sheet.maxColumns) {
        _cache[cacheKey] = 0.0;
        _evaluating.remove(cacheKey);
        return 0.0;
      }
      var cell = sheet.cell(CellIndex.indexByColumnRow(rowIndex: index.rowIndex, columnIndex: index.columnIndex));
      if (cell.value == null) {
        _cache[cacheKey] = 0.0;
        _evaluating.remove(cacheKey);
        return 0.0;
      }
      
      final result = evaluateValue(sheetName, cell.value!);
      _cache[cacheKey] = result;
      _evaluating.remove(cacheKey);
      return result;
    } catch (e) {
      _cache[cacheKey] = 0.0;
      _evaluating.remove(cacheKey);
      return 0.0;
    }
  }

  double evaluateValue(String sheetName, CellValue val) {
    if (val is IntCellValue) {
      return val.value.toDouble();
    } else if (val is DoubleCellValue) {
      return val.value;
    } else if (val is FormulaCellValue) {
      final formula = val.formula.trim();
      if (formula.isEmpty) return 0.0; // Empty formula → 0
      return evaluateFormula(sheetName, formula);
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

    // If formula is empty after cleaning
    if (clean.isEmpty) return 0.0;

    // 1. Check if it's a direct sheet reference, e.g. 'DESGLOSE APUS'!H10009 or '1.1'!G38
    // Accept any sheet name in single quotes, or simple names without quotes
    var sheetRefRegex = RegExp(r"^'([^']+)'!([A-Z]+[0-9]+)$");
    var match = sheetRefRegex.firstMatch(clean);
    if (match != null) {
      var refSheetName = match.group(1)!;
      var refCell = match.group(2)!;
      return evaluateCell(refSheetName, refCell);
    }
    // Also handle unquoted sheet references like FUNCIONAMIENTO!J9
    var unquotedSheetRefRegex = RegExp(r"^([A-Za-z0-9_\-\.]+)!([A-Z]+[0-9]+)$");
    match = unquotedSheetRefRegex.firstMatch(clean);
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

    // 3. Check ROUND(expression, N)
    var roundRegex = RegExp(r"^ROUND\((.+),\s*(\d+)\)$", caseSensitive: false);
    match = roundRegex.firstMatch(clean);
    if (match != null) {
      var expr = match.group(1)!;
      var decimals = int.parse(match.group(2)!);
      var val = _evaluateExpr(sheetName, expr);
      return double.parse(val.toStringAsFixed(decimals));
    }

    // 4. Evaluate as an expression
    return _evaluateExpr(sheetName, clean);
  }

  /// Evaluates an arithmetic expression that may contain cell references,
  /// sheet references, and basic operators (+, -, *).
  double _evaluateExpr(String sheetName, String expr) {
    expr = expr.trim();
    if (expr.isEmpty) return 0.0;

    // If it's a simple number (with comma as decimal separator)
    var numVal = double.tryParse(expr.replaceAll(',', '.'));
    if (numVal != null) return numVal;

    // Tokenize the expression to properly handle additions and multiplications
    // Split by + but keep track of terms (handle simple left-to-right evaluation)
    // We need to handle + and * properly, respecting operator precedence
    
    // First, split by '+' for addition (lowest precedence)
    if (expr.contains('+')) {
      var terms = _splitByOperator(expr, '+');
      if (terms.length > 1) {
        double sum = 0;
        for (var t in terms) {
          sum += _evaluateExpr(sheetName, t);
        }
        return sum;
      }
    }

    // Then, split by '*' for multiplication
    if (expr.contains('*')) {
      var terms = _splitByOperator(expr, '*');
      if (terms.length > 1) {
        double prod = 1;
        for (var t in terms) {
          prod *= _evaluateExpr(sheetName, t);
        }
        return prod;
      }
    }

    // Check for sheet reference within expression: 'SheetName'!Cell
    var sheetRefRegex = RegExp(r"^'([^']+)'!([A-Z]+[0-9]+)$");
    var match = sheetRefRegex.firstMatch(expr);
    if (match != null) {
      return evaluateCell(match.group(1)!, match.group(2)!);
    }
    // Unquoted sheet reference: SheetName!Cell
    var unquotedRefRegex = RegExp(r"^([A-Za-z0-9_\-\.]+)!([A-Z]+[0-9]+)$");
    match = unquotedRefRegex.firstMatch(expr);
    if (match != null) {
      return evaluateCell(match.group(1)!, match.group(2)!);
    }

    // Simple cell reference in current sheet, e.g. G37
    var cellRegex = RegExp(r"^([A-Z]+)(\d+)$");
    match = cellRegex.firstMatch(expr);
    if (match != null) {
      return evaluateCell(sheetName, expr);
    }

    return 0.0;
  }

  /// Splits an expression by a top-level operator, respecting parentheses and quotes.
  List<String> _splitByOperator(String expr, String op) {
    List<String> parts = [];
    int depth = 0;
    bool inQuote = false;
    int lastSplit = 0;

    for (int i = 0; i < expr.length; i++) {
      var ch = expr[i];
      if (ch == "'") {
        inQuote = !inQuote;
      } else if (!inQuote) {
        if (ch == '(') {
          depth++;
        } else if (ch == ')') {
          depth--;
        } else if (ch == op && depth == 0) {
          var part = expr.substring(lastSplit, i).trim();
          if (part.isNotEmpty) parts.add(part);
          lastSplit = i + 1;
        }
      }
    }
    var lastPart = expr.substring(lastSplit).trim();
    if (lastPart.isNotEmpty) parts.add(lastPart);

    return parts;
  }

  int _colIndex(String colStr) {
    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 65 + 1);
    }
    return col - 1;
  }
}
