import 'package:flutter/material.dart';
import 'app.dart';
import 'utils/window_utils.dart';

Future<void> main() async {
  await setupWindow();

  runApp(const PcAgentApp());
}
