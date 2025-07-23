import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:yolodetection/app/modules/home/views/home_view.dart';
import 'package:yolodetection/app/utils/indonesianLabels.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

enum DetectionMode { navigation, search }

class YoloController extends GetxController {
  final YOLOViewController yoloViewController = YOLOViewController();
  final FlutterTts flutterTts = FlutterTts();
  final RxDouble confidenceThreshold = 0.5.obs;
  final RxDouble iouThreshold = 0.45.obs;
  final RxDouble zoomLevel = 1.0.obs;
  final RxString currentModel = 'yolo11n'.obs;
  final Rx<YOLOTask> currentTask = YOLOTask.detect.obs;
  final RxList<YOLOResult> lastResults = <YOLOResult>[].obs;
  final RxBool _isSpeaking = false.obs;
  final RxString selectedClass = ''.obs;
  final Rx<DetectionMode> currentMode = DetectionMode.navigation.obs;
  final Map<String, String> _lastSpokenPositions = {};

  // Rx Variables untuk lokasi
  final RxString currentAddress = 'Mencari lokasi...'.obs;
  final RxDouble latitude = 0.0.obs;
  final RxDouble longitude = 0.0.obs;

  // Variabel kontrol alur
  final RxBool _initialSetupCompleted = false.obs;
  Completer<void>? _speechCompleter;

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _detectionTimer;

  Timer? _noObjectFoundTimer;
  @override
  void onInit() {
    super.onInit();
    _initializeTTS();

    // Konfigurasi YOLO
    yoloViewController.setThresholds(
      confidenceThreshold: confidenceThreshold.value,
      iouThreshold: iouThreshold.value,
    );
    yoloViewController.setZoomLevel(zoomLevel.value);
    yoloViewController.switchModel(currentModel.value, currentTask.value);

    // Memulai pembaruan lokasi, deteksi akan dimulai setelah lokasi pertama didapat
    _startLocationUpdates();
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    if (_isSpeaking.value) {
      await flutterTts.stop();
      _speechCompleter?.complete();
      _isSpeaking.value = false;
    }

    _speechCompleter = Completer<void>();
    _isSpeaking.value = true;
    await flutterTts.speak(text);
    Future.delayed(const Duration(seconds: 10), () {
      if (!_speechCompleter!.isCompleted) {
        _isSpeaking.value = false;
        _speechCompleter!.complete();
      }
    });
    return _speechCompleter!.future;
  }

  void _initializeTTS() async {
    await flutterTts.setLanguage("id-ID");
    await flutterTts.setSpeechRate(0.35);
    await flutterTts.setPitch(1.0);

    flutterTts.setCompletionHandler(() {
      _isSpeaking.value = false;
      _speechCompleter?.complete();
    });
  }

  // Fungsi untuk melakukan pengumuman berurutan di awal
  Future<void> _performInitialAnnouncements() async {
    // 1. Umumkan lokasi
    await speak("Sekarang Anda ada di ${currentAddress.value}");

    // 2. Umumkan masuk ke mode navigasi
    await speak("Anda masuk ke mode navigasi.");

    // 3. Mulai timer deteksi setelah semua pengumuman selesai
    startDetectionInterval();
  }

