import 'package:intl/intl.dart';

import '../core/models/debug_console_print_format.dart';
import '../core/models/debug_log_entry.dart';
import '../core/models/debug_log_level.dart';
import '../core/models/debug_log_source.dart';
import '../core/models/debug_network_transaction.dart';
import '../core/models/debug_network_transaction_phase.dart';
import '../utils/network/debug_network_transaction_builder.dart';

/// Pure formatter that converts sanitized DebugKit records to console text.
///
/// The formatter is intentionally stateless and testable. It consumes already
/// sanitized store data and never reaches back into the controller or sinks.
class DebugConsoleLogFormatter {
  static final _timeFormat = DateFormat('HH:mm:ss');
  static final _isoFormat = DateFormat('yyyy-MM-ddTHH:mm:ss.SSS');

  /// Formats a sanitized [DebugLogEntry] for console output.
  String formatLogEntry(
    DebugLogEntry entry, {
    required DebugConsolePrintFormat format,
    bool colorizeConsoleOutput = true,
  }) {
    final network = _tryBuildNetworkTransaction(entry);
    if (network != null) {
      return _formatNetwork(
        entry,
        network,
        format,
        colorizeConsoleOutput: colorizeConsoleOutput,
      );
    }

    if (entry.source == DebugLogSource.router) {
      return _formatRouter(
        entry,
        format,
        colorizeConsoleOutput: colorizeConsoleOutput,
      );
    }

    if (entry.source == DebugLogSource.riverpod) {
      return _formatRiverpod(
        entry,
        format,
        colorizeConsoleOutput: colorizeConsoleOutput,
      );
    }

    return _formatManual(
      entry,
      format,
      colorizeConsoleOutput: colorizeConsoleOutput,
    );
  }

  /// Formats a trace lifecycle update for console output.
  String formatTraceLifecycle({
    required DebugConsolePrintFormat format,
    required String event,
    required String traceName,
    String? traceId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? error,
    Map<String, String>? metadata,
    bool colorizeConsoleOutput = true,
  }) {
    final timestamp = _isoFormat.format(endedAt ?? startedAt ?? DateTime.now());
    final eventLabel = _traceEventLabel(event);
    final duration = startedAt == null || endedAt == null
        ? null
        : endedAt.difference(startedAt);
    final durationLabel = duration == null ? null : _formatDuration(duration);
    final terse = _traceTerseSummary(
      traceName: traceName,
      eventLabel: eventLabel,
      durationLabel: durationLabel,
      error: error,
    );

    return switch (format) {
      DebugConsolePrintFormat.tiny => _truncateOneLine(
          _colorizeCompactLine(
            _segmentList([
              _coloredToken(
                'TRACE',
                colorizeConsoleOutput,
                _AnsiColor.cyan,
                bold: true,
              ),
              _coloredText(terse, colorizeConsoleOutput, _AnsiColor.gray),
            ]),
            colorizeConsoleOutput,
          ),
        ),
      DebugConsolePrintFormat.short => _truncateOneLine(
          _colorizeCompactLine(
            _segmentList([
              _coloredText(
                _timeFormat.format(endedAt ?? startedAt ?? DateTime.now()),
                colorizeConsoleOutput,
                _AnsiColor.gray,
              ),
              _coloredToken(
                'TRACE',
                colorizeConsoleOutput,
                _AnsiColor.cyan,
                bold: true,
              ),
              _coloredText(terse, colorizeConsoleOutput, _AnsiColor.gray),
            ]),
            colorizeConsoleOutput,
          ),
        ),
      DebugConsolePrintFormat.dev => _truncateOneLine(
          _colorizeCompactLine(
            _segmentList([
              _coloredToken(
                '⏱',
                colorizeConsoleOutput,
                _AnsiColor.cyan,
                bold: true,
              ),
              _coloredText(terse, colorizeConsoleOutput, _AnsiColor.gray),
            ]),
            colorizeConsoleOutput,
          ),
        ),
      DebugConsolePrintFormat.detailed => _formatDetailedTrace(
          timestamp: timestamp,
          event: eventLabel,
          traceName: traceName,
          traceId: traceId,
          startedAt: startedAt,
          endedAt: endedAt,
          durationLabel: durationLabel,
          error: error,
          metadata: metadata,
          colorizeConsoleOutput: colorizeConsoleOutput,
        ),
    };
  }

