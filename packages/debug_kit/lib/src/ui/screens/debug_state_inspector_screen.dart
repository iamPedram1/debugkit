import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/controller/debug_kit_controller.dart';
import '../../core/models/debug_state_diff_entry.dart';
import '../../core/models/debug_state_diff_type.dart';
import '../../core/models/debug_state_event.dart';
import '../../core/models/debug_state_event_type.dart';

class DebugStateInspectorScreen extends StatefulWidget {
  const DebugStateInspectorScreen({super.key});

  @override
  State<DebugStateInspectorScreen> createState() =>
      _DebugStateInspectorScreenState();
}

class _DebugStateInspectorScreenState extends State<DebugStateInspectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _searchQuery = '';
  String _nameQuery = '';
  Set<DebugStateEventType> _selectedTypes = {};
  String? _selectedEventId;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = DebugKitController();

    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.stateStore]),
      builder: (context, _) {
        final allEvents = controller.stateStore.events.toList();
        final filteredEvents = _filterEvents(allEvents);
        final isWide = MediaQuery.sizeOf(context).width >= 900;
        final selectedEvent = _selectedEvent(filteredEvents, allEvents);

        return Scaffold(
          backgroundColor: const Color(0xFF111111),
          body: SafeArea(
            child: Column(
              children: [
                _buildToolbar(context, controller, allEvents, filteredEvents),
                Expanded(
                  child: filteredEvents.isEmpty
                      ? _buildEmptyState(controller)
                      : isWide
                          ? Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _buildEventList(
                                    filteredEvents,
                                    selectedEvent?.id,
                                    onTap: (event) => setState(
                                        () => _selectedEventId = event.id),
                                  ),
                                ),
                                Container(width: 1, color: Colors.grey[850]),
                                Expanded(
                                  flex: 4,
                                  child: selectedEvent == null
                                      ? _buildDetailPlaceholder()
                                      : _buildDetailPanel(selectedEvent),
                                ),
                              ],
                            )
                          : _buildEventList(
                              filteredEvents,
                              null,
                              onTap: (event) => _openEventSheet(context, event),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    DebugKitController controller,
    List<DebugStateEvent> allEvents,
    List<DebugStateEvent> filteredEvents,
  ) {
    final paused = controller.isStateRecordingPaused;

    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 760;
          final searchField = TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'Search state events...',
              icon: Icons.search,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          );
          final nameField = TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'Provider / name filter',
              icon: Icons.label_outline,
            ),
            onChanged: (value) => setState(() => _nameQuery = value),
          );
          final actionRow = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              _CountBadge(
                  shown: filteredEvents.length, total: allEvents.length),
              TextButton.icon(
                onPressed: () {
                  if (paused) {
                    controller.resumeStateRecording();
                  } else {
                    controller.pauseStateRecording();
                  }
                },
                icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 18),
                label: Text(paused ? 'Resume' : 'Pause'),
              ),
              TextButton.icon(
                onPressed: controller.stateStore.events.isEmpty
                    ? null
                    : () {
                        controller.clearStateEvents();
                        setState(() => _selectedEventId = null);
                      },
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: const Text('Clear'),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: double.infinity, child: searchField),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: nameField),
                const SizedBox(height: 8),
                _buildChipRow(
                  label: 'Event',
                  selectedCount: _selectedTypes.length,
                  children: DebugStateEventType.values.map((type) {
                    final selected = _selectedTypes.contains(type);
                    return _FilterChipButton(
                      label: type.label,
                      selected: selected,
                      color: _eventTypeColor(type),
                      onTap: () => setState(() {
                        final next =
                            Set<DebugStateEventType>.from(_selectedTypes);
                        if (selected) {
                          next.remove(type);
                        } else {
                          next.add(type);
                        }
                        _selectedTypes = next;
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: actionRow),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: nameField),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildChipRow(
                      label: 'Event',
                      selectedCount: _selectedTypes.length,
                      children: DebugStateEventType.values.map((type) {
                        final selected = _selectedTypes.contains(type);
                        return _FilterChipButton(
                          label: type.label,
                          selected: selected,
                          color: _eventTypeColor(type),
                          onTap: () => setState(() {
                            final next =
                                Set<DebugStateEventType>.from(_selectedTypes);
                            if (selected) {
                              next.remove(type);
                            } else {
                              next.add(type);
                            }
                            _selectedTypes = next;
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  actionRow,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[700], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
      filled: true,
      fillColor: const Color(0xFF111111),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      isDense: true,
    );
  }

  Widget _buildChipRow({
    required String label,
    required int selectedCount,
    required List<Widget> children,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 10),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...children,
              if (selectedCount > 0)
                TextButton(
                  onPressed: () => setState(() {
                    if (label == 'Event') {
                      _selectedTypes = {};
                    }
                  }),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventList(
    List<DebugStateEvent> events,
    String? selectedId, {
    required void Function(DebugStateEvent event) onTap,
  }) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[events.length - 1 - index];
        final isSelected = event.id == selectedId;
        return _StateEventTile(
          event: event,
          isSelected: isSelected,
          onTap: () => onTap(event),
        );
      },
    );
  }

  Widget _buildEmptyState(DebugKitController controller) {
    final hasEvents = controller.stateStore.events.isNotEmpty;
    final message = hasEvents
        ? 'No matching state events. Try widening the search or clearing filters.'
        : 'No state events yet. Trigger a provider, bloc, or app state update to inspect changes here.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schema_outlined, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            const Text(
              'State',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              controller.isStateRecordingPaused
                  ? 'Recording is paused.'
                  : 'Recording is active.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPlaceholder() {
    return Center(
      child: Text(
        'Select a state event to inspect details.',
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildDetailPanel(DebugStateEvent event) {
    return Container(
      color: const Color(0xFF101010),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _StateEventDetail(event: event),
      ),
    );
  }

  Future<void> _openEventSheet(
    BuildContext context,
    DebugStateEvent event,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101010),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: _StateEventDetail(event: event),
        ),
      ),
    );
  }

  List<DebugStateEvent> _filterEvents(List<DebugStateEvent> events) {
    final search = _searchQuery.trim().toLowerCase();
    final name = _nameQuery.trim().toLowerCase();

    return events.where((event) {
      if (_selectedTypes.isNotEmpty &&
          !_selectedTypes.contains(event.eventType)) {
        return false;
      }
      if (name.isNotEmpty && !event.name.toLowerCase().contains(name)) {
        return false;
      }
      if (search.isEmpty) return true;

      final haystack = _searchHaystack(event);

      return haystack.contains(search);
    }).toList();
  }

  String _searchHaystack(DebugStateEvent event) {
    final changeParts = event.changes.expand((change) => [
          change.path,
          change.type.label,
          change.previousValuePreview ?? '',
          change.nextValuePreview ?? '',
        ]);

    return [
      event.source,
      event.name,
      event.eventType.label,
      event.type ?? '',
      event.previousValuePreview ?? '',
      event.nextValuePreview ?? '',
      event.diffPreview ?? '',
      event.error ?? '',
      event.stackTrace ?? '',
      ...changeParts,
      ...?event.metadata?.entries.map((e) => '${e.key}=${e.value}'),
    ].join(' ').toLowerCase();
  }

  DebugStateEvent? _selectedEvent(
    List<DebugStateEvent> filteredEvents,
    List<DebugStateEvent> allEvents,
  ) {
    if (filteredEvents.isEmpty) return null;
    if (_selectedEventId != null) {
      for (final event in allEvents) {
        if (event.id == _selectedEventId) return event;
      }
    }
    return filteredEvents.last;
  }
}

class _StateEventTile extends StatelessWidget {
  final DebugStateEvent event;
  final bool isSelected;
  final VoidCallback onTap;

  const _StateEventTile({
    required this.event,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm:ss').format(event.timestamp);
    final typeColor = _eventTypeColor(event.eventType);
    final sourceColor = _sourceColor(event.source);
    final hasError = event.error != null;
    final changeCount = event.changes.length;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF152136) : const Color(0xFF141414),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.blue.withValues(alpha: 0.14),
                    const Color(0xFF141414),
                  ],
                )
              : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey[850]!, width: 1),
            left: BorderSide(color: typeColor, width: 4),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(label: event.eventType.label, color: typeColor),
                const SizedBox(width: 6),
                _Badge(label: _displaySource(event.source), color: sourceColor),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (changeCount > 0) ...[
                  _Badge(
                    label: '$changeCount change${changeCount == 1 ? '' : 's'}',
                    color: const Color(0xFF42A5F5),
                  ),
                  const SizedBox(width: 6),
                ],
                if (hasError)
                  const Icon(Icons.error_outline,
                      size: 16, color: Color(0xFFF44336)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              event.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (event.type != null) ...[
              const SizedBox(height: 2),
              Text(
                event.type!,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            _buildPreview(
              event,
              maxEntries: 2,
              compact: true,
            ),
            if (hasError) ...[
              const SizedBox(height: 4),
              Text(
                event.error!,
                style: const TextStyle(
                  color: Color(0xFFF44336),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(
    DebugStateEvent event, {
    required int maxEntries,
    required bool compact,
  }) {
    if (event.changes.isNotEmpty) {
      final entries = event.changes.take(maxEntries).toList();
      final remaining = event.changes.length - entries.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _CompactDiffPreview(change: entries[i]),
            if (i < entries.length - 1) const SizedBox(height: 8),
          ],
          if (remaining > 0) ...[
            const SizedBox(height: 8),
            Text(
              '+ $remaining more change${remaining == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      );
    }

    final lines = <Widget>[];
    if (event.diffPreview != null && event.diffPreview!.isNotEmpty) {
      lines.add(
        Text(
          event.diffPreview!,
          style: TextStyle(
            color: Colors.grey[200],
            fontSize: compact ? 12 : 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          maxLines: compact ? 2 : null,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      if (event.previousValuePreview != null &&
          event.previousValuePreview!.isNotEmpty) {
        lines.add(
          _PreviewValueLine(
            label: 'Previous',
            value: event.previousValuePreview!,
            accent: const Color(0xFFF44336),
            compact: compact,
          ),
        );
      }
      if (event.nextValuePreview != null &&
          event.nextValuePreview!.isNotEmpty) {
        if (lines.isNotEmpty) {
          lines.add(const SizedBox(height: 6));
        }
        lines.add(
          _PreviewValueLine(
            label: 'Next',
            value: event.nextValuePreview!,
            accent: const Color(0xFF66BB6A),
            compact: compact,
          ),
        );
      }
      if (lines.isEmpty) {
        lines.add(
          Text(
            'No structured diff available.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: compact ? 11 : 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }
}

class _StateEventDetail extends StatelessWidget {
  final DebugStateEvent event;

  const _StateEventDetail({required this.event});

  @override
  Widget build(BuildContext context) {
    final timestamp =
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(event.timestamp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(
                        label: event.eventType.label,
                        color: _eventTypeColor(event.eventType),
                      ),
                      _Badge(
                        label: _displaySource(event.source),
                        color: _sourceColor(event.source),
                      ),
                      if (event.changes.isNotEmpty)
                        _Badge(
                          label: '${event.changes.length} change'
                              '${event.changes.length == 1 ? '' : 's'}',
                          color: const Color(0xFF42A5F5),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Copy event',
                  onPressed: () => _copy(context, _formatEvent(event)),
                  icon: const Icon(Icons.copy, color: Colors.white),
                ),
                if (event.changes.isNotEmpty)
                  IconButton(
                    tooltip: 'Copy changes',
                    onPressed: () => _copy(context, _formatChanges(event)),
                    icon: const Icon(Icons.alt_route, color: Colors.white),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _detailCard([
          _detailRow('Type', event.type ?? 'Unknown'),
          _detailRow('Timestamp', timestamp),
          if (event.diffPreview != null)
            _detailRow('Summary', event.diffPreview!),
        ]),
        if (event.changes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('Changed fields'),
          _detailCard([
            ...event.changes.map((change) => _DiffEntryRow(change: change)),
          ]),
        ],
        if (event.previousValuePreview != null ||
            event.nextValuePreview != null ||
            event.diffPreview != null) ...[
          const SizedBox(height: 12),
          _section(event.changes.isNotEmpty ? 'Raw previews' : 'Value preview'),
          _detailCard([
            if (event.previousValuePreview != null)
              _collapsedPreviewTile(
                context,
                label: 'Previous',
                value: event.previousValuePreview!,
                accent: const Color(0xFFF44336),
              ),
            if (event.nextValuePreview != null)
              _collapsedPreviewTile(
                context,
                label: 'Next',
                value: event.nextValuePreview!,
                accent: const Color(0xFF66BB6A),
              ),
            if (event.diffPreview != null && event.changes.isEmpty)
              _collapsedPreviewTile(
                context,
                label: 'Summary',
                value: event.diffPreview!,
                accent: const Color(0xFF42A5F5),
              ),
          ]),
        ] else if (event.changes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('Raw previews'),
          _detailCard([
            Text(
              'Structured diff captured. Raw previews were not included.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ]),
        ],
        if (event.metadata != null && event.metadata!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _section('Metadata'),
          _detailCard(
            event.metadata!.entries
                .map((entry) => _detailRow(entry.key, entry.value))
                .toList(),
          ),
        ],
        if (event.error != null) ...[
          const SizedBox(height: 12),
          _section('Error'),
          _detailCard([
            _collapsedPreviewTile(
              context,
              label: 'Message',
              value: event.error!,
              accent: const Color(0xFFF44336),
            ),
            if (event.stackTrace != null)
              _collapsedPreviewTile(
                context,
                label: 'Stack Trace',
                value: event.stackTrace!,
                accent: const Color(0xFFFFB74D),
              ),
          ]),
        ],
      ],
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _detailCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[850]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final child in children) ...[
            child,
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _collapsedPreviewTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 10, right: 10, bottom: 10),
          collapsedIconColor: accent,
          iconColor: accent,
          title: Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          subtitle: SelectableText(
            value,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.45,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _copy(context, value),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatEvent(DebugStateEvent event) {
    final buffer = StringBuffer()
      ..writeln('State Event')
      ..writeln('Source: ${event.source}')
      ..writeln('Name: ${event.name}')
      ..writeln('Type: ${event.type ?? 'Unknown'}')
      ..writeln('Event: ${event.eventType.label}')
      ..writeln(
          'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(event.timestamp)}');
    if (event.changes.isNotEmpty) {
      buffer.writeln('Changes:');
      for (final change in event.changes) {
        buffer.writeln('  - ${change.path} (${change.type.label})');
        if (change.previousValuePreview != null) {
          buffer.writeln('      Previous: ${change.previousValuePreview}');
        }
        if (change.nextValuePreview != null) {
          buffer.writeln('      Next: ${change.nextValuePreview}');
        }
      }
    } else {
      if (event.previousValuePreview != null) {
        buffer.writeln('Previous: ${event.previousValuePreview}');
      }
      if (event.nextValuePreview != null) {
        buffer.writeln('Next: ${event.nextValuePreview}');
      }
      if (event.diffPreview != null) {
        buffer.writeln('Diff: ${event.diffPreview}');
      }
    }
    if (event.metadata != null && event.metadata!.isNotEmpty) {
      buffer.writeln('Metadata:');
      for (final entry in event.metadata!.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    if (event.error != null) {
      buffer.writeln('Error: ${event.error}');
    }
    if (event.stackTrace != null) {
      buffer.writeln('Stack Trace:\n${event.stackTrace}');
    }
    return buffer.toString().trimRight();
  }

  String _formatChanges(DebugStateEvent event) {
    final buffer = StringBuffer()
      ..writeln('Changed fields for ${event.name}')
      ..writeln('Source: ${event.source}')
      ..writeln('Type: ${event.type ?? 'Unknown'}');
    for (final change in event.changes) {
      buffer.writeln('- ${change.path} (${change.type.label})');
      if (change.previousValuePreview != null) {
        buffer.writeln('  previous: ${change.previousValuePreview}');
      }
      if (change.nextValuePreview != null) {
        buffer.writeln('  next: ${change.nextValuePreview}');
      }
    }
    return buffer.toString().trimRight();
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

String _displaySource(String source) {
  final cleaned = source.trim().replaceAll(RegExp(r'[_-]+'), ' ');
  if (cleaned.isEmpty) return 'Unknown';
  return cleaned
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

Color _sourceColor(String source) {
  final normalized = source.toLowerCase();
  if (normalized.contains('riverpod')) return const Color(0xFFAB47BC);
  if (normalized.contains('bloc')) return const Color(0xFF42A5F5);
  if (normalized.contains('provider')) return const Color(0xFF66BB6A);
  if (normalized.contains('getx')) return const Color(0xFFFFB74D);
  return const Color(0xFF26C6DA);
}

Color _eventTypeColor(DebugStateEventType type) {
  return switch (type) {
    DebugStateEventType.added => const Color(0xFF66BB6A),
    DebugStateEventType.updated => const Color(0xFF42A5F5),
    DebugStateEventType.disposed => const Color(0xFF9E9E9E),
    DebugStateEventType.error => const Color(0xFFF44336),
  };
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        backgroundColor: const Color(0xFF111111),
        selectedColor: color.withValues(alpha: 0.2),
        side: BorderSide(
          color: selected ? color.withValues(alpha: 0.5) : Colors.grey[800]!,
          width: 1,
        ),
        labelStyle: TextStyle(
          color: selected ? color : Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int shown;
  final int total;

  const _CountBadge({required this.shown, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Text(
        total == 0 ? '0' : '$shown/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DiffEntryRow extends StatelessWidget {
  final DebugStateDiffEntry change;

  const _DiffEntryRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final typeColor = _diffTypeColor(change.type);
    final path = change.path == r'$' ? 'state' : change.path;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: typeColor.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    path,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Badge(label: change.type.label, color: typeColor),
              ],
            ),
            const SizedBox(height: 10),
            if (change.previousValuePreview != null)
              _DiffValueLine(
                label: '- Previous',
                value: change.previousValuePreview!,
                accent: const Color(0xFFF44336),
              ),
            if (change.nextValuePreview != null)
              _DiffValueLine(
                label: '+ Next',
                value: change.nextValuePreview!,
                accent: const Color(0xFF66BB6A),
              ),
            if (change.previousValuePreview == null &&
                change.nextValuePreview == null)
              Text(
                'No value preview available.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactDiffPreview extends StatelessWidget {
  final DebugStateDiffEntry change;

  const _CompactDiffPreview({required this.change});

  @override
  Widget build(BuildContext context) {
    final typeColor = _diffTypeColor(change.type);
    final path = change.path == r'$' ? 'state' : change.path;
    final showPrevious = change.previousValuePreview != null;
    final showNext = change.nextValuePreview != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: typeColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  path,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _Badge(label: change.type.label, color: typeColor),
            ],
          ),
          const SizedBox(height: 8),
          if (showPrevious)
            _CompactChangeLine(
              label: '-',
              value: change.previousValuePreview!,
              accent: const Color(0xFFF44336),
              visible: true,
            ),
          if (showPrevious && showNext) const SizedBox(height: 6),
          if (showNext)
            _CompactChangeLine(
              label: '+',
              value: change.nextValuePreview!,
              accent: const Color(0xFF66BB6A),
              visible: true,
            ),
          if (!showPrevious && !showNext)
            Text(
              'No value preview available.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactChangeLine extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final bool visible;

  const _CompactChangeLine({
    required this.label,
    required this.value,
    required this.accent,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label ',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.3,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewValueLine extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final bool compact;

  const _PreviewValueLine({
    required this.label,
    required this.value,
    required this.accent,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: accent,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.35,
                fontFamily: 'monospace',
              ),
              maxLines: compact ? 2 : null,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffValueLine extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _DiffValueLine({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.4,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _diffTypeColor(DebugStateDiffType type) {
  return switch (type) {
    DebugStateDiffType.added => const Color(0xFF66BB6A),
    DebugStateDiffType.removed => const Color(0xFFF44336),
    DebugStateDiffType.changed => const Color(0xFFFFB74D),
    DebugStateDiffType.unchanged => const Color(0xFF78909C),
  };
}
