import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeviceProvider>(context, listen: false).fetchDevices();
    });
  }

  Future<void> _showEditNameDialog(Device device) async {
    final nameController = TextEditingController(text: device.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      await Provider.of<DeviceProvider>(
        context,
        listen: false,
      ).updateDeviceName(device.id.toInt(), newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Devices')),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }

          if (provider.devices.isEmpty) {
            return const Center(child: Text('No paired devices found.'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchDevices(),
            child: ListView.builder(
              itemCount: provider.devices.length,
              itemBuilder: (context, index) {
                final device = provider.devices[index];
                return Dismissible(
                  key: ValueKey(device.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade900,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    provider.deleteDevice(device.id.toInt());
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${device.name} unpaired')),
                    );
                  },
                  child: ListTile(
                    leading: Icon(
                      device.clientType == ClientType.AGENT
                          ? Icons.computer
                          : Icons.phone_android,
                    ),
                    title: Text(device.name),
                    subtitle: Text('Type: ${device.clientType.name}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditNameDialog(device),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
