enum NoteType { short, long }

class BlinkNote {
  final Duration startTime;
  final Duration duration;
  final NoteType type;

  BlinkNote({
    required this.startTime,
    required this.duration,
    required this.type,
  });
}

class FocusSong {
  final String title;
  final String audioAssetPath;
  final List<BlinkNote> notes;

  FocusSong({
    required this.title,
    required this.audioAssetPath,
    required this.notes,
  });

  factory FocusSong.calmPiano() {
    // Existing placeholder or simple pattern
    return FocusSong(
      title: "Calm Piano",
      audioAssetPath: "audio/zen_music.mp3",
      notes: List.generate(10, (i) => BlinkNote(
        startTime: Duration(seconds: 2 + (i * 4)), 
        duration: const Duration(milliseconds: 500), 
        type: NoteType.short
      )),
    );
  }

  // NEW: 1-Minute Guided Exercise
  // Pattern: 3 Short Blinks (Regular) + 1 Long Blink (Hold)
  // Repeat 5 times (approx 60 seconds)
  factory FocusSong.guidedExercise() {
    List<BlinkNote> notes = [];
    int currentTime = 2000; // Start at 2 seconds

    for (int i = 0; i < 5; i++) {
      // 3 Short Blinks (every 3 seconds)
      for (int j = 0; j < 3; j++) {
        notes.add(BlinkNote(
          startTime: Duration(milliseconds: currentTime),
          duration: const Duration(milliseconds: 800), // Window to blink
          type: NoteType.short,
        ));
        currentTime += 3000;
      }

      // 1 Long Blink (Hold for 3 seconds)
      notes.add(BlinkNote(
        startTime: Duration(milliseconds: currentTime),
        duration: const Duration(milliseconds: 3000), // Window to hold
        type: NoteType.long,
      ));
      currentTime += 5000; // Allow time for the hold + recovery
    }

    return FocusSong(
      title: "1-Min Dry Eye Relief",
      audioAssetPath: "audio/zen_music.mp3", 
      notes: notes,
    );
  }
}