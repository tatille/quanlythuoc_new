// ignore_for_file: depend_on_referenced_packages, avoid_print, unused_import, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:quanlythuoc_new/models/medicine.dart';
import 'package:quanlythuoc_new/database/database_helper.dart';
import 'package:intl/intl.dart'; // Required for time formatting
import 'package:quanlythuoc_new/models/medicine_history.dart'; // Import MedicineHistory model
import 'package:uuid/uuid.dart'; // Required for generating history ID
import 'package:collection/collection.dart'; // Required for firstWhereOrNull
import 'dart:math';
import 'package:quanlythuoc_new/screens/database_viewer_screen.dart';
// Required for max function

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Assuming _selectedIndex is managed by the parent (MainScreen) now
  // int _selectedIndex = 0;

  // void _onItemTapped(int index) {
  //   setState(() {
  //     _selectedIndex = index;
  //   });
  //
  // }

  List<Medicine> _allMedicines = [];
  List<Map<String, dynamic>> _todaysIntakes = [];
  Map<String, dynamic>? _nextIntake;
  List<MedicineHistory> _todaysHistory = []; // Store history for today
  List<MedicineHistory> _recentHistory =
      []; // Store history for recent days (e.g., 7 days)

  // Statistics variables
  int _totalMedicines = 0;
  int _todaysScheduledIntakes = 0;
  int _todaysTakenIntakes = 0;

  // Data for chart (daily adherence over recent days)
  Map<DateTime, int> _dailyTaken = {};
  Map<DateTime, int> _dailyScheduled = {};

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMedicineData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('App lifecycle state changed to: $state');
    if (state == AppLifecycleState.resumed) {
      print('App resumed, reloading data...');
      _loadMedicineData();
    }
  }

  Future<void> _loadMedicineData() async {
    try {
      print('Loading medicine data...');
      _allMedicines = await _dbHelper.getMedicines();
      _totalMedicines = _allMedicines.length;
      print('Loaded ${_allMedicines.length} medicines');

      // Load history for today and recent days
      final now = DateTime.now();
      _todaysHistory = await _dbHelper.getMedicineHistoryForDate(now);
      print('Loaded ${_todaysHistory.length} history records for today');

      _recentHistory = await _dbHelper.getMedicineHistoryForLastDays(7);
      print('Loaded ${_recentHistory.length} history records for last 7 days');

      _scheduleTodaysIntakes();
      _findNextIntake();
      _calculateDailyAdherence();

      // Calculate today's taken intakes based on loaded history
      _todaysTakenIntakes = _todaysHistory.length;
      _todaysScheduledIntakes = _todaysIntakes.length;
      print(
        'Today\'s intakes - Taken: $_todaysTakenIntakes, Scheduled: $_todaysScheduledIntakes',
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading medicine data: $e');
    }
  }

  void _scheduleTodaysIntakes() {
    _todaysIntakes = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Simple scheduling logic (needs refinement)
    for (var medicine in _allMedicines) {
      // Check if medicine is active today
      // Normalize start and end dates to compare just the date part
      final medicineStartDate = DateTime(
        medicine.startDate.year,
        medicine.startDate.month,
        medicine.startDate.day,
      );
      final medicineEndDate = DateTime(
        medicine.endDate.year,
        medicine.endDate.month,
        medicine.endDate.day,
      );

      if (!medicineStartDate.isAfter(today) &&
          !medicineEndDate.isBefore(today)) {
        // Generate placeholder times based on timesPerDay or specificIntakeTimes
        List<String> timesToSchedule =
            medicine.specificIntakeTimes.isNotEmpty
                ? medicine.specificIntakeTimes
                : List.generate(medicine.timesPerDay, (i) {
                  // Simple logic: distribute times throughout the day if specific times not provided
                  if (medicine.timesPerDay == 1) return '12:00';
                  int hour =
                      8 +
                      (16 ~/
                              (medicine.timesPerDay > 1
                                  ? medicine.timesPerDay - 1
                                  : 1)) *
                          i;
                  // Ensure hour is within 24 hour format
                  if (hour >= 24) hour = 23;
                  return '${hour.toString().padLeft(2, '0')}:00';
                });

        for (String timeStr in timesToSchedule) {
          final parts = timeStr.split(':');
          if (parts.length == 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            // Create DateTime for the intake time today
            final DateTime scheduledIntakeTimeToday = DateTime(
              today.year,
              today.month,
              today.day,
              hour,
              minute,
            );

            // We schedule ALL intakes for today for statistics, but the 'Next Medicine' section filters future ones.

            // Check if this specific intake has already been recorded as taken today from _todaysHistory
            bool isTaken = _todaysHistory.any(
              (history) =>
                  history.medicineId == medicine.id &&
                  // Compare history takenAt date and time with the scheduled intake time today
                  history.takenAt.year == scheduledIntakeTimeToday.year &&
                  history.takenAt.month == scheduledIntakeTimeToday.month &&
                  history.takenAt.day == scheduledIntakeTimeToday.day &&
                  history.takenAt.hour == scheduledIntakeTimeToday.hour &&
                  history.takenAt.minute == scheduledIntakeTimeToday.minute,
            );

            _todaysIntakes.add({
              'medicine': medicine,
              'time': scheduledIntakeTimeToday,
              'isTaken': isTaken,
            });
            //}
          }
        }
      }
    }

    // Sort intakes by time
    _todaysIntakes.sort((a, b) => a['time'].compareTo(b['time']));

    // After scheduling, recalculate scheduled intakes for today
    _todaysScheduledIntakes = _todaysIntakes.length;
  }

  void _findNextIntake() {
    final now = DateTime.now();
    _nextIntake = null;

    // Find the first intake time that is after or at the current moment and not yet taken
    for (var intake in _todaysIntakes) {
      if ((intake['time'].isAfter(now) ||
              intake['time'].isAtSameMomentAs(now)) &&
          !intake['isTaken']) {
        _nextIntake = intake;
        break; // Found the next one, exit loop
      }
    }

    // If no future intakes today, maybe find the earliest one from the entire schedule for tomorrow?
    // For now, _nextIntake remains null if no future intakes today.
  }

  void _toggleIntakeStatus(int index, bool? value) async {
    if (value == null) return;

    try {
      print('Toggling intake status for index $index to $value');

      final intake = _todaysIntakes[index];
      final medicine = intake['medicine'];
      final intakeTime = intake['time'];

      print(
        'Medicine: ${medicine.name}, Time: ${DateFormat('HH:mm').format(intakeTime)}',
      );

      if (value) {
        // Marked as taken
        final historyEntry = MedicineHistory(
          id: const Uuid().v4(),
          medicineId: medicine.id,
          takenAt: intakeTime,
          status: 'taken',
          notes: null,
          createdAt: DateTime.now(),
        );

        print('Inserting history entry: ${historyEntry.id}');
        await _dbHelper.insertMedicineHistory(historyEntry);

        // Update local state after successful DB insert
        setState(() {
          _todaysIntakes[index]['isTaken'] = true;
          if (_nextIntake != null && _nextIntake == _todaysIntakes[index]) {
            _nextIntake!['isTaken'] = true;
          }
          _todaysTakenIntakes++;
        });

        print('Successfully marked as taken');
      } else {
        // Marked as untaken
        final historyToRemove = _todaysHistory.firstWhereOrNull(
          (history) =>
              history.medicineId == medicine.id &&
              history.takenAt.year == intakeTime.year &&
              history.takenAt.month == intakeTime.month &&
              history.takenAt.day == intakeTime.day &&
              history.takenAt.hour == intakeTime.hour &&
              history.takenAt.minute == intakeTime.minute,
        );

        if (historyToRemove != null) {
          print('Removing history entry: ${historyToRemove.id}');
          await _dbHelper.deleteMedicineHistory(historyToRemove.id);

          // Update local state after successful DB delete
          setState(() {
            _todaysIntakes[index]['isTaken'] = false;
            if (_nextIntake != null && _nextIntake == _todaysIntakes[index]) {
              _nextIntake!['isTaken'] = false;
            }
            _todaysTakenIntakes--;
          });

          print('Successfully marked as untaken');
        } else {
          print('No history entry found to remove');
        }
      }

      // Reload data to ensure consistency
      await _loadMedicineData();
    } catch (e) {
      print('Error toggling intake status: $e');
    }
  }

  void _calculateDailyAdherence() {
    _dailyTaken = {};
    _dailyScheduled = {};
    final today = DateTime.now();

    // Initialize maps for the last 7 days with 0
    for (int i = 0; i < 7; i++) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      _dailyTaken[date] = 0;
      _dailyScheduled[date] = 0;
    }

    // Populate daily taken counts from recent history
    for (var history in _recentHistory) {
      final date = DateTime(
        history.takenAt.year,
        history.takenAt.month,
        history.takenAt.day,
      );
      // Only count if the date is within the last 7 days (including today)
      if (_dailyTaken.containsKey(date)) {
        _dailyTaken[date] = (_dailyTaken[date] ?? 0) + 1;
      }
    }

    // Calculate daily scheduled counts (Simplified logic - needs improvement for accurate scheduling over days)
    // This is a placeholder; accurate daily scheduled counts require iterating through medicine schedules for each day.
    for (int i = 0; i < 7; i++) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      int scheduledCount = 0;
      for (var medicine in _allMedicines) {
        // Simple logic: if medicine is active on this date, add its timesPerDay
        // This is NOT accurate for specific intake times and date ranges.
        if (!medicine.startDate.isAfter(date) &&
            !medicine.endDate.isBefore(date)) {
          scheduledCount +=
              medicine.timesPerDay; // Using timesPerDay as a simple proxy
        }
      }
      _dailyScheduled[date] = scheduledCount;
    }

    // Ensure keys are sorted for chart display
    _dailyTaken = Map.fromEntries(
      _dailyTaken.entries.toList()..sort((e1, e2) => e1.key.compareTo(e2.key)),
    );
    _dailyScheduled = Map.fromEntries(
      _dailyScheduled.entries.toList()
        ..sort((e1, e2) => e1.key.compareTo(e2.key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Quản lý thuốc',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DatabaseViewerScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hãy uống thuốc đúng giờ nhé!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Next Medicine Card
                if (_nextIntake != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Thuốc tiếp theo',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _nextIntake!['medicine'].name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Thời gian: ${DateFormat('HH:mm').format(_nextIntake!['time'])}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Liều lượng: ${_nextIntake!['medicine'].dosage}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                            ElevatedButton(
                              onPressed:
                                  () => _toggleIntakeStatus(
                                    _todaysIntakes.indexOf(_nextIntake!),
                                    true,
                                  ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Theme.of(context).primaryColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Đã uống'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Tổng số thuốc',
                        _totalMedicines.toString(),
                        Icons.medication_outlined,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Đã uống hôm nay',
                        '$_todaysTakenIntakes/$_todaysScheduledIntakes',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Today's Schedule
                Text(
                  'Lịch uống hôm nay',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                ..._todaysIntakes.map((intake) => _buildIntakeCard(intake)),
                const SizedBox(height: 24),

                // Adherence Chart
                Container(
                  padding: const EdgeInsets.all(20),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Thống kê tuần qua',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tỷ lệ tuân thủ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: BarChart(_createBarChartData()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildIntakeCard(Map<String, dynamic> intake) {
    final medicine = intake['medicine'];
    final time = intake['time'];
    final isTaken = intake['isTaken'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  isTaken
                      ? Colors.green.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isTaken ? Icons.check_circle : Icons.medication_outlined,
              color: isTaken ? Colors.green : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('HH:mm').format(time)} • ${medicine.dosage}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: isTaken,
            onChanged:
                (value) =>
                    _toggleIntakeStatus(_todaysIntakes.indexOf(intake), value),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  BarChartData _createBarChartData() {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: 1.0,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          tooltipBgColor: Colors.blueGrey,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final date = DateTime.now().subtract(
              Duration(days: 6 - groupIndex),
            );
            final taken = _dailyTaken[date] ?? 0;
            final scheduled = _dailyScheduled[date] ?? 1;
            final percentage = ((taken / scheduled) * 100).toStringAsFixed(0);
            return BarTooltipItem(
              '${DateFormat('E').format(date)}\n$percentage%',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < 7) {
                final date = DateTime.now().subtract(
                  Duration(days: 6 - value.toInt()),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('E').format(date),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                );
              }
              return const Text('');
            },
            reservedSize: 30,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const Text('');
              return Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              );
            },
            reservedSize: 40,
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 0.2,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1);
        },
      ),
      barGroups: _createBarGroups(),
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      final taken = _dailyTaken[date] ?? 0;
      final scheduled = _dailyScheduled[date] ?? 1;
      final adherence = taken / scheduled;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: adherence,
              color: Theme.of(context).primaryColor,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }
    return barGroups;
  }
}
