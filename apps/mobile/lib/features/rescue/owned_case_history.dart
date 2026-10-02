import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adoption/community_ui.dart';
import 'case_update_repository.dart';

class OwnedCaseHistory extends ConsumerWidget {
  const OwnedCaseHistory(this.caseId, {super.key});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      const Text(
        'La historia hasta ahora',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 19,
          height: 1.3,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          color: Color(0xff15110d),
        ),
      ),
      const SizedBox(height: 12),
      LiveSection<List<CaseUpdate>>(
        key: ValueKey('owned-case-history:$caseId'),
        tables: const ['dopmi_case_updates'],
        load: () => ref.read(caseUpdateRepositoryProvider).publicFor(caseId),
        builder: (items, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              const Text(
                'Los avances aprobados del rescate aparecerán aquí.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xff554e48),
                ),
              ),
            for (final item in items)
              OwnedCaseStory(item, key: ValueKey(item.id)),
          ],
        ),
      ),
    ],
  );
}

class OwnedCaseStory extends StatelessWidget {
  const OwnedCaseStory(this.update, {super.key});
  final CaseUpdate update;

  @override
  Widget build(BuildContext context) {
    final date = localDate(update.publishedAt ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffe6e2dd)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < update.photos.length; index++)
            Stack(
              children: [
                OwnedStoryPhoto(
                  update.photos[index],
                  key: ValueKey(update.photos[index]),
                ),
                if (index == 0 && date.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _StoryDate(date),
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (update.photos.isEmpty && date.isNotEmpty) ...[
                  _StoryDate(date),
                  const SizedBox(height: 10),
                ],
                Text(
                  update.body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.55,
                    letterSpacing: 0,
                    color: Color(0xff15110d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryDate extends StatelessWidget {
  const _StoryDate(this.date);
  final String date;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xebffffff),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SvgPicture.asset(
            'assets/profile/icon-clock.svg',
            width: 12,
            height: 12,
            colorFilter: const ColorFilter.mode(
              Color(0xff15110d),
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            date,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              height: 1.4,
              letterSpacing: 0,
              fontWeight: FontWeight.w600,
              color: Color(0xff15110d),
            ),
          ),
        ),
      ],
    ),
  );
}

class OwnedStoryPhoto extends ConsumerStatefulWidget {
  const OwnedStoryPhoto(this.path, {super.key});
  final String path;
  @override
  ConsumerState<OwnedStoryPhoto> createState() => _OwnedStoryPhotoState();
}

class _OwnedStoryPhotoState extends ConsumerState<OwnedStoryPhoto>
    with WidgetsBindingObserver {
  late Future<String> url = request();
  Future<String> request() {
    final result = Future<String>.sync(
      () => ref.read(caseUpdateRepositoryProvider).photoUrl(widget.path),
    );
    result.ignore();
    return result;
  }

  void reload() => setState(() {
    url = request();
  });
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(OwnedStoryPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) url = request();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget unavailable() => Center(
    child: TextButton.icon(
      onPressed: reload,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Reintentar foto'),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 160,
    width: double.infinity,
    child: ColoredBox(
      color: const Color(0xffeeeeee),
      child: FutureBuilder<String>(
        key: ObjectKey(url),
        future: url,
        builder: (context, result) {
          if (result.hasError) return unavailable();
          if (!result.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando foto del avance',
              ),
            );
          }
          return Image.network(
            result.data!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: 'Foto aprobada del avance',
            loadingBuilder: (context, image, progress) => progress == null
                ? image
                : const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando foto del avance',
                    ),
                  ),
            errorBuilder: (context, error, stack) => unavailable(),
          );
        },
      ),
    ),
  );
}
