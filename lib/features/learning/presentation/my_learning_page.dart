import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/api_error_snack.dart';
import '../../../core/widgets/course_image.dart';
import '../../auth/data/auth_repository.dart';
import '../../payment/data/payment_api.dart';
import '../../profile/data/user_profile.dart';
import '../data/learning_api.dart';
import '../data/my_learning.dart';
import 'start_course.dart';

/// The My Learning tab.
///
/// **Reads `GET /my-learning/` since 2026-10-27.** Everything here was hardcoded
/// until 2026-10-16 (`68% Complete`, `Lesson 12 of 18`, `24.5h`), then driven by
/// an in-memory store, which at least responded to enrolling but died with the
/// process. It is now the server's answer: a reopened app shows the same courses,
/// the same progress, and the same resume point.
///
/// **What the payload does not give, and what the screen therefore does not
/// show.** `hours_learned` is always null — there are no watch times to sum — so
/// the strip prints `—` rather than a number.
///
/// **`pending_payment` is its own section since 2026-10-30.** It used to be
/// excluded from the endpoint, which meant a student whose app died during
/// checkout saw nothing at all for a course the gateway may already have
/// charged them for. The row is now here with the payment to re-ask about; it is
/// deliberately *not* in Continue learning, because it cannot be resumed.
///
/// **Certificates are metadata only.** The API returns an id, a type and a
/// title — no file, no URL, no serial — so the cards cannot be opened. They show
/// the real title and the real issue date and stop there.
class MyLearningPage extends ConsumerWidget {
  const MyLearningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learning = ref.watch(myLearningProvider);

