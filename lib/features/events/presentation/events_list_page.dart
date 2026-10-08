import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_error.dart';
import '../data/event.dart';
import '../data/events_api.dart';
import 'event_details.dart';
import 'event_format.dart';

const _bg = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _chipBg = Color(0xFFF2F1F7);
const _border = Color(0xFFEAEAEA);
const _gold = Color(0xFFE6B800);

/// The "See All" list behind the home rail.
///
/// **Paginated, and the pagination is the point.** The rail shows at most ten;
/// this screen walks the server's `next` link as the user scrolls. The link is
/// followed exactly as sent rather than rebuilt from the filters, because it
/// already encodes every parameter the first request used — rebuilding it would
/// be a second place for the two to disagree, and the first page would silently
/// differ from the second.
///
/// Upcoming events only, by date: the default the backend applies, stated here
/// so the intent survives a change to that default.
class EventsListPage extends ConsumerStatefulWidget {
  const EventsListPage({super.key});

  @override
  ConsumerState<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends ConsumerState<EventsListPage> {
  final _scrollController = ScrollController();

  final List<Event> _events = [];
  String? _nextUrl;
  ApiException? _error;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // `showSpinner: false` because this runs before the first build — see the
    // same note in `event_details.dart`. A pull-to-refresh passes true.
    _loadFirstPage(showSpinner: false);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // A screen-and-a-half of runway, so the next page is usually already there
    // by the time the user reaches the bottom.
    if (position.pixels >= position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _loadFirstPage({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final page = await ref
          .read(eventsApiProvider)
          .list(upcoming: true, pageSize: 20);
      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(page.events);
        _nextUrl = page.nextUrl;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = const ApiException(
          kind: ApiErrorKind.unknown,
          message: 'We could not load events.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final url = _nextUrl;
    // Guarded on both flags: the scroll listener fires on every frame near the
    // bottom, and without this the same page would be requested repeatedly.
    if (url == null || _loadingMore || _loading) return;

    setState(() => _loadingMore = true);

    try {
      final page = await ref.read(eventsApiProvider).nextPage(url);
      if (!mounted) return;
      setState(() {
        _events.addAll(page.events);
        _nextUrl = page.nextUrl;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // A failed *later* page does not discard the pages already on screen — the
      // user keeps what they have and can scroll again to retry.
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upcoming Events',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final error = _error;
    if (error != null) {
      return _buildMessage(
        error.displayMessage,
        actionLabel: 'Try again',
        onAction: _loadFirstPage,
      );
    }

    if (_events.isEmpty) {
      return _buildMessage('No upcoming events right now.');
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      color: _gold,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _events.length + (_nextUrl == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _events.length) return _buildFooter();
          return _buildCard(_events[index]);
        },
      ),
    );
  }

  Widget _buildMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 14,
                color: _gray,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            // The next page is fetched as soon as this row is reached, so a
            // still footer means the request has not come back yet.
            : const SizedBox(height: 20),
      ),
    );
  }

  /// Opens one event, then re-reads just that event on the way back.
  ///
  /// **Not a full reload.** The list holds every page it has fetched, so
  /// reloading would discard the pages the user scrolled past and jump them back
  /// to the top. Registering on the details screen changes one event's counts, so
  /// one request is enough — and it leaves the scroll position alone.
  ///
  /// A failed re-read is swallowed: the card keeps the values it had, and the
  /// details screen has already told the user what happened.
  Future<void> _openDetails(int eventId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailsPage(eventId: eventId)),
    );
    if (!mounted) return;

    final index = _events.indexWhere((event) => event.id == eventId);
    if (index < 0) return;

    try {
      final updated = await ref.read(eventsApiProvider).detail(eventId);
      if (!mounted) return;
      setState(() => _events[index] = updated);
    } catch (_) {
      // Leave the card as it was.
    }
  }

  Widget _buildCard(Event event) {
    final date = eventDateLabel(event.startAt);
    final place = eventPlaceLabel(city: event.city, format: event.format);
    final distance = distanceLabel(event.distanceKm);

    final meta = [
      ?date,
      if (place.isNotEmpty) place,
      ?distance,
    ].join(' \u00b7 ');

    return GestureDetector(
      // Awaited, so the card can be refreshed on the way back — registering or
      // cancelling on the details screen changes the counts shown here.
      onTap: () => _openDetails(event.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 104,
                height: 104,
                child: event.coverImageUrl == null
                    ? _coverPlaceholder()
                    : Image.network(
                        event.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _coverPlaceholder(),
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : _coverPlaceholder(),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: _ink,
                      ),
                    ),
                    if (event.host != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'By ${event.host!.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                      ),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: _chipBg,
      child: const Icon(Icons.event, size: 32, color: Color(0xFFB9B4C7)),
    );
  }
}
