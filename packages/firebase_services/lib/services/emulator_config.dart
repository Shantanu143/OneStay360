import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// True only when the app is started with `--dart-define=USE_EMULATOR=true`.
const bool kUseFirebaseEmulator = bool.fromEnvironment('USE_EMULATOR');

/// 10.0.2.2 is the host machine as seen from the Android emulator.
/// Override with `--dart-define=EMULATOR_HOST=<lan-ip>` for a physical device.
const String _emulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

/// Ports default to the standard emulator ports; override one with e.g.
/// `--dart-define=EMULATOR_FIRESTORE_PORT=8280` to use a second suite.
const int _firestorePort = int.fromEnvironment('EMULATOR_FIRESTORE_PORT', defaultValue: 8080);
const int _authPort = int.fromEnvironment('EMULATOR_AUTH_PORT', defaultValue: 9099);
const int _functionsPort = int.fromEnvironment('EMULATOR_FUNCTIONS_PORT', defaultValue: 5001);
const int _storagePort = int.fromEnvironment('EMULATOR_STORAGE_PORT', defaultValue: 9199);

/// Points Auth, Firestore, Functions and Storage at the local Firebase
/// Emulator Suite so nothing touches the production project.
///
/// Call right after `Firebase.initializeApp` and before any other Firebase
/// call. Does nothing unless [kUseFirebaseEmulator] is set. Every service is
/// redirected even when its emulator is not running, so a call fails locally
/// instead of reaching production.
Future<void> connectToFirebaseEmulatorIfEnabled() async {
  if (!kUseFirebaseEmulator) return;

  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestorePort);
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authPort);
  FirebaseFunctions.instance.useFunctionsEmulator(_emulatorHost, _functionsPort);
  FirebaseFunctions.instanceFor(region: 'us-central1')
      .useFunctionsEmulator(_emulatorHost, _functionsPort);
  await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, _storagePort);

  debugPrint('🧪 Firebase emulators enabled ($_emulatorHost): '
      'auth:$_authPort firestore:$_firestorePort functions:$_functionsPort storage:$_storagePort');
}
