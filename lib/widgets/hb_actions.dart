import 'package:flutter/material.dart';

import '../theme.dart';

/// Sticky dual-button bottom bar: OUT (red) + IN (green), used on the
/// Cash book and party ledger for the two primary entry actions.
/// Usage: HBStickyBottomBar(outLabel: 'Cash Out', inLabel: 'Cash In',
///          onOut: (){...}, onIn: (){...})
class HBStickyBottomBar extends StatelessWidget {
  final String outLabel;
  final String inLabel;
  final VoidCallback onOut;
  final VoidCallback onIn;

  const HBStickyBottomBar({
    super.key,
    required this.outLabel,
    required this.inLabel,
    required this.onOut,
    required this.onIn,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? HBColors.cardDark : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark
                  ? HBColors.hairlineDark
                  : HBColors.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _barButton(
              context,
              label: outLabel,
              icon: Icons.remove_circle_outline,
              bg: HBColors.moneyOut,
              fg: Colors.white,
              onTap: onOut,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _barButton(
              context,
              label: inLabel,
              icon: Icons.add_circle_outline,
              bg: HBColors.moneyIn,
              fg: Colors.white,
              onTap: onIn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barButton(BuildContext context,
      {required String label,
      required IconData icon,
      required Color bg,
      required Color fg,
      required VoidCallback onTap}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// Full-width pill button (solid or outlined).
/// Usage: HBPillButton(label: 'Save', onPressed: (){...})
class HBPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final Color? color;

  const HBPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? HBColors.primary;
    final btn = icon == null
        ? ElevatedButton(
            onPressed: onPressed, child: Text(label))
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label));
    final outline = icon == null
        ? OutlinedButton(
            onPressed: onPressed, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label));
    if (outlined) return SizedBox(width: double.infinity, child: outline);
    if (color != null) {
      final colored = icon == null
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(backgroundColor: bg),
              child: Text(label))
          : ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(backgroundColor: bg),
              icon: Icon(icon, size: 20),
              label: Text(label));
      return SizedBox(width: double.infinity, child: colored);
    }
    return SizedBox(width: double.infinity, child: btn);
  }
}

/// Extended pill FAB (icon + label), bottom-right.
/// Usage: HBFab(label: 'Add', icon: Icons.add, onPressed: (){...})
class HBFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const HBFab(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: HBColors.primary,
      foregroundColor: Colors.white,
      icon: Icon(icon),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28)),
    );
  }
}
