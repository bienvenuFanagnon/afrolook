// widgets/crypto_chart_widget.dart
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../models/crypto_model.dart';

class CryptoChartWidget extends StatefulWidget {
  final List<PriceHistory> priceHistory;
  final String selectedTimeFrame;
  final bool isInteractive;

  const CryptoChartWidget({
    Key? key,
    required this.priceHistory,
    required this.selectedTimeFrame,
    this.isInteractive = true,
  }) : super(key: key);

  @override
  _CryptoChartWidgetState createState() => _CryptoChartWidgetState();
}

class _CryptoChartWidgetState extends State<CryptoChartWidget> {
  late List<PriceHistory> _displayedData;
  double? _selectedPrice;
  DateTime? _selectedTime;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _filterData();
  }

  @override
  void didUpdateWidget(covariant CryptoChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.priceHistory != widget.priceHistory ||
        oldWidget.selectedTimeFrame != widget.selectedTimeFrame) {
      _filterData();
    }
  }

  void _filterData() {
    final now = DateTime.now();
    List<PriceHistory> filtered = [];

    switch (widget.selectedTimeFrame) {
      case '1H':
        final oneHourAgo = now.subtract(Duration(hours: 1));
        filtered = widget.priceHistory
            .where((point) => point.timestamp.isAfter(oneHourAgo))
            .toList();
        break;
      case '24H':
        final oneDayAgo = now.subtract(Duration(days: 1));
        filtered = widget.priceHistory
            .where((point) => point.timestamp.isAfter(oneDayAgo))
            .toList();
        break;
      case '1S':
        final oneWeekAgo = now.subtract(Duration(days: 7));
        filtered = widget.priceHistory
            .where((point) => point.timestamp.isAfter(oneWeekAgo))
            .toList();
        break;
      case '1M':
        final oneMonthAgo = now.subtract(Duration(days: 30));
        filtered = widget.priceHistory
            .where((point) => point.timestamp.isAfter(oneMonthAgo))
            .toList();
        break;
      case '1A':
        final oneYearAgo = now.subtract(Duration(days: 365));
        filtered = widget.priceHistory
            .where((point) => point.timestamp.isAfter(oneYearAgo))
            .toList();
        break;
      default:
        filtered = widget.priceHistory;
    }

    // Trier par timestamp
    filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    setState(() {
      _displayedData = filtered;
      _showDetails = false;
    });
  }

  void _onChartTap(Offset localPosition, Size chartSize) {
    if (!widget.isInteractive || _displayedData.isEmpty) return;

    final index = (_displayedData.length * (localPosition.dx / chartSize.width)).clamp(0, _displayedData.length - 1).toInt();
    final point = _displayedData[index];

    setState(() {
      _selectedPrice = point.price;
      _selectedTime = point.timestamp;
      _showDetails = true;
    });
  }

  String _getTimeFormat() {
    switch (widget.selectedTimeFrame) {
      case '1H':
        return 'HH:mm';
      case '24H':
        return 'HH:mm';
      case '1S':
        return 'E dd';
      case '1M':
        return 'dd/MM';
      case '1A':
        return 'MM/yyyy';
      default:
        return 'dd/MM HH:mm';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_displayedData.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Column(
        children: [
          // Header avec prix sélectionné
          if (_showDetails && _selectedPrice != null && _selectedTime != null)
            _buildPriceHeader(),

          // Graphique
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(details.globalPosition);
                final chartSize = renderBox.size;
                _onChartTap(localPosition, chartSize);
              },
              child: CustomPaint(
                painter: _CryptoChartPainter(
                  data: _displayedData,
                  selectedIndex: _showDetails ? _displayedData.indexWhere(
                          (point) => point.price == _selectedPrice && point.timestamp == _selectedTime
                  ) : -1,
                  timeFormat: _getTimeFormat(),
                ),
              ),
            ),
          ),

          // Légende timeframe
          _buildTimeFrameLegend(),
        ],
      ),
    );
  }

  Widget _buildPriceHeader() {
    final isPositive = _selectedPrice! >= (_displayedData.first.price);

    return Container(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text(
            '${_selectedPrice!.toStringAsFixed(2)} FCFA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(_selectedTime!),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPositive
                  ? Color(0xFF00B894).withOpacity(0.2)
                  : Color(0xFFFF4D4D).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPositive ? '▲ Hausse' : '▼ Baisse',
              style: TextStyle(
                color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFrameLegend() {
    return Container(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getStartTimeLabel(),
            style: TextStyle(color: Colors.grey[400], fontSize: 10),
          ),
          Text(
            _getEndTimeLabel(),
            style: TextStyle(color: Colors.grey[400], fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _getStartTimeLabel() {
    if (_displayedData.isEmpty) return '';
    return DateFormat(_getTimeFormat()).format(_displayedData.first.timestamp);
  }

  String _getEndTimeLabel() {
    if (_displayedData.isEmpty) return '';
    return DateFormat(_getTimeFormat()).format(_displayedData.last.timestamp);
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.chart_2, color: Color(0xFF00B894), size: 40),
            SizedBox(height: 8),
            Text(
              'Données historiques indisponibles',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CryptoChartPainter extends CustomPainter {
  final List<PriceHistory> data;
  final int selectedIndex;
  final String timeFormat;

  _CryptoChartPainter({
    required this.data,
    required this.selectedIndex,
    required this.timeFormat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final prices = data.map((point) => point.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    final path = Path();
    final pointPaint = Paint()
      ..color = Color(0xFF00B894)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = Color(0xFF00B894).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final selectedPointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Dessiner la ligne
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i].price - minPrice) / priceRange) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Remplir la zone sous la courbe
    final fillPath = Path()..addPath(path, Offset.zero);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, pointPaint);

    // Dessiner le point sélectionné
    if (selectedIndex >= 0 && selectedIndex < data.length) {
      final x = (selectedIndex / (data.length - 1)) * size.width;
      final y = size.height - ((data[selectedIndex].price - minPrice) / priceRange) * size.height;

      canvas.drawCircle(Offset(x, y), 4, selectedPointPaint);
      canvas.drawCircle(Offset(x, y), 8, selectedPointPaint..color = Colors.white.withOpacity(0.3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}