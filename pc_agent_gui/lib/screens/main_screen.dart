import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_form.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Status'),
        actions: [
          if (authProvider.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () {
                context.read<AuthProvider>().logout();
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildContent(
              context,
              authProvider.isLoading,
              authProvider.isAuthenticated,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isLoading,
    bool isAuthenticated,
  ) {
    if (isLoading) {
      return const CircularProgressIndicator(key: ValueKey('loader'));
    }
    if (!isAuthenticated) {
      return const LoginForm(key: ValueKey('login_form'));
    } else {
      return Column(
        key: const ValueKey('status_view'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Status: Connected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'QR Code will appear here',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Keep this application running to receive commands.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      );
    }
  }
}
