// Nickname rules. The app checks the same format (lib/core/nickname.dart)
// for instant feedback; the server has the last word.

export const MIN_LENGTH = 3;
export const MAX_LENGTH = 16;

const FORMAT = /^[\p{L}\p{N}](?:[\p{L}\p{N}._-]| (?! ))*$/u;

/** Trimmed, single-spaced nickname, or null if it breaks the rules. */
export function cleanNickname(raw) {
  if (typeof raw !== 'string') return null;
  const name = raw.normalize('NFC').trim().replace(/\s+/g, ' ');
  const length = [...name].length;
  if (length < MIN_LENGTH || length > MAX_LENGTH) return null;
  if (!FORMAT.test(name)) return null;
  if (!/[\p{L}]/u.test(name)) return null; // not only digits
  return name;
}

/**
 * Key for uniqueness and the word filter: Turkish lower case, without
 * accents and separators, so "Şeyma", "seyma" and "S.e.y.m.a" collide.
 */
export function nicknameKey(name) {
  return name
    .replace(/I/g, 'ı')
    .replace(/İ/g, 'i')
    .toLowerCase()
    .replace(/ı/g, 'i')
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .replace(/[ ._-]/g, '');
}

// Matched anywhere in the key.
const BLOCKED_PARTS = [
  'orospu', 'orosbu', 'siktir', 'sikerim', 'sikeyim', 'sikis', 'sikik',
  'yarrak', 'amcik', 'aminako', 'aminak', 'amina', 'pezevenk', 'kahpe',
  'gavat', 'serefsiz', 'fuck', 'shit', 'bitch', 'cunt', 'nigger', 'nigga',
  'whore', 'slut', 'porn', 'hitler', 'admin', 'moderator', 'yonetici',
];

// Matched only as the whole key (too short to search inside words).
const BLOCKED_WORDS = [
  'amk', 'aq', 'sik', 'got', 'pic', 'ibne', 'yarak', 'kabaca', 'mod',
];

export function isBlocked(key) {
  return (
    BLOCKED_WORDS.includes(key) ||
    BLOCKED_PARTS.some((part) => key.includes(part))
  );
}
