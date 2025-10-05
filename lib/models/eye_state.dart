class   EyeState {
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
  final bool isLeftEyeOpen;
  final bool isRightEyeOpen;
  final bool isBothEyesOpen;
  final bool isBothEyesClosed;
  
  EyeState({
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability
  }) : isLeftEyeOpen = leftEyeOpenProbability > 0.5,
      isRightEyeOpen = rightEyeOpenProbability > 0.5,
      isBothEyesOpen = leftEyeOpenProbability > 0.5 && rightEyeOpenProbability > 0.5,
      isBothEyesClosed = leftEyeOpenProbability <= 0.5 && rightEyeOpenProbability <= 0.5;


}