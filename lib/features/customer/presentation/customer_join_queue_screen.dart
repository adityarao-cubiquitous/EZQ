import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../../core/widgets/ezq_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/auth_repository.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/domain/queue_entry.dart';
import '../../queue/domain/queue_status.dart';
import '../../recommendation/domain/customer_preferences.dart';
import '../../recommendation/domain/recommendation_types.dart';
import '../../tables/data/table_repository.dart';
import '../../tables/domain/restaurant_table.dart';
import '../../tables/domain/table_status.dart';
import '../data/customer_queue_repository.dart';
import '../domain/seating_preference_service.dart';
import 'customer_shell.dart';
import 'restaurant_logo.dart';

class CustomerJoinQueueScreen extends ConsumerStatefulWidget {
  const CustomerJoinQueueScreen({
    super.key,
    required this.restaurantId,
    required this.branchSlug,
    required this.restaurantName,
    required this.branchName,
  });

  final String restaurantId;
  final String branchSlug;
  final String restaurantName;
  final String branchName;

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
  bool _emptyTableOnly = false;
  bool _submitting = false;
  bool _profilePrefilled = false;
  bool _checkingActiveQueue = !kIsWeb;
  ActiveQueueConflictException? _activeQueueConflict;
  late SeatingEta _eta;

  @override
  void initState() {
    super.initState();
    _eta = ref
        .read(seatingPreferenceServiceProvider)
        .computeEtaEstimate(partySize: _partySize);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _prefillMobileProfile(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPartySizeChanged(int value) {
    setState(() {
      _partySize = value;
      if (value > 6) _emptyTableOnly = false;
      _eta = ref
          .read(seatingPreferenceServiceProvider)
          .computeEtaEstimate(partySize: value);
    });
  }

  Future<void> _prefillMobileProfile() async {
    if (kIsWeb || _profilePrefilled || !mounted) return;
    _profilePrefilled = true;

    final authRepository = ref.read(customerPhoneAuthRepositoryProvider);
    final user = authRepository.currentUser();
    var debugPhone = ref.read(debugCustomerPhoneSessionProvider).value;
    debugPhone ??= await ref
        .read(debugCustomerSessionStoreProvider)
        .loadPhone();
    if (debugPhone != null) {
      ref.read(debugCustomerPhoneSessionProvider).value = debugPhone;
    }
    final debugProfile = ref.read(debugCustomerNameProfileProvider).value;

    CustomerNameProfile? profile = debugProfile;
    if (profile == null && (user != null || debugPhone != null)) {
      try {
        profile = await ref
            .read(customerProfileRepositoryProvider)
            .loadNameProfile(user, phoneNumber: debugPhone);
      } catch (_) {
        profile = null;
      }
    }
    if (!mounted) return;

    final displayName = profile?.displayName.trim() ?? '';
    final phone = _mobileNumberForForm(user?.phoneNumber ?? debugPhone);

    if (displayName.isNotEmpty && _nameController.text.trim().isEmpty) {
      _nameController.text = displayName;
    }
    if (phone != null && _phoneController.text.trim() == '98765 43210') {
      _phoneController.text = phone;
    }

    final queuePhone = user?.phoneNumber ?? debugPhone;
    if (queuePhone == null || queuePhone.trim().isEmpty) {
      setState(() => _checkingActiveQueue = false);
      return;
    }
    try {
      final activeQueue = await ref
          .read(customerQueueRepositoryProvider)
          .findActiveQueueEntry(phone: queuePhone, customerId: user?.uid);
      if (!mounted) return;
      setState(() {
        _checkingActiveQueue = false;
        _activeQueueConflict = activeQueue;
      });
      if (activeQueue != null) {
        await _showActiveQueueDialog(activeQueue);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingActiveQueue = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not check your active queue: $error')),
      );
    }
  }

  Future<void> _showActiveQueueDialog(
    ActiveQueueConflictException activeQueue,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.confirmation_number_outlined,
          color: AppColors.deepTeal,
          size: 36,
        ),
        title: const Text('You’re already in a queue'),
        content: Text(
          'Your token ${activeQueue.tokenCode} is still active. '
          'To join another restaurant, cancel your current queue or wait until you are seated.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go(activeQueue.statusRoute);
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('View my current queue'),
          ),
        ],
      ),
    );
  }

  String? _mobileNumberForForm(String? phone) {
    final trimmed = phone?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return trimmed;
  }

  // Returns null if the user cancelled (do not join).
  Future<CustomerPreferences?> _resolveSeatingPreference() async {
    final now = DateTime.now();

    final canChooseEmptyTable = _partySize <= 6;

    if (!canChooseEmptyTable || !_emptyTableOnly) {
      return CustomerPreferences(
        seatingPreference: SeatingPreference.anyAvailable,
        acceptedLongerWait: false,
        etaShared: _eta.sharedMinutes,
        etaEmptyTable: _eta.emptyTableMinutes,
        selectedAt: now,
      );
    }

    final confirmed = await _showEmptyTableConfirmDialog();
    if (!mounted || confirmed == null) return null;

    if (confirmed) {
      return CustomerPreferences(
        seatingPreference: SeatingPreference.emptyTableOnly,
        acceptedLongerWait: true,
        etaShared: _eta.sharedMinutes,
        etaEmptyTable: _eta.emptyTableMinutes,
        selectedAt: now,
      );
    }

    // User chose "Allow Shared Seating" in the confirmation dialog.
    setState(() => _emptyTableOnly = false);
    return CustomerPreferences(
      seatingPreference: SeatingPreference.anyAvailable,
      acceptedLongerWait: false,
      etaShared: _eta.sharedMinutes,
      etaEmptyTable: _eta.emptyTableMinutes,
      selectedAt: now,
    );
  }

  // Returns true  → Wait for Empty Table
  //         false → Allow Shared Seating
  //         null  → Cancel
  Future<bool?> _showEmptyTableConfirmDialog() {
    final eta = _eta;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: const Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              color: AppColors.warningOrange,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'You may wait longer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Waiting for an exclusively empty table typically takes '
          '~${eta.emptyTableMinutes} min, compared to ~${eta.sharedMinutes} min '
          'for shared seating.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.55,
            color: Color(0xFF3E484F),
          ),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepTeal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Wait for Empty Table',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepTeal,
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Allow Shared Seating',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedText,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinQueue() async {
    final existingQueue = _activeQueueConflict;
    if (existingQueue != null) {
      await _showActiveQueueDialog(existingQueue);
      return;
    }
    if (_checkingActiveQueue) return;
    if (!_formKey.currentState!.validate()) return;

    final prefs = await _resolveSeatingPreference();
    if (!mounted || prefs == null) return;

    setState(() => _submitting = true);
    final repository = ref.read(customerQueueRepositoryProvider);
    final user = ref.read(customerPhoneAuthRepositoryProvider).currentUser();
    try {
      final result = await repository.joinQueue(
        JoinQueueRequest(
          restaurantId: widget.restaurantId,
          branchId: widget.branchSlug,
          customerName: _nameController.text,
          phone: _phoneController.text,
          partySize: _partySize,
          notes: _notesController.text,
          appSource: kIsWeb ? 'web' : 'mobile_app',
          customerId: kIsWeb ? null : user?.uid,
          sessionType: kIsWeb
              ? 'web_guest'
              : user == null
              ? 'mobile_debug'
              : 'mobile_phone_auth',
          enforceSingleActiveQueue: true,
          customerPreferences: prefs,
        ),
      );
      if (!mounted) return;
      ref.invalidate(currentCustomerVisitProvider);
      context.go(
        FirestorePaths.customerStatusRoute(
          widget.restaurantId,
          widget.branchSlug,
          result.queueEntryId,
        ),
      );
    } on ActiveQueueConflictException catch (error) {
      if (!mounted) return;
      setState(() => _activeQueueConflict = error);
      await _showActiveQueueDialog(error);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveEtaState = kIsWeb
        ? null
        : ref.watch(
            _liveSeatingEtaProvider((
              restaurantId: widget.restaurantId,
              branchId: widget.branchSlug,
              partySize: _partySize,
            )),
          );
    final liveEta = liveEtaState?.asData?.value;
    final eta = liveEta ?? _eta;

    return CustomerShell(
      restaurantId: widget.restaurantId,
      branchId: widget.branchSlug,
      activeTab: CustomerTab.join,
      appBackRoute: '/app/home',
      footer: const CustomerFooter(),
      showBottomNav: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            _HeroHeader(
              restaurantName: widget.restaurantName,
              branchName: widget.branchName,
            ),
            const SizedBox(height: 24),
            _JoinQueueCard(
              formKey: _formKey,
              nameController: _nameController,
              phoneController: _phoneController,
              notesController: _notesController,
              partySize: _partySize,
              onPartySizeChanged: _onPartySizeChanged,
              emptyTableOnly: _emptyTableOnly,
              onEmptyTableOnlyChanged: (v) =>
                  setState(() => _emptyTableOnly = v),
              eta: eta,
              isLiveEta: liveEta != null,
              onJoin:
                  _submitting ||
                      _checkingActiveQueue ||
                      _activeQueueConflict != null
                  ? null
                  : _joinQueue,
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 18),
              const _FeaturedWaitCard(),
            ],
            SizedBox(height: kIsWeb ? 132 : 28),
          ],
        ),
      ),
    );
  }
}

