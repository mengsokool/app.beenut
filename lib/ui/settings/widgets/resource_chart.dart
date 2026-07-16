import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class ResourceHistoryChart extends StatefulWidget {
  const ResourceHistoryChart({
    super.key,
    required this.daemonCpu,
    required this.daemonRam,
    required this.flutterCpu,
    required this.flutterRam,
    this.maxPoints = 60,
  });

  final double daemonCpu;
  final double daemonRam;
  final double flutterCpu;
  final double flutterRam;
  final int maxPoints;

  @override
  State<ResourceHistoryChart> createState() => _ResourceHistoryChartState();
}

class _ResourceHistoryChartState extends State<ResourceHistoryChart> {
  final List<double> _daemonCpuHistory = [];
  final List<double> _daemonRamHistory = [];
  final List<double> _flutterCpuHistory = [];
  final List<double> _flutterRamHistory = [];

  @override
  void initState() {
    super.initState();
    _addPoint();
  }

  @override
  void didUpdateWidget(covariant ResourceHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.daemonCpu != widget.daemonCpu ||
        oldWidget.daemonRam != widget.daemonRam ||
        oldWidget.flutterCpu != widget.flutterCpu ||
        oldWidget.flutterRam != widget.flutterRam) {
      _addPoint();
    }
  }

  void _addPoint() {
    setState(() {
      _daemonCpuHistory.add(widget.daemonCpu.clamp(0.0, 100.0));
      _daemonRamHistory.add(widget.daemonRam.clamp(0.0, 10000.0));
      _flutterCpuHistory.add(widget.flutterCpu.clamp(0.0, 100.0));
      _flutterRamHistory.add(widget.flutterRam.clamp(0.0, 10000.0));

      if (_daemonCpuHistory.length > widget.maxPoints) {
        _daemonCpuHistory.removeAt(0);
        _daemonRamHistory.removeAt(0);
        _flutterCpuHistory.removeAt(0);
        _flutterRamHistory.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daemonColor = scheme.primary;
    final flutterColor = scheme.tertiary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Column(
          children: [
            Expanded(
              child: _ChartPanel(
                title: 'CPU Usage',
                unitLabel: '%',
                compact: compact,
                chart: CustomPaint(
                  painter: _CpuChartPainter(
                    daemonData: _daemonCpuHistory,
                    flutterData: _flutterCpuHistory,
                    maxPoints: widget.maxPoints,
                    gridColor: scheme.outlineVariant,
                    labelColor: scheme.onSurfaceVariant,
                    daemonColor: daemonColor,
                    flutterColor: flutterColor,
                  ),
                ),
                children: [
                  _buildMetricBadge('Daemon', widget.daemonCpu, daemonColor),
                  _buildMetricBadge(
                    'Flutter UI',
                    widget.flutterCpu,
                    flutterColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ChartPanel(
                title: 'Memory Usage',
                unitLabel: 'MB',
                compact: compact,
                chart: CustomPaint(
                  painter: _RamChartPainter(
                    daemonData: _daemonRamHistory,
                    flutterData: _flutterRamHistory,
                    maxPoints: widget.maxPoints,
                    gridColor: scheme.outlineVariant,
                    labelColor: scheme.onSurfaceVariant,
                    daemonColor: daemonColor,
                    flutterColor: flutterColor,
                  ),
                ),
                children: [
                  _buildMetricBadge(
                    'Daemon',
                    widget.daemonRam,
                    daemonColor,
                    unit: ' MB',
                  ),
                  _buildMetricBadge(
                    'Flutter UI',
                    widget.flutterRam,
                    flutterColor,
                    unit: ' MB',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricBadge(
    String label,
    double value,
    Color color, {
    String unit = '%',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        borderRadius: BeenutTheme.radiusSharp,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BeenutTheme.radiusSharp,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ${value.toStringAsFixed(1)}$unit',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: BeenutTheme.inkColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.unitLabel,
    required this.compact,
    required this.children,
    required this.chart,
  });

  final String title;
  final String unitLabel;
  final bool compact;
  final List<Widget> children;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BeenutTheme.radiusPanel,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, compact ? 10 : 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: BeenutTheme.inkColor(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unitLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Wrap(spacing: 6, runSpacing: 6, children: children),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }
}

class _CpuChartPainter extends CustomPainter {
  _CpuChartPainter({
    required this.daemonData,
    required this.flutterData,
    required this.maxPoints,
    required this.gridColor,
    required this.labelColor,
    required this.daemonColor,
    required this.flutterColor,
  });

  final List<double> daemonData;
  final List<double> flutterData;
  final int maxPoints;
  final Color gridColor;
  final Color labelColor;
  final Color daemonColor;
  final Color flutterColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double chartWidth = width;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: labelColor.withValues(alpha: 0.7),
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      fontFamily: 'monospace',
    );

    const int gridRows = 4;
    for (int i = 0; i <= gridRows; i++) {
      final double y = height * (1.0 - i / gridRows);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);

      final int pct = (i * 100 ~/ gridRows);
      final textPainter = TextPainter(
        text: TextSpan(text: '$pct%', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      double offsetY = y - textPainter.height / 2;
      if (i == 0) {
        offsetY = y - textPainter.height + 2;
      } else if (i == gridRows) {
        offsetY = y - 2;
      }
      textPainter.paint(
        canvas,
        Offset(chartWidth - textPainter.width - 4, offsetY),
      );
    }

    _drawSeries(canvas, size, daemonData, daemonColor, 100.0, chartWidth);
    _drawSeries(canvas, size, flutterData, flutterColor, 100.0, chartWidth);
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double> data,
    Color color,
    double maxVal,
    double chartWidth,
  ) {
    if (data.isEmpty) return;

    final double height = size.height;
    final int divisor = data.length > 1 ? data.length - 1 : 1;
    final double stepX = chartWidth / divisor;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, height));

    final path = Path();
    final fillPath = Path();

    double startX = 0;
    double startY = height * (1.0 - data.first / maxVal);
    path.moveTo(startX, startY);
    fillPath.moveTo(startX, height);
    fillPath.lineTo(startX, startY);

    if (data.length == 1) {
      path.lineTo(chartWidth, startY);
      fillPath.lineTo(chartWidth, startY);
      fillPath.lineTo(chartWidth, height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
      return;
    }

    for (int i = 1; i < data.length; i++) {
      final double x = i * stepX;
      final double y = height * (1.0 - data[i] / maxVal);

      final double prevX = (i - 1) * stepX;
      final double prevY = height * (1.0 - data[i - 1] / maxVal);
      final double controlX = (prevX + x) / 2;
      path.quadraticBezierTo(controlX, prevY, controlX, (prevY + y) / 2);
      path.lineTo(x, y);

      fillPath.quadraticBezierTo(controlX, prevY, controlX, (prevY + y) / 2);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo((data.length - 1) * stepX, height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _CpuChartPainter oldDelegate) {
    return oldDelegate.daemonData != daemonData ||
        oldDelegate.flutterData != flutterData ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.daemonColor != daemonColor ||
        oldDelegate.flutterColor != flutterColor;
  }
}

class _RamChartPainter extends CustomPainter {
  _RamChartPainter({
    required this.daemonData,
    required this.flutterData,
    required this.maxPoints,
    required this.gridColor,
    required this.labelColor,
    required this.daemonColor,
    required this.flutterColor,
  });

  final List<double> daemonData;
  final List<double> flutterData;
  final int maxPoints;
  final Color gridColor;
  final Color labelColor;
  final Color daemonColor;
  final Color flutterColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double chartWidth = width;

    double maxVal = 100.0;
    for (final val in daemonData) {
      if (val > maxVal) maxVal = val;
    }
    for (final val in flutterData) {
      if (val > maxVal) maxVal = val;
    }
    maxVal = ((maxVal + 49) ~/ 50) * 50.0;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: labelColor.withValues(alpha: 0.7),
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      fontFamily: 'monospace',
    );

    const int gridRows = 4;
    for (int i = 0; i <= gridRows; i++) {
      final double y = height * (1.0 - i / gridRows);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);

      final double val = (i * maxVal / gridRows);
      final textPainter = TextPainter(
        text: TextSpan(text: '${val.toStringAsFixed(0)}M', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      double offsetY = y - textPainter.height / 2;
      if (i == 0) {
        offsetY = y - textPainter.height + 2;
      } else if (i == gridRows) {
        offsetY = y - 2;
      }
      textPainter.paint(
        canvas,
        Offset(chartWidth - textPainter.width - 4, offsetY),
      );
    }

    _drawSeries(canvas, size, daemonData, daemonColor, maxVal, chartWidth);
    _drawSeries(canvas, size, flutterData, flutterColor, maxVal, chartWidth);
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double> data,
    Color color,
    double maxVal,
    double chartWidth,
  ) {
    if (data.isEmpty) return;

    final double height = size.height;
    final int divisor = data.length > 1 ? data.length - 1 : 1;
    final double stepX = chartWidth / divisor;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, height));

    final path = Path();
    final fillPath = Path();

    double startX = 0;
    double startY = height * (1.0 - data.first / maxVal);
    path.moveTo(startX, startY);
    fillPath.moveTo(startX, height);
    fillPath.lineTo(startX, startY);

    if (data.length == 1) {
      path.lineTo(chartWidth, startY);
      fillPath.lineTo(chartWidth, startY);
      fillPath.lineTo(chartWidth, height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
      return;
    }

    for (int i = 1; i < data.length; i++) {
      final double x = i * stepX;
      final double y = height * (1.0 - data[i] / maxVal);

      final double prevX = (i - 1) * stepX;
      final double prevY = height * (1.0 - data[i - 1] / maxVal);
      final double controlX = (prevX + x) / 2;
      path.quadraticBezierTo(controlX, prevY, controlX, (prevY + y) / 2);
      path.lineTo(x, y);

      fillPath.quadraticBezierTo(controlX, prevY, controlX, (prevY + y) / 2);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo((data.length - 1) * stepX, height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RamChartPainter oldDelegate) {
    return oldDelegate.daemonData != daemonData ||
        oldDelegate.flutterData != flutterData ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.daemonColor != daemonColor ||
        oldDelegate.flutterColor != flutterColor;
  }
}
