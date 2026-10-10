import 'package:flutter/material.dart';

// Storage keys remain compatible with existing approved publications.
const personalityLabels = <String, String>{
  'alegre': 'Alegre',
  'playful': 'Juguetón',
  'tranquilo': 'Tranquilo',
  'nervioso': 'Nervioso',
  'dormilon': 'Dormilón',
  'protector': 'Protector',
  'obediente': 'Obediente',
  'affectionate': 'Cariñoso',
  'timido': 'Tímido',
};
const legacyPersonalityLabels = <String, String>{
  'calm': 'Tranquilo',
  'active': 'Activo',
  'sociable': 'Sociable',
  'independent': 'Independiente',
  'feliz': 'Feliz',
  'esperanzado': 'Esperanzado',
  'emocionado': 'Emocionado',
  'triste': 'Triste',
  'enojado': 'Enojado',
  'ansioso': 'Ansioso',
  'contento': 'Contento',
  'satisfecho': 'Satisfecho',
  'solo': 'Solo',
};
const personalityColors = <String, Color>{
  'alegre': Color(0xfffff3b8),
  'playful': Color(0xffffd9ec),
  'tranquilo': Color(0xffd9ecfb),
  'nervioso': Color(0xfff5e8c8),
  'dormilon': Color(0xffe8e4f5),
  'protector': Color(0xfff8ddd0),
  'obediente': Color(0xffd8f3e4),
  'affectionate': Color(0xffffe0eb),
  'timido': Color(0xffdce4f2),
};
const personalityBorderColors = <String, Color>{
  'alegre': Color(0xfff0d878),
  'playful': Color(0xfff5a8c8),
  'tranquilo': Color(0xffa8cce8),
  'nervioso': Color(0xffe0c990),
  'dormilon': Color(0xffc9c0e3),
  'protector': Color(0xffe8b8a0),
  'obediente': Color(0xff9fd9b8),
  'affectionate': Color(0xfff0b8cc),
  'timido': Color(0xffb8c8de),
};
const personalityTextColors = <String, Color>{
  'alegre': Color(0xff5c4a12),
  'playful': Color(0xff6b2348),
  'tranquilo': Color(0xff1e4a66),
  'nervioso': Color(0xff5c4a1a),
  'dormilon': Color(0xff443a66),
  'protector': Color(0xff6b3a24),
  'obediente': Color(0xff1f5c3a),
  'affectionate': Color(0xff6b2844),
  'timido': Color(0xff334766),
};
const coexistenceLabels = <String, String>{
  'children': 'Social con niños',
  'pets': 'Social con otras mascotas',
  'apartment': 'Ideal para departamento',
  'yard': 'Necesita patio',
  'first_time': 'Ideal para primerizos',
  'experienced': 'Mejor para alguien con experiencia',
};
const ageBandLabels = <String, String>{
  'puppy': 'Cachorro',
  'adult': 'Adulto',
  'senior': 'Senior',
};
