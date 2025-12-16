import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth_engine/face_auth_engine.dart';

class FaceFirestoreRepo {
  final _db = FirebaseFirestore.instance;

  Future<void> saveEmbedding({
    required String userId,
    required FaceEmbedding embedding,
  }) async {
    inspect(userId);
    inspect(embedding);
    final users = _db.collection('users').doc(userId);
    await users
        .set({
          'embedding': embedding.embedding.toList(),
          'embeddingVersion': embedding.version,
          'enrolledAt': FieldValue.serverTimestamp(),
        })
        .then((value) => log("User Added"))
        .catchError((error) => log("Failed to add user: $error"));
  }

  Future<List<FaceEmbedding>> loadAllEmbeddings() async {
    final snapshot = await _db.collection('users').get();

    return snapshot.docs.map((doc) {
      return FaceEmbedding(
        personId: doc.id,
        embedding: Float32List.fromList(List<double>.from(doc['embedding'])),
        version: doc['embeddingVersion'],
      );
    }).toList();
  }
}
