// lib/widgets/login_form.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // _submit metodu artık bir Future döndürmüyor, sadece komutu tetikliyor
  void _submit() {
    // Formun geçerli olup olmadığını kontrol et
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // AuthProvider üzerinden login işlemini başlat
    context.read<AuthProvider>().login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  // Controller'ları temizlemek için dispose metodu
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Hata mesajını daha kullanıcı dostu hale getiren yardımcı bir metod
  String _parseErrorMessage(String rawError) {
    if (rawError.contains('400')) {
      return 'Invalid username or password. Please try again.';
    }
    if (rawError.contains('Failed to connect') ||
        rawError.contains('Error connecting')) {
      return 'Could not connect to the server. Please check your connection and try again.';
    }
    return 'An unexpected error occurred. Please try again later.';
  }

  @override
  Widget build(BuildContext context) {
    // 'watch' ile AuthProvider'daki değişiklikleri dinleyerek UI'ı güncel tut
    final authProvider = context.watch<AuthProvider>();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment
            .stretch, // Butonun ve form elemanlarının genişlemesi için
        children: [
          // --- Başlık ---
          const Text(
            'Login to Your Account',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // --- Kullanıcı Adı Alanı ---
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value!.isEmpty ? 'Please enter a username' : null,
          ),
          const SizedBox(height: 12),

          // --- Şifre Alanı ---
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (value) =>
                value!.isEmpty ? 'Please enter a password' : null,
            // Enter'a basıldığında da formu göndermesi için
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),

          // --- Buton veya Yükleme Göstergesi ---
          // authProvider.isLoading durumuna göre ya butonu ya da yükleme animasyonunu göster
          SizedBox(
            height:
                50, // Sabit bir yükseklik vererek geçişlerdeki zıplamayı önler
            child: authProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('LOGIN'),
                  ),
          ),

          // --- Hata Mesajı Alanı ---
          // Sadece bir hata mesajı varsa ve yükleme durumu yoksa gösterilir
          if (authProvider.errorMessage != null && !authProvider.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                _parseErrorMessage(authProvider.errorMessage!),
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
