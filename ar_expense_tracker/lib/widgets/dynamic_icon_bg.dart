import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class DynamicIconBg extends ConsumerWidget {
  final Widget child;
  final Color? color;
  final double padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final AppIconShape? shape;

  const DynamicIconBg({
    super.key,
    required this.child,
    this.color,
    this.padding = 8.0,
    this.width,
    this.height,
    this.alignment,
    this.shape,
  });

  static OutlinedBorder getShapeBorder(AppIconShape shape) {
    switch (shape) {
      case AppIconShape.circle:
        return const CircleBorder();
      case AppIconShape.square:
        return const RoundedRectangleBorder(borderRadius: BorderRadius.zero);
      case AppIconShape.rounded:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
      case AppIconShape.squircle:
        return ContinuousRectangleBorder(borderRadius: BorderRadius.circular(20));
      case AppIconShape.hexagon:
        return const StarBorder.polygon(sides: 6, pointRounding: 0.2);
      case AppIconShape.octagon:
        return const StarBorder.polygon(sides: 8, pointRounding: 0.2);
      case AppIconShape.pentagon:
        return const StarBorder.polygon(sides: 5, pointRounding: 0.2);
      case AppIconShape.diamond:
        return const StarBorder.polygon(sides: 4, pointRounding: 0.2);
      case AppIconShape.star:
        return const StarBorder(points: 5, innerRadiusRatio: 0.5, pointRounding: 0.1);
      case AppIconShape.beveled:
        return BeveledRectangleBorder(borderRadius: BorderRadius.circular(10));
      case AppIconShape.teardrop:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(6),
          ),
        );
      case AppIconShape.flower:
        return const StarBorder(points: 8, innerRadiusRatio: 0.8, pointRounding: 0.3, valleyRounding: 0.3);
      case AppIconShape.flower2:
        return const StarBorder(points: 6, innerRadiusRatio: 0.75, pointRounding: 0.4, valleyRounding: 0.4);
      case AppIconShape.flower3:
        return const StarBorder(points: 12, innerRadiusRatio: 0.85, pointRounding: 0.2, valleyRounding: 0.2);
      case AppIconShape.wavy:
        return const StarBorder(points: 4, innerRadiusRatio: 0.8, pointRounding: 0.5, valleyRounding: 0.5);
      case AppIconShape.shield:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        );
      case AppIconShape.ticket:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(0),
          ),
        );
      case AppIconShape.pill:
        return const StadiumBorder();
      case AppIconShape.triangle:
        return const StarBorder.polygon(sides: 3, pointRounding: 0.2);
      case AppIconShape.cross:
        return const StarBorder(points: 4, innerRadiusRatio: 0.4, pointRounding: 0.1);
      case AppIconShape.polygon10:
        return const StarBorder.polygon(sides: 10, pointRounding: 0.2);
      case AppIconShape.polygon12:
        return const StarBorder.polygon(sides: 12, pointRounding: 0.2);
      case AppIconShape.burst:
        return const StarBorder(points: 16, innerRadiusRatio: 0.9, pointRounding: 0.1);
      case AppIconShape.badge:
        return const StarBorder(points: 20, innerRadiusRatio: 0.92, pointRounding: 0.1, valleyRounding: 0.1);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppIconShape activeShape = shape ?? ref.watch(iconShapeProvider);
    final bgColor = color ?? Theme.of(context).colorScheme.primaryContainer;

    return Container(
      width: width,
      height: height,
      alignment: alignment,
      decoration: ShapeDecoration(
        color: bgColor,
        shape: getShapeBorder(activeShape),
      ),
      padding: EdgeInsets.all(padding),
      child: child,
    );
  }
}
