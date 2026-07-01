import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Future<AuthResponse> loginWithEmailAndPassword(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> registerWithEmailAndPassword(String email, String password) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return response;
  }

  Future<void> saveUserDocument(String uid, Map<String, dynamic> data) async {
    await _supabase.from('users').upsert({'id': uid, ...data});
  }

  Future<void> saveWorkshopDocument(Map<String, dynamic> data) async {
    await _supabase.from('workshops').insert(data);
  }

  Future<void> saveSubscriptionDocument(Map<String, dynamic> data) async {
    await _supabase.from('subscriptions').insert(data);
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
