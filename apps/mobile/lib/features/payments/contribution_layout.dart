import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../rescue/rescue_repository.dart';
import '../rescue/rescue_public_photo.dart';

String contributionMoney(int cents) {
  final whole = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  final fraction = cents % 100 == 0
      ? ''
      : '.${(cents % 100).toString().padLeft(2, '0')}';
  return '${String.fromCharCode(36)}$whole$fraction MXN';
}

class ContributionFrame extends StatelessWidget {
  const ContributionFrame({
    super.key,
    required this.title,
    required this.back,
    required this.child,
    this.rescuer = false,
    this.bottomNavigationBar,
  });
  final String title;
  final VoidCallback? back;
  final Widget child;
  final bool rescuer;
  final Widget? bottomNavigationBar;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    bottomNavigationBar: bottomNavigationBar,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight:
          title.isNotEmpty && MediaQuery.textScalerOf(context).scale(18) > 25
          ? MediaQuery.textScalerOf(context).scale(18) * 2.6 + 16
          : 67,
      leadingWidth: 60,
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: rescuer ? const Color(0xffe3e4ed) : const Color(0xffe6e2dd),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: IconButton(
          tooltip: 'Regresar',
          onPressed: back,
          icon: SvgPicture.asset(
            'assets/profile/back.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              rescuer ? const Color(0xff151423) : ink,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
      title: title.isEmpty
          ? null
          : Text(
              title,
              maxLines: MediaQuery.textScalerOf(context).scale(18) > 25 ? 3 : 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: rescuer ? const Color(0xff151423) : ink,
              ),
            ),
    ),
    body: SafeArea(top: false, child: child),
  );
}

class ContributionCaseHeader extends StatelessWidget {
  const ContributionCaseHeader({
    super.key,
    required this.expenseTitle,
    this.record,
  });
  final String expenseTitle;
  final RescueRecord? record;
  @override
  Widget build(BuildContext context) {
    final photos = (record?.publicData['photos'] as List? ?? [])
        .whereType<String>()
        .toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffe6e2dd)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: photos.isNotEmpty
                ? RescuePublicPhoto(photos.first, height: 58, radius: 14)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.pets_outlined, color: muted),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record?.title ?? expenseTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    height: 1.2,
                  ),
                ),
                if (record != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    expenseTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContributionSummary extends StatelessWidget {
  const ContributionSummary({
    super.key,
    required this.rows,
    this.title,
    this.balancedColumns = false,
    this.emphasizeLast = false,
  });
  final String? title;
  final bool balancedColumns, emphasizeLast;
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(13) > 20;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffe6e2dd)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            if (large)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].$1,
                    style: TextStyle(
                      fontSize: emphasizeLast && i == rows.length - 1 ? 15 : 13,
                      fontWeight: emphasizeLast && i == rows.length - 1
                          ? FontWeight.w700
                          : null,
                      color: emphasizeLast && i == rows.length - 1
                          ? ink
                          : muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rows[i].$2,
                    style: TextStyle(
                      fontSize: emphasizeLast && i == rows.length - 1 ? 17 : 13,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      height: 1.2,
                    ),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(
                        fontSize: emphasizeLast && i == rows.length - 1
                            ? 15
                            : 13,
                        fontWeight: emphasizeLast && i == rows.length - 1
                            ? FontWeight.w700
                            : null,
                        color: emphasizeLast && i == rows.length - 1
                            ? ink
                            : muted,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: balancedColumns ? 1 : 2,
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: emphasizeLast && i == rows.length - 1
                            ? 17
                            : 13,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            if (i < rows.length - 1) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: Color(0xffe6e2dd)),
            ],
          ],
        ],
      ),
    );
  }
}

class ContributionButton extends StatelessWidget {
  const ContributionButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, busy;
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      animationDuration: Duration.zero,
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      foregroundColor: const WidgetStatePropertyAll(ink),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? (secondary ? cream : yellow).withValues(alpha: .5)
            : secondary
            ? cream
            : yellow,
      ),
      side: WidgetStatePropertyAll(
        BorderSide(
          color: secondary ? const Color(0xffe6e2dd) : Colors.transparent,
        ),
      ),
    );
    final content = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: busy ? 0 : 1,
          child: Text(label, textAlign: TextAlign.center),
        ),
        if (busy)
          Semantics(
            label: 'En proceso',
            liveRegion: true,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            ),
          ),
      ],
    );
    return secondary
        ? OutlinedButton(
            style: style,
            onPressed: busy ? null : onPressed,
            child: content,
          )
        : FilledButton(
            style: style,
            onPressed: busy ? null : onPressed,
            child: content,
          );
  }
}
