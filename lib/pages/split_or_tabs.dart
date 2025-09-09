// lib/pages/split_or_tabs.dart

import 'package:flutter/material.dart';

class SplitOrTabs extends StatelessWidget {
  const SplitOrTabs({
    required this.tabs,
    required this.children,
    required this.controller, // Добавляем этот параметр
    super.key,
  });

  final List<Tab> tabs;
  final List<Widget> children;
  final TabController? controller; // Добавляем этот параметр

  @override
  Widget build(BuildContext context) {
    // Эта логика будет использовать либо TabBar на маленьких экранах,
    // либо отображать оба виджета рядом на больших.
    // Для простоты здесь реализован только вариант с TabBar.
    return Column(
      children: [
        TabBar(
          controller: controller,
          tabs: tabs,
          isScrollable: false,
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: children,
          ),
        ),
      ],
    );
  }
}