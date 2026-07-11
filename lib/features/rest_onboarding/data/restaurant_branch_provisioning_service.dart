import 'package:cloud_functions/cloud_functions.dart';

class RestaurantBranchProvisioningRequest {
  const RestaurantBranchProvisioningRequest({
    required this.restaurantBranchId,
    required this.slug,
    required this.restaurantName,
    required this.branchName,
    required this.area,
    required this.address,
    required this.qrSlug,
    this.latitude,
    this.longitude,
    this.subscription,
  });

  final String restaurantBranchId;
  final String slug;
  final String restaurantName;
  final String branchName;
  final String area;
  final String address;
  final String qrSlug;
  final double? latitude;
  final double? longitude;
  final Map<String, Object?>? subscription;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'restaurantBranchId': restaurantBranchId,
      'slug': slug,
      'restaurantName': restaurantName,
      'branchName': branchName,
      'area': area,
      'address': address,
      'qrSlug': qrSlug,
      if (latitude != null && longitude != null)
        'geoPoint': <String, Object?>{
          'latitude': latitude,
          'longitude': longitude,
        },
      if (subscription != null) 'subscription': subscription,
    };
  }
}

class AdminAssignmentRequest {
  const AdminAssignmentRequest({
    required this.uid,
    required this.restaurantBranchId,
    required this.role,
    this.isActive = true,
  });

  final String uid;
  final String restaurantBranchId;
  final String role;
  final bool isActive;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'uid': uid,
      'restaurantBranchId': restaurantBranchId,
      'role': role,
      'isActive': isActive,
    };
  }
}

class RestaurantBranchProvisioningResult {
  const RestaurantBranchProvisioningResult({
    required this.id,
    required this.path,
  });

  final String id;
  final String path;
}

class AdminAssignmentResult {
  const AdminAssignmentResult({
    required this.uid,
    required this.restaurantBranchId,
    required this.path,
  });

  final String uid;
  final String restaurantBranchId;
  final String path;
}

abstract class RestaurantBranchProvisioningService {
  Future<RestaurantBranchProvisioningResult> createRestaurantBranch(
    RestaurantBranchProvisioningRequest request,
  );

  Future<AdminAssignmentResult> assignAdmin(AdminAssignmentRequest request);
}

class CallableRestaurantBranchProvisioningService
    implements RestaurantBranchProvisioningService {
  CallableRestaurantBranchProvisioningService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<RestaurantBranchProvisioningResult> createRestaurantBranch(
    RestaurantBranchProvisioningRequest request,
  ) async {
    try {
      final response = await _functions
          .httpsCallable('createRestaurantBranch')
          .call<Map<dynamic, dynamic>>(request.toPayload());
      final data = response.data;
      return RestaurantBranchProvisioningResult(
        id: (data['restaurantBranchId'] as String? ?? '').trim(),
        path: (data['path'] as String? ?? '').trim(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw RestaurantBranchProvisioningException(
        error.message ?? 'RestaurantBranch creation failed',
        code: error.code,
        cause: error,
      );
    }
  }

  @override
  Future<AdminAssignmentResult> assignAdmin(
    AdminAssignmentRequest request,
  ) async {
    try {
      final response = await _functions
          .httpsCallable('assignRestaurantBranchAdmin')
          .call<Map<dynamic, dynamic>>(request.toPayload());
      final data = response.data;
      return AdminAssignmentResult(
        uid: (data['uid'] as String? ?? '').trim(),
        restaurantBranchId: (data['restaurantBranchId'] as String? ?? '')
            .trim(),
        path: (data['path'] as String? ?? '').trim(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw RestaurantBranchProvisioningException(
        error.message ?? 'Admin assignment failed',
        code: error.code,
        cause: error,
      );
    }
  }
}

class RestaurantBranchProvisioningException implements Exception {
  const RestaurantBranchProvisioningException(
    this.message, {
    required this.code,
    this.cause,
  });

  final String message;
  final String code;
  final Object? cause;

  @override
  String toString() => '$code: $message';
}
