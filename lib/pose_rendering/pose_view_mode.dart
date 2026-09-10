enum PoseViewMode {
  camera,
  skeleton,
  cameraWithSkeleton,
}

extension PoseViewModeDisplay on PoseViewMode {
  String get label => switch (this) {
        PoseViewMode.camera => 'Camera',
        PoseViewMode.skeleton => 'Skeleton',
        PoseViewMode.cameraWithSkeleton => 'Camera + Skeleton',
      };

  bool get showsCamera =>
      this == PoseViewMode.camera || this == PoseViewMode.cameraWithSkeleton;

  bool get showsSkeleton =>
      this == PoseViewMode.skeleton || this == PoseViewMode.cameraWithSkeleton;
}
