import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../../core/widgets/ezq_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/utils/validators.dart';
import '../data/customer_queue_repository.dart';
import 'customer_shell.dart';
import 'restaurant_logo.dart';

class CustomerJoinQueueScreen extends ConsumerStatefulWidget {
  const CustomerJoinQueueScreen({
    super.key,
    required this.restaurantId,
    required this.branchId,
  });

  final String restaurantId;
  final String branchId;

  @override
  ConsumerState<CustomerJoinQueueScreen> createState() =>
      _CustomerJoinQueueScreenState();
}

class _CustomerJoinQueueScreenState
    extends ConsumerState<CustomerJoinQueueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '98765 43210');
  final _notesController = TextEditingController();
  int _partySize = 4;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _joinQueue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final repository = ref.read(customerQueueRepositoryProvider);
    final result = await repository.joinQueue(
      JoinQueueRequest(
        restaurantId: widget.restaurantId,
        branchId: widget.branchId,
        customerName: _nameController.text,
        phone: _phoneController.text,
        partySize: _partySize,
        notes: _notesController.text,
      ),
    );
    if (!mounted) return;
    context.go(
      '/customer/${widget.restaurantId}/${widget.branchId}/status/${result.queueEntryId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      restaurantId: widget.restaurantId,
      branchId: widget.branchId,
      activeTab: CustomerTab.join,
      footer: const CustomerFooter(),
      showBottomNav: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            const _HeroHeader(),
            const SizedBox(height: 24),
            _JoinQueueCard(
              formKey: _formKey,
              nameController: _nameController,
              phoneController: _phoneController,
              notesController: _notesController,
              partySize: _partySize,
              onPartySizeChanged: (value) => setState(() => _partySize = value),
              onJoin: _submitting ? null : _joinQueue,
            ),
            const SizedBox(height: 18),
            const _FeaturedWaitCard(),
            const SizedBox(height: 132),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        RestaurantLogo(size: 66),
        SizedBox(height: 14),
        StatusBadge(
          label: 'Indiranagar Branch',
          foreground: Color(0xFF006B79),
          background: Color(0x8090EAFD),
        ),
        SizedBox(height: 14),
        Text(
          'The Spice House',
          style: TextStyle(
            color: AppColors.navyText,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            height: 34 / 27,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Skip the wait, join the queue.',
          style: TextStyle(
            color: Color(0xFF3E484F),
            fontSize: 17,
            height: 25 / 17,
          ),
        ),
      ],
    );
  }
}

class _JoinQueueCard extends StatelessWidget {
  const _JoinQueueCard({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.notesController,
    required this.partySize,
    required this.onPartySizeChanged,
    required this.onJoin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController notesController;
  final int partySize;
  final ValueChanged<int> onPartySizeChanged;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x26BDC8D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1212A9DC),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            EzqTextField(
              label: 'Your Name',
              hintText: 'Enter your name',
              controller: nameController,
              validator: Validators.requiredName,
            ),
            const SizedBox(height: 18),
            EzqTextField(
              label: 'Mobile Number',
              hintText: '98765 43210',
              prefixText: '+91  ',
              controller: phoneController,
              keyboardType: TextInputType.phone,
              validator: Validators.indianMobile,
            ),
            const SizedBox(height: 18),
            _PartySizeSelector(value: partySize, onChanged: onPartySizeChanged),
            const SizedBox(height: 18),
            EzqTextField(
              label: 'Special Notes (Optional)',
              hintText: 'e.g. Need high chair, birthday celebration',
              controller: notesController,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            EzqButton(
              label: 'Join Queue',
              icon: Icons.arrow_forward_rounded,
              large: true,
              onPressed: onJoin,
            ),
            const SizedBox(height: 14),
            const Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: Color(0x993E484F),
                ),
                Text(
                  'No app install required',
                  style: TextStyle(
                    color: Color(0xB33E484F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartySizeSelector extends StatelessWidget {
  const _PartySizeSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = List<int>.generate(20, (index) => index + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'Party Size',
            style: TextStyle(
              color: Color(0xFF3E484F),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.28,
            ),
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.groups_outlined),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryTeal),
            ),
          ),
          items: [
            for (final option in options)
              DropdownMenuItem<int>(
                value: option,
                child: Text(
                  option == 1 ? '1 person' : '$option people',
                  style: const TextStyle(
                    color: AppColors.navyText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
          onChanged: (nextValue) {
            if (nextValue != null) onChanged(nextValue);
          },
        ),
      ],
    );
  }
}

class _FeaturedWaitCard extends StatefulWidget {
  const _FeaturedWaitCard();

  @override
  State<_FeaturedWaitCard> createState() => _FeaturedWaitCardState();
}

class _FeaturedWaitCardState extends State<_FeaturedWaitCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.inkBlue,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A00394D),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _WaitingLoungeAnimation(animation: _controller),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xB0001B24),
                  Color(0x3300394D),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final glow =
                    0.55 + 0.25 * math.sin(_controller.value * math.pi * 2);
                return Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF001A22).withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08 + glow * 0.08),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live wait estimate',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '~ 15-20 Mins',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingLoungeAnimation extends StatelessWidget {
  const _WaitingLoungeAnimation({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return CustomPaint(
            painter: _WaitingLoungePainter(progress: animation.value),
          );
        },
      ),
    );
  }
}