  void startDetectionInterval() {
    if (_detectionTimer?.isActive ?? false) return;

    _detectionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      detectAndAnnounce();
    });
  }

  void stopDetectionInterval() {
    _detectionTimer?.cancel();
  }

  Future<void> detectAndAnnounce() async {
    if (_isSpeaking.value) return;

    List<YOLOResult> resultsToAnnounce = [];

    if (currentMode.value == DetectionMode.search && selectedClass.isNotEmpty) {
      if (lastResults.isEmpty) {
        _startNoObjectFoundTimer();
        return;
      }

      resultsToAnnounce = lastResults
          .where((r) => r.className == selectedClass.value)
          .toList();

      if (resultsToAnnounce.isEmpty) {
        _startNoObjectFoundTimer();
        return;
      } else {
        _cancelNoObjectFoundTimer(); // objek ditemukan, cancel timer
      }
    } else if (currentMode.value == DetectionMode.navigation) {
      if (lastResults.isEmpty) return;

      resultsToAnnounce = List<YOLOResult>.from(lastResults);
    }

    if (resultsToAnnounce.isEmpty) return;

    resultsToAnnounce.sort((a, b) => b.confidence.compareTo(a.confidence));
    final topResult = resultsToAnnounce.first;

    final label = getIndonesianLabel(topResult.className);
    final xCenter =
        topResult.normalizedBox.left + topResult.normalizedBox.width / 2;
    final yCenter =
        topResult.normalizedBox.top + topResult.normalizedBox.height / 2;
    final rawPosition = PositionHelper.getCombinedPosition(xCenter, yCenter);
    final formattedPosition = _formatSpeechPosition(rawPosition);

    final lastPosition = _lastSpokenPositions[topResult.className];
    if (lastPosition == formattedPosition) return;

    _lastSpokenPositions[topResult.className] = formattedPosition;

    final text = "Ada $label di bagian $formattedPosition Anda.";
    await speak(text);
  }

  void setMode(DetectionMode mode) async {
    if (currentMode.value == mode && mode == DetectionMode.navigation) return;

    currentMode.value = mode;
    _lastSpokenPositions.clear();

    if (mode == DetectionMode.navigation) {
      resetSelection();
      _cancelNoObjectFoundTimer(); // <-- Tambahan ini
      await speak("Anda masuk ke mode navigasi.");
    }

    startDetectionInterval();

    print(
      "Mode diubah ke: ${mode == DetectionMode.navigation ? 'Navigasi' : 'Cari'}",
    );
  }

  void setSelectedClass(String className) async {
    selectedClass.value = className;
    currentMode.value = DetectionMode.search;

    final indonesianLabel = getIndonesianLabel(className);
    await speak("Anda masuk ke mode cari, Anda mencari $indonesianLabel.");

    startDetectionInterval();
  }

  Future<void> _getAddressFromLatLng(double lat, double long) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        currentAddress.value =
            "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}";
      } else {
        currentAddress.value = 'Tidak dapat menemukan nama lokasi.';
      }

      if (!_initialSetupCompleted.value &&
          !currentAddress.value.startsWith('Mencari')) {
        _initialSetupCompleted.value = true;
        _performInitialAnnouncements();
      }
    } catch (e) {
      currentAddress.value = 'Gagal mendapatkan nama lokasi.';
      print('Error geocoding: $e');
    }
  }

  void _startNoObjectFoundTimer() {
    if (_noObjectFoundTimer?.isActive ?? false) return;

    _noObjectFoundTimer = Timer(const Duration(seconds: 5), () async {
      final label = getIndonesianLabel(selectedClass.value);
      await speak("Tidak ada $label di sekitar Anda.");
    });
  }

  void _cancelNoObjectFoundTimer() {
    _noObjectFoundTimer?.cancel();
  }

  @override
  void onClose() {
    stopDetectionInterval();
    flutterTts.stop();
    _isSpeaking.value = false;
    _lastSpokenPositions.clear();
    _positionStreamSubscription?.cancel();
    _noObjectFoundTimer?.cancel();

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

  void resetSelection() {
    selectedClass.value = '';
    print("Reset seleksi - Kembali ke mode navigasi");
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
            distanceFilter: 10,
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

  String _formatSpeechPosition(String position) {
    if (position == 'TENGAH-TENGAH') return 'tengah';
    final parts = position.split('-');
    if (parts.length == 2) {
      if (parts[0] == 'TENGAH') return parts[1].toLowerCase();
      if (parts[1] == 'TENGAH') return parts[0].toLowerCase();
      return "${parts[0].toLowerCase()} dan ${parts[1].toLowerCase()}";
    }
    return position.toLowerCase();
  }
}
