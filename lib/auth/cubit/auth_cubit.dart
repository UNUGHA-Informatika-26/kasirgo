import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/services/supabase_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  void resetRegisterPasswordVisibility() {
    emit(
      state.copyWith(
        isRegisterPasswordObscured: true,
        isConfirmPasswordObscured: true,
      ),
    );
  }

  void resetPasswordResetState() {
    emit(state.copyWith(isPasswordResetSubmitted: false));
  }

  void toggleLoginPasswordVisibility() {
    emit(
      state.copyWith(isLoginPasswordObscured: !state.isLoginPasswordObscured),
    );
  }

  void toggleRegisterPasswordVisibility() {
    emit(
      state.copyWith(
        isRegisterPasswordObscured: !state.isRegisterPasswordObscured,
      ),
    );
  }

  void toggleConfirmPasswordVisibility() {
    emit(
      state.copyWith(
        isConfirmPasswordObscured: !state.isConfirmPasswordObscured,
      ),
    );
  }

  Future<void> restoreSession() async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        operation: AuthOperation.restore,
      ),
    );
    try {
      final hasSession = await SupabaseService.restoreSession();
      emit(
        state.copyWith(
          status: hasSession
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          operation: AuthOperation.restore,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          operation: AuthOperation.restore,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        operation: AuthOperation.login,
      ),
    );
    try {
      await SupabaseService.loginUser(email: email, password: password);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          operation: AuthOperation.login,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          operation: AuthOperation.login,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String storeName,
    required String storeAddress,
    required String storePhone,
  }) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        operation: AuthOperation.register,
      ),
    );
    try {
      await SupabaseService.registerUser(
        email: email,
        password: password,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
      );
      emit(
        state.copyWith(
          status: AuthStatus.registrationSuccess,
          operation: AuthOperation.register,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          operation: AuthOperation.register,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> logout() async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        operation: AuthOperation.logout,
      ),
    );
    try {
      await SupabaseService.logout();
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          operation: AuthOperation.logout,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          operation: AuthOperation.logout,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        operation: AuthOperation.passwordReset,
      ),
    );
    try {
      await SupabaseService.sendPasswordReset(email);
      emit(
        state.copyWith(
          status: AuthStatus.passwordResetSent,
          operation: AuthOperation.passwordReset,
          isPasswordResetSubmitted: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          operation: AuthOperation.passwordReset,
          message: error.toString(),
        ),
      );
    }
  }
}
