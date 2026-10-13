enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromName(String value) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == value.toLowerCase(),
      orElse: () => AppEnvironment.development,
    );
  }
}

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  factory AppConfig.fromDefines() {
    final environment = AppEnvironment.fromName(
      const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
    );
    final configuredUrl = const String.fromEnvironment('API_BASE_URL');

    return AppConfig(
      environment: environment,
      apiBaseUrl: configuredUrl.isNotEmpty
          ? configuredUrl
          : _defaultUrls[environment]!,
    );
  }

  final AppEnvironment environment;
  final String apiBaseUrl;

  /// The backend confirms a **`/api/v1/`** prefix, so it is part of every URL
  /// here. The staging and production *hosts* are still unconfirmed on both
  /// sides — they are placeholders, and `v1` is the only segment of them that is
  /// settled. Override with `--dart-define=API_BASE_URL=...` when they are known.
  ///
  /// **`127.0.0.1` is the host machine only on web, desktop and the iOS
  /// simulator.** An Android emulator has its own loopback, so `127.0.0.1` there
  /// is the emulator itself and every request fails with `Connection refused`
  /// (errno 111) — which reads like the backend being down when it is not. Use
  /// the emulator's alias for the host instead:
  ///
  /// ```
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  /// ```
  ///
  /// `10.0.2.2` is routed to the host's *loopback*, so Django's default
  /// `runserver` is reachable through it.
  ///
  /// **A physical device is a different problem, and `10.0.2.2` is meaningless
  /// there** — it is just a private address nothing routes to, so the failure
  /// changes from `Connection refused` to a **connect timeout**. Tunnel the port
  /// instead of addressing the host over the network:
  ///
  /// ```
  /// adb reverse tcp:8000 tcp:8000
  /// flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
  /// ```
  ///
  /// That forwards the *device's* `127.0.0.1:8000` to the host, and requests
  /// arrive with `Host: 127.0.0.1:8000`, which Django's default `ALLOWED_HOSTS`
  /// accepts under `DEBUG`, unlike `10.0.2.2`. It must be re-run after the
  /// device reconnects, and the explicit `--dart-define` is **required** now
  /// that the default is the LAN address below rather than loopback.
  ///
  /// **The host's LAN address is the other route, and the one to prefer when
  /// there is a real backend to talk to.** It survives a device reconnect, needs
  /// no `adb`, and works from a second machine or an iOS device. Three things
  /// have to be true, and each fails differently:
  ///
  /// 1. The server must listen beyond loopback — `runserver`'s default binds
  ///    `127.0.0.1` only. `python manage.py runserver 0.0.0.0:8000`.
  /// 2. The address must be in Django's `ALLOWED_HOSTS`, as a **bare host**:
  ///    `'192.168.1.77'`, no scheme and no port. Django compares it against the
  ///    `Host` header with the port stripped, so `'http://192.168.1.77:8000'`
  ///    never matches, and `0.0.0.0` cannot be listed at all — it is a bind
  ///    directive, not an address a client sends. Under `DEBUG=True` Django
  ///    narrows the default to `localhost`, `127.0.0.1` and `[::1]`, so the LAN
  ///    address is rejected with `DisallowedHost` (400) until it is added.
  /// 3. Both devices on the same network, and inbound TCP 8000 allowed by the
  ///    host's firewall — on Windows the first launch prompts, and a click on
  ///    "Cancel" leaves a rule that silently drops the packets.
  ///
  /// ```
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.77:8000/api/v1
  /// ```
  ///
  /// A quick confirmation that the host, address and firewall are all right,
  /// before involving Flutter: open `http://192.168.1.77:8000/api/v1/` in the
  /// phone's browser. A JSON 404 means the request got through; a timeout or a
  /// "site can't be reached" means it did not, and the problem is on the host.
  ///
  /// Note this address also decides what the *server* sees, so anything the
  /// backend does with request origins (CORS, `CSRF_TRUSTED_ORIGINS`) has to
  /// name this host too.
  ///
  /// **The LAN address of the development machine is the default as of
  /// 2026-10-09.** The backend runs on that same machine, and a physical Android
  /// device reaches it over Wi-Fi with **no `adb` tunnel** — which is the point:
  /// `adb` is not on this machine's `PATH`, and a failed `adb reverse` leaves the
  /// app running with every request refused, which reads like a backend fault.
  ///
  /// Two conditions are required, both server-side:
  ///
  /// 1. `python manage.py runserver 0.0.0.0:8000` — the default binds
  ///    `127.0.0.1`, which a phone cannot reach.
  /// 2. This address listed in `ALLOWED_HOSTS` (set in
  ///    `D:\SkillSikka-Django\.env`), or Django answers `400 DisallowedHost`.
  ///
  /// **This address is DHCP-assigned and can change** — the backend's lease has
  /// already moved three times between 2026-09-28 and 2026-10-07 (`.84` → `.77` →
  /// `.68`). When it moves, either update this line, set a DHCP reservation, or
  /// override at launch with `--dart-define=API_BASE_URL=...`, which needs no code
  /// change.
  ///
  /// For a device with no usable LAN path — a different network, or a firewall
  /// that drops inbound — the fallback is the `adb reverse` tunnel described
  /// above, which needs an explicit
  /// `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`, since loopback is
  /// no longer the default.
  ///
  /// Because this is a LAN address, it only resolves on the network that owns it:
  /// a device on a different network cannot reach it and needs the tunnel above
  /// instead, and the server must actually be running on that address.
  ///
  /// Reachability can be checked without Flutter: the URL in a browser, or a
  /// raw TCP probe. Any HTTP response at all, even `400`, means the request got
  /// through.
  ///
  /// A **timeout** and a **connection refused** are both "the request did not
  /// arrive", but they are different faults and the fix is not the same:
  ///
  /// * **Refused** — the host answered with a reset. Routing and the firewall
  ///   are fine and nothing is bound to that port: the server is down, or still
  ///   on loopback. Fix on the host's `runserver` line.
  /// * **Timeout** — the packets were dropped with no reply. That may be the
  ///   server being absent, but it is also exactly what a firewall rule that
  ///   denies inbound 8000 looks like, so it must not be read as proof that
  ///   Django is not running.
  ///
  /// To tell the two apart, probe a port Django does not own (see
  /// `dev-backend-and-guard.md`), and probe an address that does not exist as a
  /// control. Measured 2026-10-02: `.84` **refused** on 8000, 80 and 3389 while
  /// `192.168.1.200` — absent, no ARP entry — **timed out**, so refused means a
  /// live host with nothing bound to the port and a timeout means the packets
  /// were dropped. (On 2026-10-01 `.84` timed out on every port instead: host
  /// firewall, with the backend possibly running throughout.)
  ///
  /// **The address moved once, and this is where it landed.** On 2026-10-02 the
  /// dev host — MAC `a8-41-f4-97-32-4c` — left `.84` for `192.168.1.77` under a
  /// new DHCP lease, with this dev machine moving `.77` → `.75` in the same
  /// reshuffle; the default below then pointed at a machine that no longer held
  /// the address, and every request failed with `Connection refused`. A static
  /// `.84` was tried and abandoned — `.84` is held by an unrelated device with a
  /// randomized MAC — so **`.77` is the address to use**, and the server accepts
  /// it: verified 2026-10-02, `Host: 192.168.1.77` returns `404` from the URL
  /// resolver rather than `400 DisallowedHost`, so no backend change is
  /// outstanding. Because the lease can still move, prefer a DHCP reservation or
  /// a hostname over editing this constant; `--dart-define=API_BASE_URL=...` is
  /// the override that needs no code edit.
  /// **The address moved again on 2026-10-07 — it is `.68` now, not `.77`.**
  /// Same dev PC (MAC `a8-41-f4-97-32-4c`), new DHCP lease; `.77` stopped
  /// answering and the MAC turned up at `.68`. Every `.77` below is history, kept
  /// because the reasoning still holds — only the number changed. **It changed
  /// again on 2026-10-09, and the backend moved onto this machine:** the default
  /// was set to `192.168.18.30`. **That was a misreading and it is fixed as of
  /// 2026-10-12 — the development machine is not a `192.168.18.x` host at all.**
  /// `192.168.18.30` came from a Wi-Fi *client* address of a separate router
  /// (`Honor-9C-71`, WPA2, channel 100) that this PC does not currently hold; the
  /// machine's own active address is on `192.168.1.0/24`.
  ///
  /// **Measured 2026-10-12:** `192.168.18.30:8000` does not answer — a physical
  /// device on the same Wi-Fi times out after dio's 15 s connect timeout, which
  /// is the failure this line caused. `192.168.1.64:8000` answers: raw TCP open,
  /// `GET /api/v1/` → **404** (URL resolver reached, so not `DisallowedHost`),
  /// `POST /api/v1/login/` → **400** (validator ran), and
  /// `/api/schema/?format=json` → **200**. The listener is bound `0.0.0.0:8000`,
  /// so no `runserver` change is outstanding.
  ///
  /// **Lesson, and the reason this keeps moving:** confirm which address is
  /// actually live *before* writing it here. `ipconfig` + a TCP probe on the
  /// candidate, not an address recalled from an earlier session — and not an
  /// address that turns out to belong to a different subnet entirely.
  ///
  /// As before, prefer a DHCP reservation or a hostname over editing this
  /// constant; `--dart-define=API_BASE_URL=...` needs no code change.
  static const _defaultUrls = <AppEnvironment, String>{
    AppEnvironment.development: 'http://192.168.1.64:8000/api/v1',
    AppEnvironment.staging: 'https://staging-api.skillsikka.com/api/v1',
    AppEnvironment.production: 'https://api.skillsikka.com/api/v1',
  };
}