  String _formatManual(
    DebugLogEntry entry,
    DebugConsolePrintFormat format, {
    required bool colorizeConsoleOutput,
  }) {
    final isUserAction = entry.source == DebugLogSource.userAction;
    final level = entry.level;
    final category = isUserAction ? 'user' : 'app';
    final detailedCategory = isUserAction ? 'USER' : 'APP';
    final message = _truncateOneLine(entry.message);
    final error = entry.error == null ? null : _truncateOneLine(entry.error!);
    final levelName = _levelName(level);

    return switch (format) {
      DebugConsolePrintFormat.tiny => _truncateOneLine(
          _colorizeCompactLine(
            _segmentList([
              _coloredLevelToken(levelName, level, colorizeConsoleOutput),
              _coloredText(message, colorizeConsoleOutput, _AnsiColor.defaultText),
            ]),
            colorizeConsoleOutput,
          ),
        ),
      DebugConsolePrintFormat.short => _truncateOneLine(
          _colorizeCompactLine(
            _segmentList([
              _coloredText(
                _timeFormat.format(entry.timestamp),
                colorizeConsoleOutput,
                _AnsiColor.gray,
              ),
              _coloredLevelToken(levelName, level, colorizeConsoleOutput),
              _coloredText(category, colorizeConsoleOutput, _AnsiColor.gray),
              _coloredText(message, colorizeConsoleOutput, _AnsiColor.defaultText),
            ]),
            colorizeConsoleOutput,
          ),
        ),
      DebugConsolePrintFormat.dev => _truncateOneLine(
          [
            _coloredManualSymbol(
              _manualLevelSymbol(level),
              level,
              colorizeConsoleOutput,
            ),
            _colorizeCompactLine(
              _segmentList([
                _coloredText(category, colorizeConsoleOutput, _AnsiColor.gray),
                _coloredText(message, colorizeConsoleOutput, _AnsiColor.defaultText),
                if (error != null)
                  _coloredText(error, colorizeConsoleOutput, _AnsiColor.red),
              ]),
              colorizeConsoleOutput,
            ),
          ].join(' '),
        ),
      DebugConsolePrintFormat.detailed => _formatDetailedEntry(
          timestamp: entry.timestamp,
          category: detailedCategory,
          source: null,
          level: levelName,
          message: entry.message,
          error: entry.error,
          location: entry.location,
          metadata: entry.metadata,
          details: entry.details,
          payloadPreview: entry.payloadPreview,
          responsePreview: entry.responsePreview,
          stackTrace: entry.stackTrace,
          requestId: entry.requestId,
          traceId: entry.traceId,
          traceName: entry.traceName,
          traceStep: entry.traceStep,
          repeatCount: entry.repeatCount,
          lastSeenAt: entry.lastSeenAt,
          colorizeConsoleOutput: colorizeConsoleOutput,
        ),
    };
  }

  String _formatNetwork(
    DebugLogEntry entry,
    DebugNetworkTransaction tx,
    DebugConsolePrintFormat format, {
    required bool colorizeConsoleOutput,
  }) {
    final path = tx.displayPath;
    final durationLabel = tx.durationLabel;
    final statusText = _networkStatusText(tx);
    final slow = _isSlowTransaction(entry, tx);
    final error = _firstNonEmpty([
      tx.errorSummary,
      entry.error,
      tx.errorMessage,
      tx.errorType,
    ]);
    final shortCore = _networkShortCore(
      tx: tx,
      statusText: statusText,
      durationLabel: durationLabel,
      slow: slow,
      colorizeConsoleOutput: colorizeConsoleOutput,
    );
    final devCore = _networkDevCore(
      tx: tx,
      statusText: statusText,
      durationLabel: durationLabel,
      slow: slow,
      error: error,
      colorizeConsoleOutput: colorizeConsoleOutput,
    );
    return switch (format) {
      DebugConsolePrintFormat.tiny => _truncateOneLine(
          switch (tx.phase) {
            DebugNetworkTransactionPhase.pending => _compactNetworkLine([
                _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
                _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
                _coloredNetworkStatus(
                  'started',
                  statusText,
                  slow,
                  colorizeConsoleOutput,
                  isPending: true,
                ),
              ], colorizeConsoleOutput),
            DebugNetworkTransactionPhase.completed => _compactNetworkLine([
                _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
                _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
                _coloredNetworkStatus(
                  statusText,
                  statusText,
                  slow,
                  colorizeConsoleOutput,
                ),
                _coloredDuration(durationLabel, slow, colorizeConsoleOutput),
              ], colorizeConsoleOutput),
            DebugNetworkTransactionPhase.failed ||
            DebugNetworkTransactionPhase.cancelled ||
            DebugNetworkTransactionPhase.unknown => _compactNetworkLine([
                _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
                _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
                _coloredNetworkStatus(
                  _networkFailureText(tx),
                  statusText,
                  slow,
                  colorizeConsoleOutput,
                  failed: tx.statusCode == null,
                ),
                _coloredDuration(durationLabel, slow, colorizeConsoleOutput),
                if (error != null)
                  _coloredText(error, colorizeConsoleOutput, _AnsiColor.red),
              ], colorizeConsoleOutput),
          },
        ),
      DebugConsolePrintFormat.short => _truncateOneLine(
          _colorizeCompactLine(
            _segmentList([
              _coloredText(
                _timeFormat.format(entry.timestamp),
                colorizeConsoleOutput,
                _AnsiColor.gray,
              ),
              _coloredToken('NET', colorizeConsoleOutput, _AnsiColor.cyan, bold: true),
              shortCore,
            ]),
            colorizeConsoleOutput,
          ),
        ),
      DebugConsolePrintFormat.dev => _truncateOneLine(devCore),
      DebugConsolePrintFormat.detailed => _formatDetailedNetwork(
          timestamp: entry.timestamp,
          tx: tx,
          entry: entry,
          statusText: statusText,
          slow: slow,
          durationLabel: durationLabel,
          error: error,
          colorizeConsoleOutput: colorizeConsoleOutput,
        ),
    };
  }

