import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/phone_utils.dart';

abstract class AuthRepository {
  Future<void> signInAdmin({required String email, required String password});

  Future<PhoneCodeRequestResult> startAdminPhoneSignIn({
    required String phone,
    int? resendToken,
  });

  Future<UserCredential> confirmAdminSmsCode({
    required String verificationId,
    required String smsCode,
  });

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

  Future<UserCredential> confirmDebugSmsCode({required String phone});

  Future<void> signOut();
}

class CustomerNameProfile {
  const CustomerNameProfile({required this.firstName, required this.lastName});

  final String firstName;
  final String lastName;

  String get displayName => '$firstName $lastName'.trim();
}

abstract class CustomerProfileRepository {
  Future<bool> needsNameProfile(User? user);

  Future<CustomerNameProfile?> loadNameProfile(User? user);

  Future<void> saveNameProfile({
    required User? user,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  });
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
  Future<UserCredential> confirmDebugSmsCode({required String phone}) async {
    final normalizedPhone = PhoneUtils.normalizeIndiaMobile(phone);
    final userCredential = await _auth.signInAnonymously();
    await _upsertDebugCustomerProfile(
      user: userCredential.user,
      phone: normalizedPhone,
    );
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

  Future<void> _upsertDebugCustomerProfile({
    required User? user,
    required String phone,
  }) async {
    if (user == null) return;
    final profileRef = _firestore.doc(FirestorePaths.customer(user.uid));
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(profileRef);
      transaction.set(profileRef, {
        'uid': user.uid,
        'phone': phone,
        'authProvider': 'debug_phone',
        'appInstalled': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}

class FirebaseCustomerProfileRepository implements CustomerProfileRepository {
  FirebaseCustomerProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<bool> needsNameProfile(User? user) async {
    if (user == null) return true;
    final snapshot = await _firestore
        .doc(FirestorePaths.customer(user.uid))
        .get();
    final data = snapshot.data();
    final firstName = (data?['firstName'] as String? ?? '').trim();
    final lastName = (data?['lastName'] as String? ?? '').trim();
    return firstName.isEmpty || lastName.isEmpty;
  }

  @override
  Future<CustomerNameProfile?> loadNameProfile(User? user) async {
    if (user == null) return null;
    final snapshot = await _firestore
        .doc(FirestorePaths.customer(user.uid))
        .get();
    final data = snapshot.data();
    if (data == null) return null;
    final firstName = (data['firstName'] as String? ?? '').trim();
    final lastName = (data['lastName'] as String? ?? '').trim();
    if (firstName.isEmpty && lastName.isEmpty) return null;
    return CustomerNameProfile(firstName: firstName, lastName: lastName);
  }

  @override
  Future<void> saveNameProfile({
    required User? user,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    if (user == null) return;
    final normalizedFirst = firstName.trim();
    final normalizedLast = lastName.trim();
    final profileRef = _firestore.doc(FirestorePaths.customer(user.uid));
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(profileRef);
      transaction.set(profileRef, {
        'uid': user.uid,
        'phone': user.phoneNumber ?? phoneNumber,
        'authProvider': user.isAnonymous ? 'debug_phone' : 'phone',
        'appInstalled': true,
        'firstName': normalizedFirst,
        'lastName': normalizedLast,
        'displayName': '$normalizedFirst $normalizedLast'.trim(),
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<void> signInAdmin({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<PhoneCodeRequestResult> startAdminPhoneSignIn({
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
          await _auth.signInWithCredential(credential);
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
  Future<UserCredential> confirmAdminSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {}

  @override
  Future<PhoneCodeRequestResult> startAdminPhoneSignIn({
    required String phone,
    int? resendToken,
  }) async {
    return PhoneCodeRequestResult(
      verificationId: 'mock-admin-verification-id',
      resendToken: 1,
      phoneNumber: PhoneUtils.normalizeIndiaMobile(phone),
    );
  }

  @override
  Future<UserCredential> confirmAdminSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    throw UnsupportedError(
      'Admin phone authentication requires Firebase. Run with USE_FIREBASE=true.',
    );
  }

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
  Future<UserCredential> confirmDebugSmsCode({required String phone}) {
    throw UnsupportedError(
      'Debug phone authentication requires Firebase. Run with USE_FIREBASE=true.',
    );
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

class MockCustomerProfileRepository implements CustomerProfileRepository {
  CustomerNameProfile? _profile;

  @override
  Future<bool> needsNameProfile(User? user) async {
    return _profile == null ||
        _profile!.firstName.trim().isEmpty ||
        _profile!.lastName.trim().isEmpty;
  }

  @override
  Future<CustomerNameProfile?> loadNameProfile(User? user) async {
    return _profile;
  }

  @override
  Future<void> saveNameProfile({
    required User? user,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    _profile = CustomerNameProfile(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) {
    return FirebaseAuthRepository();
  }
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

final customerProfileRepositoryProvider = Provider<CustomerProfileRepository>((
  ref,
) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) {
    return FirebaseCustomerProfileRepository();
  }
  return MockCustomerProfileRepository();
});

final customerAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(customerPhoneAuthRepositoryProvider).authStateChanges();
});

final debugCustomerPhoneSessionProvider = Provider<ValueNotifier<String?>>((
  ref,
) {
  return ValueNotifier<String?>(null);
});

final debugCustomerNameProfileProvider =
    Provider<ValueNotifier<CustomerNameProfile?>>((ref) {
      return ValueNotifier<CustomerNameProfile?>(null);
    });
