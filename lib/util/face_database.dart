import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalUserEmbeddingRepo {
  static const _key = 'demo_user_embeddings';

  Future<void> saveUsers(List<UserEmbedded> users) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = users.map((u) => jsonEncode(u.toJson())).toList();

    await prefs.setStringList(_key, encoded);
  }

  Future<List<UserEmbedded>> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();

    final stored = prefs.getStringList(_key);
    if (stored == null) return [];

    return stored
        .map(
          (e) => UserEmbedded.fromJson(jsonDecode(e) as Map<String, dynamic>),
        )
        .toList();
  }
}

class UserEmbedded {
  final String name;
  final List<List<double>> embeddings;

  const UserEmbedded({required this.name, required this.embeddings});

  Map<String, dynamic> toJson() => {'name': name, 'embeddings': embeddings};

  factory UserEmbedded.fromJson(Map<String, dynamic> json) {
    return UserEmbedded(
      name: json['name'] as String,
      embeddings: (json['embeddings'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
    );
  }
}
