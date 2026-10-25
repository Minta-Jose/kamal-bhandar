import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';
import 'firebase.dart';

/// Where the signed-in person stands; the router picks screens from this.
sealed class Session {
  const Session();
}

class SignedOut extends Session {
  const SignedOut();
}

/// Signed in with Google but has not filled the registration form yet.
class NeedsProfile extends Session {
  const NeedsProfile(this.user);
  final User user;
}

class Customer extends Session {
  const Customer(this.profile);
  final AppUser profile;
}

class Owner extends Session {
  const Owner(this.uid, this.profile);
  final String uid;
  final AppUser? profile;
}

/// Watches sign-in, the owner claim and the profile document together.
final sessionProvider = StreamProvider<Session>((ref) {
  final auth = ref.watch(authProvider);
  final db = ref.watch(firestoreProvider);
  final controller = StreamController<Session>();
  StreamSubscription<Object?>? profileSub;

  final authSub = auth.idTokenChanges().listen((user) async {
    await profileSub?.cancel();
    profileSub = null;
    if (user == null) {
      controller.add(const SignedOut());
      return;
    }
    final token = await user.getIdTokenResult();
    final isOwner = token.claims?['owner'] == true;
    profileSub = db.doc('users/${user.uid}').snapshots().listen(
      (snap) {
        final profile = snap.exists ? AppUser.fromDoc(snap) : null;
        if (isOwner) {
          controller.add(Owner(user.uid, profile));
        } else if (profile == null) {
          controller.add(NeedsProfile(user));
        } else {
          controller.add(Customer(profile));
        }
      },
      onError: (Object e) {
        // A blocked customer's token is revoked; signing out shows the welcome screen.
        debugPrint('Profile listener failed: $e');
        controller.add(const SignedOut());
      },
    );
  });

  ref.onDispose(() {
    authSub.cancel();
    profileSub?.cancel();
    controller.close();
  });
  return controller.stream;
});

final currentUidProvider = Provider<String?>((ref) {
  return switch (ref.watch(sessionProvider).value) {
    Customer(:final profile) => profile.uid,
    Owner(:final uid) => uid,
    NeedsProfile(:final user) => user.uid,
    _ => null,
  };
});

class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;
  bool _initialised = false;

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_initialised) {
      await google.initialize();
      _initialised = true;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Already signed out of Google.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(authProvider)));

final settingsProvider = StreamProvider<StoreSettings>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const StoreSettings());
  return ref
      .watch(firestoreProvider)
      .doc('settings/store')
      .snapshots()
      .map((s) => StoreSettings.fromMap(s.data()));
});

/// Prices stay hidden from customers until the owner switches them on.
final showPricesProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session is Owner) return true;
  return ref.watch(settingsProvider).value?.showPrices ?? false;
});
