import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class CustomerQrRepository {
  Future<String?> customerRouteForQrValue(String rawValue);
}

class FirebaseCustomerQrRepository implements CustomerQrRepository {
  FirebaseCustomerQrRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<String?> customerRouteForQrValue(String rawValue) async {
    final localRoute = customerRouteFromQrValue(rawValue);
    if (localRoute != null) return localRoute;

    final slug = _qrSlugFromValue(rawValue);
    if (!_isRouteSegment(slug)) return null;

    final snapshot = await _firestore
        .collection('restaurantBranches')
        .where('qrSlug', isEqualTo: slug)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    if (data['isActive'] == false) return null;

    final restaurantBranchId = doc.id;
    if (!_isRouteSegment(restaurantBranchId)) return null;
    return '/customer/$restaurantBranchId';
  }
}

final customerQrRepositoryProvider = Provider<CustomerQrRepository>((ref) {
  return FirebaseCustomerQrRepository();
});

@visibleForTesting
String? customerRouteFromQrValue(String rawValue) {
  final value = rawValue.trim();
  final uri = Uri.tryParse(value);
  if (uri == null) return null;

  final restaurantBranchId = uri.queryParameters['restaurantBranchId'];
  if (_isRouteSegment(restaurantBranchId)) {
    return '/customer/$restaurantBranchId';
  }

  final pathSegments = uri.pathSegments;
  final customerIndex = pathSegments.indexOf('customer');
  if (customerIndex >= 0 && pathSegments.length > customerIndex + 1) {
    final restaurantBranch = pathSegments[customerIndex + 1];
    if (_isRouteSegment(restaurantBranch) &&
        pathSegments.length == customerIndex + 2) {
      return '/customer/$restaurantBranch';
    }
  }
  return null;
}

String _qrSlugFromValue(String rawValue) {
  final value = rawValue.trim();
  final uri = Uri.tryParse(value);
  if (uri == null || uri.pathSegments.isEmpty) return value;
  return uri.pathSegments.last.trim().isEmpty ? value : uri.pathSegments.last;
}

bool _isRouteSegment(String? value) {
  if (value == null || value.isEmpty) return false;
  return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value);
}
