import 'package:flutter/material.dart';

import '../theme.dart';

/// Small letterspaced section label, e.g. "KHATA".
/// Usage: HBSectionLabel('KHATA', trailing: myLinkWidget)
class HBSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const HBSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        ?trailing,
      ],
    );
  }
}

/// Icon tile: icon on a tinted rounded square + label below.
/// Usage: HBModuleTile(icon: Icons.people, label: 'Party',
///          onTap: () => ..., tint: HBColors.primarySoft)
class HBModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tint;
  final Color iconColor;
  final String? badge;

  const HBModuleTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = HBColors.primarySoft,
    this.iconColor = HBColors.primary,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? HBColors.primarySoftDark : tint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 30, color: iconColor),
              ),
              if (badge != null)
                Positioned(
                  top: -6,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: HBColors.moneyIn,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// White summary card with 2-3 stat blocks + optional action row.
/// Usage: HBSummaryCard(stats: [HBStat('You will get', 'Rs 5,000', false)],
///          actionLabel: 'Report', onAction: ...)
class HBStat {
  final String label;
  final String value;
  final bool isIn; // money direction -> green/red

  const HBStat(this.label, this.value, this.isIn);
}

class HBSummaryCard extends StatelessWidget {
  final List<HBStat> stats;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HBSummaryCard({
    super.key,
    required this.stats,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      color: isDark ? HBColors.cardDark : HBColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(stats[i].label,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? HBColors.mutedDark
                                    : HBColors.muted)),
                        const SizedBox(height: 4),
                        Text(stats[i].value,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: moneyColor(stats[i].isIn,
                                    isDark: isDark))),
                      ],
                    ),
                  ),
                  if (i < stats.length - 1)
                    Container(
                      width: 1,
                      height: 36,
                      color: isDark
                          ? HBColors.hairlineDark
                          : HBColors.hairline,
                    ),
                ],
              ],
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.bar_chart, size: 18),
                label: Text(actionLabel!),
                style: TextButton.styleFrom(
                    foregroundColor: HBColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small rounded chip, selectable.
/// Usage: HBChip(label: 'All', selected: true, onTap: () {...})
class HBChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const HBChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? HBColors.primary
              : (isDark ? HBColors.cardDark : HBColors.card),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? HBColors.primary
                  : (isDark
                      ? HBColors.hairlineDark
                      : HBColors.hairline)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? HBColors.mutedDark : HBColors.muted),
          ),
        ),
      ),
    );
  }
}
