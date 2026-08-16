import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../state/providers.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/now_playing_bar.dart';

/// Root shell: splash → auth → main (home/search/library + player bar).
final class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    switch (app.status) {
      case AppStatus.loading:
        return const _Splash();
      case AppStatus.error:
        return _ErrorScreen(message: app.errorMessage ?? 'Startup failed');
      case AppStatus.ready:
        return app.isAuthed ? const _MainShell() : const AuthScreen();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('HIRENA', style: HType.hero),
            SizedBox(height: HSpacing.s4),
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Something went wrong', style: HType.screenTitle),
            const SizedBox(height: HSpacing.s3),
            Text(message, style: HType.metadata, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  int _index = 0;

  static const _titles = ['Home', 'Search', 'Library'];
  static const _pages = [HomeScreen(), SearchScreen(), LibraryScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            selected: _index,
            onSelect: (i) => setState(() => _index = i),
            title: _titles[_index],
            onSettings: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
          const NowPlayingBar(),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.selected,
    required this.onSelect,
    required this.title,
    required this.onSettings,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final String title;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HSpacing.s5),
      height: 64,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: [
          const Text('HIRENA',
              style: TextStyle(
                fontFamily: 'Barlow',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: HColors.brandRed,
              )),
          const SizedBox(width: HSpacing.s6),
          _NavItem(label: 'Home', selected: selected == 0, onTap: () => onSelect(0)),
          _NavItem(label: 'Search', selected: selected == 1, onTap: () => onSelect(1)),
          _NavItem(label: 'Library', selected: selected == 2, onTap: () => onSelect(2)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: HColors.inkPrimary),
            tooltip: 'Settings',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HSpacing.s3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HRadii.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HSpacing.s2, vertical: HSpacing.s2),
          child: Text(
            label,
            style: HType.body.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? HColors.inkPrimary : HColors.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
