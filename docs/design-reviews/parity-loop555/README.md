# Loop 555 — Historia real y coordenadas del borde

Source local/remoto `a3c969cd9103fd46dc5cd886999912526ce75efb` revalidado. Story date Source usa Hoy/Hace3días. Native ahora calcula días de calendario local desde published_at, no duración de24horas; muestra Hoy/Hace1día/HaceNdías y conserva fecha exacta mediante semántica. Valor futuro mantiene fecha absoluta, inválido no aparece. No se inventan recuperación, agradecimientos, gastos relacionados ni fotos.

**Corrección de evidencia espacial:** Container añade automáticamente decoration.padding del borde. Los incrementos de padding de550/553/554 duplicaban un píxel. Se restauran padding14 en tarjeta de caso,16 en resumen/gasto y14 en cuerpo de historia. Test nuevo contrasta medidas runtimeSource553 x33/y293 de texto (summaryx16/y276), sin inferir el borde desde CSS solamente. Supersede esas afirmaciones de reserva manual previas. Auditar otros Containers antes de cerrar paridad.

Primera58753exit0 24/24,12s/analyzer10444exit0limpio19.7s. Después ampliar corrección,9095exit1 56/1 por montaje sin ProviderScope;14152exit1 56/1 por montaje sin GoRouterState. Coordenadas pasaron, excepción del montaje se conservó como fallo. Fixture se monta con sesión y ruta reales. Final38152exit0 57/57,20s; analyzer54038exit0limpio20.8s. Dos pruebas nuevas: calendario/fechas y coordenadas. Full619 no ejecutado;611 de546 anterior.

20PNG regenerados, storynormal/ampliado y detailnormal finales inspeccionados. Manifiesto con hashes. Sin runtime web nuevo (medidas553), aceptación física/global ni Codemagic.