final _liveSeatingEtaProvider = StreamProvider.autoDispose
    .family<
      SeatingEta,
      ({String restaurantId, String branchId, int partySize})
    >((ref, args) {
      final queueRepository = ref.watch(queueRepositoryProvider);
      final tableRepository = ref.watch(tableRepositoryProvider);
      final controller = StreamController<SeatingEta>();
      List<QueueEntry>? latestQueue;
      List<RestaurantTable>? latestTables;

      void emitIfReady() {
        final queue = latestQueue;
        final tables = latestTables;
        if (queue == null || tables == null || controller.isClosed) return;
        controller.add(
          _computeLiveEta(
            queue: queue,
            tables: tables,
            partySize: args.partySize,
          ),
        );
      }

      final queueSubscription = queueRepository
          .watchTodayQueue(
            restaurantId: args.restaurantId,
            branchId: args.branchId,
          )
          .listen((queue) {
            latestQueue = queue;
            emitIfReady();
          }, onError: controller.addError);

      final tableSubscription = tableRepository
          .watchTables(restaurantId: args.restaurantId, branchId: args.branchId)
          .listen((tables) {
            latestTables = tables;
            emitIfReady();
          }, onError: controller.addError);

      ref.onDispose(() {
        queueSubscription.cancel();
        tableSubscription.cancel();
        controller.close();
      });

      return controller.stream;
    });

