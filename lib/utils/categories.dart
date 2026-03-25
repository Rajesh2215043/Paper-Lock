import 'package:flutter/material.dart';

class AppCategories {
  static const List<String> categories = [
    'ID Proof',
    'Education',
    'Medical',
    'Finance',
    'Vehicle',
    'Other',
  ];

  static IconData getIcon(String category) {
    switch (category) {
      case 'ID Proof':
        return Icons.badge_outlined;
      case 'Education':
        return Icons.school_outlined;
      case 'Medical':
        return Icons.local_hospital_outlined;
      case 'Finance':
        return Icons.account_balance_outlined;
      case 'Vehicle':
        return Icons.directions_car_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}
