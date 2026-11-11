# Catálogo propuesto de Tienda Dopmi

La vista previa ampliada reúne **32 familias y 127 combinaciones** de sabor y
presentación. Perros aporta 17 familias y 64 presentaciones. Gatos aporta 15
familias y 63 presentaciones. La selección cubre cachorro o gatito, adulto y
adulto mayor, con bolsas pequeñas y bultos de reposición.

Una familia tiene una ficha. Al abrirla, la presentación se elige entre las
verificadas para ese sabor. Fórmulas distintas, como Pro Plan Sensitive Skin y
Pro Plan Adulto, conservan fichas propias. Las fórmulas que sólo anuncian
presentación muestran los pesos disponibles. El buscador acepta marca, nombre,
sabor y peso, por ejemplo «Whiskas atun 1,5 kg». Los filtros ayudan a acotar por
etapa, marca, sabor, presentación y, en perros, tamaño.

El [surtido completo](../apps/mobile/lib/features/store/store_review_catalog.dart) contiene
la combinación de cada ficha. Es una muestra local reproducible en Flutter.
La ficha nativa muestra la foto de la variante seleccionada, su sabor y su
presentación. En la muestra se usa un empaque ilustrativo propio para enseñar
la colocación, con enlaces comerciales deshabilitados.

## Fotos y salida a Amazon

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

La vista previa de Flutter carga estos candidatos desde un archivo de captura, con ilustraciones genéricas y salida externa deshabilitada. Para cargar fichas comerciales se requieren imágenes autorizadas y enlaces aprobados por producto. El catálogo productivo conserva su configuración actual.
