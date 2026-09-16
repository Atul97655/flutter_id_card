/// The Drift schema version the suite expects.
///
/// Kept in one place because three separate test files assert it, and every
/// migration used to mean chasing all three. Bump this when
/// `AppDatabase.schemaVersion` changes - the mismatch is the point, it forces
/// a deliberate acknowledgement that the schema moved.
const int kExpectedSchemaVersion = 8;
