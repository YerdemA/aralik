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
export const APP_CERT_FINGERPRINTS = [
  // Upload key (aralik-upload.jks).
  'C0:7D:46:33:A7:FC:77:90:8F:C2:54:A4:D2:34:1F:0A:B1:41:D8:FF:C8:99:B7:70:53:82:FD:7F:96:F1:B5:58',
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
  if (url.pathname === '/robots.txt') {
    return new Response('User-agent: *\nAllow: /\n', {
      headers: { 'content-type': 'text/plain; charset=utf-8' },
    });
  }
  if (!env.ASSETS) return new Response('Not found', { status: 404 });
  const response = await env.ASSETS.fetch(request);
  if (response.status !== 200) return response;
  // Pages may change between deploys; images are cached longer.
  const page = /\.html$|\/$/.test(url.pathname);
  const headers = new Headers(response.headers);
  headers.set('cache-control', page ? 'public, max-age=600' : 'public, max-age=86400');
  headers.set('x-content-type-options', 'nosniff');
  headers.set('referrer-policy', 'strict-origin-when-cross-origin');
  return new Response(response.body, { status: 200, headers });
}
