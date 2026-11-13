import 'dart:async';
import 'package:flutter/material.dart';

class UndoSnackbarContent extends StatefulWidget {
  final VoidCallback onUndo;
  final int durationSeconds;

  const UndoSnackbarContent({
    super.key,
    required this.onUndo,
    this.durationSeconds = 10,
  });

  @override
  State<UndoSnackbarContent> createState() => _UndoSnackbarContentState();
}

class _UndoSnackbarContentState extends State<UndoSnackbarContent> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remaining > 1) {
            _remaining--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.onInverseSurface),
          const SizedBox(width: 8),
          Text(
            'Expense deleted',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onInverseSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          // Timer text
          Text(
            '${_remaining}s',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onInverseSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          // Undo Button
          InkWell(
            onTap: widget.onUndo,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'UNDO',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.inversePrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
