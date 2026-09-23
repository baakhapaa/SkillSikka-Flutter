import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/network/api_error.dart';

/// Builds a [DioException] the way dio would, without needing a server.
DioException _dioError(
  DioExceptionType type, {
  int? statusCode,
  Object? body,
  Headers? headers,
}) {
  final options = RequestOptions(path: '/probe');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response<Object?>(
            requestOptions: options,
            statusCode: statusCode,
            data: body,
            headers: headers,
          ),
  );
}

void main() {
  group('the error envelope we asked the backend for', () {
    test('reads code, message and per-field errors', () {
      final error = ApiException.fromResponseBody(
        statusCode: 422,
        body: {
          'error': {
            'code': 'validation_error',
            'message': 'One or more fields are invalid.',
            'fields': {'email': 'This email is already registered.'},
          },
        },
      );

      expect(error.kind, ApiErrorKind.validation);
      expect(error.code, 'validation_error');
      expect(error.message, 'One or more fields are invalid.');
      expect(error.fieldError('email'), 'This email is already registered.');
      expect(error.hasFieldErrors, isTrue);
    });

    test('a 409 duplicate is distinguishable from a generic 400', () {
      final taken = ApiException.fromResponseBody(
        statusCode: 409,
        body: {
          'error': {'code': 'email_taken', 'message': 'Email already in use.'},
        },
      );
      final malformed = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'error': {'code': 'bad_request', 'message': 'Malformed.'},
        },
      );

      expect(taken.kind, ApiErrorKind.conflict);
      expect(malformed.kind, ApiErrorKind.badRequest);
      expect(taken.code, isNot(malformed.code));
    });
  });

  group('tolerant parsing, because the contract is not confirmed yet', () {
    test('a bare envelope without the error wrapper', () {
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {'code': 'bad_request', 'message': 'Nope.'},
      );

      expect(error.code, 'bad_request');
      expect(error.message, 'Nope.');
    });

    test('a DRF-style detail string', () {
      final error = ApiException.fromResponseBody(
        statusCode: 404,
        body: {'detail': 'Not found.'},
      );

      expect(error.message, 'Not found.');
      expect(error.kind, ApiErrorKind.notFound);
    });

    test('error as a plain string rather than an object', () {
      final error = ApiException.fromResponseBody(
        statusCode: 403,
        body: {'error': 'You cannot do that.'},
      );

      expect(error.message, 'You cannot do that.');
      expect(error.kind, ApiErrorKind.forbidden);
    });

    test('field errors whose values are lists', () {
      final error = ApiException.fromResponseBody(
        statusCode: 422,
        body: {
          'errors': {
            'email': ['This email is already registered.'],
          },
        },
      );

      expect(error.fieldError('email'), 'This email is already registered.');
    });

    test('field errors whose values are lists of objects', () {
      final error = ApiException.fromResponseBody(
        statusCode: 422,
        body: {
          'errors': {
            'phone': [
              {'message': 'Enter a valid Nepali mobile number.'},
            ],
          },
        },
      );

      expect(error.fieldError('phone'), 'Enter a valid Nepali mobile number.');
    });

    test('field errors whose values are objects', () {
      final error = ApiException.fromResponseBody(
        statusCode: 422,
        body: {
          'fields': {
            'dob': {'message': 'You must be at least 10 years old.'},
          },
        },
      );

      expect(error.fieldError('dob'), 'You must be at least 10 years old.');
    });

    test('an RFC 7807 title counts as the message', () {
      final error = ApiException.fromResponseBody(
        statusCode: 500,
        body: {'title': 'Internal Server Error'},
      );

      expect(error.message, 'Internal Server Error');
    });

    test('a plain-text body from a proxy still yields something showable', () {
      final error = ApiException.fromResponseBody(
        statusCode: 502,
        body: 'Bad Gateway',
      );

      expect(error.kind, ApiErrorKind.server);
      expect(error.message, 'Bad Gateway');
    });

    test('a long message is truncated rather than pasted into a snackbar', () {
      final error = ApiException.fromResponseBody(
        statusCode: 500,
        body: {
          'error': {'message': 'x' * 5000},
        },
      );

      expect(error.message, isNotNull);
      expect(error.message!.length, lessThanOrEqualTo(303));
      expect(error.message, endsWith('...'));
    });

    test('an HTML error page is dropped, not shown', () {
      // A proxy answers a 502 with a document rather than a message. dio hands
      // it over as a string, and `<html><body><h1>502 Bad Gateway</h1>` in a
      // snackbar is worse than the generic fallback.
      final error = ApiException.fromResponseBody(
        statusCode: 502,
        body: '<html>${'x' * 5000}</html>',
      );

      expect(error.kind, ApiErrorKind.server);
      expect(error.message, isNull);
      expect(error.displayMessage, isNotEmpty);
      expect(error.displayMessage, isNot(contains('<')));
    });

    test('markup nested inside an envelope is dropped too', () {
      final error = ApiException.fromResponseBody(
        statusCode: 502,
        body: {
          'error': {'message': '<html><body>Bad Gateway</body></html>'},
        },
      );

      expect(error.message, isNull);
    });

    test('a message that merely contains an angle bracket survives', () {
      // The markup check is "starts with a tag", so ordinary copy is untouched.
      final error = ApiException.fromResponseBody(
        statusCode: 422,
        body: {
          'error': {'message': 'Password must be < 8 characters.'},
        },
      );

      expect(error.message, 'Password must be < 8 characters.');
    });

    test(
      'an empty or unusable body leaves message null so the default applies',
      () {
        for (final body in <Object?>[
          null,
          '',
          '   ',
          42,
          <Object?>[],
          <String, Object?>{},
        ]) {
          final error = ApiException.fromResponseBody(
            statusCode: 500,
            body: body,
          );
          expect(error.message, isNull, reason: 'body was $body');
          expect(
            error.displayMessage,
            isNotEmpty,
            reason: 'a user must never see an empty message for $body',
          );
        }
      },
    );

    test('a non-string field key is ignored rather than throwing', () {
      final error = ApiException.fromResponseBody(
        statusCode: 422,
        body: {
          'errors': {7: 'numeric key'},
        },
      );

      expect(error.hasFieldErrors, isFalse);
    });
  });

  group('status to kind', () {
    test('maps the codes the UI branches on', () {
      const expected = {
        400: ApiErrorKind.badRequest,
        401: ApiErrorKind.unauthorized,
        403: ApiErrorKind.forbidden,
        404: ApiErrorKind.notFound,
        409: ApiErrorKind.conflict,
        422: ApiErrorKind.validation,
        429: ApiErrorKind.rateLimited,
        500: ApiErrorKind.server,
        503: ApiErrorKind.server,
        418: ApiErrorKind.unknown,
      };

      expected.forEach((status, kind) {
        expect(
          ApiException.fromResponseBody(statusCode: status).kind,
          kind,
          reason: 'status $status',
        );
      });
    });
  });

  group('DioException normalisation', () {
    test('timeouts of every flavour become timeout', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          ApiException.fromDio(_dioError(type)).kind,
          ApiErrorKind.timeout,
          reason: '$type',
        );
      }
    });

    test('transport failures become network, not unknown', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.badCertificate,
      ]) {
        expect(
          ApiException.fromDio(_dioError(type)).kind,
          ApiErrorKind.network,
        );
      }
    });

    test('an unknown failure with no response is treated as connectivity', () {
      // This is what a browser reports when the request never left the device.
      // Calling it "unknown" would send the user to support for their wifi.
      expect(
        ApiException.fromDio(_dioError(DioExceptionType.unknown)).kind,
        ApiErrorKind.network,
      );
    });

    test('a cancel is its own kind so callers can ignore it', () {
      expect(
        ApiException.fromDio(_dioError(DioExceptionType.cancel)).kind,
        ApiErrorKind.cancelled,
      );
    });

    test('a bad response keeps its status and parsed body', () {
      final error = ApiException.fromDio(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 409,
          body: {
            'error': {
              'code': 'email_taken',
              'fields': {'email': 'This email is already registered.'},
            },
          },
        ),
      );

      expect(error.statusCode, 409);
      expect(error.kind, ApiErrorKind.conflict);
      expect(error.code, 'email_taken');
      expect(error.fieldError('email'), 'This email is already registered.');
    });

    test('Retry-After is read as a duration', () {
      final error = ApiException.fromDio(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 429,
          body: {'message': 'Too many attempts.'},
          headers: Headers.fromMap({
            'retry-after': ['30'],
          }),
        ),
      );

      expect(error.kind, ApiErrorKind.rateLimited);
      expect(error.retryAfter, const Duration(seconds: 30));
    });

    test('a Retry-After date is ignored rather than guessed at', () {
      final error = ApiException.fromDio(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 429,
          body: {'message': 'Too many attempts.'},
          headers: Headers.fromMap({
            'retry-after': ['Wed, 23 Sep 2026 14:30:00 GMT'],
          }),
        ),
      );

      expect(error.retryAfter, isNull);
    });

    test('the original error is kept for logging', () {
      final original = _dioError(DioExceptionType.connectionTimeout);
      expect(ApiException.fromDio(original).cause, same(original));
    });
  });

  // The backend is Django REST Framework, so these are not hypothetical
  // neighbours — they are the *default* bodies DRF produces, and the UI is
  // useless if they do not survive parsing.
  group('DRF default error bodies', () {
    test('a serializer validation error is a bare field-to-list map', () {
      // This is exactly what a DRF serializer returns for a 400: no envelope,
      // no `message`, no `code`. Just field -> list of strings.
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'email': ['This email is already registered.'],
          'password': ['This password is too short.'],
        },
      );

      expect(error.kind, ApiErrorKind.badRequest);
      expect(error.fieldError('email'), 'This email is already registered.');
      expect(error.fieldError('password'), 'This password is too short.');
      expect(error.hasFieldErrors, isTrue);
    });

    test('a single-field serializer error keeps its field name', () {
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'phone': ['Enter a valid Nepali mobile number.'],
        },
      );

      expect(error.fieldErrors.keys, ['phone']);
    });

    test('non_field_errors is a banner message, not a form field', () {
      // DRF puts object-level validation here. There is no input to highlight,
      // so it must surface as the message instead of a field named
      // `non_field_errors` that no form can match.
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'non_field_errors': ['Unable to log in with provided credentials.'],
        },
      );

      expect(error.message, 'Unable to log in with provided credentials.');
      expect(error.hasFieldErrors, isFalse);
      expect(
        error.displayMessage,
        'Unable to log in with provided credentials.',
      );
    });

    test('non_field_errors alongside field errors keeps both', () {
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'non_field_errors': ['Passwords do not match.'],
          'email': ['This email is already registered.'],
        },
      );

      expect(error.message, 'Passwords do not match.');
      expect(error.fieldError('email'), 'This email is already registered.');
    });

    test('a 401 detail body carries no field errors', () {
      final error = ApiException.fromResponseBody(
        statusCode: 401,
        body: {'detail': 'Authentication credentials were not provided.'},
      );

      expect(error.kind, ApiErrorKind.unauthorized);
      expect(error.message, 'Authentication credentials were not provided.');
      expect(error.hasFieldErrors, isFalse);
      expect(error.isAuthFailure, isTrue);
    });

    test('a 403 detail body is a permission failure, not a field error', () {
      final error = ApiException.fromResponseBody(
        statusCode: 403,
        body: {'detail': 'You do not have permission to perform this action.'},
      );

      expect(error.kind, ApiErrorKind.forbidden);
      expect(error.hasFieldErrors, isFalse);
    });

    test('DRF with a custom exception handler keeps code and fields', () {
      // A DRF app that has adopted the envelope we asked for, still emitting
      // serializer errors in the usual place.
      final error = ApiException.fromResponseBody(
        statusCode: 409,
        body: {
          'error': {
            'code': 'email_taken',
            'message': 'This email is already registered.',
            'fields': {
              'email': ['This email is already registered.'],
            },
          },
        },
      );

      expect(error.code, 'email_taken');
      expect(error.fieldError('email'), 'This email is already registered.');
    });

    test('drf-standardized-errors sends a list under `errors`, not a map', () {
      // The package the DRF docs recommend for a uniform error format. Read as a
      // map it becomes one field called `errors` holding the first message, which
      // no form can match — and it hides every real error.
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'type': 'validation_error',
          'errors': [
            {
              'code': 'required',
              'detail': 'This field is required.',
              'attr': 'name',
            },
            {
              'code': 'invalid',
              'detail': 'Enter a valid email address.',
              'attr': 'email',
            },
          ],
        },
      );

      expect(error.kind, ApiErrorKind.badRequest);
      expect(error.code, 'validation_error');
      expect(error.fieldError('name'), 'This field is required.');
      expect(error.fieldError('email'), 'Enter a valid email address.');
      expect(error.fieldErrors.containsKey('errors'), isFalse);
    });

    test('a standardized error with no attr is a banner, not a field', () {
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'type': 'validation_error',
          'errors': [
            {
              'code': 'invalid',
              'detail': 'Passwords do not match.',
              'attr': null,
            },
          ],
        },
      );

      expect(error.message, 'Passwords do not match.');
      expect(error.hasFieldErrors, isFalse);
    });

    test('a nested standardized error keeps the dotted field path', () {
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'type': 'validation_error',
          'errors': [
            {
              'code': 'invalid',
              'detail': 'Enter a valid phone number.',
              'attr': 'profile.phone',
            },
          ],
        },
      );

      expect(error.fieldError('profile.phone'), 'Enter a valid phone number.');
    });

    test('DRF get_full_details keeps the code per field', () {
      // `serializer.errors` / `exc.get_full_details()` emit `{message, code}`
      // per field, which is what a DRF team sees when debugging and may well
      // send to us.
      final error = ApiException.fromResponseBody(
        statusCode: 400,
        body: {
          'email': {'message': 'This field is required.', 'code': 'required'},
        },
      );

      expect(error.fieldError('email'), 'This field is required.');
    });

    test('a DRF throttled 429 keeps its numeric Retry-After', () {
      final error = ApiException.fromDio(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 429,
          body: {
            'detail':
                'Request was throttled. Expected available in 42 seconds.',
          },
          headers: Headers.fromMap({
            'retry-after': ['42'],
          }),
        ),
      );

      expect(error.kind, ApiErrorKind.rateLimited);
      expect(error.retryAfter, const Duration(seconds: 42));
    });
  });

  group('what the UI asks of an error', () {
    test('only auth failures are auth failures', () {
      expect(
        ApiException.fromResponseBody(statusCode: 401).isAuthFailure,
        isTrue,
      );
      expect(
        ApiException.fromResponseBody(statusCode: 403).isAuthFailure,
        isTrue,
      );
      expect(
        ApiException.fromResponseBody(statusCode: 422).isAuthFailure,
        isFalse,
      );
    });

    test(
      'a validation failure is not retryable but a dropped connection is',
      () {
        expect(
          ApiException.fromResponseBody(statusCode: 422).isRetryable,
          isFalse,
          reason: 'the same body would fail the same way',
        );
        expect(
          ApiException.fromResponseBody(statusCode: 409).isRetryable,
          isFalse,
        );
        for (final status in [500, 503, 429]) {
          expect(
            ApiException.fromResponseBody(statusCode: status).isRetryable,
            isTrue,
            reason: 'status $status',
          );
        }
        expect(
          ApiException.fromDio(
            _dioError(DioExceptionType.connectionError),
          ).isRetryable,
          isTrue,
        );
      },
    );

    test('every kind has a fallback message with no server input', () {
      for (final kind in ApiErrorKind.values) {
        expect(
          ApiException(kind: kind).displayMessage,
          isNotEmpty,
          reason: '${kind.name} has no default message',
        );
      }
    });

    test('the server wording wins over the fallback when present', () {
      final error = ApiException.fromResponseBody(
        statusCode: 409,
        body: {
          'error': {'message': 'That email is already registered.'},
        },
      );

      expect(error.displayMessage, 'That email is already registered.');
    });

    test('toString names the kind and the fields, but not the body', () {
      final error = ApiException.fromResponseBody(
        statusCode: 422,
        body: {
          'error': {
            'code': 'validation_error',
            'message': 'secret-looking detail',
            'fields': {'email': 'taken'},
          },
        },
      );

      expect(error.toString(), contains('validation'));
      expect(error.toString(), contains('email'));
      expect(error.toString(), isNot(contains('secret-looking detail')));
    });
  });
}
