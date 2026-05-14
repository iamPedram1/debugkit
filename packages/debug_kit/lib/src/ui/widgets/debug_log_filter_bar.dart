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
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search logs...',
              hintStyle: TextStyle(color: Colors.grey[700], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
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
                borderSide:
                    const BorderSide(color: Colors.blueAccent, width: 1),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              isDense: true,
            ),
            onChanged: (value) => onChanged(state.copyWith(searchQuery: value)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...DebugLogLevel.values.map(
                  (level) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(level.label),
                      selected: state.levels.contains(level),
                      showCheckmark: false,
                      onSelected: (selected) {
                        final newLevels = Set<DebugLogLevel>.from(state.levels);
                        if (selected) {
                          newLevels.add(level);
                        } else {
                          newLevels.remove(level);
                        }
                        onChanged(state.copyWith(levels: newLevels));
                      },
                      backgroundColor: const Color(0xFF111111),
                      selectedColor:
                          _getLevelColor(level).withValues(alpha: 0.2),
                      side: BorderSide(
                        color: state.levels.contains(level)
                            ? _getLevelColor(level).withValues(alpha: 0.5)
                            : Colors.grey[800]!,
                        width: 1,
                      ),
                      labelStyle: TextStyle(
                        color: state.levels.contains(level)
                            ? _getLevelColor(level)
                            : Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                Container(
                  height: 16,
                  width: 1,
                  color: Colors.grey[800],
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
                ...DebugLogSource.values.map(
                  (source) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(source.label),
                      selected: state.sources.contains(source),
                      showCheckmark: false,
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
                      backgroundColor: const Color(0xFF111111),
                      selectedColor:
                          _getSourceColor(source).withValues(alpha: 0.2),
                      side: BorderSide(
                        color: state.sources.contains(source)
                            ? _getSourceColor(source).withValues(alpha: 0.5)
                            : Colors.grey[800]!,
                        width: 1,
                      ),
                      labelStyle: TextStyle(
                        color: state.sources.contains(source)
                            ? _getSourceColor(source)
                            : Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Color _getLevelColor(DebugLogLevel level) {
    return switch (level) {
      DebugLogLevel.debug => const Color(0xFF9E9E9E),
      DebugLogLevel.info => const Color(0xFF4CAF50),
      DebugLogLevel.warning => const Color(0xFFFF9800),
      DebugLogLevel.error => const Color(0xFFF44336),
    };
  }

  Color _getSourceColor(DebugLogSource source) {
    return switch (source) {
      DebugLogSource.app => const Color(0xFF66BB6A),
      DebugLogSource.dio => const Color(0xFF42A5F5),
      DebugLogSource.riverpod => const Color(0xFFAB47BC),
      DebugLogSource.router => const Color(0xFF26C6DA),
      DebugLogSource.userAction => const Color(0xFFFF7043),
    };
  }
}
