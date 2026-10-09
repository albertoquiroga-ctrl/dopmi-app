import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../core/reference_focus_outline.dart';
import 'community_repository.dart';
import 'discovery_filters.dart';
import 'public_profile_layout.dart';
import 'public_profile_media_grid.dart';
import 'public_profile_metrics.dart';
import '../community/content_actions.dart';

/// Shared renderer for approved public profiles and a private draft preview.
/// Draft overrides affect identity only; metrics and listings are server data.
class PublicProfileBody extends StatefulWidget {
  const PublicProfileBody({
    super.key,
    required this.profile,
    required this.avatar,
    this.interactive = true,
    this.report,
  });
  final Json profile;
  final Widget avatar;
  final bool interactive;
  final VoidCallback? report;
  @override
  State<PublicProfileBody> createState() => _PublicProfileBodyState();
}

class _PublicProfileBodyState extends State<PublicProfileBody> {
  int tab = 0;
  Json filters = {};
  String? species;
  @override
  void didUpdateWidget(PublicProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile['id'] != widget.profile['id']) {
      tab = 0;
      filters = {};
      species = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final adoptions = (profile['adoptions'] as List? ?? const [])
        .map((row) => Adoption(Json.from(row as Map)))
        .toList();
    final cases = (profile['cases'] as List? ?? const [])
        .map((row) => Json.from(row as Map))
        .where((row) => row['status'] == 'approved')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xfff2f1ea),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PublicProfileIdentity(
                avatar: widget.avatar,
                name: profile['name'] as String? ?? '',
                city: [
                  profile['city'],
                  profile['region'],
                ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
                bio: profile['bio'] as String? ?? '',
                caseCount: 0,
                verified: profile['verified'] == true,
                showCaseCount: false,
              ),
              PublicProfileContacts(
                email: profile['public_email'] as String? ?? '',
                phone: profile['public_phone'] as String? ?? '',
                address: profile['public_address'] as String? ?? '',
                website: profile['website_url'] as String? ?? '',
                interactive: widget.interactive,
              ),
              if ((profile['instagram_url'] as String? ?? '').isNotEmpty ||
                  (profile['facebook_url'] as String? ?? '').isNotEmpty)
                PublicProfileSocials(
                  instagram: profile['instagram_url'] as String? ?? '',
                  facebook: profile['facebook_url'] as String? ?? '',
                  interactive: widget.interactive,
                  open: (url) => openPublicSocialUrl(context, url),
                ),
            ],
          ),
        ),
        PublicProfileTabs(
          selected: tab,
          select: (value) => setState(() => tab = value),
          report: null,
          showReport: false,
        ),
        if (tab == 0)
          PublicProfileMetrics(
            name: profile['name'] as String? ?? '',
            metrics: {
              ...Json.from(profile['metrics'] as Map? ?? {}),
              ...profile,
            },
          ),
        if (tab == 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in [('dog', 'Perros'), ('cat', 'Gatos')])
                FilterChip(
                  label: Text(entry.$2),
                  selected: species == entry.$1,
                  onSelected: (value) =>
                      setState(() => species = value ? entry.$1 : null),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('Filtros'),
                onPressed: () async {
                  final id = widget.profile['id'];
                  final selected = await showDialog<Json>(
                    context: context,
                    builder: (_) => DiscoveryFilters(filters),
                  );
                  if (selected != null &&
                      mounted &&
                      widget.profile['id'] == id) {
                    setState(() => filters = selected);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (adoptions.isEmpty)
            const Notice('No hay mascotas disponibles en este momento.')
          else
            PublicProfileAdoptionGrid(
              adoptions: adoptions,
              filters: filters,
              species: species,
              interactive: widget.interactive,
            ),
        ],
        if (tab == 2)
          PublicProfileCaseGrid(cases: cases, interactive: widget.interactive),
        const SizedBox(height: 18),
        ReferenceFocusOutline(
          radius: 0,
          child: TextButton.icon(
            onPressed: widget.interactive ? widget.report : null,
            icon: const Icon(Icons.report_outlined, size: 16),
            label: const Text('Reportar perfil'),
          ),
        ),
      ],
    );
  }
}
