import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../../core/content_links.dart';
import '../../core/design_tokens.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../community/content_actions.dart';
import '../payments/contribution_layout.dart';
import '../payments/guardian_repository.dart';
import '../payments/guardian_promotion_screen.dart';
import '../rescue/rescue_public_photo.dart';
import '../rescue/rescue_repository.dart';

/// Membership decides the entry, while history remains reachable for former
/// Guardians and people who only made punctual contributions.
class ImpactEntryScreen extends ConsumerWidget {
  const ImpactEntryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(guardianEnabledProvider)) return const ImpactScreen();
    return LiveSection<Json>(
      load: () => ref.read(guardianRepositoryProvider).state(),
      errorMessage: (_) =>
          'No pudimos consultar tu estado de Guardián. Vuelve a intentarlo.',
      statusFrame: (content) => Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: const CommunityNav(3),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ),
      ),
      builder: (state, _) =>
          state['plan'] == null && state['activation'] == null
          ? const GuardianPromotionScreen(navigation: CommunityNav(3))
          : const ImpactScreen(),
    );
  }
}

class ImpactScreen extends ConsumerWidget {
  const ImpactScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: Colors.white,
    bottomNavigationBar: const CommunityNav(3),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 18),
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Vidas que continúan gracias a ti.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.25,
                        letterSpacing: .07,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Avances públicos de los casos a los que tus aportaciones sí fueron asignadas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LiveSection<List<Json>>(
              load: () =>
                  ref.read(communityRepositoryProvider).personalImpact(),
              errorMessage: (_) =>
                  'No pudimos consultar tus avances. Vuelve a intentarlo.',
              builder: (items, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isEmpty) const ImpactEmptyCard(),
                  for (final item in items) ...[
                    ImpactCaseCard(item, key: ValueKey(item['case_id'])),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            if (ref.watch(guardianEnabledProvider)) ...[
              const SizedBox(height: 16),
              ContributionButton(
                'Administrar suscripción',
                secondary: true,
                onPressed: () => context.push('/guardian'),
              ),
              TextButton(
                onPressed: () => context.push('/impact/guardian'),
                child: const Text('Conoce Guardián'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ImpactEmptyCard extends StatelessWidget {
  const ImpactEmptyCard({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 333),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffe6e2dd)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2415110d),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xfffef5d0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/profile/empty-impact-paw.svg',
                  width: 32,
                  height: 32,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 274),
              child: Text(
                'Aquí verás las mascotas que hayas apoyado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 26,
                  fontVariations: DopmiTokens.display26Variations,
                  height: 1.2,
                  letterSpacing: -.52,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Todavía no hay avances públicos de tus aportaciones asignadas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: muted),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

class ImpactCaseCard extends StatelessWidget {
  const ImpactCaseCard(this.item, {super.key});
  final Json item;
  @override
  Widget build(BuildContext context) {
    final publicData = Json.from(item['public_data'] as Map? ?? {});
    final name = publicData['pet_name'] as String? ?? 'Caso de rescate';
    final allocated = item['allocated_cents'];
    final amount = allocated is int && allocated > 0
        ? pesos(allocated)
        : 'Asignación por confirmar';
    final updates = (item['updates'] as List? ?? [])
        .map((value) => Json.from(value as Map))
        .toList();
    final photos = (publicData['photos'] as List? ?? [])
        .whereType<String>()
        .toList();
    void openCase() => context.push('/rescue-cases/${item['case_id']}');
    final amountBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          amount,
          style: const TextStyle(
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: Color(0xff6b5000),
          ),
        ),
        const Text(
          'Asignados de tus aportaciones',
          style: TextStyle(fontSize: 12, height: 1.4, color: muted),
        ),
      ],
    );
    final share = OutlinedButton.icon(
      onPressed: () => shareContent(
        context,
        'Conoce el caso $name en Dopmi. ${publicContentLink(PublicContent.rescueCase, item['case_id'] as String)}',
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xffe6e2dd)),
        foregroundColor: ink,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.share_outlined, size: 14),
      label: const Text('Compartir'),
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffe6e2dd)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photos.isNotEmpty)
            RescuePublicPhoto(photos.first, height: 192, radius: 0)
          else
            const SizedBox(
              height: 192,
              child: ColoredBox(
                color: Color(0xfff1eee8),
                child: Center(
                  child: Icon(Icons.pets_outlined, size: 36, color: muted),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: 'Ver caso $name',
                      onTap: openCase,
                      child: InkWell(
                        onTap: openCase,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfff1eee8),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'Apoyo asignado',
                        style: TextStyle(fontSize: 10, height: 1.2, color: ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (updates.isEmpty)
                  const Text(
                    'Este caso todavía no tiene avances públicos.',
                    style: TextStyle(fontSize: 14, height: 1.55, color: muted),
                  ),
                for (final update in updates) ...[
                  Text(
                    update['body'] as String? ?? 'Avance publicado',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localDate(update['published_at'] as String? ?? ''),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(height: 1, color: Color(0xffe6e2dd)),
                const SizedBox(height: 12),
                if (MediaQuery.textScalerOf(context).scale(17) > 25)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      amountBlock,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: share),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: amountBlock),
                      const SizedBox(width: 12),
                      share,
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