  String _formatRouter(
    DebugLogEntry entry,
    DebugConsolePrintFormat format, {
    required bool colorizeConsoleOutput,
  }) {
    final from = entry.metadata?['previous_route_path'];
    final to = entry.metadata?['route_path'];
    final action = entry.metadata?['action'];
    final name = entry.metadata?['route_name'] ?? entry.metadata?['name'];
    final argumentsPreview =
        entry.metadata?['arguments_preview'] ?? entry.metadata?['arguments'];

    final routeMessage = from != null && to != null
        ? '$from → $to'
        : _truncateOneLine(entry.message);

    return switch (format) {
      DebugConsolePrintFormat.tiny => _truncateOneLine(
          _compactNetworkLine([
            _coloredToken('ROUTE', colorizeConsoleOutput, _AnsiColor.cyan, bold: true),
            _coloredText(routeMessage, colorizeConsoleOutput, _AnsiColor.defaultText),
          ], colorizeConsoleOutput),
        ),
      DebugConsolePrintFormat.short => _truncateOneLine(
          _colorizeCompactLine(
            _segmentList([
              _coloredText(
                _timeFormat.format(entry.timestamp),
                colorizeConsoleOutput,
                _AnsiColor.gray,
              ),
              _coloredToken('ROUTE', colorizeConsoleOutput, _AnsiColor.cyan, bold: true),
              _coloredText(routeMessage, colorizeConsoleOutput, _AnsiColor.defaultText),
            ]),
            colorizeConsoleOutput,
          ),
        ),
      DebugConsolePrintFormat.dev => _truncateOneLine(
          [
            _coloredToken('↪', colorizeConsoleOutput, _AnsiColor.cyan, bold: true),
            _colorizeCompactLine(
              _segmentList([
                _coloredText(routeMessage, colorizeConsoleOutput, _AnsiColor.defaultText),
              ]),
              colorizeConsoleOutput,
            ),
          ].join(' '),
        ),
      DebugConsolePrintFormat.detailed => _formatDetailedEntry(
          timestamp: entry.timestamp,
          category: 'ROUTE',
          source: 'GO_ROUTER',
          level: _levelName(entry.level),
          message: entry.message,
          error: entry.error,
          location: entry.location,
          metadata: {
            if (from != null) 'from': from,
            if (to != null) 'to': to,
            if (action != null) 'action': action,
            if (name != null) 'name': name,
            if (argumentsPreview != null) 'arguments': argumentsPreview,
            ...?entry.metadata,
          },
          details: entry.details,
          payloadPreview: entry.payloadPreview,
          responsePreview: entry.responsePreview,
          stackTrace: entry.stackTrace,
          requestId: entry.requestId,
          traceId: entry.traceId,
          traceName: entry.traceName,
          traceStep: entry.traceStep,
          repeatCount: entry.repeatCount,
          lastSeenAt: entry.lastSeenAt,
          colorizeConsoleOutput: colorizeConsoleOutput,
        ),
    };
  }

  String _formatRiverpod(
    DebugLogEntry entry,
    DebugConsolePrintFormat format, {
    required bool colorizeConsoleOutput,
  }) {
    final provider = entry.metadata?['provider_name'] ?? 'provider';
    final eventType = entry.metadata?['event_type'] ?? 'updated';
    final previousPreview = entry.metadata?['previous_preview'];
    final nextPreview = entry.metadata?['next_preview'] ??
        entry.metadata?['value_preview'];
    final isFailure = entry.level == DebugLogLevel.error ||
        eventType.toLowerCase().contains('failure');
    final message =
        isFailure ? '$provider failed' : '$provider updated';
    final error = entry.error == null ? null : _truncateOneLine(entry.error!);

    return switch (format) {
      DebugConsolePrintFormat.tiny => _truncateOneLine(
          _compactNetworkLine([
            _coloredToken('STATE', colorizeConsoleOutput, _AnsiColor.magenta, bold: true),
            _coloredText(provider, colorizeConsoleOutput, _AnsiColor.defaultText),
            _coloredText(message, colorizeConsoleOutput, _AnsiColor.defaultText),
          ], colorizeConsoleOutput),
        ),
      DebugConsolePrintFormat.short => _truncateOneLine(
          _colorizeCompactLine(
            _segmentList([
              _coloredText(
                _timeFormat.format(entry.timestamp),
                colorizeConsoleOutput,
                _AnsiColor.gray,
              ),
              _coloredToken('STATE', colorizeConsoleOutput, _AnsiColor.magenta, bold: true),
              _coloredText(provider, colorizeConsoleOutput, _AnsiColor.defaultText),
              _coloredText(message, colorizeConsoleOutput, _AnsiColor.defaultText),
            ]),
            colorizeConsoleOutput,
          ),
        ),
      DebugConsolePrintFormat.dev => _truncateOneLine(
          [
            _coloredToken('◆', colorizeConsoleOutput, _AnsiColor.magenta, bold: true),
            _colorizeCompactLine(
              _segmentList([
                _coloredText(provider, colorizeConsoleOutput, _AnsiColor.defaultText),
                _coloredText(message, colorizeConsoleOutput, _AnsiColor.defaultText),
              ]),
              colorizeConsoleOutput,
            ),
          ].join(' '),
        ),
      DebugConsolePrintFormat.detailed => _formatDetailedEntry(
          timestamp: entry.timestamp,
          category: 'STATE',
          source: 'RIVERPOD',
          level: _levelName(entry.level),
          message: entry.message,
          error: entry.error,
          location: entry.location,
          metadata: {
            'provider': provider,
            'event': isFailure ? 'failed' : 'updated',
            if (previousPreview != null) 'previousPreview': previousPreview,
            if (nextPreview != null) 'nextPreview': nextPreview,
            ...?entry.metadata,
          },
          details: entry.details,
          payloadPreview: entry.payloadPreview,
          responsePreview: entry.responsePreview,
          stackTrace: entry.stackTrace,
          requestId: entry.requestId,
          traceId: entry.traceId,
          traceName: entry.traceName,
          traceStep: entry.traceStep,
          repeatCount: entry.repeatCount,
          lastSeenAt: entry.lastSeenAt,
          colorizeConsoleOutput: colorizeConsoleOutput,
        ),
    };
  }

