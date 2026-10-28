import 'package:flutter_id_card/features/auth/domain/session_user.dart';
import 'package:flutter_id_card/features/parent/application/parent_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole.parent', () {
    test('round-trips through its wire value', () {
      expect(UserRole.fromWire('Parent'), UserRole.parent);
      expect(UserRole.fromWire('parent'), UserRole.parent);
      expect(UserRole.parent.wireValue, 'Parent');
    });

    test('is not an admin, and is an operator for messaging purposes', () {
      expect(UserRole.parent.isOperator, isTrue);
      const SessionUser p = SessionUser(
        uid: 'p1',
        email: 'p@example.com',
        role: UserRole.parent,
      );
      expect(p.isAdmin, isFalse);
      expect(p.isParent, isTrue);
    });

    test('can enter data with no school; a teacher without one cannot', () {
      const SessionUser parent = SessionUser(
        uid: 'p1',
        email: 'p@example.com',
        role: UserRole.parent,
      );
      const SessionUser teacher = SessionUser(
        uid: 't1',
        email: 't@example.com',
        role: UserRole.teacher,
      );
      expect(parent.canEnterData, isTrue);
      expect(teacher.canEnterData, isFalse);
    });

    test('survives the session cache round trip', () {
      const SessionUser p = SessionUser(
        uid: 'p1',
        email: 'p@example.com',
        role: UserRole.parent,
        displayName: 'Asha',
      );
      final SessionUser back = SessionUser.fromJson(p.toJson());
      expect(back.role, UserRole.parent);
      expect(back.schoolId, isNull);
    });
  });

  group('ParentStrings', () {
    test('has a Hindi version of every greeting and differs from English', () {
      const ParentStrings en = ParentStrings.english();
      const ParentStrings hi = ParentStrings.hindi();
      expect(en.makeCard, isNot(hi.makeCard));
      expect(en.hello('Asha'), contains('Asha'));
      expect(hi.hello('Asha'), contains('Asha'));
      expect(en.hello(''), isNotEmpty);
    });
  });
}
