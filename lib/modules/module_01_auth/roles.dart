import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';

/// Every role a person can pick. [value] is what the backend stores.
class RoleInfo {
  final String value;
  final String _name;
  final String _desc;
  final IconData icon;
  const RoleInfo(this.value, this._name, this._desc, this.icon);
  String get name => tr(_name);
  String get desc => tr(_desc);
}

const List<RoleInfo> kRoles = [
  RoleInfo(
    'Farmer',
    'Farmer',
    'Manage crops, rent machines, store and sell produce',
    Icons.grass,
  ),
  RoleInfo(
    'MachineryOwner',
    'Machinery Owner',
    'List tractors and harvesters to rent or sell',
    Icons.agriculture,
  ),
  RoleInfo(
    'WarehouseOwner',
    'Warehouse Owner',
    'List storage space and manage stored crops',
    Icons.warehouse_outlined,
  ),
  RoleInfo(
    'Buyer',
    'Market Person',
    'Make offers, buy produce and track delivery',
    Icons.shopping_basket_outlined,
  ),
  RoleInfo(
    'Supplier',
    'Fertilizer Supplier',
    'Sell seeds, fertilizer and pesticides',
    Icons.inventory_2_outlined,
  ),
  RoleInfo(
    'Expert',
    'Agri Expert',
    'Answer farmer questions and publish advice',
    Icons.eco_outlined,
  ),
];

RoleInfo roleInfo(String value) {
  final k = normalizeRole(value);
  for (final r in kRoles) {
    if (r.value == k) return r;
  }
  if (k == 'Admin') {
    return const RoleInfo(
      'Admin',
      'Admin',
      'Manage users, approvals and reports',
      Icons.shield_outlined,
    );
  }
  return kRoles.first;
}

/// 'machinery_owner' / 'Machinery Owner' / 'MachineryOwner' -> 'MachineryOwner'
String normalizeRole(String v) {
  final k = v.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  switch (k) {
    case 'machineryowner':
      return 'MachineryOwner';
    case 'warehouseowner':
      return 'WarehouseOwner';
    case 'buyer':
    case 'marketperson':
      return 'Buyer';
    case 'supplier':
    case 'fertilizersupplier':
      return 'Supplier';
    case 'expert':
    case 'agriexpert':
      return 'Expert';
    case 'admin':
      return 'Admin';
    default:
      return 'Farmer';
  }
}

String roleName(String v) => roleInfo(v).name;
