import 'package:material_ui/material_ui.dart';

import '../core/anim/press_scale.dart';
import '../theme/app_theme.dart';

/// App-bar button that opens the nearest [Scaffold]'s navigation drawer.
///
/// Every top-level tab shows its own drawer, so all three app bars need the
/// same affordance. It is a widget rather than the framework's
/// `automaticallyImplyLeading` button because that one cannot carry
/// [PressScale]'s gated haptic and press feel. (Named after `AppDrawer`: the
/// framework already has a `DrawerButton`.)
class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    // `Scaffold.of` needs a context below the Scaffold: the button sits inside
    // the app bar, which is built by that Scaffold.
    return Builder(
      builder: (innerContext) => PressScale(
        child: IconButton(
          icon: Icon(Icons.menu_rounded, color: innerContext.colors.onSurface),
          tooltip: MaterialLocalizations.of(innerContext).openAppDrawerTooltip,
          onPressed: () => Scaffold.of(innerContext).openDrawer(),
        ),
      ),
    );
  }
}
