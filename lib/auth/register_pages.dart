import 'package:flutter/material.dart';

class RegisterPages extends StatefulWidget {
  const RegisterPages({super.key});

  @override
  State<RegisterPages> createState() => _RegisterPagesState();
}

// Alias agar kompatibel jika dipanggil sebagai RegisterPage
typedef RegisterPage = RegisterPages;

class _RegisterPagesState extends State<RegisterPages> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isObscuredPassword = true;
  bool _isObscuredConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 130,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.shopping_cart_outlined,
                        size: 90,
                        color: primaryBlue,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Daftar Akun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 28),

                // Field 1: Nama Pengguna/Nama Usaha
                const Text(
                  'Nama Pengguna/Nama Usaha',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontSize: 15,
                    color: textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama pengguna atau usaha',
                    hintStyle: const TextStyle(color: textGrey, fontSize: 14),
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      color: textGrey,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Field 2: Email
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    fontSize: 15,
                    color: textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Masukkan email Anda',
                    hintStyle: const TextStyle(color: textGrey, fontSize: 14),
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: textGrey,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Field 3: Password
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _isObscuredPassword,
                  style: const TextStyle(
                    fontSize: 15,
                    color: textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Masukkan password Anda',
                    hintStyle: const TextStyle(color: textGrey, fontSize: 14),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: textGrey,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscuredPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: textGrey,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscuredPassword = !_isObscuredPassword;
                        });
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Field 4: Konfirmasi Password
                const Text(
                  'Konfirmasi Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _isObscuredConfirmPassword,
                  style: const TextStyle(
                    fontSize: 15,
                    color: textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Konfirmasi password Anda',
                    hintStyle: const TextStyle(color: textGrey, fontSize: 14),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: textGrey,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscuredConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: textGrey,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscuredConfirmPassword = !_isObscuredConfirmPassword;
                        });
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Button Daftar (Primary)
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      // Action Daftar
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Daftar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Footer Text: Sudah punya akun? Masuk sekarang
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sudah punya akun? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text(
                        'Masuk sekarang',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
