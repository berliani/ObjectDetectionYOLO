import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:yolodetection/app/modules/home/controllers/home_controller.dart';

class YoloPage extends StatelessWidget {
  final YoloController controller = Get.put(YoloController());

  YoloPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deteksi Kamera'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => controller.flipCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: YOLOView(
              controller: controller.yoloViewController,
              modelPath: 'yolo11n',
              task: YOLOTask.detect,
              onResult: (results) {
                controller.onResult(results);
              },
              onPerformanceMetrics: (metrics) {
                controller.onPerformance(metrics);
              },
            ),
          ),
          Container(
            color: Colors.grey[200],
            height: 100,
            child: Obx(() {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.lastResults.length,
                itemBuilder: (context, index) {
                  final result = controller.lastResults[index];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            result.className,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(result.confidence * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
