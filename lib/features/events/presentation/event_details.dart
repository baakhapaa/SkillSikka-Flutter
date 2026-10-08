import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_error.dart';
import '../data/event.dart';
import '../data/events_api.dart';
import '../data/events_providers.dart';
import 'event_format.dart';

const _bg = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);
const _gray = Color(0xFF4B5563);
const _chipBg = Color(0xFFF2F1F7);
const _border = Color(0xFFEAEAEA);
const _gold = Color(0xFFE6B800);
const _iconYellowBg = Color(0xFFFDF6DD);
const _iconBlueBg = Color(0xFFEEF2F6);
const _star = Color(0xFFFBBF24);

/// One event, loaded by id.
///
/// **Takes an id.** It used to take nothing and render a single hardcoded event,
/// which is why every card in the rail opened the same page. The id is what
/// makes this a detail view rather than a mock-up.
///
/// Every field on the payload can be absent — the cover, the host, the host's
/// avatar, the highlights, the attendee avatars, the coordinates, the capacity
/// and (today) the rating — so each row hides itself rather than rendering a
/// blank. That is the whole of the null-handling requirement, and it is done per
/// row rather than with one guard, because the right answer differs per row: a
/// missing cover wants a placeholder, a missing host wants no row at all.
class EventDetailsPage extends ConsumerStatefulWidget {
  const EventDetailsPage({required this.eventId, super.key});

  final int eventId;

