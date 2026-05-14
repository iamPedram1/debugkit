import 'package:flutter/material.dart';
import '../../core/models/debug_log_level.dart';
import '../../core/models/debug_log_source.dart';
import '../../utils/filtering/debug_log_filter.dart';

class DebugLogFilterBar extends StatelessWidget {
  final DebugLogFilterState state;
  final ValueChanged<DebugLogFilterState> onChanged;

  const DebugLogFilterBar({
    super.key,
    required this.state,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search logs...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) => onChanged(state.copyWith(searchQuery: value)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              ...DebugLogLevel.values.map((level) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(level.label),
                      selected: state.levels.contains(level),
                      onSelected: (selected) {
                        final newLevels = Set<DebugLogLevel>.from(state.levels);
                        if (selected) {
                          newLevels.add(level);
                        } else {
                          newLevels.remove(level);
                        }
                        onChanged(state.copyWith(levels: newLevels));
                      },
                      backgroundColor: Colors.grey[900],
                      selectedColor:
                          _getLevelColor(level).withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: state.levels.contains(level)
                            ? _getLevelColor(level)
                            : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
              const VerticalDivider(color: Colors.grey),
              ...DebugLogSource.values.map((source) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(source.label),
                      selected: state.sources.contains(source),
                      onSelected: (selected) {
                        final newSources =
                            Set<DebugLogSource>.from(state.sources);
                        if (selected) {
                          newSources.add(source);
                        } else {
                          newSources.remove(source);
                        }
                        onChanged(state.copyWith(sources: newSources));
                      },
                      backgroundColor: Colors.grey[900],
                      selectedColor: Colors.blue.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: state.sources.contains(source)
                            ? Colors.blue
                            : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Color _getLevelColor(DebugLogLevel level) {
    return switch (level) {
      DebugLogLevel.debug => Colors.grey,
      DebugLogLevel.info => Colors.green,
      DebugLogLevel.warning => Colors.orange,
      DebugLogLevel.error => Colors.red,
    };
  }
}
