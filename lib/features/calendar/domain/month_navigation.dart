// Swipe policy for the adaptive (Hindu/Bengali) month grid.
//
// The Gregorian path gets its swipe handling from TableCalendar's internal
// PageView, which turns on drag *distance*. The adaptive grid has no page
// view, so this module defines the equivalent contract: a swipe navigates
// on a fast fling OR a slow drag past a distance slop. The previous
// velocity-only detector ignored slow drags entirely, so swiping felt
// broken whenever Hindu/Bengali was primary while chevrons (which call the
// same navigate functions) always worked.

/// Fling speed (logical px/s) that navigates regardless of distance.
/// Matches the threshold the old detector used, so existing fling
/// behavior is unchanged.
const double adaptiveSwipeVelocityThreshold = 300.0;

/// Drag distance (logical px) that navigates regardless of release
/// velocity. Mirrors a page-view turn slop: a deliberate slow drag still
/// turns the month.
const double adaptiveSwipeDistanceThreshold = 80.0;

/// Swipe outcome: +1 next month, -1 previous month, 0 stay.
///
/// Negative velocity/distance is a leftward swipe (finger moves left),
/// which advances to the next month — same direction mapping the chevrons
/// and the Gregorian page turn use.
int adaptiveSwipeDirection({
  required double velocity,
  required double distance,
}) {
  if (velocity < -adaptiveSwipeVelocityThreshold ||
      distance < -adaptiveSwipeDistanceThreshold) {
    return 1;
  }
  if (velocity > adaptiveSwipeVelocityThreshold ||
      distance > adaptiveSwipeDistanceThreshold) {
    return -1;
  }
  return 0;
}
