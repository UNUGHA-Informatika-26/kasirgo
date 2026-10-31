enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  registrationSuccess,
  passwordResetSent,
  failure,
}

enum AuthOperation { restore, login, register, logout, passwordReset }

class AuthState {
  final AuthStatus status;
  final AuthOperation? operation;
  final String? message;
  final bool isLoginPasswordObscured;
  final bool isRegisterPasswordObscured;
  final bool isConfirmPasswordObscured;
  final bool isPasswordResetSubmitted;

  const AuthState({
    this.status = AuthStatus.initial,
    this.operation,
    this.message,
    this.isLoginPasswordObscured = true,
    this.isRegisterPasswordObscured = true,
    this.isConfirmPasswordObscured = true,
    this.isPasswordResetSubmitted = false,
  });

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthOperation? operation,
    String? message,
    bool? isLoginPasswordObscured,
    bool? isRegisterPasswordObscured,
    bool? isConfirmPasswordObscured,
    bool? isPasswordResetSubmitted,
  }) {
    return AuthState(
      status: status ?? this.status,
      operation: operation ?? this.operation,
      message: message,
      isLoginPasswordObscured:
          isLoginPasswordObscured ?? this.isLoginPasswordObscured,
      isRegisterPasswordObscured:
          isRegisterPasswordObscured ?? this.isRegisterPasswordObscured,
      isConfirmPasswordObscured:
          isConfirmPasswordObscured ?? this.isConfirmPasswordObscured,
      isPasswordResetSubmitted:
          isPasswordResetSubmitted ?? this.isPasswordResetSubmitted,
    );
  }
}