  String _formatDetailedEntry({
    required DateTime timestamp,
    required String category,
    String? source,
    required String level,
    required String message,
    String? error,
    String? location,
    Map<String, String>? metadata,
    String? details,
    String? payloadPreview,
    String? responsePreview,
    String? stackTrace,
    String? requestId,
    String? traceId,
    String? traceName,
    int? traceStep,
    int repeatCount = 1,
    DateTime? lastSeenAt,
    required bool colorizeConsoleOutput,
  }) {
    final buffer = StringBuffer();
    buffer.write(
      _colorizeDetailedHeader(
        '[DebugKit][${_isoFormat.format(timestamp)}]',
        colorizeConsoleOutput,
        _AnsiColor.bold,
      ),
    );
    buffer.write(
      _colorizeDetailedHeader(
        '[${level.toUpperCase()}][${category.toUpperCase()}]',
        colorizeConsoleOutput,
        _detailedCategoryColor(category),
      ),
    );
    if (source != null && source.toUpperCase() != category.toUpperCase()) {
      buffer.write(
        _colorizeDetailedHeader(
          '[${source.toUpperCase()}]',
          colorizeConsoleOutput,
          _AnsiColor.cyan,
        ),
      );
    }
    buffer.writeln();
    buffer.writeln(
      '${_detailedFieldName('message', colorizeConsoleOutput)}: ${_truncateOneLine(message, maxLength: 220)}',
    );
    if (repeatCount > 1) {
      buffer.writeln(
        '${_detailedFieldName('repeatCount', colorizeConsoleOutput)}: x$repeatCount',
      );
    }
    if (requestId != null) {
      buffer.writeln(
        '${_detailedFieldName('requestId', colorizeConsoleOutput)}: $requestId',
      );
    }
    if (traceId != null) {
      buffer.writeln(
        '${_detailedFieldName('traceId', colorizeConsoleOutput)}: $traceId',
      );
    }
    if (traceName != null) {
      buffer.writeln(
        '${_detailedFieldName('traceName', colorizeConsoleOutput)}: $traceName',
      );
    }
    if (traceStep != null) {
      buffer.writeln(
        '${_detailedFieldName('traceStep', colorizeConsoleOutput)}: $traceStep',
      );
    }
    if (lastSeenAt != null) {
      buffer.writeln(
        '${_detailedFieldName('lastSeenAt', colorizeConsoleOutput)}: ${_isoFormat.format(lastSeenAt)}',
      );
    }
    if (location != null) {
      buffer.writeln(
        '${_detailedFieldName('location', colorizeConsoleOutput)}: $location',
      );
    }
    if (error != null) {
      buffer.writeln(
        '${_detailedFieldName('error', colorizeConsoleOutput)}: ${_truncateOneLine(error, maxLength: 220)}',
      );
    }
    if (details != null) {
      buffer.writeln('${_detailedFieldName('details', colorizeConsoleOutput)}:');
      buffer.writeln(_indent(_truncateMultiline(details), 2));
    }
    if (payloadPreview != null) {
      buffer.writeln(
        '${_detailedFieldName('payloadPreview', colorizeConsoleOutput)}:',
      );
      buffer.writeln(_indent(_truncateMultiline(payloadPreview), 2));
    }
    if (responsePreview != null) {
      buffer.writeln(
        '${_detailedFieldName('responsePreview', colorizeConsoleOutput)}:',
      );
      buffer.writeln(_indent(_truncateMultiline(responsePreview), 2));
    }
    if (stackTrace != null) {
      buffer.writeln('${_detailedFieldName('stack', colorizeConsoleOutput)}:');
      buffer.writeln(_indent(_truncateStackTrace(stackTrace), 2));
    }
    if (metadata != null && metadata.isNotEmpty) {
      buffer.writeln('${_detailedFieldName('metadata', colorizeConsoleOutput)}:');
      final keys = metadata.keys.toList()..sort();
      for (final key in keys) {
        final value = metadata[key] ?? '';
        final rendered = _truncateOneLine(value, maxLength: 220);
        buffer.writeln(
          '  ${_detailedFieldName(key, colorizeConsoleOutput)}: $rendered',
        );
      }
    }
    return buffer.toString().trimRight();
  }

