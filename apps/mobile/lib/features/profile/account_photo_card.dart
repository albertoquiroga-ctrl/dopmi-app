import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';

class AccountPhotoCard extends StatelessWidget {
  const AccountPhotoCard({
    super.key,
    required this.name,
    this.bytes,
    this.url,
    this.onEdit,
  });
  final String name;
  final Uint8List? bytes;
  final String? url;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'D'
        : name.trim().characters.first.toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xff6b5000),
        ),
      ),
    );
    final avatar = SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: ColoredBox(
                color: const Color(0xfffff2b8),
                child: bytes != null
                    ? Image.memory(
                        bytes!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      )
                    : url != null
                    ? Image.network(
                        url!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => fallback,
                      )
                    : fallback,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: yellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/profile/onb-camera.svg',
                width: 12,
                height: 12,
              ),
            ),
          ),
        ],
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto de perfil',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ink,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cambia tu foto de perfil',
          style: TextStyle(fontSize: 13, color: muted, height: 1.3),
        ),
      ],
    );
    final edit = Tooltip(
      message: 'Editar foto de perfil',
      child: OutlinedButton(
        onPressed: onEdit,
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xffe6e2dd)),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/profile/icon-edit.svg',
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 6),
            const Text('Editar'),
          ],
        ),
      ),
    );
    final large = MediaQuery.textScalerOf(context).scale(13) > 20;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e2dd)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: edit),
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(child: details),
                const SizedBox(width: 16),
                edit,
              ],
            ),
    );
  }
}
