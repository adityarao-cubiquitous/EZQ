import 'package:cloud_firestore/cloud_firestore.dart';
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
    final localRoute = _customerRouteFromQrValue(rawValue);
    if (localRoute != null) return localRoute;

    final slug = _qrSlugFromValue(rawValue);
    if (!_isRouteSegment(slug)) return null;

    final snapshot = await _firestore
        .collectionGroup('branches')
        .where('qrSlug', isEqualTo: slug)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    if (data['isActive'] == false) return null;

    final restaurantId =
        data['restaurantId'] as String? ?? doc.reference.parent.parent?.id;
    final branchId = doc.id;
    if (!_isRouteSegment(restaurantId) || !_isRouteSegment(branchId)) {
      return null;
    }
    return '/customer/$restaurantId/$branchId';
  }
}

final customerQrRepositoryProvider = Provider<CustomerQrRepository>((ref) {
  return FirebaseCustomerQrRepository();
});

String? _customerRouteFromQrValue(String rawValue) {
  final value = rawValue.trim();
  final uri = Uri.tryParse(value);
  if (uri == null) return null;

  final restaurantId =
      uri.queryParameters['restaurantId'] ?? uri.queryParameters['restaurant'];
  final branchId =
      uri.queryParameters['branchId'] ?? uri.queryParameters['branch'];
  if (_isRouteSegment(restaurantId) && _isRouteSegment(branchId)) {
    return '/customer/$restaurantId/$branchId';
  }

  final pathSegments = uri.pathSegments;
  final customerIndex = pathSegments.indexOf('customer');
  if (customerIndex >= 0 && pathSegments.length > customerIndex + 2) {
    final restaurant = pathSegments[customerIndex + 1];
    final branch = pathSegments[customerIndex + 2];
    if (_isRouteSegment(restaurant) && _isRouteSegment(branch)) {
      return '/customer/$restaurant/$branch';
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
