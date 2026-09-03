/// Lifecycle of a locally-created record on its way to Firestore.
///
/// The data-entry app is offline-first: an entry is *always* written to the
/// local database first and only then queued. The operator must be able to see
/// at a glance whether their day's work has actually left the device.
enum SyncStatus {
  /// Saved locally, waiting for a connection or for the sync worker to pick up.
  pending('Pending'),

  /// Currently being uploaded. Transient - reset to [pending] on app restart so
  /// a crash mid-upload cannot strand a record.
  syncing('Syncing'),

  /// Confirmed written to Firestore, with photo uploaded to Storage.
  synced('Synced'),

  /// Upload failed. Retried automatically with backoff; the error is kept so
  /// the operator can be told *why* rather than just "failed".
  failed('Failed');

  const SyncStatus(this.label);

  final String label;

  bool get isTerminal => this == SyncStatus.synced;

  /// Whether the sync worker should attempt this record on its next pass.
  bool get needsUpload => this == SyncStatus.pending || this == SyncStatus.failed;

  static SyncStatus fromName(String? value) => SyncStatus.values.firstWhere(
        (SyncStatus s) => s.name == value,
        orElse: () => SyncStatus.pending,
      );
}
