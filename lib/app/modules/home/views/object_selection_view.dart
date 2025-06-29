import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yolodetection/app/modules/home/controllers/home_controller.dart';
import 'package:yolodetection/app/utils/indonesianLabels.dart';

class ObjectSelectionPage extends StatelessWidget {
  ObjectSelectionPage({Key? key}) : super(key: key);
  final YoloController controller = Get.put(YoloController());

  final RxString searchQuery = ''.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Objek'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            
            controller.setMode(DetectionMode.search);
            Get.back();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Kolom pencarian aktif
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                onChanged: (value) => searchQuery.value = value.toLowerCase(),
                decoration: const InputDecoration(
                  hintText: 'Cari objek...',
                  hintStyle: TextStyle(color: Colors.white),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.white),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),

            // Daftar tombol hasil pencarian
            Expanded(
              child: Obx(() {
                final filtered = indonesianLabels.entries
                    .where((entry) =>
                        entry.value.toLowerCase().contains(searchQuery.value))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("Tidak ada hasil ditemukan"));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final isSelected =
                        controller.selectedClass.value == entry.key;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      // Hapus widget Center di sini
                      child: ElevatedButton( // <--- Langsung ElevatedButton
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.blue[400]
                              : Colors.grey[300],
                          foregroundColor: isSelected
                              ? Colors.white
                              : Colors.black,
                          minimumSize: const Size(double.infinity, 60), // <--- Ubah ini
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          controller.lastResults.clear();
                          controller.setSelectedClass(entry.key);
                          Get.back();
                        },
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}