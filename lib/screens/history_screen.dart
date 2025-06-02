import 'package:flutter/material.dart';
import 'package:quanlythuoc_new/database/database_helper.dart';
import 'package:quanlythuoc_new/models/medicine_history.dart';
import 'package:intl/intl.dart'; // Required for date/time formatting
import 'package:quanlythuoc_new/models/medicine.dart'; // Import Medicine model

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  List<MedicineHistory> _historyList = [];
  // Map to store medicine names by ID for easy lookup
  Map<String, Medicine> _medicinesMap = {};
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistoryData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadHistoryData();
    }
  }

  Future<void> _loadHistoryData() async {
    _historyList = await _dbHelper.getMedicineHistory();
    // Fetch all medicines to get their names
    final allMedicines = await _dbHelper.getMedicines();
    _medicinesMap = {for (var medicine in allMedicines) medicine.id: medicine};

    setState(() {}); // Update UI after loading history and medicines
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử dùng thuốc'),
        centerTitle: true,
        elevation: 0,
      ),
      body:
          _historyList.isEmpty
              ? Center(child: Text('Chưa có lịch sử dùng thuốc nào.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _historyList.length,
                itemBuilder: (context, index) {
                  final history = _historyList[index];
                  // Get the medicine name using the medicineId from the history record
                  final medicine = _medicinesMap[history.medicineId];
                  final medicineName =
                      medicine?.name ??
                      'Unknown Medicine'; // Use name if found, otherwise 'Unknown Medicine'

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4.0,
                    ), // Adjusted margin
                    elevation: 1.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ListTile(
                      title: Text(medicineName), // Display actual medicine name
                      subtitle: Text(
                        'Thời gian uống: ${DateFormat('dd/MM/yyyy HH:mm').format(history.takenAt)}\nTrạng thái: ${history.status == 'taken' ? 'Đã uống' : history.status}',
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
