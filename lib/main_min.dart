import 'package:flutter/material.dart';

// Minimal entry point to isolate whether the Flutter toolchain & web build work
// independent of Firebase or other packages.
void main() {
  runApp(const MinimalApp());
}

class MinimalApp extends StatelessWidget {
  const MinimalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minimal Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('Minimal OK')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('If you can read this, base Flutter web build works.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => runApp(const MinimalApp()),
                child: const Text('Rebuild'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
