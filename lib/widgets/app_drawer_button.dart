import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'app_buttons.dart';

/// App-bar button that opens the nearest [Scaffold]'s navigation drawer.
///
/// Every top-level tab shows its own drawer, so all three app bars need the
/// same affordance. Uses [AppIconButton] so the expressive press and the
/// accessibility-gated haptic come from one shared place. (Named after
/// `AppDrawer`: the framework already has a `DrawerButton`.)
class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    // `Scaffold.of` needs a context below the Scaffold: the button sits inside
    // the app bar, which is built by that Scaffold.
    return Builder(
      builder: (innerContext) => AppIconButton(
        icon: Icon(Icons.menu_rounded, color: innerContext.colors.onSurface),
        tooltip: MaterialLocalizations.of(innerContext).openAppDrawerTooltip,
        onPressed: () => Scaffold.of(innerContext).openDrawer(),
      ),
    );
  }
}
