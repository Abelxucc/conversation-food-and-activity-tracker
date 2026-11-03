import 'package:flutter/cupertino.dart';

import 'auth/LoginPage.dart';
import 'shared/app_navigation_scope.dart';
import 'shared/food_chrome.dart';
import 'food/food_page.dart';
import 'food/food_service.dart';
import 'shared/food_style.dart';
import 'me_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.service});

  static const routeName = '/app';
  final FoodService service;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _foodNavigator = GlobalKey<NavigatorState>();
  FoodDestination _selected = FoodDestination.add;
  int _pendingWrites = 0;
  bool _signingOut = false;
  String? _error;

  bool get _busy => _signingOut || _pendingWrites > 0;

  void _busyChanged(bool busy) {
    if (!mounted) return;
    setState(() => _pendingWrites += busy ? 1 : -1);
  }

  void _select(FoodDestination destination) {
    if (_busy || _selected == destination) return;
    FocusScope.of(context).unfocus();
    setState(() => _selected = destination);
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      await widget.service.signOut();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
        CupertinoPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _signingOut = false;
          _error = 'Could not sign out. Check your connection and try again.';
        });
      }
    }
  }

  Route<void> _foodRoute(RouteSettings settings) => CupertinoPageRoute<void>(
    settings: settings,
    builder: (_) => FoodPage(service: widget.service),
  );

  @override
  Widget build(BuildContext context) => FoodStyle.theme(
    PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        if (_selected != FoodDestination.add) {
          _select(FoodDestination.add);
        } else {
          _foodNavigator.currentState?.maybePop();
        }
      },
      child: CupertinoPageScaffold(
        resizeToAvoidBottomInset: false,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppNavigationScope(
                onBusyChanged: _busyChanged,
                child: Column(
                  children: [
                    Expanded(
                      child: IndexedStack(
                        index: _selected.index,
                        children: [
                          const _ComingSoonPage(
                            title: 'Home',
                            icon: CupertinoIcons.house,
                          ),
                          const _ComingSoonPage(
                            title: 'Food',
                            icon: CupertinoIcons.leaf_arrow_circlepath,
                          ),
                          ExcludeFocus(
                            excluding: _selected != FoodDestination.add,
                            child: TickerMode(
                              enabled: _selected == FoodDestination.add,
                              child: HeroControllerScope.none(
                                child: Navigator(
                                  key: _foodNavigator,
                                  onGenerateInitialRoutes: (_, _) => [
                                    _foodRoute(
                                      const RouteSettings(
                                        name: FoodPage.routeName,
                                      ),
                                    ),
                                  ],
                                  onGenerateRoute: _foodRoute,
                                ),
                              ),
                            ),
                          ),
                          const _ComingSoonPage(
                            title: 'Activity',
                            icon: CupertinoIcons.sportscourt,
                          ),
                          MePage(
                            onSignOut: _signOut,
                            signingOut: _signingOut,
                            error: _error,
                          ),
                        ],
                      ),
                    ),
                    if (MediaQuery.viewInsetsOf(context).bottom == 0)
                      FoodNavigation(
                        highlightAdd: false,
                        selectedDestination: _selected,
                        onSelected: _busy ? null : _select,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
        child: Text(title, style: const TextStyle(fontSize: 24)),
      ),
      Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: FoodStyle.forest),
              const SizedBox(height: 16),
              const Text(
                'Coming soon',
                style: TextStyle(fontSize: 18, color: FoodStyle.muted),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
