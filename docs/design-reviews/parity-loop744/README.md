# Loop744 — Revisión por grupos y segundo historial

2026-10-04. Base37ea404/fuente432ecb2 de colección743. Sourceirlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb revalidado inicio/cierre.

Se inspeccionaron24 PNG normales actuales en cuatro composiciones sin reducir sus377×852px por captura (3 columnas×2 filas, etiquetas externas). Son revisión visual de primer viewport, no aceptación global ni comparación directa Source de todos.

1. adoption-swipe, adoption-detail, match-all, chat-bubbles, support-home, case-detail: tarjetas, galería, contactos, mensajes, hero y acciones visibles; datos/fotos equivalentes sólo cuando el fixture lo permite. Match-all conserva vacío alrededor de una conversación y foto fallback, sin inventar contenido.
2. profile-overview, profile-settings, rescuer-profile, rescuer-settings, rescuer-home, owned-cases: perfiles/modos, cuenta/verificación, panel y tarjetas por estado. Elementos inferiores requieren desplazamiento; no se considera su ausencia del primer viewport como defecto.
3. public-profile, saved-adoptions, payment-methods, guardian-billing-active, contribution-review, guardian-history: contenido financiero real/test y variantes de historial. Se detectó preview Guardian sin inset de borde igual al defecto742.
4. publish-photos, case-publication, verification-form, expense-evidence, managed-updates-editor-new, basic-info: datos privados/públicos distinguidos, evidencia y revisión reales. Estos formularios incluyen campos/avisos necesarios ausentes de simulaciones. No se atribuye igualdad exacta a esas diferencias funcionales.

SourceApp billing usa la misma profile-activity-list/row de /history; CSSborder1, rowpadding14, date52/gap10. Mediciónruntime742 coloca cuerpo en93. GuardianHistoryPreview tenía Material.shape pero ningún inset; añadir Padding1 corrige la misma alineación sin cambiar consultas, propietarios, cargas, callbacks ni detalles económicos. Prueba en guardian_billing verifica x93 y preserva expansión de detalles reales.

Test25395 terminal0,16/16 en3s (guardian_billing/history). Capture67824 terminal0,1/1 en2s (guardian-billing-active normal/large), normal final inspeccionado. Analyzer67824 terminal0 limpio19.5s. Full743/795 antecede esta modificación; no nuevo full ni aceptación física.

Composiciones temporales loop744-group1..4.png en directorio design-review, no versionadas. Colección743 sigue siendo base de los otros fixtures; los dos guardian-billing-active fueron renovados aquí. Objetivo activo, dinero test-only; sin Codemagic.