SeatingEta _computeLiveEta({
  required List<QueueEntry> queue,
  required List<RestaurantTable> tables,
  required int partySize,
}) {
  final waitingCount = queue
      .where((entry) => entry.status == QueueStatus.waiting)
      .length;
  final sharedReadySlots = tables
      .where((table) => _tableCanFitParty(table, partySize, allowShared: true))
      .length;
  final emptyReadySlots = tables
      .where((table) => _tableCanFitParty(table, partySize, allowShared: false))
      .length;

  final sharedPosition = (waitingCount + 1 - sharedReadySlots).clamp(0, 99);
  final emptyPosition = (waitingCount + 1 - emptyReadySlots).clamp(0, 99);
  final partySizePremium = partySize > 4 ? 6 : 0;
  final sharedMinutes = sharedPosition == 0
      ? 5
      : (8 + sharedPosition * 5 + partySizePremium).clamp(5, 75).toInt();
  final rawEmptyMinutes = emptyPosition == 0
      ? 6
      : (10 + emptyPosition * 6 + partySizePremium).clamp(6, 100).toInt();
  final emptyMinutes = rawEmptyMinutes <= sharedMinutes
      ? (sharedMinutes + 8).clamp(6, 100).toInt()
      : rawEmptyMinutes;

  return SeatingEta(
    sharedMinutes: sharedMinutes,
    emptyTableMinutes: emptyMinutes,
  );
}

bool _tableCanFitParty(
  RestaurantTable table,
  int partySize, {
  required bool allowShared,
}) {
  if (table.status == TableStatus.available) return table.capacity >= partySize;
  if (!allowShared || table.status != TableStatus.occupied) return false;
  final currentPartySize = table.currentPartySize ?? 0;
  if (currentPartySize <= 0) return false;
  return table.capacity - currentPartySize >= partySize;
}

