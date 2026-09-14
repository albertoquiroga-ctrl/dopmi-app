class RescueField {
  const RescueField(
    this.key,
    this.label, {
    this.lines = 1,
    this.options,
    this.private = false,
    this.initial = '',
    this.max = 100,
  });
  final String key, label, initial;
  final int lines, max;
  final bool private;
  final Map<String, String>? options;
}

const rescueFields = <String, List<RescueField>>{
  'verification': [
    RescueField('public_name', 'Nombre público', max: 80),
    RescueField('bio', 'Presentación pública', lines: 3, max: 1000),
    RescueField('city', 'Ciudad'),
    RescueField('state', 'Estado'),
    RescueField(
      'legal_name',
      'Nombre completo de tu identificación',
      private: true,
      max: 150,
    ),
    RescueField('phone', 'Teléfono', private: true, max: 20),
    RescueField(
      'experience',
      'Cuéntanos tu experiencia de rescate',
      private: true,
      lines: 4,
      max: 4000,
    ),
    RescueField(
      'social_url',
      'Enlace a tu perfil social (https://)',
      private: true,
      max: 500,
    ),
    RescueField(
      'identity_type',
      'Identificación oficial',
      private: true,
      initial: 'ine',
      options: {'ine': 'INE', 'passport': 'Pasaporte', 'license': 'Licencia'},
    ),
  ],
  'case': [
    RescueField('pet_name', 'Nombre de la mascota', max: 80),
    RescueField(
      'species',
      'Especie',
      initial: 'dog',
      options: {'dog': 'Perro', 'cat': 'Gato'},
    ),
    RescueField(
      'sex',
      'Sexo',
      initial: 'unknown',
      options: {
        'female': 'Hembra',
        'male': 'Macho',
        'unknown': 'Por determinar',
      },
    ),
    RescueField('age', 'Edad aproximada'),
    RescueField('story', 'Historia de rescate', lines: 4, max: 4000),
    RescueField('city', 'Ciudad'),
    RescueField('state', 'Estado'),
    RescueField('need', 'Necesidad y cuidados', lines: 3, max: 4000),
  ],
  'expense': [
    RescueField('title', 'Título del gasto', max: 100),
    RescueField(
      'category',
      'Necesidad cubierta',
      initial: 'veterinary',
      options: {
        'veterinary': 'Atención veterinaria',
        'medicine': 'Medicamentos',
        'food': 'Comida',
        'other': 'Otro gasto',
      },
    ),
    RescueField('round_label', 'Ronda de comida (si aplica)', max: 100),
    RescueField(
      'description',
      'Qué se realizó y cómo ayudó',
      lines: 4,
      max: 4000,
    ),
    RescueField(
      'paid_on',
      'Fecha de pago (AAAA-MM-DD)',
      private: true,
      max: 10,
    ),
    RescueField('vendor', 'Proveedor', private: true, max: 150),
    RescueField(
      'amount_cents',
      'Importe pagado en pesos MXN',
      private: true,
      max: 11,
    ),
    RescueField(
      'receipt_reference',
      'Folio o referencia del comprobante',
      private: true,
      max: 150,
    ),
    RescueField(
      'urgency_reason',
      'Motivo de urgencia (opcional)',
      private: true,
      lines: 3,
      max: 1000,
    ),
  ],
};
