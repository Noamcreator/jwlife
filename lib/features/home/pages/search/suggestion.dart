import 'package:flutter/cupertino.dart';

class SuggestionItem {
  final String type;
  final dynamic query;
  final String title;
  final String? image;
  final IconData? icon;
  final String? subtitle;
  final String? label;

  final int? startParagraphId;
  final int? endParagraphId;

  SuggestionItem({
    required this.type,
    required this.query,
    required this.title,
    this.image,
    this.icon,
    this.subtitle,
    this.label,
    this.startParagraphId,
    this.endParagraphId
  });
}