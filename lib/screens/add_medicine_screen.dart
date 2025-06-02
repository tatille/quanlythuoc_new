// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:quanlythuoc_new/models/medicine.dart';
import 'package:quanlythuoc_new/database/database_helper.dart';
import 'package:intl/intl.dart'; // Required for time formatting

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _selectedMedicineType = 'Kháng sinh';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  // We will now use a list of specific times instead of timesPerDay directly in UI input
  final List<String> _specificIntakeTimes = [];

  final List<String> _medicineTypes = [
    'Kháng sinh',
    'Vitamin',
    'Kê đơn',
    'Không kê đơn',
    'Khác',
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != (isStartDate ? _startDate : _endDate)) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is not before start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _endDate = picked;
          // Ensure start date is not after end date
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate.subtract(const Duration(days: 7));
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      // Convert TimeOfDay to DateTime for easier handling (date part is ignored later)
      final DateTime selectedDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        picked.hour,
        picked.minute,
      );
      final String formattedTime = DateFormat('HH:mm').format(selectedDateTime);

      setState(() {
        if (!_specificIntakeTimes.contains(formattedTime)) {
          _specificIntakeTimes.add(formattedTime);
          _specificIntakeTimes.sort(); // Keep times sorted
        }
      });
    }
  }

  void _removeTime(String time) {
    setState(() {
      _specificIntakeTimes.remove(time);
    });
  }

  void _saveMedicine() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Create a new Medicine object
      final newMedicine = Medicine(
        id: const Uuid().v4(),
        name: _medicineNameController.text,
        dosage: _dosageController.text,
        // timesPerDay will be derived from specificIntakeTimes later or kept for display
        timesPerDay:
            _specificIntakeTimes
                .length, // Simple: number of times = number of specified hours
        startDate: _startDate,
        endDate: _endDate,
        notes:
            _instructionsController.text.isEmpty
                ? null
                : _instructionsController.text,
        createdAt: DateTime.now(),
        specificIntakeTimes: _specificIntakeTimes, // Save the specific times
      );

      // Insert medicine into database
      await _dbHelper.insertMedicine(newMedicine);

      print('Medicine saved: ${newMedicine.name}');

      // Navigate back after saving
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm thuốc mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Placeholder (kept for UI consistency)
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[300], // Placeholder color
                  child: Icon(
                    Icons.camera_alt,
                    size: 50,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // Medicine Name Field
              TextFormField(
                controller: _medicineNameController,
                decoration: InputDecoration(
                  labelText: 'Tên thuốc',
                  prefixIcon: Icon(Icons.medical_information_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter medicine name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // Medicine Type Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Loại thuốc',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                value: _selectedMedicineType,
                items:
                    _medicineTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMedicineType = value!;
                  });
                },
              ),
              const SizedBox(height: 16.0),

              // Dosage Field
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  labelText: 'Liều lượng',
                  prefixIcon: Icon(Icons.assignment_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter dosage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // Date Range Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Ngày bắt đầu',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_startDate),
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.0),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Ngày kết thúc',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_endDate),
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // Specific Intake Times
              Text(
                'Lịch uống thuốc trong ngày:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8.0),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _specificIntakeTimes.length,
                itemBuilder: (context, index) {
                  final time = _specificIntakeTimes[index];
                  return ListTile(
                    title: Text(time),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _removeTime(time),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8.0),
              ElevatedButton.icon(
                onPressed: () => _selectTime(context),
                icon: Icon(Icons.add_alarm_outlined),
                label: Text('Thêm giờ uống'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
              ),
              const SizedBox(height: 16.0),

              // Instructions Field
              TextFormField(
                controller: _instructionsController,
                decoration: InputDecoration(
                  labelText: 'Hướng dẫn sử dụng',
                  prefixIcon: Icon(Icons.info_outline),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24.0),

              // Save Button
              ElevatedButton(
                onPressed: _saveMedicine,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: const Text('Lưu thuốc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
