/// The complete set of data points a card can carry.
///
/// This enum is the single source of truth for three separate systems:
///   * which inputs the data-entry form renders (per-school toggles),
///   * which rows the card renderer draws,
///   * the Firestore/Drift column names.
///
/// Because the storage key is explicit and separate from the display label,
/// labels can be reworded without migrating any data.
enum StudentField {
  name(
    key: 'name',
    formLabel: 'Name',
    cardLabel: 'NAME',
    kind: FieldKind.text,
    forceUppercase: true,
    alwaysEnabled: true,
  ),
  fatherName(
    key: 'fatherName',
    formLabel: "Father's Name",
    cardLabel: 'FATHER NAME',
    kind: FieldKind.text,
    forceUppercase: true,
  ),
  studentClass(
    key: 'studentClass',
    formLabel: 'Class',
    cardLabel: 'CLASS',
    kind: FieldKind.text,
    forceUppercase: true,
  ),
  division(
    key: 'division',
    formLabel: 'Div',
    cardLabel: 'DIV',
    kind: FieldKind.text,
    forceUppercase: true,
  ),
  bloodGroup(
    key: 'bloodGroup',
    formLabel: 'Blood Group',
    cardLabel: 'BLOOD GRP',
    kind: FieldKind.bloodGroup,
  ),
  dob(
    key: 'dob',
    formLabel: 'DOB',
    cardLabel: 'DOB',
    kind: FieldKind.date,
  ),
  mobile(
    key: 'mobile',
    formLabel: 'Mobile No',
    cardLabel: 'MOBILE NO',
    kind: FieldKind.mobile,
  ),
  address(
    key: 'address',
    formLabel: 'Address',
    cardLabel: 'ADDRESS',
    kind: FieldKind.multiline,
    forceUppercase: true,
  ),
  photo(
    key: 'photo',
    formLabel: 'Photo',
    cardLabel: '',
    kind: FieldKind.photo,
    alwaysEnabled: true,
  );

  const StudentField({
    required this.key,
    required this.formLabel,
    required this.cardLabel,
    required this.kind,
    this.forceUppercase = false,
    this.alwaysEnabled = false,
  });

  /// Stable storage key. Never change these - they are persisted.
  final String key;

  /// Label shown above the input in the data-entry form.
  final String formLabel;

  /// Label printed on the card itself (already uppercase).
  final String cardLabel;

  final FieldKind kind;

  /// Whether typed input is coerced to capitals in the stored value.
  final bool forceUppercase;

  /// Fields an admin cannot switch off. A card with no name and no photo is
  /// not an ID card, so those two are locked on.
  final bool alwaysEnabled;

  /// Fields the admin panel exposes as ON/OFF toggles.
  static List<StudentField> get toggleable =>
      values.where((StudentField f) => !f.alwaysEnabled).toList();

  /// Text-bearing fields that appear as `LABEL : VALUE` rows on the card.
  static List<StudentField> get printableRows =>
      values.where((StudentField f) => f.kind != FieldKind.photo).toList();

  static StudentField? fromKey(String key) {
    for (final StudentField f in values) {
      if (f.key == key) return f;
    }
    return null;
  }
}

enum FieldKind {
  text,
  multiline,
  date,
  mobile,
  bloodGroup,
  photo,
}

/// The eight clinically recognised ABO/Rh groups, in the order operators
/// expect to see them in a dropdown.
const List<String> kBloodGroups = <String>[
  'A+',
  'A-',
  'B+',
  'B-',
  'O+',
  'O-',
  'AB+',
  'AB-',
];
