import 'package:flutter/material.dart';

/// Semi-transparent scrim with a centered progress indicator.
class LoadingOverlay extends StatelessWidget {
  /// Wraps [child] and shows [visible] loading layer.
  const LoadingOverlay({super.key, required this.visible, required this.child, this.message});

  final bool visible;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black38,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        if (message != null) ...[
                          const SizedBox(height: 16),
                          Text(message!, textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
