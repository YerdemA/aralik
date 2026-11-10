// Opening rooms (Durable Objects named after their code): duel rooms,
// shared by the HTTP handler (friend rooms) and the lobby (random
// opponents), and tournament rooms (env.TOURNAMENT_ROOMS).

import { newRoomCode, randomInt } from './duel.js';

export function roomStub(env, code, rooms = env.DUEL_ROOMS) {
  return rooms.get(rooms.idFromName(code));
}

/**
 * Opens a room under a free code and returns the code, or null when no
 * free code turned up (tries a few in the rare collision).
 */
export async function openRoom(
  env,
  random = randomInt,
  rooms = env.DUEL_ROOMS,
  mode = 'bank',
  ranked = false,
) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newRoomCode(random);
    let query = mode === 'math' ? `code=${code}&mode=math` : `code=${code}`;
    // A random opponent's room: its first round may count for the
    // monthly table (ranked.js).
    if (ranked) query += '&ranked=1';
    const response = await roomStub(env, code, rooms).fetch(
      `https://room/create?${query}`,
      { method: 'POST' },
    );
    if (response.status === 201) return code;
  }
  return null;
}
