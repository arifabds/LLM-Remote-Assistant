import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_form.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Future<void> _autoLoginFuture;

  @override
  void initState() {
    super.initState();
    _autoLoginFuture = context.read<AuthProvider>().tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _autoLoginFuture,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking session...'),
                ],
              ),
            ),
          );
        }

        return Consumer<AuthProvider>(
          builder: (ctx, authProvider, _) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Agent Status'),
                actions: [
                  if (authProvider.isAuthenticated)
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Logout',
                      onPressed: () => context.read<AuthProvider>().logout(),
                    ),
                ],
              ),
              bottomNavigationBar: BottomAppBar(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    authProvider.statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: authProvider.statusMessage.contains('başarıyla')
                          ? Colors.greenAccent
                          : authProvider.statusMessage.contains('koptu') ||
                                authProvider.statusMessage.contains('hata')
                          ? Colors.redAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildContent(context, authProvider),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, AuthProvider authProvider) {
    if (authProvider.isLoading && !authProvider.isAuthenticated) {
      return const CircularProgressIndicator(key: ValueKey('login_loader'));
    }

    if (!authProvider.isAuthenticated) {
      return const LoginForm(key: ValueKey('login_form'));
    } else {
      return SingleChildScrollView(
        child: Column(
          key: const ValueKey('status_view'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            SizedBox(
              width: 300,
              height: 300,
              child: authProvider.pairingToken != null
                  ? QrImageView(
                      data: authProvider.pairingToken!,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 20),
            const Text(
              'Scan this code with the mobile app to pair.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }
  }
}
