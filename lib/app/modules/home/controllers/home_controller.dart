import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:yolodetection/app/utils/indonesianLabels.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

enum DetectionMode { navigation, search }

class YoloController extends GetxController {
  final YOLOViewController yoloViewController = YOLOViewController();

  final RxDouble confidenceThreshold = 0.5.obs;
  final RxDouble iouThreshold = 0.45.obs;
  final RxDouble zoomLevel = 1.0.obs;
  final RxString currentModel = 'yolo11n'.obs;
  final Rx<YOLOTask> currentTask = YOLOTask.detect.obs;
  final RxList<YOLOResult> lastResults = <YOLOResult>[].obs;

  final RxString selectedClass = ''.obs;
  final Rx<DetectionMode> currentMode = DetectionMode.navigation.obs;

  // Rx Variables untuk lokasi
  final RxString currentAddress = 'Mencari lokasi...'.obs;
  final RxDouble latitude = 0.0.obs;
  final RxDouble longitude = 0.0.obs;

  // StreamSubscription untuk mendengarkan perubahan lokasi
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void onInit() {
    super.onInit();

    yoloViewController.setThresholds(
      confidenceThreshold: confidenceThreshold.value,
      iouThreshold: iouThreshold.value,
    );
    yoloViewController.setZoomLevel(zoomLevel.value);
    yoloViewController.switchModel(currentModel.value, currentTask.value);

    // Panggil method lokasi
    _startLocationUpdates();
  }

  @override
  void onClose() {
    _positionStreamSubscription?.cancel();
    super.onClose();
  }

  // Method untuk mendapatkan label Indonesia
  String getIndonesianLabel(String className) {
    final lowerClassName = className.toLowerCase();
    for (var entry in indonesianLabels.entries) {
      if (entry.key.toLowerCase() == lowerClassName) {
        return entry.value;
      }
    }
    return className;
  }

  void updateConfidence(double value) {
    confidenceThreshold.value = value;
    yoloViewController.setConfidenceThreshold(value);
    update();
  }

  void flipCamera() {
    yoloViewController.switchCamera();
  }

  // Mode pilih objek
  void setSelectedClass(String className) {
    selectedClass.value = className;
    currentMode.value = DetectionMode.search;
    print("Objek yang dipilih: $className");
  }

  void resetSelection() {
    selectedClass.value = '';
    currentMode.value = DetectionMode.navigation;
    print("Reset seleksi - Mode navigasi");
  }

  void setMode(DetectionMode mode) {
    currentMode.value = mode;
    if (mode == DetectionMode.navigation) {
      resetSelection();
    }
    print(
      "Mode diubah ke: ${mode == DetectionMode.navigation ? 'Navigasi' : 'Cari'}",
    );
  }

  void onResult(List<YOLOResult> results) {
    print('[YOLO DEBUG] YOLOView: Received ${results.length} detections');
    lastResults.value = results.where((r) {
      return r.confidence >= confidenceThreshold.value;
    }).toList();
  }

  void clearResult() {
    lastResults.clear();
  }

  void onPerformance(Map<String, dynamic> metrics) {
    print('Performance: FPS = ${metrics['fps']?.toStringAsFixed(1)}');
  }

  /// Memulai pembaruan lokasi secara real-time.
  Future<void> _startLocationUpdates() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      currentAddress.value = 'Layanan lokasi dinonaktifkan.';
      return Future.error('Layanan lokasi dinonaktifkan.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        currentAddress.value = 'Izin lokasi ditolak.';
        return Future.error('Izin lokasi ditolak');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      currentAddress.value = 'Izin lokasi ditolak secara permanen.';
      return Future.error(
        'Izin lokasi ditolak secara permanen, kami tidak dapat meminta izin.',
      );
    }

    // Jika izin diberikan, mulai perubahan lokasi
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter:
                10, // Hanya update jika posisi berubah minimal 10 meter
          ),
        ).listen(
          (Position position) {
            latitude.value = position.latitude;
            longitude.value = position.longitude;
            _getAddressFromLatLng(position.latitude, position.longitude);
            print(
              'Lokasi diperbarui: ${position.latitude}, ${position.longitude}',
            );
          },
          onError: (e) {
            currentAddress.value = 'Gagal mendapatkan lokasi: $e';
            print('Error getting location stream: $e');
          },
        );
  }

  // Function untuk mendapatkan alamat dari koordinat
  Future<void> _getAddressFromLatLng(double lat, double long) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        currentAddress.value =
            "${place.street ?? ''}, "
            "${place.subLocality ?? ''}, "
            "${place.locality ?? ''}, "
            "${place.administrativeArea ?? ''}, "
            "${place.country ?? ''}";
      } else {
        currentAddress.value =
            'Tidak dapat menemukan alamat untuk koordinat ini.';
      }
      print("Alamat ditemukan: ${currentAddress.value}");
    } catch (e) {
      currentAddress.value = 'Tidak dapat menemukan alamat: $e';
      print('Error geocoding: $e');
    }
  }
}
