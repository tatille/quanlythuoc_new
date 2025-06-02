// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:quanlythuoc_new/database/database_helper.dart';
import 'package:quanlythuoc_new/models/medicine.dart';
import 'package:quanlythuoc_new/models/medicine_history.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Medicine> _medicines = [];
  List<MedicineHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _medicines = await _dbHelper.getMedicines();
      _history = await _dbHelper.getMedicineHistory();
    } catch (e) {
      print('Error loading data: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem dữ liệu'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Danh sách thuốc'),
            Tab(text: 'Lịch sử uống'),
            Tab(text: 'Thống kê thuốc'),
            Tab(text: 'Biểu đồ'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildMedicineList(),
                  _buildHistoryList(),
                  _buildMedicineStats(),
                  _buildCharts(),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildMedicineList() {
    return ListView.builder(
      itemCount: _medicines.length,
      itemBuilder: (context, index) {
        final medicine = _medicines[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(
              medicine.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Liều lượng: ${medicine.dosage}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('ID', medicine.id),
                    _buildInfoRow(
                      'Số lần uống/ngày',
                      medicine.timesPerDay.toString(),
                    ),
                    _buildInfoRow(
                      'Ngày bắt đầu',
                      DateFormat('dd/MM/yyyy').format(medicine.startDate),
                    ),
                    _buildInfoRow(
                      'Ngày kết thúc',
                      DateFormat('dd/MM/yyyy').format(medicine.endDate),
                    ),
                    if (medicine.specificIntakeTimes.isNotEmpty)
                      _buildInfoRow(
                        'Thời gian uống',
                        medicine.specificIntakeTimes.join(', '),
                      ),
                    if (medicine.notes != null && medicine.notes!.isNotEmpty)
                      _buildInfoRow('Ghi chú', medicine.notes!),
                    _buildInfoRow(
                      'Ngày tạo',
                      DateFormat('dd/MM/yyyy HH:mm').format(medicine.createdAt),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final record = _history[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  record.status == 'taken' ? Colors.green : Colors.orange,
              child: Icon(
                record.status == 'taken' ? Icons.check : Icons.schedule,
                color: Colors.white,
              ),
            ),
            title: FutureBuilder<Medicine?>(
              future: _dbHelper.getMedicineById(record.medicineId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Text(snapshot.data!.name);
                }
                return const Text('Không tìm thấy thuốc');
              },
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(record.takenAt)}',
                ),
                if (record.notes != null && record.notes!.isNotEmpty)
                  Text('Ghi chú: ${record.notes}'),
              ],
            ),
            isThreeLine: record.notes != null && record.notes!.isNotEmpty,
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(record),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(MedicineHistory record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text('Bạn có chắc chắn muốn xóa lịch sử này không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.deleteMedicineHistory(record.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa lịch sử thành công')),
        );
        _loadData(); // Tải lại dữ liệu sau khi xóa
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa lịch sử: $e')));
      }
    }
  }

  Widget _buildMedicineStats() {
    // Tính toán thống kê
    final totalMedicines = _medicines.length;
    final activeMedicines =
        _medicines.where((m) => m.endDate.isAfter(DateTime.now())).length;
    final expiredMedicines =
        _medicines.where((m) => m.endDate.isBefore(DateTime.now())).length;

    // Tính số lượng thuốc theo số lần uống/ngày
    final Map<int, int> timesPerDayStats = {};
    for (var medicine in _medicines) {
      timesPerDayStats[medicine.timesPerDay] =
          (timesPerDayStats[medicine.timesPerDay] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard('Tổng quan', [
            _buildStatItem('Tổng số thuốc', totalMedicines.toString()),
            _buildStatItem('Thuốc đang dùng', activeMedicines.toString()),
            _buildStatItem('Thuốc hết hạn', expiredMedicines.toString()),
          ]),
          const SizedBox(height: 20),
          if (timesPerDayStats.isNotEmpty)
            _buildStatCard(
              'Số lần uống/ngày',
              timesPerDayStats.entries
                  .map(
                    (e) =>
                        _buildStatItem('${e.key} lần/ngày', e.value.toString()),
                  )
                  .toList(),
            )
          else
            _buildStatCard('Số lần uống/ngày', [
              _buildStatItem('Chưa có dữ liệu', ''),
            ]),
          // Có thể thêm các thống kê khác ở đây
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCharts() {
    // Tính toán dữ liệu cho biểu đồ
    final totalHistory = _history.length;
    final takenCount = _history.where((h) => h.status == 'taken').length;
    final missedCount = totalHistory - takenCount;

    // Tính số lượng thuốc uống theo giờ trong ngày
    final Map<int, int> hourlyStats = {};
    for (var history in _history) {
      final hour = history.takenAt.hour;
      hourlyStats[hour] = (hourlyStats[hour] ?? 0) + 1;
    }

    final sortedHourlyStats =
        hourlyStats.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Biểu đồ tròn cho lịch sử uống thuốc
          if (totalHistory > 0) // Chỉ hiển thị biểu đồ nếu có dữ liệu lịch sử
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Tỷ lệ uống thuốc',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: takenCount.toDouble(),
                            title:
                                takenCount > 0
                                    ? '${((takenCount / totalHistory) * 100).toStringAsFixed(1)}%'
                                    : '',
                            color: Colors.green,
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: missedCount.toDouble(),
                            title:
                                missedCount > 0
                                    ? '${((missedCount / totalHistory) * 100).toStringAsFixed(1)}%'
                                    : '',
                            color: Colors.orange,
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Đã uống', Colors.green),
                      const SizedBox(width: 20),
                      _buildLegendItem('Chưa uống', Colors.orange),
                    ],
                  ),
                ],
              ),
            )
          else // Hiển thị thông báo nếu không có dữ liệu lịch sử
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50.0),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu lịch sử uống thuốc để hiển thị biểu đồ tròn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 20),
          // Biểu đồ cột cho thống kê theo giờ trong ngày
          if (sortedHourlyStats
              .isNotEmpty) // Chỉ hiển thị biểu đồ nếu có dữ liệu theo giờ
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Thống kê theo giờ trong ngày',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            sortedHourlyStats.isNotEmpty
                                ? sortedHourlyStats
                                    .map((e) => e.value)
                                    .fold(0, max)
                                    .toDouble()
                                : 1.0,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}h',
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                              interval: 2,
                              reservedSize: 20,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value == 0)
                                  return const Text(
                                    '0',
                                    style: TextStyle(fontSize: 10),
                                  );
                                // Hide the label for the max value on the left axis if it's not 0
                                if (value != 0 && value == meta.max)
                                  return const SizedBox.shrink();
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                              reservedSize: 28,
                              interval: 1,
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return const FlLine(
                              color: Colors.grey,
                              strokeWidth: 0.5,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups:
                            sortedHourlyStats.map((e) {
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: e.value.toDouble(),
                                    color: Theme.of(context).primaryColor,
                                    width: 15,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                      topRight: Radius.circular(6),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (totalHistory >
              0) // Hiển thị thông báo nếu có lịch sử nhưng không có dữ liệu theo giờ (trường hợp hiếm)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50.0),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu uống thuốc theo giờ để hiển thị biểu đồ cột.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else // Hiển thị thông báo nếu không có bất kỳ dữ liệu lịch sử nào
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50.0),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu lịch sử uống thuốc để hiển thị biểu đồ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, List<Widget> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
