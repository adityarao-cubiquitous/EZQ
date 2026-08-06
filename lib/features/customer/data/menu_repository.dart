import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/branch.dart';
import '../domain/menu_document.dart';

abstract class MenuRepository {
  Stream<MenuDocument> watchMenu({required String restaurantBranchId});
}

class FirebaseMenuRepository implements MenuRepository {
  FirebaseMenuRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<MenuDocument> watchMenu({required String restaurantBranchId}) {
    return _firestore
        .doc(FirestorePaths.restaurantBranch(restaurantBranchId))
        .snapshots()
        .asyncMap((branchSnapshot) async {
          final branchData = branchSnapshot.data() ?? <String, dynamic>{};
          final branch = Branch.fromMap(branchSnapshot.id, branchData);

          return MenuDocument(
            restaurantName: branch.restaurantName!,
            branchName: branch.name,
            pdfUrl: branchData['menuPdfUrl'] as String?,
            previewImageUrl: branchData['menuPreviewImageUrl'] as String?,
          );
        });
  }
}

class MockMenuRepository implements MenuRepository {
  @override
  Stream<MenuDocument> watchMenu({required String restaurantBranchId}) async* {
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

final menuDocumentProvider = StreamProvider.family<MenuDocument, String>((
  ref,
  restaurantBranchId,
) {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.watchMenu(restaurantBranchId: restaurantBranchId);
});
