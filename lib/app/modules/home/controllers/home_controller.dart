import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_task.dart';

class YoloController extends GetxController {
  final YOLOViewController yoloViewController = YOLOViewController();

  final RxDouble confidenceThreshold = 0.5.obs;
  final RxDouble iouThreshold = 0.45.obs;
  final RxDouble zoomLevel = 1.0.obs;
  final RxString currentModel = 'yolo11n'.obs; // nama model tanpa ekstensi
  final Rx<YOLOTask> currentTask = YOLOTask.detect.obs;
  final RxList<YOLOResult> lastResults = <YOLOResult>[].obs;
  @override
  void onInit() {
    super.onInit();

    yoloViewController.setThresholds(
      confidenceThreshold: confidenceThreshold.value,
      iouThreshold: iouThreshold.value,
    );
    yoloViewController.setZoomLevel(zoomLevel.value);
    yoloViewController.switchModel(currentModel.value, currentTask.value);
  }

  void updateConfidence(double value) {
    confidenceThreshold.value = value;
    yoloViewController.setConfidenceThreshold(value);
    update(); // untuk GetBuilder/Obx
  }

  void flipCamera() {
    yoloViewController.switchCamera();
  }

  void onResult(List<YOLOResult> results) {
    print('[YOLO DEBUG] YOLOView: Received ${results.length} detections');

    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      print(
        '[YOLO DEBUG] YOLOView: Detection $i - ${r.className} (${(r.confidence * 100).toStringAsFixed(1)}%)',
      );
    }

    print('[YOLO DEBUG] YOLOView: Parsing ${results.length} detections');

    if (results.isNotEmpty) {
      final first = results[0];
      print('[YOLO DEBUG] YOLOView: ClassIndex: ${first.classIndex}');
      print('[YOLO DEBUG] YOLOView: ClassName: ${first.className}');
      print('[YOLO DEBUG] YOLOView: Confidence: ${first.confidence}');
      print('[YOLO DEBUG] YOLOView: BoundingBox: ${first.boundingBox}');
      print('[YOLO DEBUG] YOLOView: NormalizedBox: ${first.normalizedBox}');
    }

    print(
      '[YOLO DEBUG] YOLOView: Successfully parsed ${results.length} results',
    );
    print('[YOLO DEBUG] YOLOView: Parsed results count: ${results.length}');
    print('Yolo Result: ${results.length} objek');
    print('[YOLO DEBUG] YOLOView: Called onResult callback with results');

    lastResults.assignAll(results);
  }

  void onPerformance(Map<String, dynamic> metrics) {
    print('Performance: FPS = ${metrics['fps']?.toStringAsFixed(1)}');
  }
}
