import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../theme.dart';

/// Standard list row: avatar + name + subtitle, right-aligned amount
/// (colored by money direction) + small status word under it.
/// Usage: HBLedgerRow(name: 'Ali', subtitle: 'Mon, 14 Mar', amount: 5000,
///          isIn: false, status: "You'll Get", onTap: ..., onCall: ...)
class HBLedgerRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final double amount;
  final bool isIn;
  final String status;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final String? photoPath;
  final bool hideAmount;

  const HBLedgerRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.isIn,
    required this.status,
    this.onTap,
    this.onCall,
    this.photoPath,
    this.hideAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isIn
                  ? moneySoft(true, isDark: isDark)
                  : moneySoft(false, isDark: isDark),
              backgroundImage:
                  (photoPath != null && photoPath!.isNotEmpty)
                      ? null
                      : null, // [INFERRED] photoPath wired by feature crew
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: moneyColor(isIn, isDark: isDark)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? HBColors.mutedDark
                              : HBColors.muted)),
                ],
              ),
            ),
            if (onCall != null)
              IconButton(
                icon: const Icon(Icons.call, size: 20),
                color: HBColors.primary,
                onPressed: onCall,
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hideAmount ? '••••••' : formatPKR(amount),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: moneyColor(isIn, isDark: isDark)),
                ),
                const SizedBox(height: 2),
                Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? HBColors.mutedDark
                            : HBColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Search field + filter + PDF/action icons row.
/// Usage: HBSearchRow(hint: '6 Parties', onChanged: (q){...},
///          onFilter: (){...}, onPdf: (){...})
class HBSearchRow extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilter;
  final VoidCallback? onPdf;

  const HBSearchRow({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onFilter,
    this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.search),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          if (onFilter != null) ...[
            const SizedBox(width: 8),
            _squareButton(
                context, Icons.filter_list, onFilter!, isDark),
          ],
          if (onPdf != null) ...[
            const SizedBox(width: 8),
            _squareButton(context, Icons.picture_as_pdf, onPdf!,
                isDark),
          ],
        ],
      ),
    );
  }

  Widget _squareButton(BuildContext context, IconData icon,
      VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? HBColors.cardDark : HBColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? HBColors.hairlineDark
                  : HBColors.hairline),
        ),
        child: Icon(icon, color: HBColors.primary),
      ),
    );
  }
}

/// Centered empty state: icon, title, subtitle, optional CTA.
/// Usage: HBEmptyState(icon: Icons.people, title: 'No parties yet',
///          subtitle: '...', ctaLabel: 'Add', onCta: (){...})
class HBEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const HBEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: isDark
                    ? HBColors.primarySoftDark
                    : HBColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 40, color: HBColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 14,
                    color:
                        isDark ? HBColors.mutedDark : HBColors.muted),
                textAlign: TextAlign.center),
            if (ctaLabel != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                  onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Money amount text colored by direction, using [formatPKR].
/// Usage: HBAmountText(5000, isIn: true, size: 18)
class HBAmountText extends StatelessWidget {
  final double amount;
  final bool isIn;
  final double size;
  final FontWeight weight;
  final bool hide;

  const HBAmountText(
    this.amount, {
    super.key,
    required this.isIn,
    this.size = 16,
    this.weight = FontWeight.bold,
    this.hide = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      hide ? '••••••' : formatPKR(amount),
      style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: moneyColor(isIn, isDark: isDark)),
    );
  }
}