  String _formatDetailedNetwork({
    required DateTime timestamp,
    required DebugNetworkTransaction tx,
    required DebugLogEntry entry,
    required String statusText,
    required bool slow,
    required String durationLabel,
    String? error,
    required bool colorizeConsoleOutput,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      '${_colorizeDetailedHeader('[DebugKit][${_isoFormat.format(timestamp)}]', colorizeConsoleOutput, _AnsiColor.bold)}'
      '${_colorizeDetailedHeader('[NETWORK][DIO]', colorizeConsoleOutput, _AnsiColor.cyan)}',
    );
    buffer.writeln('${_detailedFieldName('method', colorizeConsoleOutput)}: ${tx.method}');
    buffer.writeln('${_detailedFieldName('path', colorizeConsoleOutput)}: ${tx.displayPath}');
    if (tx.url != null) {
      buffer.writeln('${_detailedFieldName('url', colorizeConsoleOutput)}: ${tx.url}');
    }
    if (tx.host != null) {
      buffer.writeln('${_detailedFieldName('host', colorizeConsoleOutput)}: ${tx.host}');
    }
    buffer.writeln('${_detailedFieldName('status', colorizeConsoleOutput)}: $statusText');
    buffer.writeln('${_detailedFieldName('duration', colorizeConsoleOutput)}: $durationLabel');
    buffer.writeln('${_detailedFieldName('phase', colorizeConsoleOutput)}: ${tx.phase.label.toLowerCase()}');
    if (slow) {
      buffer.writeln('${_detailedFieldName('slow', colorizeConsoleOutput)}: true');
    }
    if (entry.requestId != null) {
      buffer.writeln('${_detailedFieldName('requestId', colorizeConsoleOutput)}: ${entry.requestId}');
    }
    if (entry.traceId != null) {
      buffer.writeln('${_detailedFieldName('traceId', colorizeConsoleOutput)}: ${entry.traceId}');
    }
    if (entry.traceName != null) {
      buffer.writeln('${_detailedFieldName('traceName', colorizeConsoleOutput)}: ${entry.traceName}');
    }
    if (tx.backendRequestId != null) {
      buffer.writeln('${_detailedFieldName('backendRequestId', colorizeConsoleOutput)}: ${tx.backendRequestId}');
    }
    if (tx.backendCorrelationId != null) {
      buffer.writeln('${_detailedFieldName('backendCorrelationId', colorizeConsoleOutput)}: ${tx.backendCorrelationId}');
    }
    if (tx.backendTraceId != null) {
      buffer.writeln('${_detailedFieldName('backendTraceId', colorizeConsoleOutput)}: ${tx.backendTraceId}');
    }
    if (error != null) {
      buffer.writeln('${_detailedFieldName('error', colorizeConsoleOutput)}: $error');
    }
    if (tx.requestHeadersPreview != null) {
      buffer.writeln('${_detailedFieldName('requestHeadersPreview', colorizeConsoleOutput)}:');
      buffer.writeln(_indent(_truncateMultiline(tx.requestHeadersPreview!), 2));
    }
    if (tx.responseHeadersPreview != null) {
      buffer.writeln('${_detailedFieldName('responseHeadersPreview', colorizeConsoleOutput)}:');
      buffer.writeln(_indent(_truncateMultiline(tx.responseHeadersPreview!), 2));
    }
    if (tx.requestBodyPreview != null) {
      buffer.writeln('${_detailedFieldName('requestBodyPreview', colorizeConsoleOutput)}:');
      buffer.writeln(_indent(_truncateMultiline(tx.requestBodyPreview!), 2));
    }
    if (tx.responseBodyPreview != null) {
      buffer.writeln('${_detailedFieldName('responseBodyPreview', colorizeConsoleOutput)}:');
      buffer.writeln(_indent(_truncateMultiline(tx.responseBodyPreview!), 2));
    }
    if (tx.metadata.isNotEmpty) {
      buffer.writeln('${_detailedFieldName('metadata', colorizeConsoleOutput)}:');
      final keys = tx.metadata.keys.toList()..sort();
      for (final key in keys) {
        final value = tx.metadata[key] ?? '';
        buffer.writeln(
          '  ${_detailedFieldName(key, colorizeConsoleOutput)}: ${_truncateOneLine(value, maxLength: 220)}',
        );
      }
    }
    return buffer.toString().trimRight();
  }

  String _formatDetailedTrace({
    required String timestamp,
    required String event,
    required String traceName,
    required String? traceId,
    required DateTime? startedAt,
    required DateTime? endedAt,
    required String? durationLabel,
    required String? error,
    required Map<String, String>? metadata,
    required bool colorizeConsoleOutput,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      '${_colorizeDetailedHeader('[DebugKit][$timestamp]', colorizeConsoleOutput, _AnsiColor.bold)}'
      '${_colorizeDetailedHeader('[TRACE]', colorizeConsoleOutput, _AnsiColor.cyan)}',
    );
    buffer.writeln('${_detailedFieldName('name', colorizeConsoleOutput)}: $traceName');
    buffer.writeln('${_detailedFieldName('event', colorizeConsoleOutput)}: $event');
    if (traceId != null) {
      buffer.writeln('${_detailedFieldName('traceId', colorizeConsoleOutput)}: $traceId');
    }
    if (startedAt != null) {
      buffer.writeln('${_detailedFieldName('startedAt', colorizeConsoleOutput)}: ${_isoFormat.format(startedAt)}');
    }
    if (endedAt != null) {
      buffer.writeln('${_detailedFieldName('endedAt', colorizeConsoleOutput)}: ${_isoFormat.format(endedAt)}');
    }
    if (durationLabel != null) {
      buffer.writeln('${_detailedFieldName('duration', colorizeConsoleOutput)}: $durationLabel');
    }
    if (error != null) {
      buffer.writeln('${_detailedFieldName('error', colorizeConsoleOutput)}: $error');
    }
    if (metadata != null && metadata.isNotEmpty) {
      buffer.writeln('${_detailedFieldName('metadata', colorizeConsoleOutput)}:');
      final keys = metadata.keys.toList()..sort();
      for (final key in keys) {
        buffer.writeln(
          '  ${_detailedFieldName(key, colorizeConsoleOutput)}: ${_truncateOneLine(metadata[key] ?? '', maxLength: 220)}',
        );
      }
    }
    return buffer.toString().trimRight();
  }

