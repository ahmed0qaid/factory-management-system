import 'package:flutter/material.dart';
import '../../models/attendance_model.dart';
import '../../utils/attendance_display.dart';
import '../../utils/formatters.dart';

enum SummaryPeriod { day, week, month }

class AttendanceVisualSummaryChart extends StatefulWidget {
  final List<AttendanceRecordModel> records;

  const AttendanceVisualSummaryChart({super.key, required this.records});

  @override
  State<AttendanceVisualSummaryChart> createState() =>
      _AttendanceVisualSummaryChartState();
}

class _AttendanceVisualSummaryChartState
    extends State<AttendanceVisualSummaryChart> {
  SummaryPeriod _period = SummaryPeriod.day;
  DateTime _currentDate = DateTime.now();

  List<AttendanceRecordModel> get _currentRecords {
    return widget.records.where((r) {
      if (_period == SummaryPeriod.day) {
        return r.workDate.year == _currentDate.year &&
            r.workDate.month == _currentDate.month &&
            r.workDate.day == _currentDate.day;
      } else if (_period == SummaryPeriod.week) {
        int daysToSubtract = _currentDate.weekday == 7
            ? 0
            : _currentDate.weekday;
        DateTime startOfWeek = _currentDate.subtract(
          Duration(days: daysToSubtract),
        );
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        DateTime rDate = DateTime(
          r.workDate.year,
          r.workDate.month,
          r.workDate.day,
        );
        DateTime sDate = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        DateTime eDate = DateTime(
          endOfWeek.year,
          endOfWeek.month,
          endOfWeek.day,
        );
        return rDate.compareTo(sDate) >= 0 && rDate.compareTo(eDate) <= 0;
      } else {
        return r.workDate.year == _currentDate.year &&
            r.workDate.month == _currentDate.month;
      }
    }).toList();
  }

  void _previous() {
    setState(() {
      if (_period == SummaryPeriod.day) {
        _currentDate = _currentDate.subtract(const Duration(days: 1));
      } else if (_period == SummaryPeriod.week) {
        _currentDate = _currentDate.subtract(const Duration(days: 7));
      } else {
        _currentDate = DateTime(
          _currentDate.year,
          _currentDate.month - 1,
          _currentDate.day,
        );
      }
    });
  }

  void _next() {
    setState(() {
      if (_period == SummaryPeriod.day) {
        _currentDate = _currentDate.add(const Duration(days: 1));
      } else if (_period == SummaryPeriod.week) {
        _currentDate = _currentDate.add(const Duration(days: 7));
      } else {
        _currentDate = DateTime(
          _currentDate.year,
          _currentDate.month + 1,
          _currentDate.day,
        );
      }
    });
  }

  String _getPeriodLabel() {
    if (_period == SummaryPeriod.day) {
      return Formatters.date(_currentDate);
    } else if (_period == SummaryPeriod.week) {
      int daysToSubtract = _currentDate.weekday == 7 ? 0 : _currentDate.weekday;
      DateTime startOfWeek = _currentDate.subtract(
        Duration(days: daysToSubtract),
      );
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${Formatters.date(startOfWeek)} - ${Formatters.date(endOfWeek)}';
    } else {
      final List<String> monthsAr = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      return '${monthsAr[_currentDate.month - 1]} ${_currentDate.year}';
    }
  }

  Color _getColorForRecord(AttendanceRecordModel? record) {
    if (record == null) return Colors.grey.shade200;
    if (record.status == 'absent') return Colors.red;

    // As requested: late_minutes > 0 is clearly orange
    if (record.lateMinutes > 0 || record.earlyLeaveMinutes > 0) {
      return Colors.orange;
    }

    bool isMissingCheckout = record.checkIn != null && record.checkOut == null;
    bool isMissingCheckin = record.checkIn == null && record.checkOut != null;

    if (record.status == 'needs_review' ||
        record.status == 'incomplete' ||
        isMissingCheckin ||
        isMissingCheckout) {
      return Colors.grey.shade400;
    }

    if (record.checkIn != null && record.checkOut != null) {
      return Colors.blue;
    }
    return Colors.green;
  }

  String _formatTimeAr(DateTime? dt) {
    if (dt == null) return 'غير مسجل';
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final period = h < 12 ? 'ص' : 'م';
    return '$h12:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: _period == SummaryPeriod.day
                      ? null
                      : ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).cardColor,
                          foregroundColor: Colors.grey.shade800,
                          elevation: 0,
                        ),
                  onPressed: () {
                    setState(() {
                      _period = SummaryPeriod.day;
                    });
                  },
                  child: const Text('يوم'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: _period == SummaryPeriod.week
                      ? null
                      : ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).cardColor,
                          foregroundColor: Colors.grey.shade800,
                          elevation: 0,
                        ),
                  onPressed: () {
                    setState(() {
                      _period = SummaryPeriod.week;
                    });
                  },
                  child: const Text('أسبوع'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: _period == SummaryPeriod.month
                      ? null
                      : ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).cardColor,
                          foregroundColor: Colors.grey.shade800,
                          elevation: 0,
                        ),
                  onPressed: () {
                    setState(() {
                      _period = SummaryPeriod.month;
                    });
                  },
                  child: const Text('شهر'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _previous,
            ),
            Text(
              _getPeriodLabel(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _next),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    final records = _currentRecords;
    if (_period == SummaryPeriod.day) {
      return _buildDayView(records);
    } else if (_period == SummaryPeriod.week) {
      return _buildWeekView(records);
    } else {
      return _buildMonthView(records);
    }
  }

  Widget _buildDayView(List<AttendanceRecordModel> records) {
    if (records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('لا توجد بيانات دوام لهذه الفترة'),
        ),
      );
    }

    final record = records.first;
    final color = _getColorForRecord(record);

    bool isMissingCheckout = record.checkIn != null && record.checkOut == null;
    bool isMissingCheckin = record.checkIn == null && record.checkOut != null;
    bool needsReview =
        record.status == 'needs_review' ||
        isMissingCheckout ||
        isMissingCheckin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _buildDayTimeline(record, color),
        const SizedBox(height: 32),
        if (needsReview)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: const Text(
              'يحتاج مراجعة',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildStatCard(
              'الحالة',
              statusLabel(record.status),
              record.checkOut == null ? Colors.red : Colors.blue,
            ),
            _buildStatCard(
              'الدخول',
              _formatTimeAr(record.checkIn),
              Colors.blue,
            ),
            _buildStatCard(
              'الخروج',
              _formatTimeAr(record.checkOut),
              record.checkOut == null ? Colors.red : Colors.blue,
            ),
            _buildStatCard('التأخير', '${record.lateMinutes} د', Colors.orange),
            _buildStatCard(
              'خروج مبكر',
              '${record.earlyLeaveMinutes} د',
              Colors.orange,
            ),
            _buildStatCard(
              'ساعات العمل',
              '${(record.workedMinutes / 60).toStringAsFixed(1)} س',
              Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayTimeline(AttendanceRecordModel record, Color mainColor) {
    DateTime? startDt = record.scheduledStart;
    DateTime? endDt = record.scheduledEnd;

    if (startDt == null || endDt == null) {
      if (record.checkIn != null) {
        startDt = record.checkIn!.subtract(const Duration(hours: 1));
        endDt = (record.checkOut ?? record.checkIn!).add(
          const Duration(hours: 1),
        );
      } else {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Text('لا توجد بيانات دوام كافية لهذا اليوم'),
          ),
        );
      }
    }

    if (endDt.isBefore(startDt)) {
      endDt = endDt.add(const Duration(days: 1));
    }

    final int totalMinutes = endDt.difference(startDt).inMinutes;
    if (totalMinutes <= 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text('لا توجد بيانات دوام كافية لهذا اليوم'),
        ),
      );
    }

    DateTime? actualIn = record.checkIn;
    DateTime? actualOut = record.checkOut;

    // Night shift check-out crossing midnight check
    if (actualIn != null && actualOut != null && actualOut.isBefore(actualIn)) {
      actualOut = actualOut.add(const Duration(days: 1));
    }

    double timeToPercent(DateTime? time) {
      if (time == null) return 0.0;
      DateTime t = time;
      if (t.isBefore(startDt!.subtract(const Duration(hours: 12)))) {
        t = t.add(const Duration(days: 1));
      }
      int diff = t.difference(startDt).inMinutes;
      if (diff < 0) diff = 0;
      if (diff > totalMinutes) diff = totalMinutes;
      return diff / totalMinutes;
    }

    double inPos = timeToPercent(actualIn);
    double outPos = timeToPercent(actualOut ?? actualIn);
    double workPercent = outPos - inPos;
    if (workPercent < 0) workPercent = 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTimeAr(startDt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textDirection: TextDirection.rtl,
            ),
            Text(
              _formatTimeAr(endDt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Container(
              height: 20,
              width: width,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  if (record.status == 'absent')
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    )
                  else if (actualIn != null)
                    Positioned(
                      right: inPos * width,
                      width: record.checkOut == null ? 10 : workPercent * width,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: mainColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (record.checkIn != null)
              Text(
                'دخول فعلي: ${_formatTimeAr(record.checkIn)}',
                style: TextStyle(fontSize: 12, color: mainColor),
                textDirection: TextDirection.rtl,
              ),
            if (record.checkOut != null)
              Text(
                'خروج فعلي: ${_formatTimeAr(record.checkOut)}',
                style: TextStyle(fontSize: 12, color: mainColor),
                textDirection: TextDirection.rtl,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekView(List<AttendanceRecordModel> records) {
    int daysToSubtract = _currentDate.weekday == 7 ? 0 : _currentDate.weekday;
    DateTime startOfWeek = _currentDate.subtract(
      Duration(days: daysToSubtract),
    );

    List<Widget> dayColumns = [];
    int presentCount = 0;
    int absentCount = 0;
    int totalLate = 0;
    int reviewCount = 0;

    final List<String> weekDaysAr = [
      'أحد',
      'إثنين',
      'ثلاثاء',
      'أربعاء',
      'خميس',
      'جمعة',
      'سبت',
    ];

    for (int i = 0; i < 7; i++) {
      DateTime dayDate = startOfWeek.add(Duration(days: i));
      var matches = records.where(
        (r) =>
            r.workDate.year == dayDate.year &&
            r.workDate.month == dayDate.month &&
            r.workDate.day == dayDate.day,
      );

      AttendanceRecordModel? rec = matches.isNotEmpty ? matches.first : null;
      Color color = _getColorForRecord(rec);

      if (rec != null) {
        if (rec.status == 'present' ||
            (rec.checkIn != null && rec.checkOut != null)) {
          presentCount++;
        } else if (rec.status == 'absent') {
          absentCount++;
        }

        bool isMissingCheckout = rec.checkIn != null && rec.checkOut == null;
        bool isMissingCheckin = rec.checkIn == null && rec.checkOut != null;
        if (rec.status == 'needs_review' ||
            isMissingCheckout ||
            isMissingCheckin) {
          reviewCount++;
        }
        totalLate += rec.lateMinutes;
      }

      dayColumns.add(
        Expanded(
          child: Column(
            children: [
              Text(weekDaysAr[i], style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '${dayDate.day}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 60,
                width: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              if (rec != null && rec.lateMinutes > 0)
                Text(
                  '${rec.lateMinutes} د',
                  style: const TextStyle(fontSize: 10, color: Colors.orange),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: dayColumns,
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildStatCard('أيام الحضور', '$presentCount', Colors.green),
            _buildStatCard('أيام الغياب', '$absentCount', Colors.red),
            _buildStatCard('إجمالي التأخير', '$totalLate د', Colors.orange),
            _buildStatCard('حالات المراجعة', '$reviewCount', Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthView(List<AttendanceRecordModel> records) {
    int daysInMonth = DateUtils.getDaysInMonth(
      _currentDate.year,
      _currentDate.month,
    );

    int presentCount = 0;
    int absentCount = 0;
    int lateDaysCount = 0;
    int totalLateMins = 0;
    int totalEarlyMins = 0;
    int reviewCount = 0;

    List<Widget> gridItems = [];

    for (int i = 1; i <= daysInMonth; i++) {
      var matches = records.where(
        (r) =>
            r.workDate.year == _currentDate.year &&
            r.workDate.month == _currentDate.month &&
            r.workDate.day == i,
      );

      AttendanceRecordModel? rec = matches.isNotEmpty ? matches.first : null;
      Color color = _getColorForRecord(rec);

      if (rec != null) {
        if (rec.status == 'present' ||
            (rec.checkIn != null && rec.checkOut != null)) {
          presentCount++;
        } else if (rec.status == 'absent') {
          absentCount++;
        }

        bool isMissingCheckout = rec.checkIn != null && rec.checkOut == null;
        bool isMissingCheckin = rec.checkIn == null && rec.checkOut != null;
        if (rec.status == 'needs_review' ||
            isMissingCheckout ||
            isMissingCheckin) {
          reviewCount++;
        }
        if (rec.lateMinutes > 0) lateDaysCount++;
        totalLateMins += rec.lateMinutes;
        totalEarlyMins += rec.earlyLeaveMinutes;
      }

      gridItems.add(
        Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$i',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: gridItems,
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildStatCard('الحضور', '$presentCount', Colors.green),
            _buildStatCard('الغياب', '$absentCount', Colors.red),
            _buildStatCard('أيام التأخير', '$lateDaysCount', Colors.orange),
            _buildStatCard('دقائق التأخير', '$totalLateMins', Colors.orange),
            _buildStatCard('خروج مبكر', '$totalEarlyMins', Colors.orange),
            _buildStatCard('مراجعة', '$reviewCount', Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
