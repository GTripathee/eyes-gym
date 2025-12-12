import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _keyHighScore = 'high_score'; // Keeping for legacy, but unused in UI
  static const String _keyTotalBlinks = 'total_blinks';
  static const String _keyTotalSessions = 'total_sessions'; // NEW KEY
  static const String _keyDailyStats = 'daily_stats'; 
  static const String _keyLastPlayedDate = 'last_played_date';
  static const String _keyCurrentStreak = 'current_streak';

  Future<void> saveGameSession(int score, int blinks) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Update High Score (Background only)
    final currentHigh = prefs.getInt(_keyHighScore) ?? 0;
    if (score > currentHigh) {
      await prefs.setInt(_keyHighScore, score);
    }
    
    // 2. Update Total Blinks
    final currentTotalBlinks = prefs.getInt(_keyTotalBlinks) ?? 0;
    await prefs.setInt(_keyTotalBlinks, currentTotalBlinks + blinks);

    // 3. Update Total Sessions (NEW)
    final currentSessions = prefs.getInt(_keyTotalSessions) ?? 0;
    await prefs.setInt(_keyTotalSessions, currentSessions + 1);
    
    // 4. Update Daily Stats (For Graph)
    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    String? statsString = prefs.getString(_keyDailyStats);
    Map<String, int> stats = {};
    if (statsString != null) {
      stats = Map<String, int>.from(jsonDecode(statsString));
    }
    
    stats[todayKey] = (stats[todayKey] ?? 0) + blinks;
    
    // Keep only last 7 days
    if (stats.length > 7) {
      final sortedKeys = stats.keys.toList()..sort();
      stats.remove(sortedKeys.first);
    }
    
    await prefs.setString(_keyDailyStats, jsonEncode(stats));
    
    // 5. Update Streak
    final lastDateString = prefs.getString(_keyLastPlayedDate);
    int currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
    
    if (lastDateString != todayKey) {
       if (lastDateString != null) {
           final lastDate = DateTime.parse(lastDateString);
           final difference = now.difference(lastDate).inDays;
           
           if (difference == 1) {
               currentStreak++;
           } else if (difference > 1) {
               currentStreak = 1;
           }
       } else {
           currentStreak = 1;
       }
       await prefs.setString(_keyLastPlayedDate, todayKey);
       await prefs.setInt(_keyCurrentStreak, currentStreak);
    }
  }

  Future<DashboardData> getDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final highScore = prefs.getInt(_keyHighScore) ?? 0;
    final totalBlinks = prefs.getInt(_keyTotalBlinks) ?? 0;
    final totalSessions = prefs.getInt(_keyTotalSessions) ?? 0; // NEW
    final streak = prefs.getInt(_keyCurrentStreak) ?? 0;
    
    String? statsString = prefs.getString(_keyDailyStats);
    Map<String, int> dailyStats = {};
    if (statsString != null) {
        dailyStats = Map<String, int>.from(jsonDecode(statsString));
    }
    
    return DashboardData(
      highScore: highScore,
      totalBlinks: totalBlinks,
      totalSessions: totalSessions, // NEW
      currentStreak: streak,
      weeklyBlinks: dailyStats,
    );
  }
}

class DashboardData {
  final int highScore;
  final int totalBlinks;
  final int totalSessions; // NEW
  final int currentStreak;
  final Map<String, int> weeklyBlinks;

  DashboardData({
    required this.highScore,
    required this.totalBlinks,
    required this.totalSessions,
    required this.currentStreak,
    required this.weeklyBlinks,
  });
}