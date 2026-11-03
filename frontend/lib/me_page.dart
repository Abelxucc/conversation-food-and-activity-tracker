import 'package:flutter/cupertino.dart';

import 'food_style.dart';

class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.onSignOut,
    this.signingOut = false,
    this.error,
  });

  final VoidCallback onSignOut;
  final bool signingOut;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 0),
        child: Text('Me', style: TextStyle(fontSize: 24, letterSpacing: -.6)),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 48, 22, 22),
          children: [
            _menuItem('Edit my profile', CupertinoIcons.person),
            const SizedBox(height: 14),
            _menuItem('Settings', CupertinoIcons.gear_alt),
            const SizedBox(height: 14),
            _menuItem('About us', CupertinoIcons.info),
            const SizedBox(height: 14),
            _menuItem(
              'Sign out',
              CupertinoIcons.square_arrow_right,
              action: true,
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  key: const Key('sign-out-error'),
                  style: const TextStyle(
                    color: CupertinoColors.destructiveRed,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _menuItem(String label, IconData icon, {bool action = false}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: FoodStyle.pale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 25, color: FoodStyle.forest),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: FoodStyle.ink),
            ),
          ),
          const SizedBox(width: 10),
          if (!action)
            const Text(
              'Coming soon',
              style: TextStyle(fontSize: 10, color: FoodStyle.muted),
            )
          else if (signingOut)
            const CupertinoActivityIndicator()
          else
            const Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: FoodStyle.forest,
            ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: FoodStyle.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x102C4431),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: action
          ? CupertinoButton(
              key: const Key('sign-out'),
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(32),
              onPressed: signingOut ? null : onSignOut,
              child: row,
            )
          : Semantics(button: true, enabled: false, child: row),
    );
  }
}