    return ColoredBox(
      key: const ValueKey('destination-My Learning'),
      color: const Color(0xFFFAF9F6),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myLearningProvider.future),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            child: learning.when(
              loading: () => const _Loading(),
              // A failure keeps a retry rather than an empty screen: "no courses
              // in progress" and "we could not load your courses" are different
              // statements, and only one of them is true.
              error: (error, _) => _LoadFailed(
                error: error,
                onRetry: () => ref.invalidate(myLearningProvider),
                onSignInAgain: () => _signInAgain(context),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.pending.isNotEmpty) ...[
                    _PaymentPending(pending: data.pending),
                    const SizedBox(height: 24),
                  ],
                  _ContinueLearning(learning: data),
                  const SizedBox(height: 24),
                  _LearningStats(learning: data),
                  const SizedBox(height: 28),
                  _Certificates(certificates: data.certificates),
                  const SizedBox(height: 28),
                  _CompletedCourses(courses: data.completed),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 80),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

/// What the failure screen says, and which action it offers.
///
/// `signInAgain` is not decoration: it decides whether the button re-sends the
/// request or ends the session. Retrying a 401 or a 403 re-sends a request the
/// server has already refused, so the button would look broken.
///
/// [actionLabel] is separate from the flag because the two auth failures need
/// different words. A 401 is a dead session — "Sign in again" is the fix. A 403
/// is a **live** session on the wrong kind of account, so signing in again with
/// the same account reproduces it exactly; only switching accounts helps, and
/// "Sign in again" there sends the user in a circle.
typedef MyLearningFailure = ({
  String title,
  String body,
  bool signInAgain,
  String actionLabel,
});

/// Turns whatever `/my-learning/` threw into something true.
///
/// **This screen used to say "Check your connection and try again" for every
/// failure**, and offered "Try again" for all of them. Measured 2026-10-28
/// against the dev backend, `/my-learning/` can fail three ways and only one is
/// connectivity:
///
/// | account | answer |
/// |---|---|
/// | verified student | **200** |
/// | unverified student | **401** `Verify your email before signing in.` |
/// | instructor | **403** `Only active students can access My Learning.` |
///
/// So a signed-in instructor — the account the course builder is used from —
/// saw a Wi-Fi error, and tapping "Try again" reproduced it forever. The
/// distinction was already available: `ApiException.kind` and `.isAuthFailure`
/// exist for exactly this, and `displayMessage` already prefers the server's own
/// wording. This function only decides *which* of those to trust.
///
/// Pure on purpose, so the copy is testable without pumping a screen.
MyLearningFailure myLearningFailureCopy(Object? error) {
  final api = error is ApiException ? error : null;
  final kind = api?.kind;

  if (kind == ApiErrorKind.unauthorized || kind == ApiErrorKind.forbidden) {
    // An expired access token answers `token_not_valid` with DRF's own wording
    // ("Given token not valid for any token type"), which is developer prose.
    // The session genuinely ended, so say that instead of quoting it.
    final expired = api?.code == ApiErrorCode.tokenNotValid;
    final serverSaid = (api?.message ?? '').trim();

    return (
      title: kind == ApiErrorKind.forbidden
          ? 'My Learning is not available for this account.'
          : 'Your session has ended.',
      body: expired || serverSaid.isEmpty
          ? 'Sign in again to see your courses.'
          : api!.displayMessage,
      signInAgain: true,
      // A 403 keeps a valid session, so the honest action is changing account,
      // not signing the same one in again.
      actionLabel: kind == ApiErrorKind.forbidden
          ? 'Switch account'
          : 'Sign in again',
    );
  }

  // Everything else — offline, timeout, 5xx, an unparseable body — is worth
  // another attempt, and `displayMessage` already names the right one.
  return (
    title: 'We could not load your courses.',
    body: api?.displayMessage ?? 'Something went wrong. Please try again.',
    signInAgain: false,
    actionLabel: 'Try again',
  );
}

/// Ends the session so the router's `redirect` sends the user to login.
///
/// Reads from the [ProviderScope] container rather than the widget's `ref`,
/// because `logOut` clears `sessionProvider` and that redirect disposes this
/// page mid-call — a `ref.read` after the `await` would throw on a disposed
/// widget. The container outlives the page, so the profile clear still lands.
Future<void> _signInAgain(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // Best effort on the server side (it blacklists the refresh token); the
  // repository clears the local session either way.
  await container.read(authRepositoryProvider).logOut();
  container.read(userProfileProvider.notifier).clear();
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({
    required this.error,
    required this.onRetry,
    required this.onSignInAgain,
  });

  /// Whatever the provider threw — an [ApiException] in every case that comes
  /// from the network, but typed as `Object?` because the provider is not
  /// obliged to.
  final Object? error;

  final VoidCallback onRetry;
  final VoidCallback onSignInAgain;

  @override
  Widget build(BuildContext context) {
    final copy = myLearningFailureCopy(error);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          // The cloud was the whole problem: it says "offline" before the reader
          // gets to the words, and offline is the one thing that was often not
          // true. A lock for a session problem, a warning for anything else.
          Icon(
            copy.signInAgain ? Icons.lock_outline : Icons.cloud_off_outlined,
            size: 34,
            color: const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 10),
          Text(
            copy.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(copy.body, textAlign: TextAlign.center, style: _mutedSmall()),
          const SizedBox(height: 8),
          TextButton(
            onPressed: copy.signInAgain ? onSignInAgain : onRetry,
            child: Text(copy.actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ContinueLearning extends StatelessWidget {
  const _ContinueLearning({required this.learning});

  final MyLearning learning;

  @override
  Widget build(BuildContext context) {
    final hero = learning.continueLearning;
    final rest = learning.courses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Continue Learning'),
        const SizedBox(height: 12),
        if (hero == null)
          // Nothing resumable. Distinct from an empty account: `rest` can still
          // hold courses, they just have no next lesson.
          const _NothingInProgress()
        else
          _CourseInProgress(learning: hero),
        for (final course in rest)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _MiniCourse(learning: course),
          ),
      ],
    );
  }
}

/// Shown when nothing is resumable.
///
/// An empty state rather than a hardcoded card: with a real endpoint behind this
/// section, a fake course sitting in it would read as a bug.
class _NothingInProgress extends StatelessWidget {
  const _NothingInProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.play_circle_outline,
            size: 34,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing in progress yet',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enrol in a course and it will show up here, ready to resume.',
            textAlign: TextAlign.center,
            style: _mutedSmall(),
          ),
        ],
      ),
    );
  }
}

