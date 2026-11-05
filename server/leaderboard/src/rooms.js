// Opening duel rooms (Durable Objects named after their code). Shared by
// the HTTP handler (friend rooms) and the lobby (random opponents).

import { newRoomCode, randomInt } from './duel.js';

export function roomStub(env, code) {
  return env.DUEL_ROOMS.get(env.DUEL_ROOMS.idFromName(code));
}

/**
 * Opens a room under a free code and returns the code, or null when no
 * free code turned up (tries a few in the rare collision).
 */
export async function openRoom(env, random = randomInt) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newRoomCode(random);
    const response = await roomStub(env, code).fetch(
      `https://room/create?code=${code}`,
      { method: 'POST' },
    );
    if (response.status === 201) return code;
  }
  return null;
}
