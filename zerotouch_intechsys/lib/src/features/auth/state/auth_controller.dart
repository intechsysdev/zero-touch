import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>((ref) {
      return AuthController(ref.read(authRepositoryProvider));
    });

class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController(this._authRepository) : super(const AsyncValue.data(null));

  final AuthRepository _authRepository;

  Future<void> signIn({required String clientId, String email = ''}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return _authRepository.signIn(clientId: clientId, email: email);
    });
  }

  void signOut() {
    state = const AsyncValue.data(null);
  }
}
