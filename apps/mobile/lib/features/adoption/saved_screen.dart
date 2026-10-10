import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import 'community_repository.dart';
import 'community_ui.dart';

enum SavedKind { adoption, donation, rescuer }

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key, this.initialKind = SavedKind.adoption});
  final SavedKind initialKind;
  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  late SavedKind kind;
  int page = 1, revision = 0;
  final removing = <String>{};
  String? error;

  @override
  void initState() {
    super.initState();
    kind = widget.initialKind;
  }

  Future<DataPage<SavedEntry>> load() async {
    final repo = ref.read(communityRepositoryProvider);
    final selectedKind = kind;
    final result = await switch (selectedKind) {
      SavedKind.adoption => repo.savedAdoptions(page),
      SavedKind.donation => repo.savedCases(page),
      SavedKind.rescuer => repo.savedRescuers(page),
    };
    if (selectedKind != SavedKind.rescuer) return result;
    final items = await Future.wait(
      result.items.map((item) async {
        if (!item.available) return item;
        try {
          final profile = await repo.publicProfile(item.id);
          if (profile == null) {
            return SavedEntry({'id': item.id, 'available': false});
          }
          return SavedEntry({
            ...item.data,
            ...profile,
            'id': item.id,
            'available': true,
          });
        } catch (_) {
          return item;
        }
      }),
    );
    return DataPage(items, result.total);
  }

  Future<void> remove(SavedEntry item) async {
    final selectedKind = kind;
    final key = '$selectedKind:${item.id}';
    if (removing.contains(key)) return;
    setState(() {
      removing.add(key);
      error = null;
    });
    final repo = ref.read(communityRepositoryProvider);
    try {
      switch (selectedKind) {
        case SavedKind.adoption:
          await repo.favorite(item.id, false);
        case SavedKind.donation:
          await repo.favoriteCase(item.id, false);
        case SavedKind.rescuer:
          await repo.favoriteRescuer(item.id, false);
      }
      if (mounted) setState(() => revision++);
    } catch (cause) {
      if (mounted && kind == selectedKind) {
        setState(() => error = communityError(cause));
      }
    } finally {
      if (mounted) setState(() => removing.remove(key));
    }
  }

  void select(SavedKind value) => setState(() {
    kind = value;
    page = 1;
    error = null;
  });

  Widget _headerTitle() {
    final title = Text(
      maxLines: MediaQuery.textScalerOf(context).scale(18) > 25 ? 3 : 1,
      textAlign: TextAlign.center,
      switch (kind) {
        SavedKind.adoption => 'Mis mascotas',
        SavedKind.donation => 'Casos guardados',
        SavedKind.rescuer => 'Rescatistas guardados',
      },
      style: const TextStyle(
        fontSize: 18,
        height: 1.25,
        letterSpacing: -0.36,
        color: ink,
        fontWeight: FontWeight.w700,
      ),
    );
    if (kind != SavedKind.rescuer) return title;
    final icon = ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/profile/icon-bookmark.svg',
        key: const ValueKey('saved-rescuer-title-icon'),
        width: 20,
        height: 20,
        colorFilter: const ColorFilter.mode(Color(0xff6b5000), BlendMode.srcIn),
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(18) > 25) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(height: 6), title],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Flexible(child: title),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(
      title: _headerTitle(),
      centerTitle: true,
      toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 25
          ? MediaQuery.textScalerOf(context).scale(18) * 2.6 + 16
          : 67,
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: IconButton(
          tooltip: 'Regresar',
          style: IconButton.styleFrom(overlayColor: Colors.transparent),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
          icon: SvgPicture.asset(
            'assets/profile/back.svg',
            width: 20,
            height: 20,
          ),
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xffe6e2dd)),
      ),
      actions: [
        PopupMenuButton<SavedKind>(
          tooltip: 'Tipos de guardados',
          onSelected: select,
          itemBuilder: (_) => const [
            PopupMenuItem(value: SavedKind.adoption, child: Text('Adopción')),
            PopupMenuItem(value: SavedKind.donation, child: Text('Donación')),
            PopupMenuItem(value: SavedKind.rescuer, child: Text('Rescatistas')),
          ],
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kind == SavedKind.adoption) ...[
              const Text(
                'Solo aparecen los compañeritos que marcaste con like o guardaste para adoptar.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  letterSpacing: 0,
                  color: muted,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (error != null) Notice(error!, isError: true),
            LiveSection<DataPage<SavedEntry>>(
              key: ValueKey('$kind:$page:$revision'),
              tables: const [
                'dopmi_favorites',
                'dopmi_saved_cases',
                'dopmi_saved_rescuers',
              ],
              load: load,
              builder: (result, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result.items.isEmpty) _empty(),
                  for (final item in result.items)
                    _SavedCard(
                      item,
                      kind: kind,
                      remove: () => remove(item),
                      busy: removing.contains('$kind:${item.id}'),
                    ),
                  if (result.total > 20 || page > 1)
                    PageControls(
                      page: page,
                      total: result.total,
                      size: 20,
                      change: (value) => setState(() => page = value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _empty() => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 520),
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (kind == SavedKind.rescuer) ...[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xfffff2b8),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/profile/icon-bookmark.svg',
                colorFilter: const ColorFilter.mode(
                  Color(0xff6b5000),
                  BlendMode.srcIn,
                ),
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            switch (kind) {
              SavedKind.adoption => 'Aún no tienes mascotas guardadas',
              SavedKind.rescuer => 'Aún no guardas rescatistas',
              SavedKind.donation => 'Aún no guardas casos',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              color: ink,
              fontWeight: FontWeight.w700,
              height: 1.3,
              letterSpacing: -.38,
            ),
          ),
          const SizedBox(height: 25.77),
          Text(
            switch (kind) {
              SavedKind.adoption => 'Cuando des like o guardes un perfil en Adoptar, lo verás aquí.',
              SavedKind.rescuer =>
                'Guarda perfiles desde el detalle de un caso.',
              SavedKind.donation =>
                'Guarda un caso desde Apoyar para encontrarlo aquí.',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              letterSpacing: 0,
              color: muted,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
                animationDuration: Duration.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onPressed: () => context.go(
                kind == SavedKind.adoption ? '/adoptions' : '/rescue-cases',
              ),
              child: Text(
                kind == SavedKind.adoption ? 'Ir a Adoptar' : 'Explorar casos',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SavedCard extends StatelessWidget {
  const _SavedCard(
    this.item, {
    required this.kind,
    required this.remove,
    this.busy = false,
  });
  final bool busy;
  final SavedEntry item;
  final SavedKind kind;
  final Future<void> Function() remove;

  String get title {
    if (!item.available) return 'Contenido no disponible';
    return switch (kind) {
      SavedKind.adoption => item.text('pet_name'),
      SavedKind.donation =>
        item.publicData['pet_name'] as String? ??
            item.publicData['title'] as String? ??
            'Caso de rescate',
      SavedKind.rescuer =>
        item.text('name').isEmpty ? 'Perfil de rescatista' : item.text('name'),
    };
  }

  String get subtitle {
    if (!item.available) {
      return 'Se retiró o volvió a revisión. No mostramos su contenido privado.';
    }
    return switch (kind) {
      SavedKind.adoption => '${item.text('city')}, ${item.text('region')}',
      SavedKind.donation =>
        item.publicData['story'] as String? ??
            'Conoce su historia y gastos aprobados.',
      SavedKind.rescuer => item.text('city'),
    };
  }

  String get route => switch (kind) {
    SavedKind.adoption => '/adoptions/${item.id}',
    SavedKind.donation => '/rescue-cases/${item.id}',
    SavedKind.rescuer => '/people/${item.id}',
  };

  @override
  Widget build(BuildContext context) {
    final adoption = kind == SavedKind.adoption;
    final photos = item.available
        ? (item.data['photos'] as List? ?? []).whereType<String>().toList()
        : <String>[];
    final sex = switch (item.text('sex')) {
      'female' => 'Hembra',
      'male' => 'Macho',
      _ => '',
    };
    final months = item.data['age_months'] as int?;
    final age = months == null
        ? ''
        : months < 12
        ? '$months meses'
        : '${months ~/ 12} años';
    final detail = !item.available
        ? subtitle
        : adoption
        ? [sex, age].where((v) => v.isNotEmpty).join(' · ')
        : subtitle;
    final open = item.available ? () => context.push(route) : null;
    final metrics =
        item.available &&
            kind == SavedKind.rescuer &&
            item.data['metrics'] is Map
        ? Json.from(item.data['metrics'])
        : null;
    final publishedCases = metrics?['published_cases'];
    final avatar = SizedBox(
      width: adoption ? 70 : 40,
      height: adoption ? 70 : 40,
      child: adoption && photos.isNotEmpty
          ? AdoptionPhoto(photos.first, height: 70, radius: 16)
          : Container(
              decoration: BoxDecoration(
                color: const Color(0xfffff2b8),
                borderRadius: BorderRadius.circular(adoption ? 16 : 40),
              ),
              alignment: Alignment.center,
              child: item.available && !adoption
                  ? Text(
                      title.isEmpty ? '?' : title.characters.first,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff6b5000),
                      ),
                    )
                  : Icon(
                      item.available
                          ? Icons.pets_outlined
                          : Icons.visibility_off_outlined,
                      color: muted,
                    ),
            ),
    );
    final copy = InkWell(
      splashFactory: adoption ? NoSplash.splashFactory : null,
      overlayColor: adoption
          ? const WidgetStatePropertyAll(Colors.transparent)
          : null,
      onTap: open,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: adoption ? 6 : 0,
          vertical: adoption ? 5 : 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: ink,
                    ),
                  ),
                ),
                if (item.available &&
                    kind == SavedKind.rescuer &&
                    item.data['verified'] == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: SvgPicture.asset(
                      'assets/profile/icon-verified.svg',
                      width: 14,
                      height: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.available && kind == SavedKind.rescuer) ...[
                  SvgPicture.asset(
                    'assets/profile/location.svg',
                    width: 12,
                    height: 12,
                    colorFilter: const ColorFilter.mode(muted, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    detail,
                    style: TextStyle(
                      fontSize: adoption ? 11 : 12,
                      height: 1.2,
                      letterSpacing: 0,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
            if (publishedCases is int && publishedCases >= 0) ...[
              const SizedBox(height: 4),
              Text(
                '$publishedCases casos publicados',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  letterSpacing: 0,
                  color: muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final removeButton = IconButton(
      tooltip: 'Quitar de guardados',
      style: adoption
          ? IconButton.styleFrom(overlayColor: Colors.transparent)
          : null,
      onPressed: busy ? null : remove,
      icon: adoption
          ? Transform.translate(
              offset: const Offset(4, 0),
              child: SvgPicture.asset(
                'assets/profile/icon-bookmark.svg',
                colorFilter: const ColorFilter.mode(
                  Color(0xff6b5000),
                  BlendMode.srcIn,
                ),
                width: 20,
                height: 20,
              ),
            )
          : const Icon(Icons.close, size: 20),
    );
    return Container(
      margin: EdgeInsets.only(bottom: adoption ? 0 : 10),
      padding: adoption
          ? const EdgeInsets.symmetric(vertical: 12)
          : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: adoption ? null : BorderRadius.circular(18),
        border: adoption
            ? const Border(bottom: BorderSide(color: Color(0xffe6e2dd)))
            : Border.all(color: const Color(0xffe6e2dd)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final enlarged =
              MediaQuery.textScalerOf(context).scale(16) > 25 &&
              constraints.maxWidth < 360;
          if (enlarged) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [avatar, const Spacer(), removeButton]),
                const SizedBox(height: 8),
                copy,
              ],
            );
          }
          return Row(
            children: [
              avatar,
              SizedBox(width: adoption ? 10 : 12),
              Expanded(child: copy),
              if (adoption) const SizedBox(width: 2),
              removeButton,
            ],
          );
        },
      ),
    );
  }
}
