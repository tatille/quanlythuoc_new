// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:quanlythuoc_new/models/medicine.dart';
import 'package:quanlythuoc_new/database/database_helper.dart';
import 'package:quanlythuoc_new/screens/edit_medicine_screen.dart';
import 'package:intl/intl.dart';

class MedicineDetailScreen extends StatefulWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  Medicine? _medicine;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadMedicineDetails();
  }

  Future<void> _loadMedicineDetails() async {
    final medicine = await _dbHelper.getMedicineById(widget.medicineId);
    setState(() {
      _medicine = medicine;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết thuốc'),
        actions: [
          if (_medicine != null) // Only show edit if medicine data is loaded
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                // Navigate to EditMedicineScreen
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => EditMedicineScreen(
                          medicineId: _medicine!.id,
                        ), // Pass the medicine object
                  ),
                );
                // Refresh details after editing
                _loadMedicineDetails();
              },
            ),
          // Add a delete option here (e.g., in an overflow menu)
          if (_medicine != null) // Only show delete if medicine data is loaded
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  // Implement delete functionality
                  await _dbHelper.deleteMedicine(
                    _medicine!.id,
                  ); // Use the delete method
                  Navigator.pop(
                    context,
                  ); // Go back to the previous screen (medicine list)
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Xóa'), // Changed label to Vietnamese
                  ),
                ];
              },
            ),
        ],
      ),
      body:
          _medicine == null
              ? const Center(
                child: CircularProgressIndicator(), // Show loading indicator
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tên thuốc: ${_medicine!.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Liều lượng: ${_medicine!.dosage}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Số lần/ngày: ${_medicine!.timesPerDay}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Ngày bắt đầu: ${_medicine!.startDate}', // TODO: Format date
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Ngày kết thúc: ${_medicine!.endDate}', // TODO: Format date
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8.0),
                    if (_medicine!.notes != null &&
                        _medicine!.notes!.isNotEmpty)
                      Text(
                        'Hướng dẫn sử dụng: ${_medicine!.notes}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    // Add more details here as needed
                  ],
                ),
              ),
    );
  }
}