  @override
  ConsumerState<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends ConsumerState<EventDetailsPage> {
  Event? _event;
  ApiException? _error;
  bool _loading = true;

  /// Register / cancel in flight. Separate from [_saving] so a slow registration
  /// does not also freeze the bookmark.
  bool _registering = false;
  bool _saving = false;

  /// The bookmark state, held here so it can flip optimistically and revert on
  /// failure. Seeded from the event's own `is_saved`.
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    // `showSpinner: false` because this runs before the first build: the fields
    // already start in the loading state, so there is nothing to change and no
    // rebuild to request. A retry passes true, so the spinner does come back.
    _load(showSpinner: false);
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final event = await ref.read(eventsApiProvider).detail(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = event;
        _bookmarked = event.isSaved;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      // A deleted or unpublished event is not an error to show — the page has
      // nothing to be, so it leaves and says why. The brief asks for exactly this
      // on a 404.
      if (error.kind == ApiErrorKind.notFound) {
        Navigator.of(context).maybePop();
        _showMessage('That event is no longer available.');
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = const ApiException(
          kind: ApiErrorKind.unknown,
          message: 'We could not load this event.',
        );
        _loading = false;
      });
    }
  }

  /// Register, join the waitlist, or cancel — whichever the current state means.
  ///
  /// The returned event replaces the local one, so counts, seats and the button
  /// all update from the server's own numbers without a second GET. That matters
  /// most on a cancel, where the server may promote a waitlisted person and the
  /// client cannot know it.
  Future<void> _toggleRegistration() async {
    final event = _event;
    if (event == null || _registering) return;

    final cancelling = event.myStatus.isOnList;
    if (cancelling) {
      final confirmed = await _confirmCancel(event);
      if (!confirmed || !mounted) return;
    }

    setState(() => _registering = true);

    try {
      final api = ref.read(eventsApiProvider);
      final updated = cancelling
          ? await api.cancelRegistration(event.id)
          : await api.register(event.id);
      if (!mounted) return;

      final next = cancelling
          ? (updated ??
                event.withLocalRegistration(EventRegistrationStatus.none))
          : (updated ??
                event.withLocalRegistration(
                  // No body to read the status from, so infer it: the only way a
                  // registration lands on the waitlist is a full event.
                  event.isFull
                      ? EventRegistrationStatus.waitlisted
                      : EventRegistrationStatus.registered,
                ));

      setState(() {
        _event = next;
        _registering = false;
      });

      // **The rail caches its own copy of the list, so the update above is
      // invisible on the home screen.** Without this the card behind this route
      // keeps showing the count it was fetched with — which is how a successful
      // registration still read "Be the first to join". The home page stays
      // mounted behind a pushed route, so its `Consumer` is listening and picks
      // the refetch up straight away.
      //
      // Deliberately only the events: the device position is a separate provider
      // (see `devicePositionProvider`) so this does not re-run the GPS lookup.
      ref.invalidate(nearbyEventsProvider);

      if (!cancelling) {
        _showMessage(
          next.myStatus == EventRegistrationStatus.waitlisted
              ? "Event is full — you're on the waitlist."
              : "You're registered!",
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _registering = false);

      // The event went away underneath us: leave rather than show a button that
      // cannot work.
      if (error.kind == ApiErrorKind.notFound) {
        Navigator.of(context).maybePop();
        _showMessage('That event is no longer available.');
        return;
      }

      _showMessage(error.displayMessage);

      // A 400 here is most often "This event has already ended." — re-read the
      // event so the button reflects the real state instead of inviting the same
      // failure again.
      if (error.kind == ApiErrorKind.badRequest) await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _registering = false);
      _showMessage('Something went wrong. Please try again.');
    }
  }

  /// Flips the bookmark optimistically and reverts it if the call fails.
  ///
  /// Optimistic because the icon must respond to the tap immediately; reverted
  /// because a bookmark that silently did not save is worse than one that
  /// visibly bounced back.
  Future<void> _toggleBookmark() async {
    final event = _event;
    if (event == null || _saving) return;

    final next = !_bookmarked;
    setState(() {
      _bookmarked = next;
      _saving = true;
    });

    try {
      final api = ref.read(eventsApiProvider);
      final confirmed = next
          ? await api.save(event.id)
          : await api.unsave(event.id);
      if (!mounted) return;
      final settled = confirmed ?? next;
      setState(() {
        _bookmarked = settled;
        _event = event.copyWith(isSaved: settled);
        _saving = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _bookmarked = !next;
        _saving = false;
      });
      _showMessage(error.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bookmarked = !next;
        _saving = false;
      });
      _showMessage('Something went wrong. Please try again.');
    }
  }

  Future<bool> _confirmCancel(Event event) async {
    final leavingWaitlist =
        event.myStatus == EventRegistrationStatus.waitlisted;
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          leavingWaitlist ? 'Leave the waitlist?' : 'Cancel registration?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: _ink),
        ),
        content: Text(
          leavingWaitlist
              ? 'You will lose your place in the queue for this event.'
              : 'Your seat will be released, and the next person on the waitlist '
                    'will be offered it.',
          style: GoogleFonts.figtree(color: _gray, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Keep my place',
              style: GoogleFonts.figtree(
                fontWeight: FontWeight.w600,
                color: _gray,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              leavingWaitlist ? 'Leave' : 'Cancel registration',
              style: GoogleFonts.figtree(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB42318),
              ),
            ),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildScreenHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final error = _error;
    if (error != null) return _buildError(error);

    final event = _event;
    if (event == null) {
      // Unreachable in practice — either the event or an error is set — but the
      // page must not render a blank screen if that ever stops being true.
      return _buildError(
        const ApiException(
          kind: ApiErrorKind.unknown,
          message: 'We could not load this event.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBanner(event),
          const SizedBox(height: 20),
          _buildTitleHost(event),
          const SizedBox(height: 20),
          _buildInfoCards(event),
          const SizedBox(height: 20),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 20),
          _buildAboutSection(event),
          if (event.highlights.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildWhatYouLearn(event),
          ],
          const SizedBox(height: 20),
          _buildAttendees(event),
          const SizedBox(height: 20),
          _buildRegisterButton(event),
        ],
      ),
    );
  }

  Widget _buildError(ApiException error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: _gray),
            const SizedBox(height: 12),
            Text(
              error.displayMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 14,
                color: _gray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _load,
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
                  'Try again',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenHeader() {
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
              'Event Details',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          // Hidden until the event has loaded, so a tap cannot act on an id the
          // page does not have yet.
          if (_event != null)
            GestureDetector(
              onTap: _toggleBookmark,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _chipBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(
                  _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: _bookmarked ? _star : _gray,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBanner(Event event) {
    final url = event.coverImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 203,
        width: double.infinity,
        child: url == null
            ? _bannerPlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                // No token: the brief states these are public same-origin URLs,
                // so a plain `Image.network` is right and an authenticated fetch
                // would be unnecessary.
                errorBuilder: (_, _, _) => _bannerPlaceholder(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _bannerPlaceholder(),
              ),
      ),
    );
  }

  Widget _bannerPlaceholder() {
    return Container(
      color: _chipBg,
      child: const Icon(Icons.event, size: 60, color: Color(0xFFB9B4C7)),
    );
  }

  Widget _buildTitleHost(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: _ink,
          ),
        ),
        // The rating is null on every event today, so this block is normally
        // absent. Written rather than commented out so it starts working the day
        // the backend has ratings, with no change here.
        if (event.rating != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  Icons.star,
                  size: 14,
                  color: i < event.rating!.round()
                      ? _star
                      : const Color(0xFFE5E7EB),
                ),
              const SizedBox(width: 6),
              Text(
                ratingLabel(event.rating!),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _gray,
                ),
              ),
            ],
          ),
        ],
        if (event.host != null) ...[
          const SizedBox(height: 12),
          _buildHostRow(event.host!),
        ],
      ],
    );
  }

  Widget _buildHostRow(EventHost host) {
    return Row(
      children: [
        ClipOval(child: _buildHostAvatar(host)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                host.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(
                host.role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(fontSize: 11, color: _gray),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The host's photo, or their initial when they have none.
  ///
  /// A named host with no avatar is common — the sample data has one — so the
  /// placeholder carries the initial rather than a generic silhouette.
  Widget _buildHostAvatar(EventHost host) {
    final url = host.avatarUrl;
    if (url == null) return _initialsCircle(host.initial, 36);
    return Image.network(
      url,
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _initialsCircle(host.initial, 36),
    );
  }

  Widget _initialsCircle(String initial, double size) {
    return Container(
      width: size,
      height: size,
      color: _iconBlueBg,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.manrope(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF4A6B8A),
        ),
      ),
    );
  }

  Widget _buildInfoCards(Event event) {
    final date = eventDateLabel(event.startAt);
    final time = eventTimeLabel(event.startAt, event.endAt);
    final place = eventPlaceLabel(city: event.city, format: event.format);
    final distance = distanceLabel(event.distanceKm);

    final hasPlaceRow = event.venueName.isNotEmpty || place.isNotEmpty;
    final cards = <Widget>[
      if (date != null)
        _buildInfoCard(
          iconBg: _iconYellowBg,
          icon: Icons.calendar_today_outlined,
          iconColor: const Color(0xFFB98A00),
          title: date,
          subtitle: time ?? '',
        ),
      if (hasPlaceRow)
        _buildInfoCard(
          iconBg: _iconBlueBg,
          icon: Icons.location_on_outlined,
          iconColor: const Color(0xFF4A6B8A),
          title: event.venueName.isNotEmpty ? event.venueName : place,
          // The second line carries the city, with the distance appended when
          // the server sent one — rather than a third card for a single number.
          subtitle: event.venueName.isNotEmpty
              ? (distance == null ? place : '$place \u00b7 $distance')
              : (distance ?? ''),
        ),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          cards[i],
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required Color iconBg,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(Event event) {
    // A missing description hides the whole section — an "About Event" heading
    // over an empty paragraph is worse than no section.
    if (event.description.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Event',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          event.description,
          style: GoogleFonts.figtree(fontSize: 13, height: 1.5, color: _gray),
        ),
      ],
    );
  }

  Widget _buildWhatYouLearn(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What you'll learn",
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in event.highlights) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Color(0xFF22C55E),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      height: 1.4,
                      color: _gray,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttendees(Event event) {
    final spots = spotsLabel(event.spotsLeft);
    final avatars = event.attendeeAvatars;

    return Row(
      children: [
        if (avatars.isNotEmpty) ...[
          _buildAvatarStack(avatars),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attendingLabel(event.attendeeCount),
                style: GoogleFonts.figtree(fontSize: 12, color: _gray),
              ),
              if (spots != null)
                Text(
                  spots,
                  style: GoogleFonts.figtree(fontSize: 11, color: _gray),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Up to four overlapping avatars, as the design has it.
  ///
  /// The brief caps the list at four URLs server-side; the cap is repeated here
  /// because the layout arithmetic depends on it — a fifth avatar would push the
  /// row off the screen rather than merely looking different.
  Widget _buildAvatarStack(List<String> urls) {
    const avatarSize = 28.0;
    const overlap = 8.0;
    final shown = urls.take(4).toList(growable: false);
    final totalWidth = avatarSize + (shown.length - 1) * (avatarSize - overlap);

    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (avatarSize - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: Image.network(
                    shown[i],
                    width: avatarSize,
                    height: avatarSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _initialsCircle('?', avatarSize),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton(Event event) {
    final action = _registerAction(event);
    final enabled = action.enabled && !_registering;

    return GestureDetector(
      onTap: enabled ? _toggleRegistration : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          // A disabled button is greyed rather than hidden: the user needs to see
          // that the action exists and is unavailable, which is what "Event
          // ended" is telling them.
          color: enabled ? _gold : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Center(
          child: _registering
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: enabled ? Colors.white : _gray,
                      ),
                    ),
                    if (action.showCheck) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  /// What the register control says and does, from `my_status`, `spots_left` and
  /// `end_at` — the table in the backend brief §5.
  ({String label, bool enabled, bool showCheck}) _registerAction(Event event) {
    if (event.hasEnded) {
      return (label: 'Event ended', enabled: false, showCheck: false);
    }
    switch (event.myStatus) {
      case EventRegistrationStatus.registered:
        return (label: 'Registered', enabled: true, showCheck: true);
      case EventRegistrationStatus.waitlisted:
        return (label: 'On waitlist', enabled: true, showCheck: false);
      case EventRegistrationStatus.none:
      case EventRegistrationStatus.unknown:
        return (
          label: event.isFull ? 'Join waitlist' : 'Register Now',
          enabled: true,
          showCheck: false,
        );
    }
  }
}
