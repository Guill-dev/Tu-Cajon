import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'tc_icon.dart';

/// Mensaje flotante oscuro que aparece subiendo (0.22 s) y se va solo.
///
/// Se pone dentro de un `Stack`; [bottom] es la distancia desde abajo.
class TcToast extends StatelessWidget {
  const TcToast({super.key, required this.message, this.bottom = 108, this.icon = AppIcons.check});

  final String? message;
  final double bottom;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom + MediaQuery.paddingOf(context).bottom,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: message == null || message!.isEmpty
              ? const SizedBox.shrink()
              : Semantics(
                  key: ValueKey(message),
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.toast,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Color(0x2E000000), blurRadius: 24, offset: Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        TcIcon(icon, size: 22, color: AppColors.verdeToast),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(message!, style: AppText.body(15, color: Colors.white, height: 1.35)),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Agrega `showToast` a un `State`: guarda el mensaje y lo borra solo.
mixin ToastMixin<T extends StatefulWidget> on State<T> {
  String? toastMessage;
  Timer? _toastTimer;

  void showToast(String msg, {Duration duration = const Duration(milliseconds: 2600)}) {
    _toastTimer?.cancel();
    setState(() => toastMessage = msg);
    _toastTimer = Timer(duration, () {
      if (mounted) setState(() => toastMessage = null);
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}
