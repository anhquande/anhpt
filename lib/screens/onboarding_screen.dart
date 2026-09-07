import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function({bool launchDemo}) onComplete;
  final bool replayMode;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.replayMode = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingStep {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  const _OnboardingStep({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = [
    _OnboardingStep(
      icon: Icons.ondemand_video_outlined,
      eyebrow: 'WATCH',
      title: 'Follow the demonstration',
      description:
          'See the movement while you train, so the next action is always clear.',
    ),
    _OnboardingStep(
      icon: Icons.record_voice_over_outlined,
      eyebrow: 'LISTEN',
      title: 'Let Voice Coach guide you',
      description:
          'Hear step names, timing and cues without having to keep your eyes on the screen.',
    ),
    _OnboardingStep(
      icon: Icons.compare_outlined,
      eyebrow: 'COMPARE',
      title: 'Check your form with Mirror Mode',
      description:
          'Place your camera beside the demonstration and compare your movement live.',
    ),
    _OnboardingStep(
      icon: Icons.fitness_center_outlined,
      eyebrow: 'TRAIN',
      title: 'Ready for a real workout',
      description:
          'The tutorial stays separate from your workout history. Start the AnhPT Feature Demo when you are ready.',
    ),
  ];

  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  bool get _isLast => _page == _steps.length - 1;

  Future<void> _finish({required bool launchDemo}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await widget.onComplete(launchDemo: launchDemo);
    if (mounted) setState(() => _finishing = false);
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.replayMode,
        title: widget.replayMode ? const Text('AnhPT tutorial') : null,
        actions: [
          if (!widget.replayMode)
            TextButton(
              onPressed: _finishing ? null : () => _finish(launchDemo: false),
              child: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                  child: Row(
                    children: [
                      Text(
                        'AnhPT',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        'Watch  ·  Listen  ·  Compare  ·  Train',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _steps.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(32),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                step.icon,
                                size: 54,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              step.eyebrow,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              step.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              step.description,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _steps.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: index == _page ? 22 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_isLast)
                        FilledButton.icon(
                          onPressed: _finishing
                              ? null
                              : () => _finish(launchDemo: true),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start Demo Workout'),
                        )
                      else
                        FilledButton(
                          onPressed: _finishing ? null : _next,
                          child: const Text('Next'),
                        ),
                      if (_isLast) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _finishing
                              ? null
                              : () => _finish(launchDemo: false),
                          child: Text(widget.replayMode ? 'Close tutorial' : 'Maybe later'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
