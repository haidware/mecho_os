import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';

class LoginResult {
  final bool success;
  final String message;
  final bool shouldRegister;
  final Map<String, dynamic>? userData;

  LoginResult({
    required this.success,
    this.message = '',
    this.shouldRegister = false,
    this.userData,
  });
}

class AuthService {
  final AuthRepository _repository = AuthRepository();

  Future<LoginResult> loginWorkshopUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _repository.loginWithEmailAndPassword(email, password);
      final userData = await _repository.getUserDocument(response.user!.id);

      if (userData == null) {
        await _repository.logout();
        return LoginResult(
          success: false,
          message: 'Account not found. Please register first.',
          shouldRegister: true,
        );
      }

      if (userData['status'] != 'active') {
        await _repository.logout();
        return LoginResult(success: false, message: 'Your account is currently inactive.');
      }

      final role = userData['role'];
      if (role != 'workshop_owner' && role != 'staff') {
        await _repository.logout();
        return LoginResult(success: false, message: 'Access denied. Only workshop accounts can log in here.');
      }

      return LoginResult(success: true, userData: userData);
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return LoginResult(success: false, message: 'Incorrect password. Please try again.');
      }
      return LoginResult(success: false, message: e.message);
    } catch (e) {
      return LoginResult(success: false, message: 'An error occurred: $e');
    }
  }

  Future<void> registerGarageOwner({
    required String ownerName,
    required String garageName,
    required String phoneNumber,
    required String email,
    required String password,
    required String garageAddress,
    required String workshopType,
  }) async {
    final response = await _repository.registerWithEmailAndPassword(email, password);
    String uid = response.user!.id;

    final trialStart = DateTime.now();
    final trialEnd = trialStart.add(const Duration(days: 30));

    // Create a workshop first to get its ID
    final workshopResponse = await Supabase.instance.client.from('workshops').insert({
      'owner_id': uid,
      'owner_name': ownerName,
      'garage_name': garageName,
      'phone_number': phoneNumber,
      'email': email,
      'garage_address': garageAddress,
      'workshop_type': workshopType,
      'subscription_status': 'trial',
      'trial_start_date': trialStart.toIso8601String(),
      'trial_end_date': trialEnd.toIso8601String(),
    }).select().single();

    final workshopId = workshopResponse['id'];

    // Save User Profile with workshop_id
    await _repository.saveUserDocument(uid, {
      'full_name': ownerName,
      'email': email,
      'phone_number': phoneNumber,
      'role': 'workshop_owner',
      'workshop_id': workshopId,
      'status': 'active',
    });

    // Save Subscription
    await _repository.saveSubscriptionDocument({
      'user_id': uid,
      'workshop_id': workshopId,
      'plan': 'trial',
      'status': 'active',
      'monthly_amount': 10000,
    });
  }
}
