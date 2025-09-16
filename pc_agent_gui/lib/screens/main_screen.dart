import 'package:flutter/foundation.dart';
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
  final Stopwatch _logStopwatch = Stopwatch()..start();
  late Future<void> _autoLoginFuture;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-INIT] MainScreen initState called.',
    );
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-INIT] Triggering tryAutoLogin and assigning to _autoLoginFuture.',
    );
    _autoLoginFuture = context.read<AuthProvider>().tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-BUILD] MainScreen build method called.',
    );
    return FutureBuilder(
      future: _autoLoginFuture,
      builder: (ctx, snapshot) {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-FUTURE-BUILDER] FutureBuilder builder triggered. ConnectionState: ${snapshot.connectionState}.',
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint(
            '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-FUTURE-BUILDER-DECISION] -> Showing session check loading screen.',
          );
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

        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-FUTURE-BUILDER] Future completed. Watching providers and building main scaffold.',
        );
        final authProvider = context.watch<AuthProvider>();
        final deviceProvider = context.watch<DeviceProvider>();
        final connectionProvider = context.watch<AgentConnectionProvider>();

        return Scaffold(
          appBar: AppBar(
            title: const Text('LLM Remote Agent'),
            actions: [
              if (authProvider.isAuthenticated)
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Hard Logout (Clear All Data)',
                  onPressed: () {
                    debugPrint(
                      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-ACTION] Hard Logout button pressed.',
                    );
                    context.read<AuthProvider>().hardLogout();
                  },
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
                      connectionProvider.statusMessage.contains('Successfully')
                      ? Colors.greenAccent
                      : connectionProvider.statusMessage.contains('lost') ||
                            connectionProvider.statusMessage.contains('Error')
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
  }

  Widget _buildContent(
    BuildContext context,
    AuthProvider authProvider,
    DeviceProvider deviceProvider,
  ) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-BUILD-CONTENT] Building content with state: Auth isAuthenticated: ${authProvider.isAuthenticated}, Device isLoading: ${deviceProvider.isLoading}, Paired devices count: ${deviceProvider.pairedMobileDevices.length}, Pairing token exists: ${deviceProvider.pairingToken != null}.',
    );

    if (!authProvider.isAuthenticated) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-BUILD-CONTENT-DECISION] -> Showing LoginForm.',
      );
      return const LoginForm(key: ValueKey('login_form'));
    }

    if (deviceProvider.isLoading) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-BUILD-CONTENT-DECISION] -> Showing device loading indicator.',
      );
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('device_loader')),
      );
    }

    if (deviceProvider.pairedMobileDevices.isEmpty) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-BUILD-CONTENT-DECISION] -> Showing Pairing View (QR Code).',
      );
      return SingleChildScrollView(
        key: const ValueKey('pairing_view'),
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
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-BUILD-CONTENT-DECISION] -> Showing Paired View (Ready for Commands).',
      );
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
                    onPressed: () {
                      debugPrint(
                        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-ACTION] Unpair button pressed for device: ${device.name}.',
                      );
                      showUnpairConfirmationDialog(context, device.name).then((
                        confirmed,
                      ) {
                        debugPrint(
                          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-ACTION] Unpair confirmation dialog returned: $confirmed.',
                        );
                        if (confirmed == true && mounted) {
                          final deviceNameForSnackbar = device.name;
                          context.read<DeviceProvider>().unpairMobileDevice(
                            device.id,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '"$deviceNameForSnackbar" has been unpaired.',
                              ),
                            ),
                          );
                        }
                      });
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

  @override
  void dispose() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PC-MAIN-DISPOSE] MainScreen dispose called.',
    );
    super.dispose();
  }
}
