import 'package:camera/camera.dart';
import 'package:eyesgym/services/storage_service.dart';
import 'package:eyesgym/views/game_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  final CameraDescription camera;

  const DashboardScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StorageService _storage = StorageService();
  DashboardData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _storage.getDashboardData();
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  void _navigateToGame() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(camera: widget.camera)),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Eye Wellness', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),
                    _buildStreakCard(),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(),
                    const SizedBox(height: 12),
                    _buildChartCard(),
                    const SizedBox(height: 32),
                    _buildPlayButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hello!", style: TextStyle(color: Colors.white54, fontSize: 16)),
        SizedBox(height: 4),
        Text("Your Eye Health", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        const Text("Weekly Activity", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Tooltip(
          message: "Tracks your blinks during exercise sessions.",
          triggerMode: TooltipTriggerMode.tap,
          child: Icon(Icons.info_outline, color: Colors.white.withOpacity(0.3), size: 18),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade800, Colors.orange.shade500]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${_data?.currentStreak ?? 0} Day Streak", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Consistency is key!", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          // REPLACED HIGH SCORE WITH SESSIONS
          child: _buildStatItem("Sessions", "${_data?.totalSessions ?? 0}", Icons.fitness_center, Colors.purpleAccent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatItem("Total Blinks", "${_data?.totalBlinks ?? 0}", Icons.visibility, Colors.blue),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final stats = _data?.weeklyBlinks ?? {};
    
    // --- EMPTY STATE ---
    if (stats.isEmpty) {
      return Container(
        height: 220,
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text("No Data Yet", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Complete an exercise to see your history.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    // --- CHART DATA PREP ---
    final now = DateTime.now();
    List<String> last7DaysKeys = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      last7DaysKeys.add(key);
    }

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < last7DaysKeys.length; i++) {
        final key = last7DaysKeys[i];
        final blinkCount = stats[key] ?? 0;
        
        barGroups.add(
            BarChartGroupData(
                x: i,
                barRods: [
                    BarChartRodData(
                        toY: blinkCount.toDouble(),
                        color: i == 6 ? Colors.blueAccent : (blinkCount > 0 ? Colors.blueAccent.withOpacity(0.5) : Colors.transparent),
                        width: 16,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 500, 
                            color: Colors.white.withOpacity(0.05),
                        ),
                    )
                ]
            )
        );
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), // Removed bottom padding to rely on chart margin
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 600,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
               tooltipBgColor: Colors.blueAccent,
               getTooltipItem: (group, groupIndex, rod, rodIndex) {
                 if (rod.toY == 0) return null;
                 return BarTooltipItem('${rod.toY.toInt()}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
               },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40, // FIX: Increased space for bottom labels
                getTitlesWidget: (value, meta) {
                    if (value.toInt() >= 0 && value.toInt() < last7DaysKeys.length) {
                        final date = DateTime.parse(last7DaysKeys[value.toInt()]);
                        final isToday = value.toInt() == 6;
                        return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                                DateFormat('E').format(date)[0], 
                                style: TextStyle(
                                  color: isToday ? Colors.blueAccent : Colors.white30, 
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                )
                            ),
                        );
                    }
                    return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _navigateToGame,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          shadowColor: Colors.green.withOpacity(0.4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            SizedBox(width: 8),
            Text("START EXERCISE", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}