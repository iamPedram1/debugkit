part of 'debug_network_inspector_screen.dart';

class _DetailSheet extends StatelessWidget {
  final DebugNetworkTransaction transaction;
  final DebugNetworkWaterfallMetrics? waterfall;
  final DebugNetworkTimelineViewport viewport;

  const _DetailSheet({
    required this.transaction,
    this.waterfall,
    required this.viewport,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final hasError =
        tx.isFailed || tx.errorMessage != null || tx.errorType != null;
    final tabCount = 5 + (hasError ? 1 : 0);

    return DefaultTabController(
      length: tabCount,
      child: Column(
        children: [
          // Sheet header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            decoration: const BoxDecoration(
              color: _Dk.surface,
              border: Border(bottom: BorderSide(color: _Dk.border)),
            ),
            child: Row(
              children: [
                _MethodBadge(method: tx.method),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.displayPath,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _Dk.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _StatusBadge(transaction: tx),
                          const SizedBox(width: 6),
                          Text(
                            '${tx.phase.label} · ${tx.durationLabel}',
                            style: const TextStyle(
                                color: _Dk.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy transaction',
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: _Dk.textSecondary),
                  onPressed: () => _copyText(
                      context, _buildFullCopy(tx), 'Transaction copied'),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: _Dk.textSecondary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          // Tab bar
          Theme(
            data: Theme.of(context).copyWith(
              tabBarTheme: const TabBarThemeData(
                labelColor: _Dk.accent,
                unselectedLabelColor: _Dk.textMuted,
                indicatorColor: _Dk.accent,
                labelStyle:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: 12),
                tabAlignment: TabAlignment.start,
              ),
            ),
            child: TabBar(
              isScrollable: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: _Dk.border,
              tabs: [
                const Tab(text: 'Overview'),
                const Tab(text: 'Headers'),
                const Tab(text: 'Request'),
                const Tab(text: 'Response'),
                if (hasError) const Tab(text: 'Error'),
                const Tab(text: 'Timeline'),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: _Dk.bg,
              child: TabBarView(
                children: [
                  _OverviewTabContent(transaction: tx),
                  _HeadersTabContent(transaction: tx),
                  _BodyTabContent(
                    preview: tx.requestBodyPreview,
                    emptyMessage: _requestBodyEmptyMessage(tx),
                  ),
                  _BodyTabContent(
                    preview: tx.responseBodyPreview,
                    emptyMessage: _responseBodyEmptyMessage(tx),
                  ),
                  if (hasError) _ErrorTabContent(transaction: tx),
                  _TimingTabContent(
                    transaction: tx,
                    waterfall: waterfall,
                    viewport: viewport,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _MethodBadge extends StatelessWidget {
  final String method;

  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final color = _methodColor(method);
    final bg = _methodBg(method);
    // Shorten PATCH/DELETE to fit compact width
    final label = method.length > 4 ? method.substring(0, 4) : method;
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DebugNetworkTransaction transaction;

  const _StatusBadge({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final color = tx.isPending ? _Dk.amber : _statusColor(tx.statusFamily);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        tx.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool mono;

  const _MiniLabel({
    required this.text,
    required this.color,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontFamily: mono ? 'monospace' : null,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// Key-value grid — two-column compact display
class _KV {
  final String key;
  final String value;
  const _KV(this.key, this.value);
}

class _KVGrid extends StatelessWidget {
  final List<_KV> rows;

  const _KVGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _Dk.codeBlock,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Dk.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _KVRow(kv: rows[i]),
            if (i < rows.length - 1)
              Container(
                  height: 1,
                  color: _Dk.border,
                  margin: const EdgeInsets.symmetric(vertical: 4)),
          ],
        ],
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final _KV kv;

  const _KVRow({required this.kv});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            kv.key,
            style: const TextStyle(color: _Dk.textMuted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            kv.value,
            style: const TextStyle(
              color: _Dk.textPrimary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// Preview block — code-style box with optional copy button
class _PreviewBlock extends StatelessWidget {
  final String title;
  final String? preview;
  final String emptyMessage;

  const _PreviewBlock({
    required this.title,
    required this.preview,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty) ...[
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: _Dk.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (preview != null)
                _CopyButton(
                  label: 'Copy',
                  onPressed: () => _copyText(context, preview!, 'Copied'),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: _Dk.codeBlock,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _Dk.border),
          ),
          child: preview == null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(
                        color: _Dk.textMuted, fontSize: 11, height: 1.6),
                  ),
                )
              : Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: SelectableText(
                      preview!,
                      style: _Dk.mono,
                    ),
                  ),
                ),
        ),
        if (title.isEmpty && preview != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _CopyButton(
                label: 'Copy',
                onPressed: () => _copyText(context, preview!, 'Copied'),
              ),
            ),
          ),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _CopyButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _Dk.accentDim,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _Dk.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy_rounded, size: 11, color: _Dk.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                  color: _Dk.accent, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final bool noRequests;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.noRequests,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.network_check_outlined,
                size: 56, color: _Dk.textMuted),
            const SizedBox(height: 16),
            Text(
              noRequests ? 'No network requests yet' : 'No matching requests',
              style: const TextStyle(
                color: _Dk.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noRequests
                  ? 'Add debug_kit_dio to your Dio instance to capture requests automatically.'
                  : 'Try adjusting the search or filter chips.',
              style: const TextStyle(
                  color: _Dk.textSecondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (!noRequests) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off, size: 15),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(foregroundColor: _Dk.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty-state message helpers — context-aware, not hardcoded "disabled"
// ---------------------------------------------------------------------------

/// Returns an accurate empty-state message for the Request body tab.
/// The message reflects why the preview is absent — no body on this request
/// type, body was too large, or capture is genuinely disabled.
String _requestBodyEmptyMessage(DebugNetworkTransaction tx) {
  // GET / HEAD / DELETE typically have no body
  if (tx.method == 'GET' || tx.method == 'HEAD' || tx.method == 'DELETE') {
    return '${tx.method} requests do not carry a request body.';
  }
  // Pending requests haven't finished — body may come later
  if (tx.isPending) {
    return 'Request is still pending.';
  }
  // Skipped reasons may appear in metadata
  final skip = tx.metadata['requestBodySkipReason'] ??
      tx.metadata['request_body_skip_reason'];
  if (skip != null) return 'Body not captured: $skip';
  // Default: probably disabled or empty
  return 'No request body captured.\n'
      'If you expected a body here, ensure captureRequestBody: true is set in DebugKitDioConfig.';
}

/// Returns an accurate empty-state message for the Response body tab.
String _responseBodyEmptyMessage(DebugNetworkTransaction tx) {
  if (tx.isPending) {
    return 'Response not received yet — request is still pending.';
  }
  if (tx.isFailed && tx.statusCode == null) {
    return 'Request failed before a response was received.';
  }
  final skip = tx.metadata['responseBodySkipReason'] ??
      tx.metadata['response_body_skip_reason'];
  if (skip != null) return 'Body not captured: $skip';
  return 'No response body captured.\n'
      'If you expected a body here, ensure captureResponseBody: true is set in DebugKitDioConfig.';
}

// ---------------------------------------------------------------------------
// Copy helpers and text builders
// ---------------------------------------------------------------------------

Future<void> _copyText(
  BuildContext context,
  String text,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: _Dk.card,
      ),
    );
  }
}

String _buildSummary(DebugNetworkTransaction tx) {
  return [
    '${tx.method} ${tx.displayPath}',
    'Status: ${tx.statusLabel}',
    'Phase: ${tx.phase.label}',
    'Duration: ${tx.durationLabel}',
    if (tx.requestId != null) 'Request ID: ${tx.requestId}',
    if (tx.traceId != null) 'Trace: ${tx.traceName ?? tx.traceId}',
    if (tx.backendCorrelationId != null)
      'Correlation: ${tx.backendCorrelationId}',
  ].join('\n');
}

String _buildFullCopy(DebugNetworkTransaction tx) {
  return [
    _buildSummary(tx),
    if (tx.url != null) 'URL: ${tx.url}',
    if (tx.host != null) 'Host: ${tx.host}',
    if (tx.query != null) 'Query: ${tx.query}',
    if (tx.errorType != null) 'Error type: ${tx.errorType}',
    if (tx.errorMessage != null) 'Error: ${tx.errorMessage}',
    if (tx.stackTrace != null) 'Stack:\n${tx.stackTrace}',
    if (tx.requestHeadersPreview != null)
      'Request headers:\n${tx.requestHeadersPreview}',
    if (tx.responseHeadersPreview != null)
      'Response headers:\n${tx.responseHeadersPreview}',
    if (tx.requestBodyPreview != null)
      'Request body:\n${tx.requestBodyPreview}',
    if (tx.responseBodyPreview != null)
      'Response body:\n${tx.responseBodyPreview}',
    if (tx.metadata.isNotEmpty)
      'Metadata:\n${tx.metadata.entries.map((e) => '${e.key}=${e.value}').join('\n')}',
  ].join('\n\n');
}
