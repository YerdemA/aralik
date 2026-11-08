// The website at kabaca.app (public/, served through the ASSETS binding):
// what the game is, with screenshots, so that a person or a web filter's
// reviewer who opens the domain sees a real site. Static; nothing stored.
// www.kabaca.app redirects to kabaca.app. api.kabaca.app never gets these.

/** Hosts that get the website instead of the API. */
export const LANDING_HOSTS = new Set(['kabaca.app', 'www.kabaca.app']);

/** The answer for a request to one of LANDING_HOSTS. */
export async function landing(request, env) {
  const url = new URL(request.url);
  if (url.hostname === 'www.kabaca.app') {
    return Response.redirect(`https://kabaca.app${url.pathname}${url.search}`, 301);
  }
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return new Response('Method not allowed', { status: 405 });
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
