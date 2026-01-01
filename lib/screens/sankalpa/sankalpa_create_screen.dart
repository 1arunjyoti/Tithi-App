import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sankalpa.dart';
import '../../providers/sankalpa_provider.dart';
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
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveSankalpa() {
    if (_formKey.currentState!.validate()) {
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
          const SnackBar(content: Text('Sankalpa created successfully!')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Intention'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: AppTheme.backgroundDecoration(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What is your Sankalpa?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Intention Title',
                    hintText: 'e.g., Chant Gayatri Mantra 108 times',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Add specific details or mantra text...',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                Text(
                  'Duration (Days)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    ..._durationPresets.map(
                      (days) => ChoiceChip(
                        label: Text('$days Days'),
                        selected: _selectedDuration == days,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedDuration = days);
                          }
                        },
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Custom'),
                      selected: !_durationPresets.contains(_selectedDuration),
                      onSelected: (selected) async {
                        if (selected) {
                          // Show simple dialog to input custom days
                          // For MVP just defaulting to 100 or current for now
                          // In a real app showDialog with number input
                          setState(() => _selectedDuration = 90);
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
                        const Text('Custom Days: '),
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
                  'Daily Reminder Time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.alarm),
                  title: Text(_selectedTime.format(context)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectTime(context),
                ),

                const SizedBox(height: 48),
                FilledButton.icon(
                  onPressed: _saveSankalpa,
                  icon: const Icon(Icons.check),
                  label: const Text('Create Sankalpa'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
