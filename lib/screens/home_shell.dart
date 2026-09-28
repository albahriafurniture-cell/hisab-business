import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../routes.dart';
import '../theme.dart';

/// Bottom-nav shell. Tab bodies are STUBS for now — feature crews and the
/// coordinator wire real screens here later.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.current,
      builder: (context, lang, _) {
        final tabs = [
          _TabStub(label: tr(context, 'nav.home'), route: Routes.home),
          _TabStub(
              label: tr(context, 'nav.parties'), route: Routes.parties),
          _TabStub(label: tr(context, 'nav.cash'), route: Routes.cash),
          _TabStub(label: tr(context, 'nav.bills'), route: Routes.bills),
          _TabStub(label: tr(context, 'nav.more'), route: Routes.more),
        ];
        return Directionality(
          textDirection:
              isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: IndexedStack(index: _index, children: tabs),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              items: [
                BottomNavigationBarItem(
                    icon: const Icon(Icons.home),
                    label: tr(context, 'nav.home')),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.people),
                    label: tr(context, 'nav.parties')),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.account_balance_wallet),
                    label: tr(context, 'nav.cash')),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.receipt),
                    label: tr(context, 'nav.bills')),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.grid_view),
                    label: tr(context, 'nav.more')),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder tab body — replaced by feature crews.
class _TabStub extends StatelessWidget {
  final String label;
  final String route;

  const _TabStub({required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction,
              size: 48, color: HBColors.muted),
          const SizedBox(height: 12),
          Text(label,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('stub · $route',
              style: const TextStyle(color: HBColors.muted)),
        ],
      ),
    );
  }
}
