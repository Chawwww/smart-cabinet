import 'package:flutter/material.dart';

class DoorStatusScreen extends StatelessWidget {
  const DoorStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Door Status'),
      ),
      body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
            Icon(Icons.door_front_door, size: 64),
            SizedBox(height: 16),
                  Text(
              'Door status will be shown here',
              style: TextStyle(fontSize: 18),
                  ),
            SizedBox(height: 8),
            Text(
              'Check door open/close events',
              style: TextStyle(color: Colors.grey),
            ),
                ],
              ),
      ),
    );
  }
}