import 'package:flutter/material.dart';

import '../theme.dart';

/// Gradient app bar: back/hamburger on the left, title, 0-2 action icons.
/// Usage: HBAppBar(title: 'Parties', actions: [IconButton(...)]) as appBar.
class HBAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final bool showBack;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const HBAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = true,
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [HBColors.gradientTop, HBColors.gradientBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else if (showBack)
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// Text tabs with a brand-colored underline indicator.
/// Usage: HBTabs(labels: ['Customers','Suppliers'], index: i,
///          onChanged: (i) {...})
class HBTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const HBTabs(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: isDark
                  ? HBColors.hairlineDark
                  : HBColors.hairline),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == index
                            ? HBColors.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          i == index ? FontWeight.bold : FontWeight.w500,
                      color: i == index
                          ? HBColors.primary
                          : (isDark
                              ? HBColors.mutedDark
                              : HBColors.muted),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows a rounded-top modal bottom sheet with the app's styling.
/// Usage: showHBSheet(context, title: 'Add Entry', child: MyForm()).
Future<T?> showHBSheet<T>(BuildContext context,
    {required String title, required Widget child}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: isDark ? HBColors.cardDark : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? HBColors.hairlineDark
                    : HBColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    ),
  );
}

/// Floating pill toast, tinted. Usage: HBToast.show(context,
///   message: tr(context,'msg.saved'), icon: Icons.check).
class HBToast {
  static void show(BuildContext context,
      {required String message, IconData? icon, Color? tint}) {
    final overlay = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = tint ?? HBColors.moneyInSoft;
    final fg = tint != null
        ? (isDark ? Colors.white : HBColors.ink)
        : HBColors.moneyInDeep;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 96,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? HBColors.cardDark : bg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(message,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }
}
