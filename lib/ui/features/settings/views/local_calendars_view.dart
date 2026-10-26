import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar/domain/models/event_category.dart';
import 'package:calendar/domain/models/local_calendar.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import '../../../../providers.dart';

class LocalCalendarsView extends ConsumerWidget {
  const LocalCalendarsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(calendarViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.localCalendars)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => _addCalendar(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.addLocalCalendar),
          ),
          const SizedBox(height: 12),
          for (final calendar in viewModel.localCalendars)
            _CalendarCard(
              calendar: calendar,
              categories: viewModel.categoriesFor(calendar.id),
              onRename: () => _renameCalendar(context, ref, calendar),
              onAddCategory: () => _addCategory(context, ref, calendar),
            ),
        ],
      ),
    );
  }

  Future<void> _addCalendar(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _nameDialog(context, l10n.addLocalCalendar);
    if (name == null || !context.mounted) return;
    await _runSettingsAction(
      context,
      l10n,
      () => ref.read(calendarViewModelProvider).addLocalCalendar(name),
    );
  }

  Future<void> _renameCalendar(
    BuildContext context,
    WidgetRef ref,
    LocalCalendar calendar,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _nameDialog(
      context,
      l10n.renameLocalCalendar,
      initialValue: calendar.name,
    );
    if (name == null || !context.mounted) return;
    await _runSettingsAction(
      context,
      l10n,
      () => ref
          .read(calendarViewModelProvider)
          .renameLocalCalendar(calendar.id, name),
    );
  }

  Future<void> _addCategory(
    BuildContext context,
    WidgetRef ref,
    LocalCalendar calendar,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<({String name, Color color})>(
      context: context,
      builder: (context) => _CategoryDialog(),
    );
    if (result == null || !context.mounted) return;
    await _runSettingsAction(
      context,
      l10n,
      () => ref
          .read(calendarViewModelProvider)
          .addEventCategory(
            calendarId: calendar.id,
            name: result.name,
            color: result.color,
          ),
    );
  }

  Future<String?> _nameDialog(
    BuildContext context,
    String title, {
    String initialValue = '',
  }) => showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: title, initialValue: initialValue),
  );

  Future<void> _runSettingsAction(
    BuildContext context,
    AppLocalizations l10n,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.localCalendarSaveError(error.toString())),
          ),
        );
      }
    }
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.calendar,
    required this.categories,
    required this.onRename,
    required this.onAddCategory,
  });

  final LocalCalendar calendar;
  final List<EventCategory> categories;
  final VoidCallback onRename;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(calendar.name),
              trailing: IconButton(
                tooltip: l10n.renameLocalCalendar,
                onPressed: onRename,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
            if (categories.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final category in categories)
                    Chip(
                      avatar: CircleAvatar(backgroundColor: category.color),
                      label: Text(category.name),
                    ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddCategory,
                icon: const Icon(Icons.add),
                label: Text(l10n.addCategory),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initialValue = ''});

  final String title;
  final String initialValue;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        autofocus: true,
        controller: _controller,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.of(context).pop(value.trim());
        },
        decoration: InputDecoration(
          labelText: l10n.name,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) Navigator.of(context).pop(value);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  static const _colors = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFE11D48),
    Color(0xFF0891B2),
    Color(0xFF4D7C0F),
    Color(0xFFEA580C),
    Color(0xFF9333EA),
    Color(0xFF0F766E),
    Color(0xFFDC2626),
    Color(0xFF475569),
  ];

  late final TextEditingController _controller;
  Color _selectedColor = _colors.first;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addCategory),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: true,
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.categoryName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.categoryColor),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in _colors)
                Semantics(
                  button: true,
                  selected: color == _selectedColor,
                  label: l10n.categoryColor,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: color == _selectedColor
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: color == _selectedColor
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop((name: name, color: _selectedColor));
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
