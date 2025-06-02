// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
// Although not needed for edit, good practice if we add more fields later
import 'package:quanlythuoc_new/models/medicine.dart';
import 'package:quanlythuoc_new/database/database_helper.dart';
import 'package:intl/intl.dart'; // Required for time formatting

class EditMedicineScreen extends StatefulWidget {
  final String medicineId;

  const EditMedicineScreen({super.key, required this.medicineId});

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _selectedMedicineType = 'Kháng sinh';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  List<String> _specificIntakeTimes = [];

  final List<String> _medicineTypes = [
    'Kháng sinh',
    'Vitamin',
    'Kê đơn',
    'Không kê đơn',
    'Khác',
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadMedicineData();
  }

  Future<void> _loadMedicineData() async {
    final medicine = await _dbHelper.getMedicineById(widget.medicineId);
    if (medicine != null) {
      setState(() {
        _medicineNameController.text = medicine.name;
        _dosageController.text = medicine.dosage;
        // Find the exact medicine type or default to the first one
        _selectedMedicineType = _medicineTypes.firstWhere(
          (type) => type == medicine.dosage,
          orElse: () => _medicineTypes.first,
        );
        _startDate = medicine.startDate;
        _endDate = medicine.endDate;
        _instructionsController.text = medicine.notes ?? '';
        _specificIntakeTimes =
            medicine.specificIntakeTimes; // Load specific times
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(
        Duration(days: 365),
      ), // Allow selecting past dates within a year
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
        DateTime.now()
            .year, // Use current year, month, day as TimeOfDay has no date
        DateTime.now().month,
        DateTime.now().day,
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

      // Create an updated Medicine object
      final updatedMedicine = Medicine(
        id: widget.medicineId, // Use the existing ID
        name: _medicineNameController.text,
        dosage: _dosageController.text,
        // timesPerDay can be recalculated or kept, depending on how it's used
        timesPerDay:
            _specificIntakeTimes.length, // Update based on specific times
        startDate: _startDate,
        endDate: _endDate,
        notes:
            _instructionsController.text.isEmpty
                ? null
                : _instructionsController.text,
        createdAt:
            DateTime.now(), // Keep the original creation date? Or update?
        specificIntakeTimes:
            _specificIntakeTimes, // Save updated specific times
      );

      // Update medicine in database
      await _dbHelper.updateMedicine(updatedMedicine);

      print('Medicine updated: ${updatedMedicine.name}');

      // Navigate back after saving
      Navigator.pop(context); // Pop EditMedicineScreen
      // Optionally pop MedicineDetailScreen as well if editing from there
      // Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Chỉnh sửa thuốc')),
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

              // Medicine Type Dropdown (Keep for UI consistency, but not used in Medicine model currently)
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