class _WaitingLoungePainter extends CustomPainter {
  const _WaitingLoungePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF071C23), Color(0xFF00394D), Color(0xFF0B2331)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    _drawAmbientGlow(canvas, size);
    _drawWindow(canvas, size);
    _drawWaitingLine(canvas, size);
    _drawTable(canvas, size);
    _drawQueueDots(canvas, size);
  }

  void _drawAmbientGlow(Canvas canvas, Size size) {
    final sweepX = -size.width * 0.2 + size.width * 1.4 * progress;
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF7FD9EB).withValues(alpha: 0.32),
              const Color(0xFF7FD9EB).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(sweepX, size.height * 0.18),
              radius: size.width * 0.42,
            ),
          );
    canvas.drawCircle(
      Offset(sweepX, size.height * 0.18),
      size.width * 0.42,
      glowPaint,
    );

    final warmPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFF59E0B).withValues(alpha: 0.18),
              const Color(0xFFF59E0B).withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.18, size.height * 0.1),
              radius: size.width * 0.48,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.1),
      size.width * 0.48,
      warmPaint,
    );
  }

  void _drawWindow(Canvas canvas, Size size) {
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.62, 22, size.width * 0.28, 86),
      const Radius.circular(12),
    );
    final windowPaint = Paint()..color = Colors.white.withValues(alpha: 0.78);
    canvas.drawRRect(windowRect, windowPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF12A9DC).withValues(alpha: 0.42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.645, 34, size.width * 0.23, 56),
        const Radius.circular(4),
      ),
      borderPaint,
    );
  }

  void _drawWaitingLine(Canvas canvas, Size size) {
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(28, size.height * 0.48, size.width * 0.46, 7),
      const Radius.circular(99),
    );
    canvas.drawRRect(
      trackRect,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    final movingWidth = size.width * 0.18;
    final x = 28 + (size.width * 0.46 - movingWidth) * progress;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height * 0.48, movingWidth, 7),
        const Radius.circular(99),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFF7FD9EB)],
        ).createShader(Rect.fromLTWH(x, size.height * 0.48, movingWidth, 7)),
    );
  }

  void _drawTable(Canvas canvas, Size size) {
    final tableCenter = Offset(size.width * 0.72, size.height * 0.64);
    final tablePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: tableCenter, width: 78, height: 28),
      tablePaint,
    );

    final chairPaint = Paint()..color = Colors.white.withValues(alpha: 0.24);
    for (final angle in [0.0, math.pi * 0.5, math.pi, math.pi * 1.5]) {
      final offset = Offset(math.cos(angle) * 52, math.sin(angle) * 31);
      canvas.drawCircle(tableCenter + offset, 12, chairPaint);
    }
  }

  void _drawQueueDots(Canvas canvas, Size size) {
    final baseY = size.height * 0.24;
    for (var i = 0; i < 4; i++) {
      final phase = (progress + i * 0.18) % 1;
      final lift = math.sin(phase * math.pi * 2) * 5;
      final alpha = 0.34 + 0.28 * math.sin(phase * math.pi * 2).abs();
      final center = Offset(38 + i * 28, baseY + lift);
      canvas.drawCircle(
        center,
        i == 0 ? 7 : 5.5,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        center,
        12 + 5 * phase,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(
            0xFF7FD9EB,
          ).withValues(alpha: 0.18 * (1 - phase)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaitingLoungePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