/// The hero card: the course the server says to resume, with a Resume button.
class _CourseInProgress extends StatelessWidget {
  const _CourseInProgress({required this.learning});

  final LearningCourse learning;

  @override
  Widget build(BuildContext context) {
    final course = learning.course;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 7.1,
            child: CourseImage(
              course.image,
              fallback: const ColoredBox(color: Color(0xFFEDEDED)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // `level` has no column on the server, so this badge is
                    // empty for every API course. It is kept for the catalogue.
                    _Badge(course.level),
                    Text(
                      '${learning.percentLabel} Complete',
                      style: _boldSmall(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(course.title, style: _courseTitle()),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: learning.progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD233)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(learning.positionLabel, style: _mutedSmall()),
                    TextButton(
                      onPressed: () => continueCourse(
                        context,
                        course,
                        startIndex: learning.resumeIndex,
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD233),
                        foregroundColor: const Color(0xFF111827),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Resume', style: _boldSmall()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCourse extends StatelessWidget {
  const _MiniCourse({required this.learning});

  final LearningCourse learning;

  @override
  Widget build(BuildContext context) {
    final course = learning.course;

    return GestureDetector(
      onTap: () =>
          continueCourse(context, course, startIndex: learning.resumeIndex),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 84,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CourseImage(
                course.image,
                width: 60,
                height: 60,
                fallback: const ColoredBox(color: Color(0xFFEDEDED)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _miniTitle(),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: learning.progress,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFF3F4F6),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFE6B800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(learning.percentLabel, style: _boldTiny()),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    learning.positionLabel,
                    style: _tiny(color: const Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stat strip, now from the server.
///
/// `HOURS LEARNED` prints `—` because the endpoint always sends null — there are
/// no watch times to sum. A made-up number sitting beside two real ones is the
/// kind of thing that gets trusted.
class _LearningStats extends StatelessWidget {
  const _LearningStats({required this.learning});

  final MyLearning learning;

  @override
  Widget build(BuildContext context) {
    final stats = learning.stats;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(value: '${learning.all.length}', label: 'ENROLLED'),
          _Stat(value: '${stats.coursesCompleted}', label: 'COMPLETED'),
          _Stat(
            value: stats.hoursLearned == null ? '—' : '${stats.hoursLearned}',
            label: 'HOURS LEARNED',
          ),
          _Stat(value: '${stats.dayStreak}', label: 'DAY STREAK'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: _statValue()),
          const SizedBox(height: 4),
          Text(
            label,
            style: _tiny(color: Color(0xFF4B5563), weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Certificates extends StatelessWidget {
  const _Certificates({required this.certificates});

  final List<CourseCertificate> certificates;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(),
        const SizedBox(height: 8),
        if (certificates.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFEAEAEA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  size: 28,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 8),
                Text(
                  'No certificates yet',
                  style: _mutedSmall(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          // A wrap rather than a fixed two-column row: the API returns any
          // number of certificates, and a Row of Expanded children would
          // overflow at three.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final certificate in certificates)
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 42) / 2,
                  child: _Certificate(certificate: certificate),
                ),
            ],
          ),
      ],
    );
  }
}

class _Certificate extends StatelessWidget {
  const _Certificate({required this.certificate});

  final CourseCertificate certificate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 70,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            certificate.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _cardTitle(),
          ),
          const SizedBox(height: 4),
          // Not "download" — the API returns no file. See the class doc.
          Text(
            certificate.type == 'grade'
                ? 'Grade Certificate'
                : 'Course Certificate',
            style: _tiny(color: const Color(0xFF1E751E)),
          ),
        ],
      ),
    );
  }
}

class _CompletedCourses extends StatelessWidget {
  const _CompletedCourses({required this.courses});

  final List<LearningCourse> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Completed Courses'),
        const SizedBox(height: 12),
        for (final course in courses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CompletedCard(learning: course),
          ),
      ],
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.learning});

  final LearningCourse learning;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => continueCourse(context, learning.course),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEAEAEA)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CourseImage(
                learning.course.image,
                width: 64,
                height: 64,
                fallback: const ColoredBox(color: Color(0xFFEDEDED)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    learning.course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _miniTitle(),
                  ),
                  Text(
                    learning.completedAt == null
                        ? 'Completed'
                        : 'Completed ${_monthYear(learning.completedAt!)}',
                    style: _mutedSmall(),
                  ),
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/figma/learning/check.svg',
                        width: 12,
                        height: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Certificate Issued',
                        style: _tiny(
                          color: Color(0xFF10B981),
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `May 2026` from an ISO timestamp, or `''` when it does not parse.
String _monthYear(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = parsed.toLocal();
  return '${months[local.month - 1]} ${local.year}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF111827),
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// The unpaid courses, above the resumable ones.
///
/// **This section is a hole being closed, not a decoration.** `/my-learning/`
/// used to filter `pending_payment` out entirely, so a student whose app died
/// during checkout opened this tab and found nothing at all for a course the
/// gateway may already have charged them for. It is not in Continue learning —
/// it cannot be resumed — so it needs its own heading and its own two actions.
class _PaymentPending extends StatelessWidget {
  const _PaymentPending({required this.pending});

  final List<PendingEnrolment> pending;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('PAYMENT PENDING'),
        const SizedBox(height: 8),
        for (final row in pending) ...[
          _PendingCard(row: row),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One unpaid enrolment: the course, what the server last saw, and the one
/// action that is safe from here.
class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard({required this.row});

  final PendingEnrolment row;

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _busy = false;

  /// **Two different actions, and the difference matters.** A failed or absent
  /// payment means checkout again. Anything else — `initiated`, or even
  /// `successful` with an enrolment the server has not flipped — means the
  /// gateway may already hold the money, so the only safe move is to re-ask
  /// `GET /payments/{id}/`, which is what refreshes the row. Starting a second
  /// payment from there is how a student pays twice for one course.
  Future<void> _act() async {
    final row = widget.row;

    if (row.needsNewPayment) {
      await startCourse(context, row.course);
      if (mounted) ref.invalidate(myLearningProvider);
      return;
    }

    final id = row.paymentId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final payment = await ref.read(paymentApiProvider).status(id);
      if (!mounted) return;
      ref.invalidate(myLearningProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            payment.isSuccessful
                ? 'Payment confirmed. Your course is ready.'
                : 'The gateway has not confirmed this payment yet. '
                      'Nothing more is needed from you — try again shortly.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) showApiErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final course = row.course;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CourseImage(
                  course.image,
                  width: 56,
                  height: 56,
                  fallback: const ColoredBox(color: Color(0xFFEDEDED)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _miniTitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.statusLabel,
                      style: _tiny(color: const Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _act,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFFD233),
                foregroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      row.needsNewPayment
                          ? 'Complete payment'
                          : 'Check payment',
                      style: _boldSmall(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel([this.label = 'MY CERTIFICATES']);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF4B5563),
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: _tiny(color: const Color(0xFF4B5563), weight: FontWeight.w600),
    ),
  );
}

TextStyle _boldSmall() => const TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);
TextStyle _courseTitle() => const TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);
TextStyle _miniTitle() => const TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);
TextStyle _cardTitle() => const TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
);
TextStyle _mutedSmall() =>
    const TextStyle(fontSize: 11, color: Color(0xFF4B5563));
TextStyle _boldTiny() => const TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w700,
  color: Color(0xFF4B5563),
);
TextStyle _tiny({
  required Color color,
  FontWeight weight = FontWeight.normal,
}) => TextStyle(fontSize: 9, color: color, fontWeight: weight);
TextStyle _statValue() => const TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: Color(0xFF111827),
);
