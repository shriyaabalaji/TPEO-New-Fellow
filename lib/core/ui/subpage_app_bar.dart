import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'page_title.dart';

/// Circle back control (matches Find / booking subflows: bordered circle, not chevron-only).
class SubpageCircleBackButton extends StatelessWidget {
  const SubpageCircleBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD0D0D0), width: 1),
          ),
          child: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
        ),
      ),
    );
  }
}

/// App bar aligned with Bookings / appointments: white bar, circle back, 22 / w400 title.
AppBar buildSubpageAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  String fallbackRoute = '/profile',
}) {
  void onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    leading: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SubpageCircleBackButton(onPressed: onBack),
      ),
    ),
    leadingWidth: 56,
    title: primaryPageTitle(title),
    actions: actions,
  );
}
