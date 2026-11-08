import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/inventory_report_calculator.dart';
import '../theme/stock_theme.dart';

/// A two-series bar chart using Flutter layout, with exact values in tooltips.
class StockMovementChart extends StatelessWidget {
  const StockMovementChart({super.key, required this.report});
  final StockMovementReport report;
  static const plotHeight = 180.0;

  @override
  Widget build(BuildContext context) {
    if (report.movements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Chưa có giao dịch trong khoảng ngày đã chọn.'),
        ),
      );
    }
    final maximum = report.buckets.fold<int>(
      0,
      (current, bucket) =>
          math.max(current, math.max(bucket.stockIn, bucket.stockOut)),
    );
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.groupLabel} · Số lượng',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Legend(stockSuccess, 'Nhập kho'),
                _Legend(stockError, 'Xuất kho'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  height: plotHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final tick in [maximum, (maximum / 2).round(), 0])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('$tick'),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final groupWidth = report.groupLabel == 'Theo ngày'
                          ? 64.0
                          : 84.0;
                      final width = math.max(
                        constraints.maxWidth,
                        report.buckets.length * groupWidth,
                      );
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          child: Column(
                            children: [
                              SizedBox(
                                height: plotHeight,
                                child: Stack(
                                  children: [
                                    for (final alignment in [
                                      Alignment.topCenter,
                                      Alignment.center,
                                      Alignment.bottomCenter,
                                    ])
                                      Align(
                                        alignment: alignment,
                                        child: Container(
                                          height: 1,
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        for (final bucket in report.buckets)
                                          Expanded(
                                            child: Tooltip(
                                              triggerMode:
                                                  TooltipTriggerMode.tap,
                                              message:
                                                  '${reportDay(bucket.start)} – ${reportDay(DateTime(bucket.endExclusive.year, bucket.endExclusive.month, bucket.endExclusive.day - 1))}\nNhập: ${bucket.stockIn}\nXuất: ${bucket.stockOut}',
                                              child: Semantics(
                                                label:
                                                    '${bucket.label}: nhập ${bucket.stockIn}, xuất ${bucket.stockOut}',
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    MovementReportBar(
                                                      quantity: bucket.stockIn,
                                                      maximum: maximum,
                                                      color: stockSuccess,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    MovementReportBar(
                                                      quantity: bucket.stockOut,
                                                      maximum: maximum,
                                                      color: stockError,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final bucket in report.buckets)
                                    Expanded(
                                      child: Text(
                                        bucket.label,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Thời gian → · Vuốt ngang để xem; chạm cột để xem số lượng.',
            ),
          ],
        ),
      ),
    );
  }
}

class MovementReportBar extends StatelessWidget {
  const MovementReportBar({
    super.key,
    required this.quantity,
    required this.maximum,
    required this.color,
  });
  final int quantity;
  final int maximum;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: maximum == 0
        ? 0
        : quantity / maximum * StockMovementChart.plotHeight,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.square, color: color, size: 12),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}