  DebugNetworkTransaction? _tryBuildNetworkTransaction(DebugLogEntry entry) {
    if (!_isNetworkEntry(entry)) return null;
    final transactions = DebugNetworkTransactionBuilder.build([entry]);
    if (transactions.isEmpty) return null;
    return transactions.single;
  }

  bool _isNetworkEntry(DebugLogEntry entry) {
    final kind = entry.metadata?['kind']?.toLowerCase();
    return entry.source == DebugLogSource.dio || kind == 'networktransaction';
  }

  String _networkShortCore({
    required DebugNetworkTransaction tx,
    required String statusText,
    required String durationLabel,
    required bool slow,
    required bool colorizeConsoleOutput,
  }) {
    final path = tx.displayPath;
    return switch (tx.phase) {
      DebugNetworkTransactionPhase.pending => _compactNetworkLine([
          _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
          _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
          _coloredNetworkStatus(
            'started',
            statusText,
            slow,
            colorizeConsoleOutput,
            isPending: true,
          ),
        ], colorizeConsoleOutput),
      DebugNetworkTransactionPhase.completed => _compactNetworkLine([
          _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
          _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
          _coloredNetworkStatus(
            statusText,
            statusText,
            slow,
            colorizeConsoleOutput,
          ),
          _coloredDuration(durationLabel, slow, colorizeConsoleOutput),
          if (slow) _coloredText('slow', colorizeConsoleOutput, _AnsiColor.yellow),
        ], colorizeConsoleOutput),
      DebugNetworkTransactionPhase.failed ||
      DebugNetworkTransactionPhase.cancelled ||
      DebugNetworkTransactionPhase.unknown => _compactNetworkLine([
          _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
          _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
          _coloredNetworkStatus(
            _networkFailureText(tx),
            statusText,
            slow,
            colorizeConsoleOutput,
            failed: tx.statusCode == null,
          ),
          _coloredDuration(durationLabel, slow, colorizeConsoleOutput),
          if (slow) _coloredText('slow', colorizeConsoleOutput, _AnsiColor.yellow),
        ], colorizeConsoleOutput),
    };
  }

  String _networkDevCore({
    required DebugNetworkTransaction tx,
    required String statusText,
    required String durationLabel,
    required bool slow,
    required String? error,
    required bool colorizeConsoleOutput,
  }) {
    final path = tx.displayPath;
    final symbol = _networkStatusSymbol(tx, slow: slow);

    final segments = switch (tx.phase) {
      DebugNetworkTransactionPhase.pending => [
          _coloredNetworkSymbol('→', colorizeConsoleOutput, _AnsiColor.cyan),
          _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
          _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
          _coloredNetworkStatus(
            'started',
            statusText,
            slow,
            colorizeConsoleOutput,
            isPending: true,
          ),
        ],
      DebugNetworkTransactionPhase.completed => [
          _coloredNetworkSymbol(symbol, colorizeConsoleOutput, _networkSymbolColor(tx, slow: slow)),
          _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
          _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
          _coloredNetworkStatus(
            statusText,
            statusText,
            slow,
            colorizeConsoleOutput,
          ),
          _coloredDuration(durationLabel, slow, colorizeConsoleOutput),
          if (slow) _coloredText('slow', colorizeConsoleOutput, _AnsiColor.yellow),
        ],
      DebugNetworkTransactionPhase.failed ||
      DebugNetworkTransactionPhase.cancelled ||
      DebugNetworkTransactionPhase.unknown => [
          _coloredNetworkSymbol('✕', colorizeConsoleOutput, _AnsiColor.red),
          _coloredNetworkMethod(tx.method, colorizeConsoleOutput),
          _coloredText(path, colorizeConsoleOutput, _AnsiColor.defaultText),
          _coloredNetworkStatus(
            _networkFailureText(tx),
            statusText,
            slow,
            colorizeConsoleOutput,
            failed: tx.statusCode == null,
          ),
          _coloredDuration(durationLabel, true, colorizeConsoleOutput),
          if (error != null)
            _coloredText(error, colorizeConsoleOutput, _AnsiColor.red),
          if (slow) _coloredText('slow', colorizeConsoleOutput, _AnsiColor.yellow),
        ],
    };

    final prefix = segments.first;
    final remainder = _compactLine(segments.skip(1).toList());
    return remainder.isEmpty ? prefix : '$prefix $remainder';
  }

