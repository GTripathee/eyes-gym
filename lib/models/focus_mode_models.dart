enum NoteType { short, long }

class BlinkNote {
  final NoteType type;
  final Duration duration; // How long to hold (for long) or window size (for short)
  final Duration startTime; // When this note appears in the song
  
  BlinkNote({
    required this.type,
    required this.duration,
    required this.startTime,
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
  
  // Mock Song Data
  static FocusSong calmPiano() {
    return FocusSong(
      title: "Calm Piano",
      audioAssetPath: "audio/piano_calm.mp3",
      notes: [
        // 0:02 - Short Blink
        BlinkNote(type: NoteType.short, duration: const Duration(milliseconds: 400), startTime: const Duration(seconds: 2)),
        // 0:04 - Short Blink
        BlinkNote(type: NoteType.short, duration: const Duration(milliseconds: 400), startTime: const Duration(seconds: 4)),
        // 0:06 - LONG HOLD (2 seconds)
        BlinkNote(type: NoteType.long, duration: const Duration(milliseconds: 2000), startTime: const Duration(seconds: 6)),
        // 0:10 - Short Blink
        BlinkNote(type: NoteType.short, duration: const Duration(milliseconds: 400), startTime: const Duration(seconds: 10)),
      ],
    );
  }
}