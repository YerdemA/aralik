import 'package:aralik/widgets/number_pad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keys are full height when there is room, shorter when there is not',
    () {
      const others = 196.0;
      expect(
        NumberPad.keyHeightFor(800, others: others),
        NumberPad.fullKeyHeight,
      );
      expect(
        NumberPad.keyHeightFor(double.infinity, others: others),
        NumberPad.fullKeyHeight,
      );
      // 421 dp: the pad gets what is left, (421 - 196) / 4 - 8 per key.
      expect(NumberPad.keyHeightFor(421, others: others), closeTo(48.25, 0.01));
      // Never below a comfortable target.
      expect(
        NumberPad.keyHeightFor(300, others: others),
        NumberPad.minKeyHeight,
      );
    },
  );
}
