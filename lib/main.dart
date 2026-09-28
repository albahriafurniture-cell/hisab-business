import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: Text('HELLO - minimal test OK',
            style: TextStyle(fontSize: 24, color: Colors.white)),
      ),
    ),
  ));
}
