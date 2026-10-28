import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the parent screens speak Hindi. Remembered between launches.
///
/// A parent may be the first in the family to use an app like this, and the
/// screens are written to be read at a glance - but "at a glance" depends on
/// the language. One tap switches every parent screen; it is deliberately a
/// plain toggle, not a settings page, so nobody has to find it.
class ParentLangController extends Notifier<bool> {
  static const String _key = 'parent_lang_hindi';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool saved = prefs.getBool(_key) ?? false;
      if (saved != state) state = saved;
    } on Object {
      // Storage unavailable: stay on English for this run.
    }
  }

  Future<void> toggle() async {
    state = !state;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, state);
    } on Object {
      // Not remembered, but the switch itself already took effect.
    }
  }
}

final NotifierProvider<ParentLangController, bool> parentLangProvider =
    NotifierProvider<ParentLangController, bool>(ParentLangController.new);

/// The strings for the language the parent has picked.
final Provider<ParentStrings> parentStringsProvider = Provider<ParentStrings>(
  (Ref ref) => ref.watch(parentLangProvider)
      ? const ParentStrings.hindi()
      : const ParentStrings.english(),
);

/// Every word the parent screens show, in both languages.
///
/// Kept in one place so a screen never hard-codes English, and so adding a
/// third language later is one more constructor, not a hunt through widgets.
/// Sentences are short and plain on purpose: they are read by parents, and by
/// children helping them.
class ParentStrings {
  const ParentStrings._(this._hi);

  const ParentStrings.english() : this._(false);
  const ParentStrings.hindi() : this._(true);

  final bool _hi;

  String _t(String en, String hi) => _hi ? hi : en;

  // --- shared ---------------------------------------------------------
  String get switchLanguage => _t('हिंदी', 'English');
  String get appTagline => _t(
    "Make your child's school ID card from your phone",
    'अपने बच्चे का स्कूल ID कार्ड अपने फ़ोन से बनाएँ',
  );

  // --- sign up / sign in ----------------------------------------------
  String get getStarted => _t('Get started', 'शुरू करें');
  String get welcomeBack => _t('Welcome back', 'वापसी पर स्वागत है');
  String get signUpSubtitle => _t(
    'Make an account in a minute. No school code needed.',
    'एक मिनट में अकाउंट बनाएँ। स्कूल कोड की ज़रूरत नहीं।',
  );
  String get signInSubtitle =>
      _t('Sign in to see your cards.', 'अपने कार्ड देखने के लिए साइन इन करें।');
  String get yourName => _t('Your name', 'आपका नाम');
  String get email => _t('Email', 'ईमेल');
  String get password => _t('Password', 'पासवर्ड');
  String get passwordHint =>
      _t('At least 6 characters', 'कम से कम 6 अक्षर');
  String get createAccount => _t('Create account', 'अकाउंट बनाएँ');
  String get signIn => _t('Sign in', 'साइन इन');
  String get haveAccount =>
      _t('I already have an account', 'मेरा अकाउंट पहले से है');
  String get newHere => _t('I am new here', 'मैं नया हूँ');
  String get enterName => _t('Enter your name', 'अपना नाम लिखें');
  String get enterEmail => _t('Enter your email', 'अपना ईमेल लिखें');
  String get badEmail =>
      _t('That does not look like an email', 'यह ईमेल सही नहीं लगता');
  String get shortPassword =>
      _t('At least 6 characters', 'कम से कम 6 अक्षर');
  String get genericAuthError => _t(
    'Something went wrong. Please try again.',
    'कुछ गड़बड़ हो गई। कृपया फिर कोशिश करें।',
  );

  // --- home -----------------------------------------------------------
  String hello(String name) => name.isEmpty
      ? _t('Hello!', 'नमस्ते!')
      : _t('Hello, $name', 'नमस्ते, $name');
  String get heroTitle =>
      _t("Make your child's ID card", 'अपने बच्चे का ID कार्ड बनाएँ');
  String get heroSubtitle => _t(
    'Three easy steps. The school office prints it.',
    'तीन आसान क़दम। स्कूल ऑफ़िस इसे प्रिंट करता है।',
  );
  String get stepSchool => _t('Pick school', 'स्कूल चुनें');
  String get stepPhoto => _t('Photo & details', 'फ़ोटो और जानकारी');
  String get stepSend => _t('Send', 'भेजें');
  String get makeCard => _t('Make an ID card', 'ID कार्ड बनाएँ');
  String get yourCards => _t('Your cards', 'आपके कार्ड');
  String get emptyTitle => _t('No cards yet', 'अभी कोई कार्ड नहीं');
  String get emptyHint => _t(
    'Your cards will show up here, with where each one is.',
    'आपके कार्ड यहाँ दिखेंगे, और यह भी कि हर कार्ड कहाँ तक पहुँचा।',
  );

  // --- card progress --------------------------------------------------
  String get progressSaved => _t('Saved', 'सेव');
  String get progressSent => _t('Sent', 'भेजा');
  String get progressApproved => _t('Approved', 'मंज़ूर');
  String get progressPrinted => _t('Printed', 'प्रिंट');

  String get statusWaiting => _t('Waiting to send', 'भेजने का इंतज़ार');
  String get statusRetry =>
      _t('Could not send yet. Trying again.', 'अभी भेज नहीं सका। फिर कोशिश कर रहा है।');
  String get statusOffice =>
      _t('With the school office', 'स्कूल ऑफ़िस के पास');
  String get statusApproved => _t('Approved', 'मंज़ूर हो गया');
  String get statusPrinted => _t('Printed', 'प्रिंट हो गया');
  String get statusSentBack => _t('Sent back by the office', 'ऑफ़िस ने वापस भेजा');
  String get makeAgain => _t('Make it again', 'दोबारा बनाएँ');

  // --- school picker --------------------------------------------------
  String get chooseSchool => _t('Choose your school', 'अपना स्कूल चुनें');
  String get stepOfThree => _t('Step 1 of 3', 'क़दम 1 / 3');
  String get searchSchools => _t('Search school name', 'स्कूल का नाम खोजें');
  String get noSchools =>
      _t('No schools are available yet.', 'अभी कोई स्कूल उपलब्ध नहीं है।');
  String noMatch(String q) =>
      _t('No school matches "$q".', '"$q" से कोई स्कूल नहीं मिला।');
  String get loadError => _t(
    'Could not load schools. Check your internet and try again.',
    'स्कूल लोड नहीं हुए। इंटरनेट जाँचकर फिर कोशिश करें।',
  );
  String get retry => _t('Try again', 'फिर कोशिश करें');
  String get savedMessage => _t(
    'Saved. It goes to the school as soon as you are online.',
    'सेव हो गया। इंटरनेट मिलते ही यह स्कूल को चला जाएगा।',
  );
}
