enum PoseViewMode {
  camera,
  skeleton,
  cameraWithSkeleton,
  stickman,
}

extension PoseViewModeDisplay on PoseViewMode {
  String get label => switch (this) {
        PoseViewMode.camera => 'Camera',
        PoseViewMode.skeleton => 'Skeleton',
        PoseViewMode.cameraWithSkeleton => 'Camera + Skeleton',
        PoseViewMode.stickman => 'Stickman 2D',
      };

  bool get showsCamera =>
      this == PoseViewMode.camera || this == PoseViewMode.cameraWithSkeleton;

  bool get showsSkeleton =>
      this == PoseViewMode.skeleton || this == PoseViewMode.cameraWithSkeleton;

  bool get showsStickman => this == PoseViewMode.stickman;
}
