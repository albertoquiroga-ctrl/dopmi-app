import 'store_review_amazon_listings.dart';

class StoreKitItem {
  const StoreKitItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.presentation,
    required this.species,
    required this.listing,
  });

  final String id, name, brand, presentation;
  final Set<String> species;
  final StoreReviewAmazonListing listing;

  Uri? get imageUri => listing.imageUri;
}

const storeReviewKitItems = <StoreKitItem>[
  StoreKitItem(
    id: 'kit-dog-collar',
    name: 'Collar ajustable',
    brand: 'Fancy Pets',
    presentation: 'Talla XCH · Cuello de 17 a 30 cm',
    species: {'dog'},
    listing: StoreReviewAmazonListing(
      'B0BVWN7DVR',
      'https://m.media-amazon.com/images/I/51nPgoVArIL._AC_SL1000_.jpg',
    ),
  ),
  StoreKitItem(
    id: 'kit-dog-leash',
    name: 'Correa fija de cuerda',
    brand: 'Fancy Pets',
    presentation: '1.60 m · Negra · 1 pieza',
    species: {'dog'},
    listing: StoreReviewAmazonListing(
      'B0CZPKZSWJ',
      'https://m.media-amazon.com/images/I/51IrqG4WQvL._AC_SL1000_.jpg',
    ),
  ),
  StoreKitItem(
    id: 'kit-dog-bowls',
    name: 'Platos de acero inoxidable',
    brand: 'LUANMA',
    presentation: '2 platos antideslizantes de 18 cm',
    species: {'dog'},
    listing: StoreReviewAmazonListing(
      'B0D3DTXH6R',
      'https://m.media-amazon.com/images/I/51PvXGJ2KyL._AC_SL1500_.jpg',
    ),
  ),
  StoreKitItem(
    id: 'kit-dog-carrier',
    name: 'Transportadora rígida de doble puerta',
    brand: 'Amazon Basics',
    presentation: '58 × 38 × 33 cm · 1 pieza',
    species: {'dog'},
    listing: StoreReviewAmazonListing(
      'B00OP6SVJW',
      'https://m.media-amazon.com/images/I/71zJAg+iTDL._AC_SL1500_.jpg',
    ),
  ),
  StoreKitItem(
    id: 'kit-cat-collar',
    name: 'Collar de seguridad',
    brand: 'Nuvuq',
    presentation: 'Ajustable de 17.5 a 26 cm · Broche liberable',
    species: {'cat'},
    listing: StoreReviewAmazonListing(
      'B0D8LZRS6H',
      'https://m.media-amazon.com/images/I/51h67f9CuLL._AC_SL1500_.jpg',
    ),
  ),
  StoreKitItem(
    id: 'kit-cat-bowls',
    name: 'Platos elevados y rascador',
    brand: 'Fancy Pets',
    presentation: '2 platos y 1 rascador de 43 cm',
    species: {'cat'},
    listing: StoreReviewAmazonListing(
      'B0F6GZHJFN',
      'https://m.media-amazon.com/images/I/31DLtgjFZpL._AC_SY300_SX300_QL70_ML2_.jpg',
    ),
  ),
  StoreKitItem(
    id: 'kit-cat-carrier',
    name: 'Transportadora rígida de doble puerta',
    brand: 'Amazon Basics',
    presentation: '48 × 32 × 25 cm · 1 pieza',
    species: {'cat'},
    listing: StoreReviewAmazonListing(
      'B00OP6SMCI',
      'https://m.media-amazon.com/images/I/71WgHnZShvL._AC_SL1500_.jpg',
    ),
  ),
  StoreKitItem(
    id: 'kit-cat-litter-box',
    name: 'Arenero abierto con pala',
    brand: 'dognut',
    presentation: '48 × 39 × 13 cm · Bandeja, paredes y pala',
    species: {'cat'},
    listing: StoreReviewAmazonListing(
      'B0DPNLTVGN',
      'https://m.media-amazon.com/images/I/715L2vLxLuL._AC_SL1500_.jpg',
    ),
  ),
];
