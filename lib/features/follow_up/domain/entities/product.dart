import 'package:flutter/material.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.brandColor,
    required this.isActive,
  });

  final String id;
  final String name;
  final String description;
  final Color brandColor;
  final bool isActive;
}
