import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/ui.dart';

/// A local practice card, independent of catalog data and adoption actions.
class SwipeTutorial extends StatefulWidget {
  const SwipeTutorial({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SwipeTutorial> createState() => _SwipeTutorialState();
}

class _SwipeTutorialState extends State<SwipeTutorial>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _scroll = ScrollController();
  int _step = 0;
  double _drag = 0;
  bool _closed = false;
  bool _reducedMotion = false;
  bool get _save => _step == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reducedMotion || _step == 2 || _closed) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    _motion.stop();
    widget.onDone();
  }

  void _advance() {
    if (_closed || _step == 2) return;
    setState(() => _step++);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _motion.reset();
    if (!_reducedMotion && _step < 2) _motion.repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _step == 2;
    final title = finished
        ? '¡Ya puedes descubrir!'
        : _save
        ? 'Desliza a la derecha'
        : 'Desliza a la izquierda';
    final copy = finished
        ? 'Tú decides con calma. También puedes usar el corazón para guardar y la X para pasar.'
        : _save
        ? 'Guarda en Mis matches para volver a ver su perfil.'
        : 'Pasa para descubrir otra mascota.';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          title: const Brand(),
          actions: [
            TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(foregroundColor: ink),
              child: const Text('Omitir'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      finished
                          ? 'Práctica terminada'
                          : 'Paso ${_step + 1} de 2',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: DopmiTokens.bodyFont,
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      copy,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.4,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!finished)
                      _practiceCard()
                    else ...[
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.pets_rounded,
                          size: 104,
                          color: DopmiTokens.orangeButton,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 20),
                    if (!finished) ...[
                      Text(
                        _save
                            ? 'El corazón también guarda.'
                            : 'La X también pasa.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: ink),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      onPressed: finished ? _finish : _advance,
                      style: FilledButton.styleFrom(
                        backgroundColor: DopmiTokens.orangeButton,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                          fontFamily: DopmiTokens.bodyFont,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(
                        finished
                            ? 'Empezar a descubrir'
                            : _save
                            ? 'Probar guardar'
                            : 'Probar pasar',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _practiceCard() => GestureDetector(
    key: const ValueKey('swipe-tutorial-card'),
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: (_) => _drag = 0,
    onHorizontalDragUpdate: (event) => _drag += event.delta.dx,
    onHorizontalDragEnd: (_) {
      if ((_save && _drag >= 48) || (!_save && _drag <= -48)) _advance();
    },
    child: Semantics(
      label: _save
          ? 'Tarjeta de práctica. Desliza a la derecha para guardar.'
          : 'Tarjeta de práctica. Desliza a la izquierda para pasar.',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 264,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/onboarding/rocky.png', fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xb346281d)],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Ejemplo',
                      style: TextStyle(color: ink, fontSize: 13),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      _save ? Icons.favorite_rounded : Icons.close_rounded,
                      size: 40,
                      color: _save ? DopmiTokens.orangeButton : ink,
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, .65),
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (_, _) => Transform.translate(
                      offset: Offset(
                        _reducedMotion
                            ? 0
                            : (_save ? 1 : -1) *
                                  72 *
                                  (Curves.easeInOut.transform(_motion.value) -
                                      .5),
                        0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_save)
                            const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          const Icon(
                            Icons.touch_app_rounded,
                            key: ValueKey('swipe-tutorial-hand'),
                            color: Colors.white,
                            size: 64,
                            shadows: [Shadow(color: ink, blurRadius: 6)],
                          ),
                          if (_save)
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
