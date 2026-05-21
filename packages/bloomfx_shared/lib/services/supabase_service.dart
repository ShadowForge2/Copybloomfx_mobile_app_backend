import '../models/user.dart';

class SupabaseSession {
  final SupabaseUser? user;
  SupabaseSession({this.user});
}

class SupabaseUser {
  final String id;
  SupabaseUser({required this.id});
}

class SupabaseService {
  static Future<void> initialize(String url, String anonKey) async {
    // Stub: real Supabase integration not yet implemented
  }

  SupabaseSession? get currentSession => null;

  Future<SupabaseSession?> signIn({String? email, String? password}) async {
    return SupabaseSession();
  }

  Future<void> signOut() async {}

  Future<Map<String, dynamic>?> fetchUserByAuthId(String authId) async {
    return null;
  }

  User mapToUser(Map<String, dynamic> data) {
    return User.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    return [];
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    return false;
  }
}
