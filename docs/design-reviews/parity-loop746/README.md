# Loop746 — Etiqueta completa en avances

2026-10-04. Base7bfc423; Sourceirlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb verificado inicio/cierre.

Inspección12 estados200%: public-profile-large, saved-adoptions-large, payment-methods-large, guardian-billing-active-large, contribution-review-large, guardian-history-large; publish-photos-large, case-publication-large, verification-form-large, expense-evidence-large, managed-updates-editor-new-large, basic-info-large. Las capturas proceden de colección743 salvo previewGuardian renovado744. Sólo primeros viewports/posición de captura; no se atribuye acceso a contenido inferior por inspección. Evidence-large está intencionalmente desplazado dentro del diálogo.

Defecto observado: editor nuevo trunca la pregunta como ¿Cómo sigue ... a200%. InputDecoration.labelText generaba Text limitado a una línea. Reemplazo por label Text con maxLines3 conserva estilos y flotación, permite pregunta completa sin bajar escala y no cambia valor/controller/maxLength/guardado. Editor productivo adicional no tiene contraparte Source localizada mediante búsqueda de texto; ésta es corrección de accesibilidad del flujo real, no comparación directa exacta del mismo formulario Source.

Prueba en editor real nuevo con Inter, escala normal/200%: RenderParagraph no excede líneas antes/después de escribir; etiqueta en campo; texto escrito conservado y repositorio sin escrituras automáticas. Gate56694 terminal0,10/10 en3s, incluye borradores, teclado, estados submitted/approved y respuestas tardías. Sin modificaciones de autorización/lifecycle/backend.

Capture73865 terminal0,1/1 en2s, dosPNG nuevos con PIL/dimensiones/SHA. Grande final inspeccionado y muestra ¿Cómo sigue el / rescate? completo. Normal PNG idéntico a743: d8115324a194154cca3d0c7b9e311ea7c0d59e3731324a48b6b8032cbd542e69. Analyzer73865 terminal0 limpio32.3s. Full743/795 antecede744-746 y seis pruebas nuevas.

Objetivo activo; sin aceptación visual global/nativa, Codemagic diferido y dinero test-only. Continuar rutas normales restantes y estados de teclado/modales pendientes; no reiniciar la revisión ya documentada744/745.
