import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../camera/presentation/screens/camera_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startScan() {
    if (!_formKey.currentState!.validate()) return;
    final soldierId = _controller.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CameraScreen(soldierId: soldierId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── App identity ──────────────────────────────────────────────
              Icon(
                Icons.gps_fixed,
                size: 64,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Target Analyser',
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter soldier ID to begin analysis',
                style: tt.bodyMedium?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // ── Soldier ID input ──────────────────────────────────────────
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _startScan(),
                  decoration: const InputDecoration(
                    labelText: 'Soldier ID',
                    hintText: 'e.g. S-1042',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Soldier ID is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── Start button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _startScan,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text(
                    'Start Scan',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
