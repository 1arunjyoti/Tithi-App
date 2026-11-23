import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shell's top-level destinations, in the order the bar paints them.
///
/// Used wherever something has to name a tab rather than hold its index: the
/// home card's "view all" action selects [festivals], and the shell maps the
/// bar's `onSelected` index back through [HomeTab.values].
enum HomeTab { today, festivals }

/// Bumped when the destination that is already selected is tapped again.
///
/// The shell cannot scroll a tab to the top itself: the tabs disagree on what
/// "the top" is - a `CustomScrollView` and a `ScrollablePositionedList` (its
/// offset belongs to its `ItemScrollController`, not to a `ScrollController`) -
/// so each tab watches its own entry here and scrolls itself.
///
/// The value is a counter, not a request object: every increment is one more
/// "go back to the top", and a tab that is not mounted simply misses it.
final tabRevealProvider = StateProvider.family<int, HomeTab>((ref, tab) => 0);

/// Fling speed (logical px/s) that switches tabs regardless of distance.
const double tabSwipeVelocityThreshold = 300.0;

/// Drag distance (logical px) that switches tabs regardless of release speed.
/// Smaller than a page-turn slop: the bar is a compact control, not a page.
const double tabSwipeDistanceThreshold = 48.0;

/// Swipe outcome for the shell's top-level tabs.
///
/// A leftward finger movement (negative [distance] / [velocity]) advances to
/// the next destination, matching the order the bar paints them and the
/// direction [HomeTab] values increase. Rightward goes back. 0 means the
/// gesture was too small or too slow to count.
int tabSwipeDirection({required double velocity, required double distance}) {
  if (velocity < -tabSwipeVelocityThreshold ||
      distance < -tabSwipeDistanceThreshold) {
    return 1;
  }
  if (velocity > tabSwipeVelocityThreshold ||
      distance > tabSwipeDistanceThreshold) {
    return -1;
  }
  return 0;
}
