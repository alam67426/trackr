import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/financial_insight.dart';
import '../../utils/constants.dart';
import '../common/glass_card.dart';

class SavingTipCard extends StatefulWidget {
  const SavingTipCard({super.key, required this.insights, this.onAction});
  final List<FinancialInsight> insights;
  final ValueChanged<FinancialInsight>? onAction;

  @override
  State<SavingTipCard> createState() => _SavingTipCardState();
}

class _SavingTipCardState extends State<SavingTipCard> {
  late final PageController _controller;
  Timer? _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.insights.length < 2) return;
      _index = (_index + 1) % widget.insights.length;
      _controller.animateToPage(_index,
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    });
  }

  @override
  void didUpdateWidget(covariant SavingTipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contentChanged = oldWidget.insights.isEmpty ||
        widget.insights.isEmpty ||
        oldWidget.insights.first.id != widget.insights.first.id ||
        oldWidget.insights.first.description !=
            widget.insights.first.description;
    if (contentChanged || _index >= widget.insights.length) {
      _index = 0;
      if (_controller.hasClients && widget.insights.isNotEmpty) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.insights.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        SizedBox(
            height: 150,
            child: PageView.builder(
                controller: _controller,
                itemCount: widget.insights.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) => _InsightPage(
                    insight: widget.insights[index],
                    onAction: widget.onAction))),
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    widget.insights.length,
                    (index) => GestureDetector(
                        onTap: () => _controller.animateToPage(index,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut),
                        child: Container(
                            width: index == _index ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                                color: index == _index
                                    ? AppColors.teal
                                    : AppColors.line,
                                borderRadius: BorderRadius.circular(10))))))),
      ]),
    );
  }
}

class _InsightPage extends StatelessWidget {
  const _InsightPage({required this.insight, this.onAction});
  final FinancialInsight insight;
  final ValueChanged<FinancialInsight>? onAction;
  @override
  Widget build(BuildContext context) {
    final color = switch (insight.category) {
      'savings' => AppColors.teal,
      'investment' => AppColors.purple,
      'budgeting' => AppColors.warning,
      'spending' => AppColors.danger,
      _ => AppColors.muted
    };
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.auto_awesome_rounded, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(insight.title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(insight.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                if (insight.actionLabel != null)
                  TextButton(
                      onPressed:
                          onAction == null ? null : () => onAction!(insight),
                      child: Text(insight.actionLabel!)),
              ])),
        ]));
  }
}
