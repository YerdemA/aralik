// The player's mascot (lib/core/mascot_look.dart): nine digits, one per
// feature. The server only checks and passes it on, so opponents draw it.

// Options per digit: gender, skin, beard, moustache, hair, hat, eyes,
// glasses, hair colour. Must match MascotLook._sizes in the app.
const SIZES = [2, 3, 5, 5, 4, 4, 4, 6, 5];

/** [raw] when it is a valid mascot code, else null. */
export function cleanLook(raw) {
  if (typeof raw !== 'string' || raw.length !== SIZES.length) return null;
  for (let i = 0; i < SIZES.length; i++) {
    const d = raw.charCodeAt(i) - 48;
    if (!(d >= 0 && d < SIZES[i])) return null;
  }
  return raw;
}
