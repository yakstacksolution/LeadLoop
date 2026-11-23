import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/domain/entities/dashboard_stats.dart';

/// One row of any chart on this page.
class ChartDatum {
  const ChartDatum(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

/// Shared axis and tooltip styling, so five charts read as one report rather
/// than five widgets that happen to be stacked.
const _labelStyle = TextStyle(fontSize: 10.5, color: AppColors.textMuted);
const _axisLine = AxisLine(color: AppColors.outline);
const _majorTick = MajorTickLines(size: 0);

/// Where venues sit in the pipeline, as a funnel.
///
/// The forward path only — "Not interested" and friends have no position on a
/// funnel, so they are reported by [OutcomeChart] instead.
class PipelineFunnel extends StatelessWidget {
  const PipelineFunnel({super.key, required this.stats});

  final DashboardStats stats;

  static const _track = [
    LeadStatus.newLead,
    LeadStatus.contacted,
    LeadStatus.interested,
    LeadStatus.meetingScheduled,
    LeadStatus.visited,
    LeadStatus.negotiation,
    LeadStatus.converted,
  ];

  @override
  Widget build(BuildContext context) {
    final data = [
      for (final status in _track)
        ChartDatum(
          status.label,
          stats.countOf(status),
          AppColors.forLeadStatus(status),
        ),
    ];

    if (data.every((datum) => datum.value == 0)) {
      return const _NoData(message: 'No venues in the pipeline yet.');
    }

    return SizedBox(
      height: 260,
      child: SfFunnelChart(
        margin: EdgeInsets.zero,
        tooltipBehavior: TooltipBehavior(enable: true),
        legend: const Legend(
          isVisible: true,
          position: LegendPosition.right,
          overflowMode: LegendItemOverflowMode.wrap,
          textStyle: _labelStyle,
        ),
        series: FunnelSeries<ChartDatum, String>(
          dataSource: data,
          xValueMapper: (datum, _) => datum.label,
          yValueMapper: (datum, _) => datum.value,
          pointColorMapper: (datum, _) => datum.color,
          neckWidth: '12%',
          neckHeight: '18%',
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Every lead status as a share of the whole book, as a doughnut.
class LeadStatusDoughnut extends StatelessWidget {
  const LeadStatusDoughnut({super.key, required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final data = [
      for (final status in LeadStatus.values)
        if (stats.countOf(status) > 0)
          ChartDatum(
            status.label,
            stats.countOf(status),
            AppColors.forLeadStatus(status),
          ),
    ];

    if (data.isEmpty) {
      return const _NoData(message: 'No venues to break down yet.');
    }

    return SizedBox(
      height: 240,
      child: SfCircularChart(
        margin: EdgeInsets.zero,
        tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x: point.y'),
        legend: const Legend(
          isVisible: true,
          position: LegendPosition.right,
          overflowMode: LegendItemOverflowMode.scroll,
          textStyle: _labelStyle,
        ),
        annotations: [
          CircularChartAnnotation(
            widget: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stats.totalVenues}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text('venues', style: _labelStyle),
              ],
            ),
          ),
        ],
        series: [
          DoughnutSeries<ChartDatum, String>(
            dataSource: data,
            xValueMapper: (datum, _) => datum.label,
            yValueMapper: (datum, _) => datum.value,
            pointColorMapper: (datum, _) => datum.color,
            innerRadius: '62%',
            radius: '88%',
          ),
        ],
      ),
    );
  }
}

/// Won, lost and everything still in play — the question a manager actually
/// asks of a lead book.
class OutcomeChart extends StatelessWidget {
  const OutcomeChart({super.key, required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final data = [
      ChartDatum('In pipeline', stats.inPipeline, AppColors.info),
      ChartDatum('Converted', stats.converted, AppColors.success),
      ChartDatum('Not interested', stats.notInterested, AppColors.danger),
      ChartDatum('Unresponsive', stats.unresponsive, AppColors.neutral),
    ];

    if (data.every((datum) => datum.value == 0)) {
      return const _NoData(message: 'No venues yet.');
    }

    return SizedBox(
      height: 210,
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        plotAreaBorderWidth: 0,
        tooltipBehavior: TooltipBehavior(enable: true),
        primaryXAxis: const CategoryAxis(
          labelStyle: _labelStyle,
          axisLine: _axisLine,
          majorTickLines: _majorTick,
          majorGridLines: MajorGridLines(width: 0),
          labelIntersectAction: AxisLabelIntersectAction.wrap,
          maximumLabelWidth: 72,
        ),
        primaryYAxis: const NumericAxis(
          labelStyle: _labelStyle,
          axisLine: AxisLine(width: 0),
          majorTickLines: _majorTick,
          majorGridLines: MajorGridLines(color: AppColors.surfaceMuted),
        ),
        series: [
          ColumnSeries<ChartDatum, String>(
            dataSource: data,
            xValueMapper: (datum, _) => datum.label,
            yValueMapper: (datum, _) => datum.value,
            pointColorMapper: (datum, _) => datum.color,
            width: 0.55,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How the follow-up queue is holding up: overdue against what is merely due.
class FollowUpChart extends StatelessWidget {
  const FollowUpChart({super.key, required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final data = [
      ChartDatum('Overdue', stats.overdueFollowUps, AppColors.danger),
      ChartDatum('Due today', stats.todaysActivities, AppColors.warning),
      ChartDatum('Pending', stats.pendingFollowUps, AppColors.info),
      ChartDatum('Scheduled', stats.meetingsScheduled, AppColors.secondary),
    ];

    if (data.every((datum) => datum.value == 0)) {
      return const _NoData(message: 'Nothing scheduled — the queue is clear.');
    }

    return SizedBox(
      height: 190,
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        plotAreaBorderWidth: 0,
        tooltipBehavior: TooltipBehavior(enable: true),
        // Horizontal bars: four labels of this length do not fit under a
        // column chart on a phone.
        primaryXAxis: const CategoryAxis(
          labelStyle: _labelStyle,
          axisLine: _axisLine,
          majorTickLines: _majorTick,
          majorGridLines: MajorGridLines(width: 0),
        ),
        primaryYAxis: const NumericAxis(
          labelStyle: _labelStyle,
          axisLine: AxisLine(width: 0),
          majorTickLines: _majorTick,
          majorGridLines: MajorGridLines(color: AppColors.surfaceMuted),
        ),
        series: [
          BarSeries<ChartDatum, String>(
            dataSource: data,
            xValueMapper: (datum, _) => datum.label,
            yValueMapper: (datum, _) => datum.value,
            pointColorMapper: (datum, _) => datum.color,
            width: 0.6,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(6),
            ),
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Completed visits per month over the last half year.
class VisitTrendChart extends StatelessWidget {
  const VisitTrendChart({super.key, required this.data});

  /// Oldest month first.
  final List<ChartDatum> data;

  @override
  Widget build(BuildContext context) {
    if (data.every((datum) => datum.value == 0)) {
      return const _NoData(message: 'No visits recorded in the last 6 months.');
    }

    return SizedBox(
      height: 210,
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        plotAreaBorderWidth: 0,
        tooltipBehavior: TooltipBehavior(enable: true),
        primaryXAxis: const CategoryAxis(
          labelStyle: _labelStyle,
          axisLine: _axisLine,
          majorTickLines: _majorTick,
          majorGridLines: MajorGridLines(width: 0),
        ),
        primaryYAxis: const NumericAxis(
          labelStyle: _labelStyle,
          axisLine: AxisLine(width: 0),
          majorTickLines: _majorTick,
          majorGridLines: MajorGridLines(color: AppColors.surfaceMuted),
          interval: 1,
        ),
        series: [
          SplineAreaSeries<ChartDatum, String>(
            dataSource: data,
            xValueMapper: (datum, _) => datum.label,
            yValueMapper: (datum, _) => datum.value,
            borderWidth: 2.5,
            borderColor: AppColors.secondary,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.secondary.withValues(alpha: 0.28),
                AppColors.secondary.withValues(alpha: 0.02),
              ],
            ),
            markerSettings: const MarkerSettings(
              isVisible: true,
              width: 6,
              height: 6,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
