import 'store_repository.dart';

// Presentations documented in Mexican product sheets, for internal review.
final storeReviewProducts = <StoreProduct>[
  ..._family(
    id: 'pedigree-mini',
    brand: 'Pedigree',
    name: 'Adulto razas pequeñas',
    species: 'dog',
    age: 'adult',
    sizes: ['small'],
    recipes: [
      ('Res y vegetales', [0.42, 2, 4, 10, 20]),
    ],
  ),
  ..._family(
    id: 'dog-chow-medium-large',
    brand: 'Dog Chow',
    name: 'Adultos medianos y grandes',
    species: 'dog',
    age: 'adult',
    sizes: ['medium', 'large'],
    recipes: [
      (null, [0.5, 2, 4, 7.5, 13, 15, 25]),
    ],
  ),
  ..._family(
    id: 'nupec-puppy-small',
    brand: 'Nupec',
    name: 'Cachorro razas pequeñas',
    species: 'dog',
    age: 'puppy',
    sizes: ['small'],
    recipes: [
      (null, [2, 8]),
    ],
  ),
  ..._family(
    id: 'dog-chow-mini',
    brand: 'Dog Chow',
    name: 'Adultos minis y pequeños',
    species: 'dog',
    age: 'adult',
    sizes: ['small'],
    recipes: [
      (null, [0.5, 4, 7.5, 20, 25]),
    ],
  ),
  ..._family(
    id: 'nupec-adult-small',
    brand: 'Nupec',
    name: 'Adulto razas pequeñas',
    species: 'dog',
    age: 'adult',
    sizes: ['small'],
    recipes: [
      (null, [2, 8]),
    ],
  ),
  ..._family(
    id: 'dog-chow-indoor',
    brand: 'Dog Chow',
    name: 'Hogareños adultos',
    species: 'dog',
    age: 'adult',
    sizes: ['small', 'medium', 'large'],
    recipes: [
      (null, [4, 10]),
    ],
  ),
  ..._family(
    id: 'dog-chow-complete',
    brand: 'Dog Chow',
    name: 'Complete Adulto',
    species: 'dog',
    age: 'adult',
    sizes: ['small', 'medium', 'large'],
    recipes: [
      ('Pollo', [22.7]),
    ],
  ),
  ..._family(
    id: 'pro-plan-dog-medium',
    brand: 'Pro Plan',
    name: 'Adulto razas medianas',
    species: 'dog',
    age: 'adult',
    sizes: ['medium'],
    recipes: [
      ('Pollo', [3, 7.5, 9.5, 15, 17.5]),
    ],
  ),
  ..._family(
    id: 'excellent-dog',
    brand: 'Purina Excellent',
    name: 'Adulto razas medianas y grandes',
    species: 'dog',
    age: 'adult',
    sizes: ['medium', 'large'],
    recipes: [
      ('Pollo y arroz', [1.5, 4, 20]),
    ],
  ),
  ..._family(
    id: 'pro-plan-sensitive-small',
    brand: 'Pro Plan',
    name: 'Sensitive Skin razas pequeñas',
    species: 'dog',
    age: 'adult',
    sizes: ['small'],
    recipes: [
      ('Salmón', [1, 3, 7.5, 9.5]),
    ],
  ),
  ..._family(
    id: 'dog-chow-senior',
    brand: 'Dog Chow',
    name: 'Adultos de 7 años en adelante',
    species: 'dog',
    age: 'senior',
    sizes: ['small', 'medium', 'large'],
    recipes: [
      (null, [4, 7.5, 10, 15]),
    ],
  ),
  ..._family(
    id: 'pedigree-adult',
    brand: 'Pedigree',
    name: 'Adulto',
    species: 'dog',
    age: 'adult',
    sizes: ['small', 'medium', 'large'],
    recipes: [
      ('Res y vegetales', [0.5, 2, 4, 11, 12, 20, 21]),
    ],
  ),
  ..._family(
    id: 'pedigree-high-protein',
    brand: 'Pedigree',
    name: 'High Protein Adulto',
    species: 'dog',
    age: 'adult',
    sizes: ['small', 'medium', 'large'],
    recipes: [
      ('Res y pollo', [2, 4, 10]),
    ],
  ),
  ..._family(
    id: 'pedigree-balance-natural',
    brand: 'Pedigree',
    name: 'Balance Natural Adulto',
    species: 'dog',
    age: 'adult',
    sizes: ['small', 'medium', 'large'],
    recipes: [
      ('Res y vegetales', [0.5, 2, 4]),
    ],
  ),
  ..._family(
    id: 'pro-plan-dog-small',
    brand: 'Pro Plan',
    name: 'Adulto razas pequeñas',
    species: 'dog',
    age: 'adult',
    sizes: ['small'],
    recipes: [
      ('Pollo', [1, 3.5, 7.5, 9.5]),
    ],
  ),
  ..._family(
    id: 'pro-plan-sensitive-medium',
    brand: 'Pro Plan',
    name: 'Sensitive Skin razas medianas y grandes',
    species: 'dog',
    age: 'adult',
    sizes: ['medium', 'large'],
    recipes: [
      ('Salmón', [3, 9.5, 15, 17.5]),
    ],
  ),
  ..._family(
    id: 'purina-one-dog-small',
    brand: 'Purina ONE',
    name: 'Adultos minis y pequeños',
    species: 'dog',
    age: 'adult',
    sizes: ['small'],
    recipes: [
      ('Pollo y carne', [0.5, 3.5, 7]),
    ],
  ),
  ..._family(
    id: 'cat-chow-indoor',
    brand: 'Cat Chow',
    name: 'Hogareños',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Carne', [1.5, 3, 9, 10.4]),
    ],
  ),
  ..._family(
    id: 'whiskas-adult',
    brand: 'Whiskas',
    name: 'Adulto 4 en 1',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Pollo', [1.5, 1.7, 4.5]),
      ('Carne', [0.3, 0.5, 1.5, 1.7, 3, 4.5, 9, 10, 20, 22]),
      ('Pescado', [1.5, 1.7, 3]),
      ('Atún', [1.5]),
      ('Salmón', [1.5]),
      ('Mix de proteínas', [1.5, 1.7, 3]),
    ],
  ),
  ..._family(
    id: 'cat-chow-sterilised',
    brand: 'Cat Chow',
    name: 'Esterilizados',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Pescado', [1.5]),
    ],
  ),
  ..._family(
    id: 'royal-canin-kitten',
    brand: 'Royal Canin',
    name: 'Kitten',
    species: 'cat',
    age: 'puppy',
    recipes: [
      ('Pollo', [0.341, 1.37, 3.1]),
    ],
  ),
  ..._family(
    id: 'cat-chow-adult',
    brand: 'Cat Chow',
    name: 'Adulto',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Carne', [1.5, 3, 4.5]),
      ('Pescado', [0.5, 1.5, 3, 9, 10, 11.5, 20.5, 25]),
    ],
  ),
  ..._family(
    id: 'cat-chow-kitten',
    brand: 'Cat Chow',
    name: 'Gatitos',
    species: 'cat',
    age: 'puppy',
    recipes: [
      ('Pescado, carne y leche', [0.5, 1.5]),
    ],
  ),
  ..._family(
    id: 'cat-chow-delimix',
    brand: 'Cat Chow',
    name: 'Delimix',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Salmón, carne y pollo', [1.5, 15]),
    ],
  ),
  ..._family(
    id: 'purina-one-cat',
    brand: 'Purina ONE',
    name: 'Esterilizados',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Pollo y salmón', [2, 7]),
    ],
  ),
  ..._family(
    id: 'pro-plan-sterilised',
    brand: 'Pro Plan',
    name: 'Esterilizados OptiRenal',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Salmón', [3, 7.5]),
    ],
  ),
  ..._family(
    id: 'whiskas-kitten',
    brand: 'Whiskas',
    name: 'Gatitos 4 en 1',
    species: 'cat',
    age: 'puppy',
    recipes: [
      ('Pollo', [1.4]),
      ('Res', [0.3, 0.5, 1.4, 9]),
    ],
  ),
  ..._family(
    id: 'whiskas-sterilised',
    brand: 'Whiskas',
    name: 'Esterilizados 4 en 1',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Carne', [1.5]),
    ],
  ),
  ..._family(
    id: 'pro-plan-cat',
    brand: 'Pro Plan',
    name: 'Adulto Optiprebio',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Pollo', [1.5, 3, 7.5]),
    ],
  ),
  ..._family(
    id: 'gatina-adult',
    brand: 'Gatina',
    name: 'Adultos',
    species: 'cat',
    age: 'adult',
    recipes: [
      ('Carne, pollo y verduras', [3, 9, 15, 16.5]),
    ],
  ),
  ..._family(
    id: 'nupec-kitten',
    brand: 'Nupec',
    name: 'Felino Kitten',
    species: 'cat',
    age: 'puppy',
    recipes: [
      ('Pollo y salmón', [1.5]),
    ],
  ),
  ..._family(
    id: 'pro-plan-cat-senior',
    brand: 'Pro Plan',
    name: 'Senior Optiage',
    species: 'cat',
    age: 'senior',
    recipes: [
      ('Pollo', [3]),
    ],
  ),
];

Iterable<StoreProduct> _family({
  required String id,
  required String brand,
  required String name,
  required String species,
  required String age,
  List<String> sizes = const [],
  required List<(String?, List<double>)> recipes,
}) sync* {
  for (final (recipeIndex, recipe) in recipes.indexed) {
    final (flavor, weights) = recipe;
    for (final kg in weights) {
      yield StoreProduct(
        id: '$id-$recipeIndex-${(kg * 1000).round()}',
        name: name,
        brand: brand,
        species: species,
        age: age,
        size: sizes.isEmpty ? 'medium' : sizes.first,
        sizes: sizes,
        weightKg: kg,
        imageUrl: '',
        merchantName: 'Amazon México',
        familyId: id,
        familyName: name,
        flavor: flavor,
      );
    }
  }
}
