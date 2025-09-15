import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final formKey = GlobalKey<FormState>();
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Agent'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter new agent name'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Agent name cannot be empty.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && mounted) {
      await Provider.of<DeviceProvider>(
        context,
        listen: false,
      ).updateDeviceName(device.id, newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My PC Agents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Pair New Agent',
            onPressed: () {
              context.push('/qr-scanner');
            },
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.devices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }
          if (provider.devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No paired PC Agents found.'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Pair your first agent'),
                    onPressed: () => context.push('/qr-scanner'),
                  ),
                ],
              ),
            );
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
                    color: Colors.red.shade800,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (direction) {
                    provider.deleteDevice(device.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${device.name}" has been unpaired.'),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: Icon(
                      Icons.computer,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(device.name),
                    subtitle: Text('Type: ${device.clientType.name}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Rename Agent',
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
