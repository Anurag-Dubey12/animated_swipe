import 'package:flutter_test/flutter_test.dart';
import 'package:animated_swipe/animated_swipe.dart';

void main() {
  test('SwipeItemState.closed initialises to resting values', () {
    const state = SwipeItemState.closed();
    expect(state.dragOffset, 0.0);
    expect(state.isClosed, isTrue);
    expect(state.activeDirection, SwipeDirection.none);
  });
}
