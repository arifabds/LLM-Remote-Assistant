import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/agent_connection_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../utils/ui_helpers.dart';
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

        return Consumer3<AuthProvider, AgentConnectionProvider, DeviceProvider>(
          builder: (ctx, authProvider, connectionProvider, deviceProvider, _) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('LLM Remote Agent'),
                actions: [
                  if (authProvider.isAuthenticated)
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Hard Logout (Clear All Data)',
                      onPressed: () =>
                          context.read<AuthProvider>().hardLogout(),
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
                    connectionProvider.statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          connectionProvider.statusMessage.contains(
                            'Successfully',
                          )
                          ? Colors.greenAccent
                          : connectionProvider.statusMessage.contains('lost') ||
                                connectionProvider.statusMessage.contains(
                                  'Error',
                                )
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
                    child: _buildContent(context, authProvider, deviceProvider),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    AuthProvider authProvider,
    DeviceProvider deviceProvider,
  ) {
    if (authProvider.isLoading && !authProvider.isAuthenticated) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('initial_loader')),
      );
    }

    if (!authProvider.isAuthenticated) {
      return const LoginForm(key: ValueKey('login_form_view'));
    }

    if (deviceProvider.pairedMobileDevices.isEmpty) {
      return SingleChildScrollView(
        key: const ValueKey('pairing_view'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Ready to Pair',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                height: 300,
                child: deviceProvider.pairingToken != null
                    ? QrImageView(
                        data: deviceProvider.pairingToken!,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 20),
              const Text(
                'Scan this code with the mobile app to pair.',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      return Column(
        key: const ValueKey('paired_view'),
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 60,
          ),
          const SizedBox(height: 10),
          const Text(
            'Ready for Commands',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Paired Mobile Devices:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: deviceProvider.pairedMobileDevices.length,
              itemBuilder: (ctx, index) {
                final device = deviceProvider.pairedMobileDevices[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.phone_android),
                  title: Text(device.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.redAccent),
                    tooltip: 'Unpair this device',
                    onPressed: () async {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      final confirmed = await showUnpairConfirmationDialog(
                        context,
                        device.name,
                      );

                      if (confirmed && mounted) {
                        await deviceProvider.unpairMobileDevice(device.id);

                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '"${device.name}" has been unpaired.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }
}