// ─────────────────────────── Hero header ─────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.restaurantName, required this.branchName});

  final String restaurantName;
  final String branchName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const RestaurantLogo(size: 66),
        const SizedBox(height: 14),
        StatusBadge(
          label: '$branchName Branch',
          foreground: const Color(0xFF006B79),
          background: const Color(0x8090EAFD),
        ),
        const SizedBox(height: 14),
        Text(
          restaurantName,
          style: const TextStyle(
            color: AppColors.navyText,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            height: 34 / 27,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
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

// ─────────────────────────── Join form card ───────────────────────────────────

class _JoinQueueCard extends StatelessWidget {
  const _JoinQueueCard({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.notesController,
    required this.partySize,
    required this.onPartySizeChanged,
    required this.emptyTableOnly,
    required this.onEmptyTableOnlyChanged,
    required this.eta,
    required this.isLiveEta,
    required this.onJoin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController notesController;
  final int partySize;
  final ValueChanged<int> onPartySizeChanged;
  final bool emptyTableOnly;
  final ValueChanged<bool> onEmptyTableOnlyChanged;
  final SeatingEta eta;
  final bool isLiveEta;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26BDC8D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A12A9DC),
            blurRadius: 28,
            offset: Offset(0, 16),
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
            if (partySize <= 6) ...[
              const SizedBox(height: 14),
              _SeatingEtaRow(
                eta: eta,
                isLive: isLiveEta,
                emptyTableOnly: emptyTableOnly,
                onEmptyTableOnlyChanged: onEmptyTableOnlyChanged,
              ),
            ],
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
            if (kIsWeb) ...[
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/admin/login'),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Manager Login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepTeal,
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Party size selector ─────────────────────────────

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
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primaryTeal,
                width: 1.5,
              ),
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

// ─────────────────────────── F1: ETA row ─────────────────────────────────────

class _SeatingEtaRow extends StatelessWidget {
  const _SeatingEtaRow({
    required this.eta,
    required this.isLive,
    required this.emptyTableOnly,
    required this.onEmptyTableOnlyChanged,
  });

  final SeatingEta eta;
  final bool isLive;
  final bool emptyTableOnly;
  final ValueChanged<bool> onEmptyTableOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SeatingChoiceTag(emptyTableOnly: emptyTableOnly),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _EtaCard(
                label: 'Shared seating',
                minutes: eta.sharedMinutes,
                isLive: isLive,
                active: !emptyTableOnly,
                onTap: () => onEmptyTableOnlyChanged(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EtaCard(
                label: 'Empty table only',
                minutes: eta.emptyTableMinutes,
                isLive: isLive,
                active: emptyTableOnly,
                onTap: () => onEmptyTableOnlyChanged(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SeatingChoiceTag extends StatelessWidget {
  const _SeatingChoiceTag({required this.emptyTableOnly});

  final bool emptyTableOnly;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 14,
              color: emptyTableOnly
                  ? AppColors.warningOrange
                  : AppColors.deepTeal,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Choose one option',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: emptyTableOnly
                      ? const Color(0xFF8A5A00)
                      : AppColors.deepTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                emptyTableOnly ? 'Empty selected' : 'Shared selected',
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtaCard extends StatefulWidget {
  const _EtaCard({
    required this.label,
    required this.minutes,
    required this.isLive,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final bool isLive;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_EtaCard> createState() => _EtaCardState();
}

class _EtaCardState extends State<_EtaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = widget.isLive
                ? (0.5 + 0.5 * math.sin(_pulseController.value * math.pi * 2))
                : 0.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.active
                    ? AppColors.softSurface
                    : AppColors.softerSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.active
                      ? AppColors.primaryTeal.withValues(
                          alpha: 0.55 + pulse * 0.22,
                        )
                      : AppColors.line.withValues(alpha: 0.45),
                  width: widget.active ? 1.5 : 1.0,
                ),
                boxShadow: widget.active
                    ? [
                        BoxShadow(
                          color: AppColors.primaryTeal.withValues(
                            alpha: widget.isLive ? 0.12 + pulse * 0.08 : 0.09,
                          ),
                          blurRadius: widget.isLive ? 14 + pulse * 8 : 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.active
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: widget.active
                        ? AppColors.primaryTeal
                        : AppColors.mutedText,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.active
                            ? AppColors.deepTeal
                            : AppColors.mutedText,
                        letterSpacing: 0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isLive) const _LiveEtaDot(),
                ],
              ),
              const SizedBox(height: 3),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '~${widget.minutes} min',
                  key: ValueKey(widget.minutes),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: widget.active
                        ? AppColors.navyText
                        : AppColors.mutedText,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveEtaDot extends StatelessWidget {
  const _LiveEtaDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(left: 4),
      decoration: const BoxDecoration(
        color: AppColors.successGreen,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Color(0x6610B981), blurRadius: 8, spreadRadius: 1),
        ],
      ),
    );
  }
}

// ─────────────────────────── Featured wait card ───────────────────────────────

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
