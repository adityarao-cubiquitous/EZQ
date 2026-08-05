import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/branch.dart';
import '../domain/menu_document.dart';

abstract class MenuRepository {
  Stream<MenuDocument> watchMenu({
    required String restaurantId,
    required String branchId,
  });
}

class FirebaseMenuRepository implements MenuRepository {
  FirebaseMenuRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<MenuDocument> watchMenu({
    required String restaurantId,
    required String branchId,
  }) {
    final restaurantBranchId =
        FirestorePaths.requireCanonicalRestaurantBranchId(
          restaurantId,
          branchId,
        );
    return _firestore
        .doc(FirestorePaths.restaurantBranch(restaurantBranchId))
        .snapshots()
        .asyncMap((branchSnapshot) async {
          final branchData = branchSnapshot.data() ?? <String, dynamic>{};
          final branch = Branch.fromMap(branchSnapshot.id, branchData);

          return MenuDocument(
            restaurantName: branch.restaurantName!,
            branchName: branch.name,
            pdfUrl: branchData['menuPdfUrl'] as String? ?? '/demo-menu.pdf',
            previewImageUrl:
                branchData['menuPreviewImageUrl'] as String? ??
                '/demo-menu-page-1.png',
          );
        });
  }
}

class MockMenuRepository implements MenuRepository {
  @override
  Stream<MenuDocument> watchMenu({
    required String restaurantId,
    required String branchId,
  }) async* {
    yield const MenuDocument(
      restaurantName: 'The Spice House',
      branchName: 'Indiranagar',
      pdfUrl: '/demo-menu.pdf',
      previewImageUrl: '/demo-menu-page-1.png',
    );
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase || kIsWeb) {
    return FirebaseMenuRepository();
  }
  return MockMenuRepository();
});

typedef MenuWatchArgs = ({String restaurantId, String branchId});

final menuDocumentProvider = StreamProvider.family<MenuDocument, MenuWatchArgs>(
  (ref, args) {
    final repository = ref.watch(menuRepositoryProvider);
    return repository.watchMenu(
      restaurantId: args.restaurantId,
      branchId: args.branchId,
    );
  },
);
