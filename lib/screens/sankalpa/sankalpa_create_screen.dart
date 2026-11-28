import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sankalpa.dart';
import '../../providers/sankalpa_provider.dart';
import '../../core/feedback/app_messages.dart';
import '../../core/navigation/haptic_back_button.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/screen_body.dart';
import '../../theme/app_metrics.dart';

class SankalpaCreateScreen extends ConsumerStatefulWidget {
  const SankalpaCreateScreen({super.key});

  @override
  ConsumerState<SankalpaCreateScreen> createState() =>
      _SankalpaCreateScreenState();
}

class _SankalpaCreateScreenState extends ConsumerState<SankalpaCreateScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customDaysController = TextEditingController(text: '40');
  String? _titleError;

  int _selectedDuration = 40; // Default Mandala
  TimeOfDay _selectedTime = const TimeOfDay(hour: 6, minute: 0); // Default 6 AM

  final List<int> _durationPresets = [11, 21, 40, 48];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await M3ETimePicker.show(
      context,
      initialTime: M3ETime(
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      ),
    );
    if (picked == null || !mounted) return;
    final time = TimeOfDay(hour: picked.hour, minute: picked.minute);
    if (time != _selectedTime) setState(() => _selectedTime = time);
  }

  Future<void> _showCustomDaysDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: _selectedDuration.toString(),
    );

    final result = await AppDialog.show<int>(
      context,
      title: l10n.customDays,
      content: M3ETextField(
        controller: controller,
        keyboardType: TextInputType.number,
        label: l10n.durationDays,
      ),
      actions: [
        AppButton(
          style: M3EButtonStyle.text,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(l10n.cancel),
        ),
        AppButton(
          onPressed: () {
            final parsed = int.tryParse(controller.text.trim());
            if (parsed != null && parsed > 0) {
              Navigator.of(context, rootNavigator: true).pop(parsed);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );

    controller.dispose();

    if (result != null && mounted) {
      setState(() => _selectedDuration = result);
    }
  }

  void _saveSankalpa() {
    final titleEmpty = _titleController.text.trim().isEmpty;
    if (titleEmpty != (_titleError != null)) {
      setState(() {
        _titleError = titleEmpty
            ? AppLocalizations.of(context)!.pleaseEnterTitle
            : null;
      });
    }
    if (!titleEmpty) {
      final l10n = AppLocalizations.of(context)!;
      try {
        final sankalpa = Sankalpa(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startDate: DateTime.now(),
          durationDays: _selectedDuration,
          reminderHour: _selectedTime.hour,
          reminderMinute: _selectedTime.minute,
        );

        ref.read(sankalpaListProvider.notifier).addSankalpa(sankalpa);

        if (mounted) {
          showAppMessage(
            context,
            l10n.sankalpaCreatedSuccessfully,
            kind: AppMessageKind.success,
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          showAppMessage(
            context,
            l10n.failedToSaveSankalpa(e.toString()),
            kind: AppMessageKind.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PageScaffold(
      // Form-style page: the form sits below the bar instead of scrolling
      // behind it.
      extendBodyBehindAppBar: false,
      leading: const HapticBackButton(),
      title: Text(l10n.newIntention),
      // Shared page frame: 12dp gutter and the 800 reading width.
      body: ScreenBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.whatIsYourSankalpa,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s24),
              M3ETextField(
                controller: _titleController,
                label: l10n.intentionTitle,
                placeholder: l10n.intentionTitleHint,
                errorText: _titleError,
                onChanged: (_) {
                  if (_titleError != null) {
                    setState(() => _titleError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.s16),
              M3ETextField(
                controller: _descriptionController,
                label: l10n.descriptionOptional,
                placeholder: l10n.descriptionHint,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.s32),

              Text(
                l10n.durationDays,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.s16),
              Wrap(
                spacing: 12,
                children: [
                  ..._durationPresets.map(
                    (days) => M3EChip(
                      label: l10n.daysCount(days),
                      type: M3EChipType.filter,
                      selected: _selectedDuration == days,
                      onPressed: () => setState(() => _selectedDuration = days),
                    ),
                  ),
                  M3EChip(
                    label: l10n.custom,
                    type: M3EChipType.filter,
                    selected: !_durationPresets.contains(_selectedDuration),
                    onPressed: () async => _showCustomDaysDialog(),
                  ),
                ],
              ),
              if (!_durationPresets.contains(_selectedDuration))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8),
                  child: Row(
                    children: [
                      Text('${l10n.customDays}: '),
                      SizedBox(
                        width: 80,
                        child: M3ETextField(
                          controller: _customDaysController,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            if (val.isNotEmpty) {
                              setState(
                                () =>
                                    _selectedDuration = int.tryParse(val) ?? 1,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.s32),
              Text(
                l10n.dailyReminderTime,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.s16),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.dense),
                  ),
                  leading: const Icon(Icons.alarm),
                  title: Text(_selectedTime.format(context)),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: AppIconSize.small,
                  ),
                  onTap: () => _selectTime(context),
                ),
              ),

              const SizedBox(height: 48),
              AppButton(
                onPressed: _saveSankalpa,
                icon: const Icon(Icons.check),
                label: Text(l10n.createSankalpa),
                padding: const EdgeInsets.all(AppSpacing.s16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
