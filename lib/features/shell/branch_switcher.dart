import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_metrics.dart';

/// Sekmeler arası geçiş.
///
/// `StatefulShellRoute.indexedStack` sekmeleri anında değiştiriyor; dokunuşla
/// ekranın değişmesi arasında hiçbir bağ kurulmuyor ve geçiş sert duruyordu.
///
/// Yalnızca **gelen** sekme belirir; giden sekme anında sahneden çekilir.
/// Önce ikisi birden çapraz soldurulmuştu ama görünmeyen sekme ağaçta etkin
/// kalıyordu: ekran okuyucu onu okuyor ve arama yapan kod aynı metni iki kez
/// buluyordu — yani ekranda olmayan bir şey uygulamaya görünür kalıyordu.
/// Çapraz solmanın estetik kazancı, bu bedele değmiyor.
///
/// Dalların kendi gezinme yığınları korunuyor: sahneden çekilen dal ağaçtan
/// silinmiyor, yalnızca çizilmiyor.
class BranchSwitcher extends StatefulWidget {
  const BranchSwitcher({
    required this.shell,
    required this.children,
    super.key,
  });

  final StatefulNavigationShell shell;
  final List<Widget> children;

  @override
  State<BranchSwitcher> createState() => _BranchSwitcherState();
}

class _BranchSwitcherState extends State<BranchSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.base,
    value: 1,
  );

  @override
  void didUpdateWidget(BranchSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shell.currentIndex != widget.shell.currentIndex) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Motion.curve);

    return Stack(
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            offstage: i != widget.shell.currentIndex,
            child: TickerMode(
              enabled: i == widget.shell.currentIndex,
              child: i == widget.shell.currentIndex
                  ? FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        // Küçük bir yukarı kayma: sayfanın "geldiğini"
                        // anlatmaya yetiyor, dikkat dağıtmıyor.
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.015),
                          end: Offset.zero,
                        ).animate(curved),
                        child: widget.children[i],
                      ),
                    )
                  : widget.children[i],
            ),
          ),
      ],
    );
  }
}
