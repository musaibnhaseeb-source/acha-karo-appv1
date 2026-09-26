import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/data/badges.dart';

// Frozen badges (badge_definitions.frozen) are never newly granted on the device; held ones stay.

void main() {
  test('fresh account reaching #1 while top1 is frozen does not get it', () {
    expect(grantableBadgeIds(['firstDeed', 'top10', 'top3', 'top1'], {}, {'top1', 'top3', 'top10'}), ['firstDeed']);
  });

  test('once unfrozen the badge is granted normally', () {
    expect(grantableBadgeIds(['firstDeed', 'top1'], {'firstDeed'}, {}), ['firstDeed', 'top1']);
  });

  test('existing holder keeps a frozen badge', () {
    expect(grantableBadgeIds(['top1', 'top10'], {'top1'}, {'top1', 'top10'}), ['top1']);
  });

  test('failed frozen read (empty set) fails open', () {
    expect(grantableBadgeIds(['top1'], {}, {}), ['top1']);
  });
}
