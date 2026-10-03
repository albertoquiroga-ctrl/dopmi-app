import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/design_tokens.dart';
import 'community_repository.dart';
import 'community_ui.dart';

class AdoptionDetailLayout extends StatefulWidget {
  const AdoptionDetailLayout({
    super.key,
    required this.post,
    required this.saved,
    required this.busy,
    required this.owner,
    required this.favorite,
    required this.contact,
    required this.share,
    required this.report,
    this.error,
  });
  final Adoption post;
  final bool saved, busy, owner;
  final VoidCallback favorite, contact, share, report;
  final String? error;
  @override
  State<AdoptionDetailLayout> createState() => _AdoptionDetailLayoutState();
}

class _AdoptionDetailLayoutState extends State<AdoptionDetailLayout> {
  int galleryIndex = 0;
  @override
  void didUpdateWidget(AdoptionDetailLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.photos.join('|') != widget.post.photos.join('|')) {
      galleryIndex = 0;
    }
  }

  void back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/adoptions');
    }
  }

  Widget svg(String name, double size) => SvgPicture.asset(
    'assets/profile/$name.svg',
    width: size,
    height: size,
    colorFilter: name == 'icon-verified'
        ? null
        : ColorFilter.mode(
            name == 'location'
                ? const Color(0xff6b5000)
                : name == 'icon-alert-circle'
                ? muted
                : ink,
            BlendMode.srcIn,
          ),
  );
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final heartColor = widget.saved ? '#15110d' : '#6b5000';
    final heroHeight = math.max(
      260.0,
      math.min(MediaQuery.sizeOf(context).height * .42, 340.0),
    );
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: heroHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (post.photos.isEmpty)
                          const ColoredBox(
                            color: yellow,
                            child: Center(
                              child: Icon(Icons.pets, size: 72, color: ink),
                            ),
                          )
                        else
                          PageView.builder(
                            key: ValueKey(
                              '${post.id}:${post.photos.join('|')}',
                            ),
                            itemCount: post.photos.length,
                            onPageChanged: (value) =>
                                setState(() => galleryIndex = value),
                            itemBuilder: (_, index) => AdoptionPhoto(
                              post.photos[index],
                              height: heroHeight,
                              radius: 0,
                            ),
                          ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: IconButton(
                                tooltip: 'Volver',
                                onPressed: back,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: .72,
                                  ),
                                  minimumSize: const Size(40, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  maximumSize: const Size(40, 40),
                                ),
                                icon: svg('back', 20),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.min(
                                MediaQuery.sizeOf(context).width * .58,
                                220,
                              ),
                            ),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(99),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(99),
                                onTap: () =>
                                    context.push('/people/${post.owner}'),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    5,
                                    6,
                                    5,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          post.text('publisher_name'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            letterSpacing: 0,
                                            fontSize: 13,
                                            height: 1.55,
                                            fontWeight: FontWeight.w600,
                                            color: ink,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: yellow,
                                        foregroundColor: ink,
                                        child: Text(
                                          post.text('publisher_name').isEmpty
                                              ? ''
                                              : post
                                                    .text('publisher_name')
                                                    .characters
                                                    .first,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            letterSpacing: 0,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (post.photos.isNotEmpty)
                          Positioned(
                            bottom: 28,
                            left: 0,
                            right: 0,
                            child: Semantics(
                              label:
                                  'Foto ${math.min(galleryIndex + 1, post.photos.length)} de ${post.photos.length}',
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < post.photos.length; i++)
                                    Container(
                                      width: i == galleryIndex ? 8 : 7,
                                      height: i == galleryIndex ? 8 : 7,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(
                                          alpha: i == galleryIndex ? 1 : .45,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: heroHeight - 22),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0f15110d),
                          offset: Offset(0, -8),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.name,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      letterSpacing: -.56,
                                      fontSize: 28,
                                      height: 1.15,
                                      fontWeight: FontWeight.w700,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      svg('location', 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          [
                                                post.text('city'),
                                                post.text('region'),
                                              ]
                                              .where((s) => s.isNotEmpty)
                                              .join(', '),
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            letterSpacing: 0,
                                            fontSize: 13,
                                            height: 1.55,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff6b5000),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  LiveSection<Json?>(
                                    key: ValueKey('verified:${post.owner}'),
                                    load: () async {
                                      try {
                                        return await repository(context)
                                            .publicProfile(post.owner);
                                      } catch (_) {
                                        return null;
                                      }
                                    },
                                    builder: (profile, _) =>
                                        profile?['verified'] == true
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                svg('icon-verified', 16),
                                                const SizedBox(width: 6),
                                                const Expanded(
                                                  child: Text(
                                                    'Rescatista verificado',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      letterSpacing: 0,
                                                      fontSize: 12,
                                                      height: 1.55,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: muted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Compartir',
                              onPressed: widget.share,
                              style: IconButton.styleFrom(
                                minimumSize: const Size(42, 42),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                maximumSize: const Size(42, 42),
                                side: const BorderSide(
                                  color: DopmiTokens.line,
                                  width: 1.5,
                                ),
                              ),
                              icon: svg('icon-share', 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, box) => Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final stat in [
                                (
                                  post.text('sex') == 'female'
                                      ? 'Hembra'
                                      : 'Macho',
                                  'Sexo',
                                ),
                                (
                                  {
                                        'small': 'Pequeño',
                                        'medium': 'Mediano',
                                        'large': 'Grande',
                                      }[post.text('size')] ??
                                      'Sin definir',
                                  'Tamaño',
                                ),
                                (
                                  post.data['distance_km'] is num
                                      ? '${(post.data['distance_km'] as num).toStringAsFixed(1)} km'
                                      : '—',
                                  'Distancia',
                                ),
                              ])
                                SizedBox(
                                  width:
                                      MediaQuery.textScalerOf(context)
                                              .scale(15) >
                                          22
                                      ? box.maxWidth
                                      : (box.maxWidth - 20) / 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: DopmiTokens.line,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0a15110d),
                                          offset: Offset(0, 4),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          stat.$1,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            letterSpacing: 0,
                                            fontSize: 15,
                                            height: 19 / 15,
                                            fontWeight: FontWeight.w700,
                                            color: ink,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          stat.$2,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            letterSpacing: 0,
                                            fontSize: 12,
                                            height: 15 / 12,
                                            color: muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Su historia',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            letterSpacing: 0,
                            fontSize: 18,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post.text('story'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            letterSpacing: 0,
                            fontSize: 14,
                            height: 1.55,
                            color: muted,
                          ),
                        ),
                        if (post.text('special_care').isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Cuidados especiales',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              letterSpacing: 0,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.text('special_care'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              letterSpacing: 0,
                              fontSize: 14,
                              height: 1.55,
                              color: muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: widget.busy ? null : widget.report,
                            style: TextButton.styleFrom(
                              foregroundColor: muted,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                letterSpacing: 0,
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            icon: svg('icon-alert-circle', 16),
                            label: const Text('Reportar publicación'),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Material(
                          color: Colors.white,
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Más sobre su salud y cuidados'),
                            children: [
                              for (final entry in {
                                'age': 'Edad',
                                'breed': 'Raza',
                                'vaccinated': 'Vacunas al día',
                                'sterilized': 'Esterilización',
                                'social_dogs': 'Convive con perros',
                                'social_cats': 'Convive con gatos',
                                'social_children': 'Convive con niñas y niños',
                              }.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${entry.value}: ${entry.key == 'age'
                                          ? post.age
                                          : entry.key == 'breed'
                                          ? (post.text('breed').isEmpty ? 'Sin especificar' : post.text('breed'))
                                          : post.data[entry.key] == null
                                          ? 'Por confirmar'
                                          : post.data[entry.key] == true
                                          ? 'Sí'
                                          : 'No'}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.error != null)
                          Notice(widget.error!, isError: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: DopmiTokens.line)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0f15110d),
                offset: Offset(0, -8),
                blurRadius: 24,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    selected: widget.saved,
                    child: IconButton(
                      tooltip: widget.saved ? 'Guardada' : 'Guardar',
                      onPressed: widget.busy ? null : widget.favorite,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        maximumSize: const Size(52, 52),
                        backgroundColor: widget.saved ? yellow : Colors.white,
                        foregroundColor: widget.saved
                            ? ink
                            : const Color(0xff6b5000),
                        side: BorderSide(color: yellow, width: 2),
                      ),
                      icon: SvgPicture.string(
                        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M19.5 12.572 12 20l-7.5-7.428A5 5 0 1 1 12 6.006a5 5 0 1 1 7.5 6.566Z" fill="${widget.saved ? heartColor : 'none'}" stroke="$heartColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
                        width: widget.saved ? 23.32 : 22,
                        height: widget.saved ? 23.32 : 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.busy ? null : widget.contact,
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          letterSpacing: 0,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(
                        widget.owner
                            ? 'Administrar mi publicación'
                            : 'Quiero adoptar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  CommunityRepository repository(BuildContext context) =>
      ProviderScope.containerOf(context).read(communityRepositoryProvider);
}
