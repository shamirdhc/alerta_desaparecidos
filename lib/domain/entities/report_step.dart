import 'package:flutter/material.dart';

class ReportStep {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final String actionText;
  final String actionType;

  ReportStep({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.actionText,
    required this.actionType,
  });
}