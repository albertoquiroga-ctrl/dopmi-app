# Loop490 — Chats sin desplazamiento por búsqueda

Base `d91a6ee`; Source SHA reconsultado
`a3c969cd9103fd46dc5cd886999912526ce75efb`.
Se usa el DOM ejecutado488: Chats empieza en332.796875 y título16/1.3
con margen inferior12. No se atribuye una nueva sesión Source en490.

La búsqueda productiva imponía fila48 + espacio18. Se coloca como control
superpuesto dentro del bloque completo de chats, con área48 y título reservado
48px a la derecha. El título controla la composición: altura20.8 + margen12,
sin espacio18 adicional. El icono se alinea visualmente con el título sin
reducir su botón. Se mantiene consulta, foco, limpiar, resultados, paginación
y navegación. Normal y texto200 adaptan la línea según el usuario.

Primer intento de extracción no leyó UTF8 y no cambió el archivo: ejecución
63330 cubrió el estado488/489, no el cambio490. Un segundo intento encontró
un `if` interior; el formateador lo rechazó antes de compilar. Se reconstruyó
exclusivamente este archivo desde HEAD (sin cambios de usuario iniciales) y
se corrigió el anclaje. Ningún archivo de usuario fue descartado.

Final de distribución20569 exit0:34/34 en16s,33community incluyendo regreso
del sistema489 y un capturador con14 estados match normal200. Precede sólo
la alineación visual del icono, cuya pasada de capturas final se registra
aparte. Logs locales en Temp `dopmi-loop490-*`. No backend ni SQL cambiados,
sin aceptación Android/física/global. Codemagic queda al objetivo completo.

Icono final60657 exit0,1 capturador/14estados,8s. PNG normal y búsqueda200
inspeccionados; etiqueta flotante de búsqueda200 sigue truncada, pendiente de
adaptar sin ocultar su propósito. Analyzer96360 exit0, limpio31.8s. ADB vacío.
El último full móvil479 precede esta producción; procede gate integrado antes
de ampliar el siguiente contraste de familias, sin atribuir el resultado aún.
