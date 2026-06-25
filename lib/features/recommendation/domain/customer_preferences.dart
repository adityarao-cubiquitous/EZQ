import 'package:flutter/foundation.dart';

import 'recommendation_types.dart';

@immutable
class CustomerPreferences {
  const CustomerPreferences({
    this.seatingPreference = SeatingPreference.anyAvailable,
    this.floorPreference,
    this.accessibilityRequired = false,
    this.acceptedLongerWait = false,
    this.etaShared,
    this.etaEmptyTable,
    this.selectedAt,
  });

  final SeatingPreference seatingPreference;
  final String? floorPreference;
  final bool accessibilityRequired;

  // F1 fields — null when the customer has not made an explicit F1 preference.
  final bool acceptedLongerWait;
  final int? etaShared;
  final int? etaEmptyTable;
  final DateTime? selectedAt;

  const CustomerPreferences.defaults()
      : seatingPreference = SeatingPreference.anyAvailable,
        floorPreference = null,
        accessibilityRequired = false,
        acceptedLongerWait = false,
        etaShared = null,
        etaEmptyTable = null,
        selectedAt = null;

  factory CustomerPreferences.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(String key) {
      final v = data[key];
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return CustomerPreferences(
      seatingPreference: SeatingPreference.fromWireName(
        data['seatingPreference'] as String?,
      ),
      floorPreference: data['floorPreference'] as String?,
      accessibilityRequired: data['accessibilityRequired'] as bool? ?? false,
      acceptedLongerWait: data['acceptedLongerWait'] as bool? ?? false,
      etaShared: data['etaShared'] as int?,
      etaEmptyTable: data['etaEmptyTable'] as int?,
      selectedAt: parseDate('selectedAt'),
    );
  }

  Map<String, dynamic> toMap() => {
    'seatingPreference': seatingPreference.wireName,
    'floorPreference': floorPreference,
    'accessibilityRequired': accessibilityRequired,
    'acceptedLongerWait': acceptedLongerWait,
    if (etaShared != null) 'etaShared': etaShared,
    if (etaEmptyTable != null) 'etaEmptyTable': etaEmptyTable,
    if (selectedAt != null) 'selectedAt': selectedAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is CustomerPreferences &&
      other.seatingPreference == seatingPreference &&
      other.floorPreference == floorPreference &&
      other.accessibilityRequired == accessibilityRequired &&
      other.acceptedLongerWait == acceptedLongerWait &&
      other.etaShared == etaShared &&
      other.etaEmptyTable == etaEmptyTable &&
      other.selectedAt == selectedAt;

  @override
  int get hashCode => Object.hash(
    seatingPreference,
    floorPreference,
    accessibilityRequired,
    acceptedLongerWait,
    etaShared,
    etaEmptyTable,
    selectedAt,
  );
}
