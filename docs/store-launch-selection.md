# Catálogo propuesto de Tienda Dopmi

La versión interna de Android incluye **29 familias y 67 presentaciones**
cotejadas con fichas de Amazon México. La selección editorial original reúne
32 familias y 128 combinaciones. Sólo se muestran las presentaciones que
tienen una ficha de Amazon y una foto de esa ficha.

Una familia tiene una ficha. Al abrirla, la presentación se elige entre las
verificadas para ese sabor. Fórmulas distintas, como Pro Plan Sensitive Skin y
Pro Plan Adulto, conservan fichas propias. Las fórmulas que sólo anuncian
presentación muestran los pesos disponibles. El buscador acepta marca, nombre,
sabor y peso, por ejemplo «Whiskas atun 1,5 kg». Los filtros ayudan a acotar por
etapa, marca, sabor, presentación y, en perros, tamaño.

El [surtido completo](../apps/mobile/lib/features/store/store_review_catalog.dart) contiene
la combinación de cada ficha. Es una muestra local reproducible en Flutter.
La tarjeta muestra la foto de Amazon de la presentación que abre. El detalle
actualiza la foto y el enlace al cambiar de sabor o peso. Amazon aloja las
fotos y la app carga sus URLs de HTTPS. Las imágenes de referencia del corte
anterior quedan disponibles para los recorridos locales de prueba.

## Kits de adopción

La versión interna añade un kit por especie, con cuatro fichas de Amazon
México en cada uno. Perros incluye collar ajustable, correa, dos platos y
transportadora. Gatos incluye collar de broche liberable, un paquete de dos
platos con rascador, transportadora y arenero con pala. La foto, las medidas
y el enlace de afiliado corresponden a la ficha de cada artículo.

