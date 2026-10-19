import 'package:flutter/material.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

class SpeedHUD extends StatelessWidget {
  final double speedKmh;
  final int? limitKmh;
  final String? streetName;

  const SpeedHUD({
    super.key,
    this.speedKmh = 0,
    this.limitKmh,
    this.streetName,
  });

  bool get _overLimit =>
      limitKmh != null && speedKmh > (limitKmh! + 8);

  @override
  Widget build(BuildContext context) {
    final limit = limitKmh;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _overLimit ? const Color(0xFFFF5252) : kEmergencyRed,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            color: _overLimit ? const Color(0xFFFF5252) : Colors.redAccent,
            size: 28,
          ),
          const SizedBox(width: 10),
          Text(
            '${speedKmh.toStringAsFixed(0)} km/h',
            style: TextStyle(
              color: _overLimit ? const Color(0xFFFF8A80) : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          if (limit != null && limit > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _overLimit
                      ? const Color(0xFFFF5252)
                      : Colors.white24,
                ),
              ),
              child: Text(
                'máx ${limit.toStringAsFixed(0)}',
                style: TextStyle(
                  color: _overLimit
                      ? const Color(0xFFFF8A80)
                      : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
