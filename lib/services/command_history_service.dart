import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../features/voice/command_parser.dart';

abstract interface class CommandHistoryWriter {
  Future<void> record(VoiceCommand command);
}

class FirestoreCommandHistoryService implements CommandHistoryWriter {
  FirestoreCommandHistoryService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firebaseFirestore,
  }) : _auth = firebaseAuth,
       _firestore = firebaseFirestore;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  @override
  Future<void> record(VoiceCommand command) async {
    if (command == VoiceCommand.unknown) return;

    final auth = _auth ?? FirebaseAuth.instance;
    final firestore = _firestore ?? FirebaseFirestore.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('Firebase anonymous sign-in returned no user.');
    }

    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('command_history')
        .add({
          'command': command.name,
          'createdAt': FieldValue.serverTimestamp(),
        });

    debugPrint('Saved command history category: ${command.name}');
  }
}