El comprador elige y abre cada artículo por separado. La documentación
vigente de Creators API describe operaciones de catálogo. El formulario
histórico para agregar varios artículos al carrito no enumera México.
[Creators API](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/api-reference)
· [Guía histórica de Amazon](https://awsdocs.s3.amazonaws.com/Associates/latest/prod-adv-api-dg.pdf).

Amazon México publica 8% estándar para Mascotas, sujeto a la clasificación
del producto y a la elegibilidad de la compra, con tope de $500 MXN por
producto calificado. [Tabla de comisiones](https://afiliados.amazon.com.mx/help/node/topic/GRXPHT8U84RAYDXZ).

## Fotos y salida a Amazon

El botón «Ver producto en Amazon México» abre la ficha `/dp/ASIN` de la
presentación seleccionada con el identificador `albertoquir0f-20`. La ficha
incluye el aviso de afiliación. Los precios y la disponibilidad se consultan
en Amazon. Dog Chow Complete 22.7 kg, Pedigree Balance Natural seco y Whiskas
Esterilizados seco quedaron fuera de este corte al no localizar sus fichas
exactas. [Formato de enlaces de Afiliados México](https://afiliados.amazon.com.mx/welcome/topic/tools).

Fotos de la vista de prueba, de `foodless`, `detrumpezvous` y colaboradores
de Open Pet Food Facts. Los créditos individuales están en el código y en las fichas. Los JPG
se conservan como los entrega su fuente, con licencia
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). La licencia
del fotógrafo y los derechos de la gráfica del empaque son distintos.
[Datos y licencia de Open Pet Food Facts](https://world.openpetfoodfacts.org/data).

- `dog-chow-medium-large-0-500` · [7501072217554](https://world.openpetfoodfacts.org/product/7501072217554)
- `pedigree-adult-0-500` · [7506174514716](https://world.openpetfoodfacts.org/product/7506174514716)
- `pedigree-high-protein-0-2000` · [7506174515058](https://world.openpetfoodfacts.org/product/7506174515058)
- `pedigree-mini-0-1000` · [7506174514419](https://world.openpetfoodfacts.org/product/7506174514419)
- `whiskas-adult-1-1500` · [0706460029284](https://world.openpetfoodfacts.org/product/0706460029284)
- `whiskas-adult-1-3000` · [0706460029376](https://world.openpetfoodfacts.org/product/0706460029376)
- `whiskas-adult-2-1500` · [0706460029321](https://world.openpetfoodfacts.org/product/0706460029321)
- `whiskas-adult-2-3000` · [7506174516345](https://world.openpetfoodfacts.org/product/7506174516345)
- `whiskas-kitten-0-1400` · [7506174513603](https://world.openpetfoodfacts.org/product/7506174513603)
- `whiskas-kitten-1-1400` · [7506174513382](https://world.openpetfoodfacts.org/product/7506174513382)
- `whiskas-sterilised-0-1500` · [7506174514792](https://world.openpetfoodfacts.org/product/7506174514792)
- `whiskas-adult-5-3000` · [7506174515119](https://world.openpetfoodfacts.org/product/7506174515119)
- `gatina-adult-0-3000` · [7501072216625](https://world.openpetfoodfacts.org/product/7501072216625)
- `cat-chow-indoor-0-3000` · [7501072202277](https://world.openpetfoodfacts.org/product/7501072202277)
- `cat-chow-kitten-0-1500` · [7501072200730](https://world.openpetfoodfacts.org/product/7501072200730)
- `cat-chow-delimix-0-1500` · [7501072204431](https://world.openpetfoodfacts.org/product/7501072204431)
- `cat-chow-adult-0-3000` · [7501072214089](https://world.openpetfoodfacts.org/product/7501072214089)
- `cat-chow-adult-1-1500` · [7501777001151](https://world.openpetfoodfacts.org/product/7501777001151)
- `cat-chow-adult-1-3000` · [7501072202246](https://world.openpetfoodfacts.org/product/7501072202246)

El peso de Pedigree Razas Pequeñas 1 kg coincide con el código de barras
del catálogo del distribuidor. [Catálogo Dibeal](https://www.dibeal.com/wp-content/uploads/2024/05/Catalogo-Dibeal-mayo-2024_compressed.pdf).

Para cada combinación comercial, conservar juntos el nombre, la marca, el
sabor, el peso, el ASIN de la variante exacta, su enlace oficial y la foto que
corresponde a ese empaque. La autorización de la foto queda registrada en
`image_rights_reference`. La ficha abre el enlace autorizado externamente
sin reescribirlo ni eliminar sus parámetros. Si el enlace se revoca, la
compra queda indisponible y se conserva la ficha.

Con el acceso móvil de Amazon autorizado, Creators API ofrece `GetVariations`
para encontrar los ASIN de las presentaciones y `GetItems` para resolver el
detalle y las imágenes del ASIN exacto. La licencia de Amazon distingue
mostrar las imágenes autorizadas de copiar y almacenar sus archivos. Las fotos
de fabricante también necesitan derechos para usarse en la tienda. [Política
móvil de Amazon México](https://afiliados.amazon.com.mx/help/node/topic/GW7ZSEASVXHFPZCY) ·
[Políticas de Afiliados](https://afiliados.amazon.com.mx/help/operating/policies/) ·
[GetVariations](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/api-reference/operations/get-variations) ·
[GetItems](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/api-reference/operations/get-items) ·
[Términos de Mars México](https://www.mars.com/legal-mexico).

## Fuentes de la ampliación

- **Pedigree**. [Adulto razas pequeñas](https://www.pedigree.com.mx/nuestros-productos/alimento-seco/pedigree-croquetas-adulto-razas-pequenas-con-res-y-vegetales), [Adulto](https://www.pedigree.com.mx/nuestros-productos/alimento-seco/pedigree-croquetas-adulto-con-res-y-vegetales), [High Protein](https://www.pedigree.com.mx/nuestros-productos/alimento-seco/pedigree-high-protein-croquetas-adulto-con-res-y-pollo), [Balance Natural](https://www.pedigree.com.mx/nuestros-productos/alimento-seco/pedigree-balance-natural-croquetas-adulto-con-res-y-vegetales).
- **Dog Chow**. [Adultos minis y pequeños](https://purina.com.mx/dogchow/productos/dog-chow-nutricion-reforzada-adultos-minis-pequenos), [medianos y grandes](https://purina.com.mx/dogchow/productos/adultos-medianos-grandes), [hogareños](https://purina.com.mx/dogchow/productos/hogarenos-adultos), [Complete pollo](https://purina.com.mx/dogchow/productos/dog-chow-complete-adulto-sabor-pollo), [adultos de 7 años en adelante](https://purina.com.mx/dogchow/productos/dog-chow-nutricion-reforzada-adultos-mayores-7-anos-todos-tamanos).
- **Nupec**. [Cachorro razas pequeñas](https://www.nupec.com/es/nutricion-canina/nutricion-diaria/cachorro-razas-pequenas), [adulto razas pequeñas](https://www.nupec.com/es/nutricion-canina/nutricion-diaria/adulto-razas-pequenas), [Felino Kitten](https://store.nupec.com/product/nupec-felino-kitten-1-5-kg/).
- **Pro Plan perro**. [Adulto razas medianas](https://purina.com.mx/proplan/perros/adulto/razas-medianas), [adulto razas pequeñas](https://purina.com.mx/proplan/productos/adulto-razas-pequenas-optihealth-sabor-pollo), [Sensitive Skin razas pequeñas](https://purina.com.mx/proplan/productos/sensitive-skin-adulto-raza-pequena-optiderma-sabor-salmon), [Sensitive Skin razas medianas y grandes](https://purina.com.mx/proplan/productos/sensitive-skin-adulto-raza-mediana-grande-optiderma-sabor-salmon).
- **Purina Excellent y Purina ONE**. [Excellent adulto pollo y arroz](https://purina.com.mx/excellent/productos/purina-excellent-adulto-pollo-arroz-razas-medianas-grandes), [ONE minis y pequeños](https://purina.com.mx/purina-one/productos/purina-one-adultos-minis-pequenos-pollo-carne), [ONE gato esterilizado](https://purina.com.mx/purina-one/productos/purina-one-croquetas-gato-esterilizado-pollo-salmon).
- **Whiskas**. Adulto [pollo](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatos-pollo), [carne](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatos-carne-la-receta-original), [pescado](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatos-pescado), [atún](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatos-atun), [salmón](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatos-salmon) y [mix de proteínas](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatos-mix-de-proteinas). Gatitos [pollo](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatitos-pollo) y [res](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatitos-carne). [Esterilizados](https://www.whiskas.com.mx/nuestros-productos/seco/whiskas-4-en-1-alimento-seco-para-gatos-esterilizados-res).
- **Cat Chow**. Adulto [carne](https://purina.com.mx/catchow/productos/adultos-carne) y [pescado](https://purina.com.mx/purina/productos/adultos-pescado), [Hogareños](https://purina.com.mx/catchow/productos/cat-chow-hogarenos-carne), [Esterilizados](https://purina.com.mx/catchow/productos/cat-chow-esterilizados-pescado-defense-plus), [Gatitos](https://purina.com.mx/catchow/productos/alimento-cat-chow-gatito-12-meses-pescado-carne-leche) y [Delimix](https://purina.com.mx/catchow/productos/cat-chow-delimix-adultos-salmon-carne-pollo).
- **Pro Plan gato, Royal Canin y Gatina**. [OptiRenal](https://purina.com.mx/proplan/gatos/esterilizados), [Optiprebio](https://purina.com.mx/proplan/gatos/adultos), [Senior Optiage](https://purina.com.mx/proplan/productos/gato-senior-optiage-sabor-pollo), [presentaciones Royal Canin Kitten](https://petloversmx.com/tienda/gato/gato-etapa/gato-etapa-cachorro/royal-canin-kitten/), [Gatina adultos](https://purina.com.mx/purina/productos/adultos-carne-pollo-verduras).

## Selección inicial

La apuesta inicial es alimento seco de uso diario para perros y gatos. Una familia que acaba de adoptar puede buscar el alimento que ya usa su mascota, y la reposición es una oportunidad de compra recurrente. Las presentaciones de 1.5 a 3.1 kg dan opciones de entrada y los bultos de 7.5 y 15 kg cubren reposición. El orden es una hipótesis para probar, sin atribuirle ventas observadas.

La organización toma de Petco la navegación por especie y el filtrado por etapa y presentación. La tienda nativa usa la tipografía, colores y fotografía editorial de Dopmi. [Referencia de categorías de Petco México](https://www.petco.com.mx/PRODUCTOS/Gato/Alimento/Croquetas/c/02-01-02)

| Especie | Producto candidato | Presentación | Qué pondría a prueba |
| --- | --- | ---: | --- |
| Perro | Pedigree Adulto razas pequeñas, res y vegetales | 2 kg | Presentación chica de una línea conocida. [Ficha de la presentación](https://lacentraldeabastos.com.mx/producto/alimento-para-perro-pedigree-adulto-razas-pequenas/) |
| Perro | Dog Chow Adultos medianos y grandes | 15 kg | Reposición en bulto grande. [Ficha de la presentación](https://www.heb.com.mx/purina-dog-chow-alimento-seco-perros-adultos-medianos-y-grandes-bulto-de-15-kg-77003/p) |
| Perro | Nupec Cachorro razas pequeñas | 2 kg | Compra para una primera etapa de vida. [Ficha de Nupec](https://store.nupec.com/en/product/nupec-cachorro-rp-2kg/) |
| Perro | Dog Chow Adultos minis y pequeños | 7.5 kg | Reposición para hogares con perros chicos. [Catálogo de Soriana](https://www.soriana.com/marcas/dog-chow/) |
| Gato | Cat Chow Hogareños, carne | 3 kg | Compra de rutina para gato de interior. [Ficha de la presentación](https://www.walmart.com.mx/ip/alimento-para-gato-purina-cat-chow-adulto-hogareno-sabor-carne-3-kg/00750107220227) |
| Gato | Whiskas Adulto, pollo | 1.5 kg | Formato chico para compra inicial o reposición. [Ficha de la presentación](https://www.walmart.com.mx/ip/alimento-para-gato-whiskas-adulto-pollo-1-5-kg/00070646002930) |
| Gato | Cat Chow Esterilizados, pescado | 1.5 kg | Demanda de una fórmula específica y de consumo recurrente. [Ficha de Purina](https://purina.com.mx/catchow/productos/cat-chow-esterilizados-pescado-defense-plus) |
| Gato | Royal Canin Kitten, pollo | 3.1 kg | Opción de mayor precio para familias con gatitos. [Catálogo de Petco](https://www.petco.com.mx/App/Productos-Kitten/c/247) |

Amazon México publica 8% estándar para Mascotas en compras calificadas y determina la categoría de cada producto. La documentación de apps móviles indica una aprobación separada y distingue sus ingresos de los de enlaces web. Las presentaciones se verificaron en fichas de marca o comercios mexicanos. Queda pendiente cotejar cada ASIN exacto, su disponibilidad y clasificación en Amazon México, y la comisión aplicable al tráfico de Dopmi. [Tabla de comisiones](https://afiliados.amazon.com.mx/help/node/topic/GRXPHT8U84RAYDXZ) · [Enlaces en aplicaciones móviles](https://afiliados.amazon.com.mx/help/node/topic/GQZMCDD9PB7CXV7N)

La revisión de Android carga estos candidatos desde el catálogo local con la salida externa deshabilitada. Para cargar fichas comerciales se requieren imágenes y enlaces aprobados por producto.
