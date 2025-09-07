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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'An unknown error occurred.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Login to Your Account', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value!.isEmpty ? 'Please enter a username' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (value) =>
                value!.isEmpty ? 'Please enter a password' : null,
          ),
          const SizedBox(height: 20),
          if (authProvider.isLoading)
            const CircularProgressIndicator()
          else
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
              ),
              child: const Text('Login'),
            ),
        ],
      ),
    );
  }
}
