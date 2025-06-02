import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:quanlythuoc_new/models/medicine.dart';
import 'package:quanlythuoc_new/database/database_helper.dart';
import 'package:quanlythuoc_new/screens/medicine_detail_screen.dart';
import 'package:quanlythuoc_new/screens/edit_medicine_screen.dart';
import 'package:quanlythuoc_new/screens/add_medicine_screen.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Medicine> _medicines = [];
  List<Medicine> _filteredMedicines = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  void _loadMedicines() async {
    final medicines = await _dbHelper.getMedicines();
    setState(() {
      _medicines = medicines;
      _filteredMedicines = medicines;
    });
  }

  void _filterMedicines(String query) {
    setState(() {
      _filteredMedicines =
          _medicines
              .where(
                (medicine) =>
                    medicine.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách thuốc'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm thuốc...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterMedicines,
            ),
          ),
          Expanded(
            child:
                _filteredMedicines.isEmpty
                    ? Center(
                      child: Text(
                        'Chưa có thuốc nào được thêm.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredMedicines.length,
                      itemBuilder: (context, index) {
                        final medicine = _filteredMedicines[index];
                        return Slidable(
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  // Implement edit functionality
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => EditMedicineScreen(
                                            medicineId:
                                                medicine
                                                    .id, // Pass the medicine ID
                                          ),
                                    ),
                                  ).then(
                                    (_) => _loadMedicines(),
                                  ); // Refresh list after editing
                                },
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                icon: Icons.edit,
                                label: 'Sửa',
                              ),
                              SlidableAction(
                                onPressed: (context) async {
                                  // Implement delete functionality
                                  await _dbHelper.deleteMedicine(
                                    medicine.id,
                                  ); // Use the delete method
                                  _loadMedicines(); // Refresh the list
                                },
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: 'Xóa',
                              ),
                            ],
                          ),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(medicine.name),
                              subtitle: Text(
                                'Liều lượng: ${medicine.dosage}\n'
                                'Số lần/ngày: ${medicine.timesPerDay}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // Navigate to medicine details
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => MedicineDetailScreen(
                                          medicineId:
                                              medicine
                                                  .id, // Pass the medicine ID
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to Add Medicine Screen
        },
        heroTag: 'addMedicineList',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
