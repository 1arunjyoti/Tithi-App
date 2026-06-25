import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sankalpa.dart';
import '../../providers/sankalpa_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class SankalpaCreateScreen extends ConsumerStatefulWidget {
  const SankalpaCreateScreen({super.key});

  @override
  ConsumerState<SankalpaCreateScreen> createState() =>
      _SankalpaCreateScreenState();
}

class _SankalpaCreateScreenState extends ConsumerState<SankalpaCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _selectedDuration = 40; // Default Mandala
  TimeOfDay _selectedTime = const TimeOfDay(hour: 6, minute: 0); // Default 6 AM

  final List<int> _durationPresets = [11, 21, 40, 48];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      if (mounted) {
        setState(() {
          _selectedTime = picked;
        });
      }
    }
  }

  Future<void> _showCustomDaysDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _selectedDuration.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customDays),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.durationDays),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.pop(dialogContext, parsed);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && mounted) {
      setState(() => _selectedDuration = result);
    }
  }

  void _saveSankalpa() {
    if (_formKey.currentState!.validate()) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.sankalpaCreatedSuccessfully)),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.failedToSaveSankalpa(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newIntention),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: AppTheme.backgroundDecoration(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.whatIsYourSankalpa,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.intentionTitle,
                        hintText: l10n.intentionTitleHint,
                        border: const OutlineInputBorder(),
                        filled: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.pleaseEnterTitle;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.descriptionOptional,
                        hintText: l10n.descriptionHint,
                        border: const OutlineInputBorder(),
                        filled: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    Text(
                      l10n.durationDays,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: [
                        ..._durationPresets.map(
                          (days) => ChoiceChip(
                            label: Text(l10n.daysCount(days)),
                            selected: _selectedDuration == days,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDuration = days);
                              }
                            },
                          ),
                        ),
                        ChoiceChip(
                          label: Text(l10n.custom),
                          selected: !_durationPresets.contains(
                            _selectedDuration,
                          ),
                          onSelected: (selected) async {
                            if (selected) {
                              await _showCustomDaysDialog();
                            }
                          },
                        ),
                      ],
                    ),
                    if (!_durationPresets.contains(_selectedDuration))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Text('${l10n.customDays}: '),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: _selectedDuration.toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  if (val.isNotEmpty) {
                                    setState(
                                      () => _selectedDuration =
                                          int.tryParse(val) ?? 1,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),
                    Text(
                      l10n.dailyReminderTime,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        tileColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: const Icon(Icons.alarm),
                        title: Text(_selectedTime.format(context)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _selectTime(context),
                      ),
                    ),

                    const SizedBox(height: 48),
                    FilledButton.icon(
                      onPressed: _saveSankalpa,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.createSankalpa),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