  String _networkStatusSymbol(
    DebugNetworkTransaction tx, {
    required bool slow,
  }) {
    if (tx.phase == DebugNetworkTransactionPhase.pending) return '→';
    if (tx.phase == DebugNetworkTransactionPhase.cancelled ||
        tx.phase == DebugNetworkTransactionPhase.failed ||
        tx.phase == DebugNetworkTransactionPhase.unknown) {
      return '✕';
    }

    final statusCode = tx.statusCode;
    if (statusCode == null) return slow ? '!' : '✓';
    if (statusCode >= 200 && statusCode <= 299) return slow ? '!' : '✓';
    if (statusCode >= 300 && statusCode <= 399) return '↪';
    if (statusCode >= 400 && statusCode <= 499) return '!';
    return '✕';
  }

  String _networkStatusText(DebugNetworkTransaction tx) {
    final statusCode = tx.statusCode;
    if (statusCode != null) return '$statusCode';
    return switch (tx.phase) {
      DebugNetworkTransactionPhase.pending => 'pending',
      DebugNetworkTransactionPhase.completed => 'completed',
      DebugNetworkTransactionPhase.failed => 'failed',
      DebugNetworkTransactionPhase.cancelled => 'cancelled',
      DebugNetworkTransactionPhase.unknown => 'unknown',
    };
  }

  String _networkFailureText(DebugNetworkTransaction tx) {
    final statusCode = tx.statusCode;
    if (statusCode != null) return '$statusCode';
    return switch (tx.phase) {
      DebugNetworkTransactionPhase.cancelled => 'cancelled',
      DebugNetworkTransactionPhase.unknown => 'unknown',
      _ => 'failed',
    };
  }

  bool _isSlowTransaction(DebugLogEntry entry, DebugNetworkTransaction tx) {
    final metadataSlow = _boolMetadata(entry.metadata, const [
      'slow',
      'is_slow',
      'isSlow',
      'slow_request',
    ]);
    return metadataSlow || tx.isSlow(1000);
  }

  bool _boolMetadata(Map<String, String>? metadata, List<String> keys) {
    if (metadata == null || metadata.isEmpty) return false;
    for (final key in keys) {
      final value = metadata[key];
      if (value == null) continue;
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
    }
    return false;
  }

  String _traceEventLabel(String event) {
    return switch (event.toLowerCase()) {
      'start' => 'started',
      'end' => 'completed',
      'fail' => 'failed',
      'cancel' => 'cancelled',
      'step' => 'step',
      _ => event,
    };
  }

