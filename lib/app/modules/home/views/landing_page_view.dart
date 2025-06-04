// landing_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yolodetection/app/modules/home/views/home_view.dart';


class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ElevatedButton(
          onPressed: () => Get.to(() => YoloPage()),
          child: const Text('Mulai Deteksi'),
        ),
      ),
    );
  }
}
