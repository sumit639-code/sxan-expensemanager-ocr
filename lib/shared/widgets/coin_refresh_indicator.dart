import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';

/// Modern, tactile pull-to-refresh widget with a 3D spinning/flipping coin animation.
///
/// When the user pulls down at the top of the scrollable content, a 3D metallic coin
/// drops down from above the top edge, rotating and flipping in 3D perspective along the
/// Y-axis. Upon release past the threshold, the coin spins continuously in a glowing
/// frosted capsule while [onRefresh] executes, then smoothly slides back up out of view.
class CoinRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? coinAccentColor;
  final double threshold;

  const CoinRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.coinAccentColor,
    this.threshold = 72.0,
  });

  @override
  State<CoinRefreshIndicator> createState() => _CoinRefreshIndicatorState();
}

class _CoinRefreshIndicatorState extends State<CoinRefreshIndicator>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _settleController;
  late Animation<double> _settleAnimation;

  double _dragDistance = 0.0;
  bool _isRefreshing = false;
  bool _isAtTop = true;
  bool _hasHapticFired = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _settleController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      if (notification.metrics.pixels <= 0) {
        _isAtTop = true;
      } else {
        _isAtTop = false;
      }
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isRefreshing) return;
    _hasHapticFired = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isRefreshing) return;

    if (_isAtTop && event.delta.dy > 0 || _dragDistance > 0) {
      final newDistance = (_dragDistance + event.delta.dy * 0.48).clamp(0.0, 150.0);
      if (newDistance != _dragDistance) {
        setState(() {
          _dragDistance = newDistance;
        });

        if (_dragDistance >= widget.threshold && !_hasHapticFired) {
          _hasHapticFired = true;
          HapticFeedback.mediumImpact();
        } else if (_dragDistance < widget.threshold && _hasHapticFired) {
          _hasHapticFired = false;
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isRefreshing) return;

    if (_dragDistance >= widget.threshold) {
      _startRefresh();
    } else if (_dragDistance > 0) {
      _animateDismiss();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!_isRefreshing && _dragDistance > 0) {
      _animateDismiss();
    }
  }

  void _animateDismiss() {
    _settleAnimation = Tween<double>(
      begin: _dragDistance,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _settleController,
      curve: Curves.easeOutCubic,
    ))..addListener(() {
        setState(() {
          _dragDistance = _settleAnimation.value;
        });
      });

    _settleController.forward(from: 0.0);
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    _settleAnimation = Tween<double>(
      begin: _dragDistance,
      end: widget.threshold,
    ).animate(CurvedAnimation(
      parent: _settleController,
      curve: Curves.easeOutBack,
    ))..addListener(() {
        setState(() {
          _dragDistance = _settleAnimation.value;
        });
      });

    await _settleController.forward(from: 0.0);
    _spinController.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        HapticFeedback.lightImpact();
        _spinController.stop();

        _settleAnimation = Tween<double>(
          begin: widget.threshold,
          end: 0.0,
        ).animate(CurvedAnimation(
          parent: _settleController,
          curve: Curves.easeInOutCubic,
        ))..addListener(() {
            setState(() {
              _dragDistance = _settleAnimation.value;
            });
          });

        await _settleController.forward(from: 0.0);

        if (mounted) {
          setState(() {
            _isRefreshing = false;
            _dragDistance = 0.0;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = widget.coinAccentColor ?? Theme.of(context).colorScheme.primary;

    // Pull progress 0.0 to 1.0+
    final progress = (_dragDistance / widget.threshold).clamp(0.0, 2.0);
    final isVisible = _dragDistance > 0.5 || _isRefreshing;

    // Compute 3D rotation angle: during drag, flips proportionally; during refresh, spins continuously
    final double coinAngle = _isRefreshing
        ? _spinController.value * 2 * math.pi
        : progress * math.pi * 2.5;

    // Top offset: drops down from -56px offscreen to resting position
    final double topPosition = -56.0 + (_dragDistance * 0.95);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Content
            widget.child,

            // Floating 3D Coin Indicator coming from top
            if (isVisible)
              Positioned(
                top: topPosition,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xE61E1B2E)
                          : const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: progress >= 1.0
                            ? const Color(0xFFFFDF70).withValues(alpha: 0.8)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : primaryAccent.withValues(alpha: 0.2)),
                        width: progress >= 1.0 ? 1.8 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB800).withValues(
                            alpha: progress >= 1.0 ? 0.35 : 0.15,
                          ),
                          blurRadius: progress >= 1.0 ? 18 : 10,
                          offset: const Offset(0, 4),
                        ),
                        if (isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedCoinWidget(
                          size: 32,
                          rotationAngle: coinAngle,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isRefreshing
                              ? 'Syncing ledger...'
                              : (progress >= 1.0
                                  ? 'Release to refresh'
                                  : 'Pull to refresh'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A standalone modern coin widget that flips/spins in 3D, displaying a currency/rupee coin with gold/purple gradient and metallic sheen.
class AnimatedCoinWidget extends StatelessWidget {
  final double size;
  final double rotationAngle; // 0 to 2*pi
  final String symbol;

  const AnimatedCoinWidget({
    super.key,
    this.size = 36,
    this.rotationAngle = 0,
    this.symbol = '₹',
  });

  @override
  Widget build(BuildContext context) {
    // 3D perspective transformation along Y axis
    final cosAngle = math.cos(rotationAngle);
    final scaleX = cosAngle.abs().clamp(0.06, 1.0);
    final isFaceFront = cosAngle >= 0;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0024) // realistic 3D perspective depth
        ..scale(scaleX, 1.0, 1.0),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isFaceFront
                ? const [
                    Color(0xFFFFEE88),
                    Color(0xFFFFC000),
                    Color(0xFFD98200),
                  ]
                : const [
                    Color(0xFFD98200),
                    Color(0xFFFFC000),
                    Color(0xFFFFF099),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB800).withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFFFF7C2),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: size * 0.78,
          height: size * 0.78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFB57000).withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: size * 0.44,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF4D2B00),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// A modern action button displaying a flipping coin on press, triggering a data refresh with haptic feedback.
class CoinRefreshActionButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final String tooltip;

  const CoinRefreshActionButton({
    super.key,
    required this.onRefresh,
    this.tooltip = 'Refresh',
  });

  @override
  State<CoinRefreshActionButton> createState() =>
      _CoinRefreshActionButtonState();
}

class _CoinRefreshActionButtonState extends State<CoinRefreshActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _triggerRefresh() async {
    if (_isRefreshing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isRefreshing = true);
    _spinController.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spinController.stop();
        _spinController.reset();
        setState(() => _isRefreshing = false);
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: _triggerRefresh,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : primaryAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : primaryAccent.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _spinController,
                builder: (context, child) {
                  return AnimatedCoinWidget(
                    size: 24,
                    rotationAngle: _spinController.value * 2 * math.pi,
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                _isRefreshing ? 'Syncing...' : 'Sync',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : primaryAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