  String _traceTerseSummary({
    required String traceName,
    required String eventLabel,
    required String? durationLabel,
    required String? error,
  }) {
    final parts = <String>[
      traceName,
      eventLabel,
      if (durationLabel != null) durationLabel,
      if (error != null && eventLabel == 'failed') error,
    ];
    return _compactLine(parts);
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    }
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
  }

  String _manualLevelSymbol(DebugLogLevel level) {
    return switch (level) {
      DebugLogLevel.debug => '·',
      DebugLogLevel.info => 'ℹ',
      DebugLogLevel.warning => '!',
      DebugLogLevel.error => '✕',
    };
  }

  String _levelName(DebugLogLevel level) {
    return switch (level) {
      DebugLogLevel.debug => 'DEBUG',
      DebugLogLevel.info => 'INFO',
      DebugLogLevel.warning => 'WARN',
      DebugLogLevel.error => 'ERROR',
    };
  }

  String _truncateOneLine(String text, {int maxLength = 180}) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= maxLength) return singleLine;
    return '${singleLine.substring(0, maxLength - 1)}…';
  }

  String _truncateMultiline(String text,
      {int maxLines = 6, int maxLength = 400}) {
    final lines = text.split('\n');
    final limited = lines.take(maxLines).join('\n');
    final truncated = limited.length <= maxLength
        ? limited
        : '${limited.substring(0, maxLength - 1)}…';
    if (lines.length <= maxLines) return truncated;
    return '$truncated\n… (${lines.length - maxLines} lines trimmed)';
  }

  String _truncateStackTrace(String stackTrace) {
    return _truncateMultiline(stackTrace, maxLines: 6, maxLength: 500);
  }

  String _indent(String text, int spaces) {
    final prefix = ' ' * spaces;
    return text.split('\n').map((line) => '$prefix$line').join('\n');
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String _compactLine(List<String> segments) {
    return segments.where((segment) => segment.trim().isNotEmpty).join(' · ');
  }

  String _compactNetworkLine(List<String> segments, bool colorizeConsoleOutput) {
    if (!colorizeConsoleOutput) {
      return _compactLine(segments);
    }
    return _compactLine(segments);
  }

  String _segmentList(List<String> segments) => _compactLine(segments);

  String _colorizeCompactLine(String text, bool colorizeConsoleOutput) {
    if (!colorizeConsoleOutput) {
      return text;
    }
    return text;
  }

  String _coloredText(
    String text,
    bool colorizeConsoleOutput,
    _AnsiColor color, {
    bool bold = false,
  }) {
    return _applyAnsi(text, colorizeConsoleOutput, color, bold: bold);
  }

  String _coloredToken(
    String token,
    bool colorizeConsoleOutput,
    _AnsiColor color, {
    bool bold = false,
  }) {
    return _applyAnsi(token, colorizeConsoleOutput, color, bold: bold);
  }

  String _coloredLevelToken(
    String token,
    DebugLogLevel level,
    bool colorizeConsoleOutput,
  ) {
    final color = switch (level) {
      DebugLogLevel.debug => _AnsiColor.gray,
      DebugLogLevel.info => _AnsiColor.cyan,
      DebugLogLevel.warning => _AnsiColor.yellow,
      DebugLogLevel.error => _AnsiColor.red,
    };
    return _applyAnsi(token, colorizeConsoleOutput, color, bold: true);
  }

  String _coloredManualSymbol(
    String symbol,
    DebugLogLevel level,
    bool colorizeConsoleOutput,
  ) {
    final color = switch (level) {
      DebugLogLevel.debug => _AnsiColor.gray,
      DebugLogLevel.info => _AnsiColor.cyan,
      DebugLogLevel.warning => _AnsiColor.yellow,
      DebugLogLevel.error => _AnsiColor.red,
    };
    return _applyAnsi(symbol, colorizeConsoleOutput, color, bold: true);
  }

  String _coloredNetworkMethod(String method, bool colorizeConsoleOutput) {
    return _applyAnsi(method, colorizeConsoleOutput, _AnsiColor.cyan, bold: true);
  }

  String _coloredNetworkSymbol(
    String symbol,
    bool colorizeConsoleOutput,
    _AnsiColor color,
  ) {
    return _applyAnsi(symbol, colorizeConsoleOutput, color, bold: true);
  }

  String _coloredNetworkStatus(
    String displayText,
    String referenceText,
    bool slow,
    bool colorizeConsoleOutput, {
    bool isPending = false,
    bool failed = false,
  }) {
    final color = failed
        ? _AnsiColor.red
        : isPending
            ? _AnsiColor.cyan
            : _networkStatusColor(referenceText);
    return _applyAnsi(displayText, colorizeConsoleOutput, color, bold: true);
  }

  String _coloredDuration(
    String durationLabel,
    bool slow,
    bool colorizeConsoleOutput,
  ) {
    return _applyAnsi(
      durationLabel,
      colorizeConsoleOutput,
      slow ? _AnsiColor.yellow : _AnsiColor.gray,
    );
  }

  String _colorizeDetailedHeader(
    String text,
    bool colorizeConsoleOutput,
    _AnsiColor color,
  ) {
    return _applyAnsi(text, colorizeConsoleOutput, color, bold: true);
  }

  String _detailedFieldName(String value, bool colorizeConsoleOutput) {
    return _applyAnsi(value, colorizeConsoleOutput, _AnsiColor.gray);
  }

  _AnsiColor _detailedCategoryColor(String category) {
    return switch (category.toUpperCase()) {
      'NETWORK' => _AnsiColor.cyan,
      'ROUTE' => _AnsiColor.blue,
      'STATE' => _AnsiColor.magenta,
      'TRACE' => _AnsiColor.cyan,
      _ => _AnsiColor.bold,
    };
  }

  _AnsiColor _networkStatusColor(String referenceText) {
    final normalized = referenceText.trim().toLowerCase();
    if (normalized == 'failed' || normalized == 'cancelled' || normalized == 'unknown') {
      return _AnsiColor.red;
    }
    final statusCode = int.tryParse(normalized);
    if (statusCode == null) {
      if (normalized == 'started' || normalized == 'pending') return _AnsiColor.cyan;
      return _AnsiColor.cyan;
    }
    if (statusCode >= 200 && statusCode <= 299) return _AnsiColor.green;
    if (statusCode >= 300 && statusCode <= 399) return _AnsiColor.cyan;
    if (statusCode >= 400 && statusCode <= 499) return _AnsiColor.yellow;
    return _AnsiColor.red;
  }

  _AnsiColor _networkSymbolColor(DebugNetworkTransaction tx, {required bool slow}) {
    final statusCode = tx.statusCode;
    if (tx.phase == DebugNetworkTransactionPhase.pending) return _AnsiColor.cyan;
    if (tx.phase == DebugNetworkTransactionPhase.failed ||
        tx.phase == DebugNetworkTransactionPhase.cancelled ||
        tx.phase == DebugNetworkTransactionPhase.unknown) {
      return _AnsiColor.red;
    }
    if (statusCode == null) return _AnsiColor.cyan;
    if (statusCode >= 200 && statusCode <= 299) return slow ? _AnsiColor.yellow : _AnsiColor.green;
    if (statusCode >= 300 && statusCode <= 399) return _AnsiColor.cyan;
    if (statusCode >= 400 && statusCode <= 499) return _AnsiColor.yellow;
    return _AnsiColor.red;
  }

  String _applyAnsi(
    String text,
    bool enabled,
    _AnsiColor color, {
    bool bold = false,
  }) {
    if (!enabled) return text;
    final buffer = StringBuffer();
    if (bold) buffer.write(_AnsiCodes.bold);
    buffer.write(color.code);
    buffer.write(text);
    buffer.write(_AnsiCodes.reset);
    return buffer.toString();
  }
}

enum _AnsiColor {
  defaultText(_AnsiCodes.defaultColor),
  gray(_AnsiCodes.gray),
  red(_AnsiCodes.red),
  green(_AnsiCodes.green),
  yellow(_AnsiCodes.yellow),
  cyan(_AnsiCodes.cyan),
  blue(_AnsiCodes.blue),
  magenta(_AnsiCodes.magenta),
  bold(_AnsiCodes.defaultColor);

  const _AnsiColor(this.code);
  final String code;
}

final class _AnsiCodes {
  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const defaultColor = '\x1B[39m';
  static const gray = '\x1B[90m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
}
