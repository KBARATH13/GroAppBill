class CalculatorEngine {
  /// Simple expression evaluator supporting +, -, *, /
  static double? evaluate(String expr) {
    try {
      expr = expr.replaceAll(' ', '');
      if (expr.isEmpty) return null;

      // Tokenize into numbers and operators
      final List<dynamic> tokens = [];
      String numBuffer = '';

      for (int i = 0; i < expr.length; i++) {
        final ch = expr[i];
        if ('0123456789.'.contains(ch)) {
          numBuffer += ch;
        } else if ('+-*/'.contains(ch)) {
          // Handle negative numbers at start or after another operator
          if (numBuffer.isEmpty && ch == '-' && 
              (tokens.isEmpty || tokens.last is String)) {
            numBuffer += ch;
          } else {
            if (numBuffer.isNotEmpty) {
              final val = double.tryParse(numBuffer);
              if (val == null) return null;
              tokens.add(val);
              numBuffer = '';
            }
            tokens.add(ch);
          }
        } else {
          return null; // Invalid character
        }
      }
      if (numBuffer.isNotEmpty) {
        final val = double.tryParse(numBuffer);
        if (val == null) return null;
        tokens.add(val);
      }

      if (tokens.isEmpty) return null;
      if (tokens.last is String) return null; // Trailing operator

      // Pass 1: handle * and /
      final List<dynamic> pass1 = [];
      int i = 0;
      while (i < tokens.length) {
        final current = tokens[i];
        if (current is String && (current == '*' || current == '/')) {
          if (pass1.isEmpty || pass1.last is String) return null;
          final left = pass1.removeLast() as double;
          i++;
          if (i >= tokens.length) return null;
          final next = tokens[i];
          if (next is! double) return null;
          
          if (current == '*') {
            pass1.add(left * next);
          } else {
            if (next == 0) return null; // Division by zero
            pass1.add(left / next);
          }
        } else {
          pass1.add(current);
        }
        i++;
      }

      // Pass 2: handle + and -
      if (pass1.isEmpty) return null;
      if (pass1.first is! double) return null;
      
      double result = pass1[0] as double;
      for (int j = 1; j < pass1.length; j += 2) {
        if (j + 1 >= pass1.length) break;
        final op = pass1[j];
        final right = pass1[j + 1];
        if (op is! String || right is! double) return null;
        
        if (op == '+') {
          result += right;
        } else if (op == '-') {
          result -= right;
        } else {
          return null;
        }
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  static String formatNumber(double n) {
    if (n == n.roundToDouble() && n.abs() < 1e15) {
      return n.toInt().toString();
    }
    // Remove trailing zeros for decimals
    String s = n.toStringAsFixed(6);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }
}
