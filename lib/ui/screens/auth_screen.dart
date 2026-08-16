import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../state/providers.dart';

/// First-run screen: paste the Deezer ARL (streaming key only — no profile
/// data is ever fetched).
final class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = ref.read(appControllerProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await app.login(_controller.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : app.errorMessage ?? 'Invalid ARL';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: HColors.bottomScrim),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HSpacing.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('HIRENA', style: HType.hero),
                  const SizedBox(height: HSpacing.s3),
                  Text(
                    'Stream the Deezer catalog with your own ARL — used only as a '
                    'streaming key. Your profile is never read.',
                    style: HType.metadata,
                  ),
                  const SizedBox(height: HSpacing.s6),
                  TextField(
                    controller: _controller,
                    obscureText: _obscure,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Deezer ARL token',
                      hintText: 'Paste your 192-character ARL',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: HSpacing.s3),
                    Text(_error!, style: HType.metadata.copyWith(color: HColors.brandRed)),
                  ],
                  const SizedBox(height: HSpacing.s5),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Start listening'),
                  ),
                  const SizedBox(height: HSpacing.s5),
                  const _HowTo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HSpacing.s4),
      decoration: BoxDecoration(
        color: HColors.surfaceRaised,
        borderRadius: BorderRadius.circular(HRadii.card),
      ),
      child: const Text(
        'How to get your ARL: log in at deezer.com → open DevTools (F12) → '
        'Application → Cookies → deezer.com → copy the value of the "arl" cookie.',
        style: HType.caption,
      ),
    );
  }
}
