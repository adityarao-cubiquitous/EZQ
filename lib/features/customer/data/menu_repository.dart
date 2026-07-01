import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/menu_document.dart';
import 'branch_identity_repository.dart';

abstract class MenuRepository {
  Stream<MenuDocument> watchMenu({
    required String restaurantId,
    required String branchId,
  });
}

class FirebaseMenuRepository implements MenuRepository {
  FirebaseMenuRepository({
    FirebaseFirestore? firestore,
    BranchIdentityRepository? branchIdentityRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _branchIdentityRepository =
           branchIdentityRepository ??
           FirebaseBranchIdentityRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final BranchIdentityRepository _branchIdentityRepository;

  @override
  Stream<MenuDocument> watchMenu({
    required String restaurantId,
    required String branchId,
  }) {
    return Stream.fromFuture(
          _branchIdentityRepository.resolveBranchSlug(
            restaurantId: restaurantId,
            branchSlug: branchId,
          ),
        )
        .asyncExpand((resolvedBranchSlug) {
          return _firestore
              .doc(FirestorePaths.branch(restaurantId, resolvedBranchSlug))
              .snapshots();
        })
        .asyncMap((branchSnapshot) async {
          final branchData = branchSnapshot.data() ?? <String, dynamic>{};
          final restaurantSnapshot = await _firestore
              .doc(FirestorePaths.restaurant(restaurantId))
              .get();
          final restaurantData =
              restaurantSnapshot.data() ?? <String, dynamic>{};

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
  if (useFirebase || kIsWeb) {
    return FirebaseMenuRepository(
      branchIdentityRepository: ref.watch(branchIdentityRepositoryProvider),
    );
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
