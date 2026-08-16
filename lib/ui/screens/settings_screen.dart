import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recsys/shuffle.dart';
import '../../state/providers.dart';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Section(
            title: 'Playback',
            children: [
              _qualityTile(app),
              _sliderTile(
                label: 'Crossfade',
                value: app.settings.crossfadeMs.toDouble(),
                min: 0,
                max: 12000,
                divisions: 24,
                onChanged: (v) => app.settings.setCrossfadeMs(v.round()),
              ),
              SwitchListTile(
                title: const Text('Automix'),
                subtitle: const Text('Beat-matched, seamless transitions'),
                value: app.automix,
                onChanged: (v) => app.setAutomix(v),
              ),
              ListTile(
                title: const Text('Default shuffle'),
                trailing: DropdownButton<String>(
                  value: app.settings.defaultShuffle,
                  items: const [
                    DropdownMenuItem(value: 'sequential', child: Text('Sequential')),
                    DropdownMenuItem(value: 'standard', child: Text('Standard')),
                    DropdownMenuItem(value: 'trueShuffle', child: Text('True shuffle')),
                    DropdownMenuItem(value: 'smart', child: Text('Smart shuffle')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      app.setDefaultShuffle(ShuffleMode.values.firstWhere((m) => m.name == v));
                    }
                  },
                ),
              ),
            ],
          ),
          _Section(
            title: 'Account',
            children: [
              ListTile(
                leading: const Icon(Icons.key_rounded),
                title: Text(app.isAuthed ? 'Deezer ARL: valid' : 'Deezer ARL: not set'),
                subtitle: Text(
                  app.isAuthed
                      ? 'Streaming key only — profile data is never read. Max quality: '
                          '${_qualityName(app.maxQuality)}.'
                      : 'Paste an ARL to stream.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () => app.logout(),
              ),
            ],
          ),
          const _Section(
            title: 'About',
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Hirena Music streams the Deezer catalog using your own ARL as a '
                  'streaming key, for personal use only. This is not affiliated with '
                  'or endorsed by Deezer.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qualityTile(dynamic app) {
    return ListTile(
      title: const Text('Streaming quality'),
      subtitle: Text(_qualityName(app.quality)),
      trailing: DropdownButton<int>(
        value: app.quality,
        items: [
          if (app.maxQuality >= 9)
            const DropdownMenuItem(value: 9, child: Text('FLAC')),
          if (app.maxQuality >= 3)
            const DropdownMenuItem(value: 3, child: Text('MP3 320')),
          const DropdownMenuItem(value: 1, child: Text('MP3 128')),
        ],
        onChanged: (v) {
          if (v != null) app.setQuality(v);
        },
      ),
    );
  }

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      title: Text(label),
      subtitle: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: '${value.round()} ms',
        onChanged: onChanged,
      ),
    );
  }

  static String _qualityName(int q) => switch (q) {
        9 => 'FLAC (lossless)',
        3 => 'MP3 320 kbps',
        _ => 'MP3 128 kbps',
      };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Barlow',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
