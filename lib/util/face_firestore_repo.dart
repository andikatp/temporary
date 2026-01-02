import 'package:cloud_firestore/cloud_firestore.dart';

class FaceFirestoreRepo {
  final _db = FirebaseFirestore.instance;

  Future<void> addFace({
    required String faceId,
    required List<List<double>> faces,
  }) async {
    final userRef = _db.collection('users').doc(faceId);

    await userRef.set({'embeddingVersion': 1});

    final batch = _db.batch();

    for (var i = 0; i < faces.length; i++) {
      batch.set(userRef.collection('embeddings').doc('$i'), {
        'vector': faces[i],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<List<List<double>>> getFaceEmbeddings(String faceId) async {
    final snapshot = await _db
        .collection('users')
        .doc(faceId)
        .collection('embeddings')
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => List<double>.from(doc['vector']))
        .toList();
  }
}
