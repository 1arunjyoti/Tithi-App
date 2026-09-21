import 'package:flutter/material.dart';

// Canonical edge-drag dismissal extracted from
// widgets/tithi_detail_sheet.dart (finalized design): a sustained downward
// touch-drag past the top edge (e.g. from the handle) pops the route.
// Overscroll fires only for touch drags via dragDetails, so ballistic
// flings can't mis-dismiss; pixels accumulate until a ~120px drag.
// Scrim-tap dismissal is untouched (route level).
class EdgeDismiss extends StatelessWidget {
  const EdgeDismiss({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (() {
        var edgeDrag = 0.0;
        return (ScrollNotification notification) {
          if (notification is ScrollStartNotification) {
            edgeDrag = 0;
          } else if (notification is OverscrollNotification &&
              notification.dragDetails != null &&
              notification.overscroll < 0) {
            edgeDrag += -notification.overscroll;
            if (edgeDrag >= 120 && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return true;
            }
          } else if (notification is ScrollUpdateNotification &&
              notification.metrics.pixels > 0) {
            // Left the edge: finger moved back into content.
            edgeDrag = 0;
          }
          return false;
        };
      })(),
      child: child,
    );
  }
}
