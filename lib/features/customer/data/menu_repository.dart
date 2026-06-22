import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
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
    final restaurantRef = _firestore.doc(
      FirestorePaths.restaurant(restaurantId),
    );
    final branchRef = _firestore.doc(
      FirestorePaths.branch(restaurantId, branchId),
    );

    return branchRef.snapshots().asyncMap((branchSnapshot) async {
      final branchData = branchSnapshot.data() ?? <String, dynamic>{};
      final restaurantSnapshot = await restaurantRef.get();
      final restaurantData = restaurantSnapshot.data() ?? <String, dynamic>{};

      return MenuDocument(
        restaurantName: restaurantData['name'] as String? ?? restaurantId,
        branchName: branchData['name'] as String? ?? branchId,
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
  if (useFirebase) {
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
