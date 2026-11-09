// The website at kabaca.app (public/, served through the ASSETS binding):
// what the game is, with screenshots, so that a person or a web filter's
// reviewer who opens the domain sees a real site. Static; nothing stored.
// www.kabaca.app redirects to kabaca.app. api.kabaca.app never gets these.

/** Hosts that get the website instead of the API. */
export const LANDING_HOSTS = new Set(['kabaca.app', 'www.kabaca.app']);

/**
 * Digital Asset Links: proves to Play that kabaca.app belongs to the app
 * (Play Console → web sitesi ilişkilendirmesi). The SHA-256 fingerprints of
 * the certificates the app is signed with: Play's app signing key (Play
 * Console → Uygulama bütünlüğü → Uygulama imzalama) and our upload key.
 * Served as JSON with no redirect, which is what the check needs.
 */
// Exactly the list Play Console gives for the association (2026-11-08); its
// check fails ("Web sitesi ilişkilendirmesi oluşturulamadı") unless every
// fingerprint it shows is here. Copy a new list from there if it changes.
export const APP_CERT_FINGERPRINTS = [
  '26:E6:0D:C7:A3:78:46:D8:F8:AF:C8:CD:25:B3:2A:54:22:EC:4E:6B:9E:EE:87:A6:7B:5A:C3:51:19:03:9E:02',
  'C0:7D:46:33:A7:FC:77:90:8F:C2:54:A4:D2:34:1F:0A:B1:41:D8:FF:C8:99:B7:70:53:82:FD:7F:96:F1:B5:58',
  '68:F4:CB:E2:1D:F2:C7:35:0D:3C:A5:8E:15:D7:D8:6A:30:54:A2:E0:CF:8E:9B:72:58:54:0B:D9:5D:9C:4B:35',
  '63:38:C8:3F:18:AD:C9:E5:20:C7:8E:14:5E:C7:CB:4C:06:59:2E:D4:5F:EF:79:83:B7:92:8E:2F:53:C4:11:BC',
];

export function assetLinks() {
  return [
    {
      relation: [
        'delegate_permission/common.handle_all_urls',
        'delegate_permission/common.get_login_creds',
      ],
      target: {
        namespace: 'android_app',
        package_name: 'com.yerdema.kabaca',
        sha256_cert_fingerprints: APP_CERT_FINGERPRINTS,
      },
    },
  ];
}

/**
 * Universal links for iOS: the App Store app with Team ID [teamId] opens
 * kabaca.app/d/… and /t/… (the rest of the site stays in the browser). iOS
 * fetches it through Apple's CDN when the app is installed; served as JSON
 * with no redirect. Null without a Team ID (wrangler.toml APPLE_TEAM_ID).
 */
export function appleAppSiteAssociation(teamId) {
  if (!teamId || !/^[A-Z0-9]{10}$/.test(teamId)) return null;
  return {
    applinks: {
      details: [
        {
          appIDs: [`${teamId}.com.yerdema.kabaca`],
          components: [{ '/': '/d/*' }, { '/': '/t/*' }],
        },
      ],
    },
  };
}

/**
 * Whether [path] is an invite link: /d/KOD (duel) or /t/KOD (tournament),
 * KOD in the room code alphabet (no I, L, O, 0, 1; lib/core/invite_link.dart).
 */
export function isInvitePath(path) {
  return /^\/[dt]\/[A-HJKMNP-Z2-9]{5}\/?$/i.test(path);
}

/** The answer for a request to one of LANDING_HOSTS. */
export async function landing(request, env) {
  const url = new URL(request.url);
  if (url.hostname === 'www.kabaca.app') {
    return Response.redirect(`https://kabaca.app${url.pathname}${url.search}`, 301);
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return new Response('Method not allowed', { status: 405 });
  }
  if (url.pathname === '/.well-known/assetlinks.json') {
    return new Response(JSON.stringify(assetLinks(), null, 2), {
      headers: {
        'content-type': 'application/json',
        'cache-control': 'public, max-age=300',
      },
    });
  }
  if (url.pathname === '/.well-known/apple-app-site-association') {
    const aasa = appleAppSiteAssociation(env.APPLE_TEAM_ID);
    if (!aasa) return new Response('Not found', { status: 404 });
    return new Response(JSON.stringify(aasa, null, 2), {
      headers: {
        'content-type': 'application/json',
        'cache-control': 'public, max-age=300',
      },
    });
  }
  if (url.pathname === '/robots.txt') {
    return new Response('User-agent: *\nAllow: /\n', {
      headers: { 'content-type': 'text/plain; charset=utf-8' },
    });
  }
  if (!env.ASSETS) return new Response('Not found', { status: 404 });
  // An invite link opened without the app (with it, Android opens the
  // app instead): the code and the store button (public/invite.html).
  const invite = isInvitePath(url.pathname);
  if (invite) url.pathname = '/invite';
  const response = await env.ASSETS.fetch(invite ? new Request(url, request) : request);
  if (response.status !== 200) return response;
  // Pages may change between deploys; images are cached longer.
  const page = invite || /\.html$|\/$/.test(url.pathname);
  const headers = new Headers(response.headers);
  headers.set('cache-control', page ? 'public, max-age=600' : 'public, max-age=86400');
  headers.set('x-content-type-options', 'nosniff');
  headers.set('referrer-policy', 'strict-origin-when-cross-origin');
  return new Response(response.body, { status: 200, headers });
}
