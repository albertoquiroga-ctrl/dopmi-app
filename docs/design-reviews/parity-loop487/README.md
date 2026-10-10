# Loop487 — conversación ejecutada

Base `55b831d`; Source reconsultado
`a3c969cd9103fd46dc5cd886999912526ce75efb`.
Edge a377×852, ruta `/messages/luna`, fuentes listas.

DOM observado: encabezado70; editor79 de alto (y773); input297×46
(x16/y790); enviar40×46 (x321/y790). Burbujas de texto ancho269.09375,
alto76.375 con dos líneas; párrafo14/21.7, hora10/normal con12px efectivos.
La burbuja de foto usa otro contrato (72 %, padding8) que no se atribuye a
mensajes de texto. No se cambia la línea de hora a1.55: el DOM confirma12px,
como el cliente.

Se escribió y envió con botones reales «Me gustaría conocerla este fin de
semana.». Después de enviar: campo vacío, botón desactivado y burbuja nueva
sin animaciones, ancho269.09375/alto76.375. La hora provino del Source local.
Esto verifica la simulación de referencia; no es un envío del backend.

El capturador Flutter ahora registra rectángulos del editor y Enviar en los
tres fixtures chat-bubbles (donante normal/200 y rescatista normal). Los datos
de pruebas siguen sintéticos. Browser cerrado y Vite55094 detenido. Gestos y
teclado físico requieren el Android; Codemagic permanece reservado al final.

Gate12902 exit0:33/33 en13s (32community y un capturador con tres estados).
Incluye teclado simulado con envío vacío bloqueado, paginación de conversación
y reintento de respuesta ambigua con el mismo id; no acredita teclado nativo.
Native normal y rescatista: input297×46 x16/y790 y botón40×46 x321/y790,
iguales a las medidas Source. Se conservan los JSON de medidas; en texto200
la composición es adaptable y no se afirma equivalencia con Source normal.
No hubo cambios productivos: el contraste descarta una corrección innecesaria
de altura o línea de hora. Log `dopmi-loop487-chat.log` en Temp local.
