import 'package:flutter/material.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/core/navigation.dart';

// Local visual-review target; never compiled into the production entrypoint.
void main() =>
    runApp(MaterialApp(theme: dopmiTheme(), home: const DesignGallery()));

class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key, this.rescuer = false});
  final bool rescuer;
  @override
  Widget build(BuildContext context) => PageFrame(
    back: false,
    bottomNavigationBar: DopmiBottomBar(
      rescuer: rescuer,
      selectedPath: rescuer ? '/rescuer' : '/adoptions',
      onSelected: (_) {},
    ),
    children: [
      Heading(
        rescuer ? 'Cada rescate cuenta.' : 'Una nueva historia.',
        'Componentes de la app para revisión visual.',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conoce su historia',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'El cuidado, la transparencia y una comunidad que acompaña.',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const TextField(
        decoration: InputDecoration(
          labelText: 'Nombre',
          hintText: '¿Cómo te llamas?',
        ),
      ),
      const SizedBox(height: 16),
      ActionButton('Continuar', onPressed: () {}),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: () {}, child: const Text('Conocer más')),
      const SizedBox(height: 20),
      const Notice(
        'Los datos privados se comparten sólo con quienes corresponda.',
      ),
    ],
  );
}
