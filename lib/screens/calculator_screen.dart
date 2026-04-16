import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/history_service.dart';
import '../utils/calculator_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_container.dart';
import '../widgets/vibrant_background.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  final String? initialExpression;
  final String? initialBillId;
  final String? initialFirestoreId;

  const CalculatorScreen({
    super.key,
    this.initialExpression,
    this.initialBillId,
    this.initialFirestoreId,
  });

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late ScrollController _textScrollController;
  bool _justEvaluated = false;
  String _lastSavedMessage = '';
  String _realTimeResult = '';

  late AnimationController _saveAnimController;
  late Animation<double> _saveAnimOpacity;

  @override
  void initState() {
    super.initState();
    _textScrollController = ScrollController();
    _saveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _saveAnimOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _saveAnimController, curve: Curves.easeInOut),
    );
    _saveAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _lastSavedMessage = '');
      }
    });

    _controller = TextEditingController(text: widget.initialExpression ?? '');
    _controller.addListener(_updateRealTimeResult);
    
    // Trigger an initial calculation if passed from history
    if (widget.initialExpression != null && widget.initialExpression!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateRealTimeResult();
      });
    } else {
      _loadDraft();
    }
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('calculator_draft');
    if (draft != null && draft.isNotEmpty && mounted) {
      _controller.text = draft;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: draft.length),
      );
      _updateRealTimeResult();
    }
  }

  @override
  void dispose() {
    _saveAnimController.dispose();
    _controller.dispose();
    _textScrollController.dispose();
    super.dispose();
  }

  void _updateRealTimeResult() {
    // Auto-scroll to keep cursor visible if it is at the end of the text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_textScrollController.hasClients && _controller.selection.baseOffset == _controller.text.length) {
        _textScrollController.animateTo(
          _textScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
    });

    final text = _controller.text;
    if (text.isEmpty) {
      setState(() => _realTimeResult = '');
      return;
    }

    // Try to evaluate. If it ends in an operator, or has an operator at cursor, evaluate prefix/cleaned version
    String evalExpr = text;
    // Simple way to handle trailing operators for real-time feedback
    while (evalExpr.isNotEmpty && '+-*/'.contains(evalExpr[evalExpr.length - 1])) {
      evalExpr = evalExpr.substring(0, evalExpr.length - 1);
    }

    if (evalExpr.isEmpty) {
      setState(() => _realTimeResult = '');
      return;
    }

    final result = CalculatorEngine.evaluate(evalExpr);
    setState(() {
      if (result != null) {
        final resStr = CalculatorEngine.formatNumber(result);
        _realTimeResult = (resStr == text) ? '' : resStr;
      } else {
        _realTimeResult = '';
      }
    });

    // Save to SharedPreferences seamlessly
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('calculator_draft', text);
    });
  }

  void _insertText(String text) {
    setState(() {
      if (_justEvaluated) {
        if ('0123456789'.contains(text)) {
          _controller.text = text;
        } else {
          _controller.text = _controller.text + text;
        }
        _justEvaluated = false;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        return;
      }

      final selection = _controller.selection;
      final currentText = _controller.text;

      // Handle operator swapping logic if inserted at current position and previous is operator
      if ('+-*/'.contains(text) && selection.start == selection.end && selection.start > 0) {
        String prevChar = currentText[selection.start - 1];
        if ('+-*/'.contains(prevChar)) {
          final newText = currentText.replaceRange(selection.start - 1, selection.start, text);
          _controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start),
          );
          return;
        }
      }

      final newText = currentText.replaceRange(selection.start, selection.end, text);
      final newOffset = selection.start + text.length;

      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    });
  }

  void _onDigit(String digit) {
    _insertText(digit);
  }

  void _onDecimal() {
    final selection = _controller.selection;
    final text = _controller.text;
    
    // Find the current number segment around the cursor
    int start = selection.start - 1;
    while (start >= 0 && '0123456789.'.contains(text[start])) {
      if (text[start] == '.') return; // Already has a decimal
      start--;
    }
    _insertText('.');
  }

  void _onOperator(String op) {
    _insertText(op);
  }

  void _onPercent() {
    // Current implementation of percent is simple; we can apply it to the whole expression result for now
    if (_realTimeResult.isNotEmpty) {
      final res = double.tryParse(_realTimeResult);
      if (res != null) {
        _controller.text = CalculatorEngine.formatNumber(res / 100);
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    }
  }

  void _onClear() async {
    setState(() {
      _controller.clear();
      _justEvaluated = false;
      _realTimeResult = '';
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('calculator_draft');
  }

  void _onBackspace() {
    setState(() {
      final selection = _controller.selection;
      final text = _controller.text;

      if (text.isEmpty) return;
      
      // Reset evaluated state as soon as user starts correcting
      _justEvaluated = false;

      // Handle case where cursor might be at the start
      if (selection.start <= 0 && selection.end <= 0) return;

      if (selection.start != selection.end) {
        // Delete the highlighted selection
        final newText = text.replaceRange(selection.start, selection.end, '');
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start),
        );
      } else {
        // Delete the single character before the cursor
        final newText = text.replaceRange(selection.start - 1, selection.start, '');
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start - 1),
        );
      }
    });
  }

  Future<void> _onEquals() async {
    String fullExpr = _controller.text;
    if (fullExpr.isEmpty) return;

    // Clean up trailing operators before evaluating to avoid errors
    while (fullExpr.isNotEmpty && '+-*/'.contains(fullExpr[fullExpr.length - 1])) {
      fullExpr = fullExpr.substring(0, fullExpr.length - 1);
    }

    if (fullExpr.isEmpty) return;

    final result = CalculatorEngine.evaluate(fullExpr);

    if (result == null) {
      setState(() {
        _controller.text = 'Error';
        _justEvaluated = true;
      });
      return;
    }

    final resultStr = CalculatorEngine.formatNumber(result);
    final expressionDisplay = '$fullExpr=$resultStr';

    setState(() {
      _controller.text = resultStr;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: resultStr.length),
      );
      _justEvaluated = true;
    });

    // Save to bill history
    await _saveToHistory(expressionDisplay, result);
  }

  Future<void> _saveToHistory(String expression, double total) async {
    final operatorName = ref.read(userProvider) ?? 'Calculator';
    final adminEmail =
        ref.read(appUserProvider).valueOrNull?.adminEmail ?? 'local-only';

    try {
      await HistoryService.saveCalculatorEntry(
        expression: expression,
        total: total,
        operatorName: operatorName,
        adminEmail: adminEmail,
        replaceBillId: widget.initialBillId,
        replaceFirestoreId: widget.initialFirestoreId,
      );
      setState(() => _lastSavedMessage = '✓ Saved: $expression');
      _saveAnimController.reset();
      _saveAnimController.forward();
    } catch (e) {
      setState(() => _lastSavedMessage = '✗ Failed to save');
      _saveAnimController.reset();
      _saveAnimController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Calculator',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: VibrantBackground(
        child: SafeArea(
          child: Column(
            children: [
              // === Display Area ===
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Saved message
                      if (_lastSavedMessage.isNotEmpty)
                        Builder(
                          builder: (context) {
                            final scheme = Theme.of(context).colorScheme;
                            final isSuccess = _lastSavedMessage.contains('✓');
                            return FadeTransition(
                              opacity: _saveAnimOpacity,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isSuccess
                                      ? scheme.secondary.withOpacity(0.15)
                                      : scheme.error.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSuccess
                                        ? scheme.secondary.withOpacity(0.3)
                                        : scheme.error.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _lastSavedMessage,
                                  style: TextStyle(
                                    color: isSuccess
                                        ? scheme.secondary
                                        : scheme.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                      
                      // Result line (if not evaluated yet)
                      if (_realTimeResult.isNotEmpty && !_justEvaluated)
                        Text(
                          '= $_realTimeResult',
                          style: TextStyle(
                            color: const Color(0xFF2ECC71).withOpacity(0.8),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      const SizedBox(height: 8),

                      // Main Expression Field (now with cursor and touch-to-edit)
                      TextField(
                        controller: _controller,
                        scrollController: _textScrollController,
                        readOnly: true,
                        showCursor: true,
                        autofocus: true,
                        cursorColor: Colors.blueAccent,
                        cursorWidth: 3,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // === Keypad ===
              Expanded(
                flex: 4,
                child: GlassContainer(
                  borderRadius: 32,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    children: [
                      // Row 1: C, ⌫, %, ÷
                      _buildRow([
                        _CalcButton(
                          label: 'C',
                          color: Colors.redAccent,
                          textColor: Colors.white,
                          onTap: _onClear,
                        ),
                        _CalcButton(
                          icon: Icons.backspace_outlined,
                          color: Colors.orangeAccent,
                          textColor: Colors.white,
                          onTap: _onBackspace,
                        ),
                        _CalcButton(
                          label: '%',
                          color: Colors.blueAccent,
                          textColor: Colors.white,
                          onTap: _onPercent,
                        ),
                        _CalcButton(
                          label: '÷',
                          color: Colors.blueAccent,
                          textColor: Colors.white,
                          onTap: () => _onOperator('/'),
                        ),
                      ]),
                      // Row 2: 7, 8, 9, ×
                      _buildRow([
                        _CalcButton(label: '7', onTap: () => _onDigit('7')),
                        _CalcButton(label: '8', onTap: () => _onDigit('8')),
                        _CalcButton(label: '9', onTap: () => _onDigit('9')),
                        _CalcButton(
                          label: '×',
                          color: Colors.blueAccent,
                          textColor: Colors.white,
                          onTap: () => _onOperator('*'),
                        ),
                      ]),
                      // Row 3: 4, 5, 6, −
                      _buildRow([
                        _CalcButton(label: '4', onTap: () => _onDigit('4')),
                        _CalcButton(label: '5', onTap: () => _onDigit('5')),
                        _CalcButton(label: '6', onTap: () => _onDigit('6')),
                        _CalcButton(
                          label: '−',
                          color: Colors.blueAccent,
                          textColor: Colors.white,
                          onTap: () => _onOperator('-'),
                        ),
                      ]),
                      // Row 4: 1, 2, 3, +
                      _buildRow([
                        _CalcButton(label: '1', onTap: () => _onDigit('1')),
                        _CalcButton(label: '2', onTap: () => _onDigit('2')),
                        _CalcButton(label: '3', onTap: () => _onDigit('3')),
                        _CalcButton(
                          label: '+',
                          color: Colors.blueAccent,
                          textColor: Colors.white,
                          onTap: () => _onOperator('+'),
                        ),
                      ]),
                      // Row 5: 0, 00, ., =
                      _buildRow([
                        _CalcButton(label: '0', onTap: () => _onDigit('0')),
                        _CalcButton(label: '00', onTap: () => _onDigit('00')),
                        _CalcButton(label: '.', onTap: _onDecimal),
                        _CalcButton(
                          label: '=',
                          color: const Color(0xFF2ECC71),
                          textColor: Colors.white,
                          onTap: _onEquals,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<_CalcButton> buttons) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: buttons
              .map(
                (btn) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: btn,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CalcButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final VoidCallback onTap;

  const _CalcButton({
    this.label,
    this.icon,
    this.color,
    this.textColor,
    required this.onTap,
  });

  @override
  State<_CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<_CalcButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isOperator = widget.color != null;
    final activeColor = (widget.color ?? Colors.white);
    
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _isPressed = true);
        widget.onTap();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: Container(
        decoration: BoxDecoration(
          color: activeColor.withOpacity(isOperator ? (_isPressed ? 0.25 : 0.15) : (_isPressed ? 0.15 : 0.07)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activeColor.withOpacity(_isPressed ? 0.25 : 0.1),
            width: _isPressed ? 2 : 1,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: widget.icon != null
              ? Icon(widget.icon, color: widget.textColor ?? Colors.white, size: 24)
              : Text(
                  widget.label ?? '',
                  style: TextStyle(
                    color: widget.textColor ?? Colors.white,
                    fontSize: widget.label == '00' ? 20 : 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
