import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import '../../../../providers.dart';
import '../../../../data/repositories/device_calendar_repository.dart';

class DeviceCalendarsView extends ConsumerStatefulWidget {
  const DeviceCalendarsView({super.key});

  @override
  ConsumerState<DeviceCalendarsView> createState() =>
      _DeviceCalendarsViewState();
}

class _DeviceCalendarsViewState extends ConsumerState<DeviceCalendarsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(deviceCalendarsViewModelProvider).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = ref.watch(deviceCalendarsViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceCalendars),
        actions: [
          if (viewModel.isSupported && viewModel.hasPermission)
            IconButton(
              tooltip: l10n.refreshCalendars,
              onPressed: viewModel.isLoading ? null : viewModel.refresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (!viewModel.isSupported) {
            return _Message(text: l10n.deviceCalendarsUnavailable);
          }
          if (viewModel.isLoading && !viewModel.hasPermission) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!viewModel.hasPermission) {
            return _PermissionPrompt(
              explanation: l10n.deviceCalendarAccessExplanation,
              actionLabel: l10n.allowCalendarAccess,
              isLoading: viewModel.isLoading,
              errorMessage: viewModel.errorMessage,
              onPressed: viewModel.requestAccess,
              onOpenSettings: viewModel.openAppSettings,
              l10n: l10n,
            );
          }

          final groupedCalendars = <String, List<DeviceCalendarInfo>>{};
          for (final calendar in viewModel.calendars) {
            groupedCalendars
                .putIfAbsent(calendar.accountName ?? '', () => [])
                .add(calendar);
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.deviceCalendarAccessExplanation,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (viewModel.errorMessage case final error?)
                _ErrorMessage(message: l10n.calendarLoadError(error)),
              if (groupedCalendars.isEmpty)
                _Message(text: l10n.noDeviceCalendars),
              for (final entry in groupedCalendars.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    entry.key.isEmpty ? l10n.deviceAccount : entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final calendar in entry.value)
                  CheckboxListTile(
                    value: viewModel.selectedCalendarIds.contains(calendar.id),
                    title: Text(calendar.name),
                    secondary: Icon(
                      Icons.calendar_month,
                      color: calendar.color,
                    ),
                    onChanged: (selected) {
                      if (selected != null) {
                        viewModel.setCalendarSelected(calendar.id, selected);
                      }
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({
    required this.explanation,
    required this.actionLabel,
    required this.isLoading,
    required this.errorMessage,
    required this.onPressed,
    required this.onOpenSettings,
    required this.l10n,
  });

  final String explanation;
  final String actionLabel;
  final bool isLoading;
  final String? errorMessage;
  final Future<bool> Function() onPressed;
  final Future<void> Function() onOpenSettings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 48),
            const SizedBox(height: 16),
            Text(explanation, textAlign: TextAlign.center),
            if (errorMessage case final error?) ...[
              const SizedBox(height: 12),
              Text(
                l10n.calendarLoadError(error),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: const Icon(Icons.lock_open),
              label: Text(actionLabel),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: Text(l10n.openCalendarSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
