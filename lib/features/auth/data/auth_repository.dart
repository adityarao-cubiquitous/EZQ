import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/phone_utils.dart';

abstract class AuthRepository {
  Future<void> signInAdmin({required String email, required String password});

  Future<void> signOut();
}

class PhoneCodeRequestResult {
  const PhoneCodeRequestResult({
    required this.verificationId,
    this.resendToken,
    this.autoVerified = false,
    this.phoneNumber,
  });

  final String verificationId;
  final int? resendToken;
  final bool autoVerified;
  final String? phoneNumber;
}

abstract class CustomerPhoneAuthRepository {
  Stream<User?> authStateChanges();

  User? currentUser();

  Future<PhoneCodeRequestResult> startPhoneSignIn({
    required String phone,
    int? resendToken,
  });

  Future<UserCredential> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();
}

class FirebaseCustomerPhoneAuthRepository
    implements CustomerPhoneAuthRepository {
  FirebaseCustomerPhoneAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? currentUser() => _auth.currentUser;

  @override
  Future<PhoneCodeRequestResult> startPhoneSignIn({
    required String phone,
    int? resendToken,
  }) async {
    final normalizedPhone = PhoneUtils.normalizeIndiaMobile(phone);
    final completer = Completer<PhoneCodeRequestResult>();
    await _preparePhoneVerification();

    void completeOnce(PhoneCodeRequestResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    void completeErrorOnce(Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          final userCredential = await _auth.signInWithCredential(credential);
          await _upsertCustomerProfile(userCredential.user);
          completeOnce(
            PhoneCodeRequestResult(
              verificationId: credential.verificationId ?? '',
              autoVerified: true,
              phoneNumber: normalizedPhone,
            ),
          );
        } catch (error, stackTrace) {
          completeErrorOnce(error, stackTrace);
        }
      },
      verificationFailed: (error) {
        completeErrorOnce(
          StateError(error.message ?? error.code),
          StackTrace.current,
        );
      },
      codeSent: (verificationId, resendToken) {
        completeOnce(
          PhoneCodeRequestResult(
            verificationId: verificationId,
            resendToken: resendToken,
            phoneNumber: normalizedPhone,
          ),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {
        completeOnce(
          PhoneCodeRequestResult(
            verificationId: verificationId,
            phoneNumber: normalizedPhone,
          ),
        );
      },
    );

    return completer.future;
  }

  Future<void> _preparePhoneVerification() async {
    if (kIsWeb || !kDebugMode) return;
    await _auth.setSettings(appVerificationDisabledForTesting: true);
  }

  @override
  Future<UserCredential> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _upsertCustomerProfile(userCredential.user);
    return userCredential;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _upsertCustomerProfile(User? user) async {
    if (user == null) return;
    final profileRef = _firestore.doc(FirestorePaths.customer(user.uid));
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(profileRef);
      transaction.set(profileRef, {
        'uid': user.uid,
        'phone': user.phoneNumber,
        'authProvider': 'phone',
        'appInstalled': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class MockCustomerPhoneAuthRepository implements CustomerPhoneAuthRepository {
  User? _currentUser;

  @override
  Stream<User?> authStateChanges() => Stream.value(_currentUser);

  @override
  User? currentUser() => _currentUser;

  @override
  Future<PhoneCodeRequestResult> startPhoneSignIn({
    required String phone,
    int? resendToken,
  }) async {
    return PhoneCodeRequestResult(
      verificationId: 'mock-verification-id',
      resendToken: 1,
      phoneNumber: PhoneUtils.normalizeIndiaMobile(phone),
    );
  }

  @override
  Future<UserCredential> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    throw UnsupportedError(
      'Phone authentication requires Firebase. Run with USE_FIREBASE=true.',
    );
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

final customerPhoneAuthRepositoryProvider =
    Provider<CustomerPhoneAuthRepository>((ref) {
      const useFirebase = bool.fromEnvironment('USE_FIREBASE');
      if (useFirebase) {
        return FirebaseCustomerPhoneAuthRepository();
      }
      return MockCustomerPhoneAuthRepository();
    });

final customerAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(customerPhoneAuthRepositoryProvider).authStateChanges();
});

final debugCustomerPhoneSessionProvider = Provider<ValueNotifier<String?>>((
  ref,
) {
  return ValueNotifier<String?>(null);
});
