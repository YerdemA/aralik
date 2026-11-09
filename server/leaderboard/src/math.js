// Math duels: the answers of the app's generated math questions
// (lib/core/math/math_problem.dart and advanced.dart), computed here from
// the question id `math:<topic>:<level>:<seed>` so the room can score them.
// Only the answer and its unit are needed; the app makes the text itself.
//
// Every random draw must happen in the same order as in Dart, or the same
// id would make another question. test/math_vectors.json (written by the
// app's tools/math/write_math_vectors_test.dart) is checked here.

/** mulberry32, as SeededRandom in lib/core/math/seeded_random.dart. */
export class SeededRandom {
  constructor(seed) {
    this.a = seed >>> 0;
  }

  nextUint32() {
    this.a = (this.a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(this.a ^ (this.a >>> 15), this.a | 1);
    t = (t + Math.imul(t ^ (t >>> 7), t | 61)) ^ t;
    return (t ^ (t >>> 14)) >>> 0;
  }

  nextInt(max) {
    return this.nextUint32() % max;
  }

  between(min, max) {
    return min + this.nextInt(max - min + 1);
  }

  stepped(min, max, step) {
    return min + step * this.nextInt(Math.trunc((max - min) / step) + 1);
  }

  nextBool() {
    return this.nextInt(2) === 1;
  }

  pick(items) {
    return items[this.nextInt(items.length)];
  }
}

/** Dart's `double.round()`: halves away from zero. */
function dartRound(x) {
  return Math.sign(x) * Math.round(Math.abs(x));
}

function roundTo(x, decimals) {
  const f = 10 ** decimals;
  return dartRound(x * f) / f;
}

const rad = (deg) => (deg * Math.PI) / 180;
const deg = (r) => (r * 180) / Math.PI;

function factorial(n) {
  let f = 1;
  for (let k = 2; k <= n; k++) f *= k;
  return f;
}

function choose(n, k) {
  if (k < 0 || k > n) return 0;
  const m = Math.min(k, n - k);
  let c = 1;
  for (let i = 1; i <= m; i++) c = Math.trunc((c * (n - m + i)) / i);
  return c;
}

function fibonacci(n) {
  let a = 0;
  let b = 1;
  for (let i = 0; i < n; i++) [a, b] = [b, a + b];
  return a;
}

function primeCount(n) {
  if (n < 2) return 0;
  const composite = new Uint8Array(n + 1);
  let count = 0;
  for (let i = 2; i <= n; i++) {
    if (composite[i]) continue;
    count++;
    for (let j = i * i; j <= n; j += i) composite[j] = 1;
  }
  return count;
}

// π(n) for the hard level's n (100.000 … 2.000.000 in steps of 50.000):
// a sieve to two million is too much work for a room's request.
// Checked against primeCount in test/math.test.js.
export const PRIME_COUNTS = [
  9592, 13848, 17984, 22044, 25997, 29977, 33860, 37706, 41538, 45322, 49098,
  52831, 56543, 60238, 63951, 67617, 71274, 74907, 78498, 82134, 85714, 89302,
  92938, 96469, 100021, 103544, 107126, 110630, 114155, 117663, 121127,
  124634, 128141, 131608, 135072, 138542, 142029, 145502, 148933,
];

function primesUpTo(n) {
  if (n >= 100000 && n % 50000 === 0) return PRIME_COUNTS[(n - 100000) / 50000];
  return primeCount(n);
}

function powerDigits(base, exponent) {
  return (BigInt(base) ** BigInt(exponent)).toString().length;
}

function factorialDigits(n) {
  let f = 1n;
  for (let k = 2n; k <= BigInt(n); k++) f *= k;
  return f.toString().length;
}

function sharedBirthday(people) {
  let none = 1;
  for (let i = 0; i < people; i++) none *= (365 - i) / 365;
  return 1 - none;
}

const isSquare = (n) => {
  const s = dartRound(Math.sqrt(n));
  return s * s === n;
};
const isCube = (n) => {
  const c = dartRound(Math.pow(n, 1 / 3));
  return c * c * c === n;
};

function gcd(a, b) {
  let x = Math.abs(a);
  let y = Math.abs(b);
  while (y !== 0) [x, y] = [y, x % y];
  return x;
}
const lcm = (a, b) => (a / gcd(a, b)) * b;

function divisorCount(n) {
  let count = 1;
  let m = n;
  for (let p = 2; p * p <= m; p++) {
    let e = 0;
    while (m % p === 0) {
      m /= p;
      e++;
    }
    count *= e + 1;
  }
  return m > 1 ? count * 2 : count;
}

function totient(n) {
  let result = n;
  let m = n;
  for (let p = 2; p * p <= m; p++) {
    if (m % p !== 0) continue;
    while (m % p === 0) m /= p;
    result -= Math.trunc(result / p);
  }
  if (m > 1) result -= Math.trunc(result / m);
  return result;
}

function determinant(a) {
  if (a.length === 2) return a[0][0] * a[1][1] - a[0][1] * a[1][0];
  return (
    a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
    a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
    a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
  );
}

function normalCdf(z) {
  const x = Math.abs(z) / Math.SQRT2;
  const t = 1 / (1 + 0.3275911 * x);
  const poly =
    t *
    (0.254829592 +
      t *
        (-0.284496736 +
          t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  const erf = 1 - poly * Math.exp(-x * x);
  return z >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}

function angleBetween(u, v) {
  let dot = 0;
  let uu = 0;
  let vv = 0;
  for (let i = 0; i < u.length; i++) {
    dot += u[i] * v[i];
    uu += u[i] * u[i];
    vv += v[i] * v[i];
  }
  if (uu === 0 || vv === 0) return NaN;
  return deg(Math.acos(Math.min(1, Math.max(-1, dot / Math.sqrt(uu * vv)))));
}

const PERCENT = '%';
const plain = (answer) => ({ answer, unit: '' });
const percent = (answer) => ({ answer, unit: PERCENT });

// Each returns {answer, unit}; only '%' matters for scoring.
const GENERATORS = {
  carpma(r, level) {
    let factors;
    if (level === 1) factors = [r.between(12, 99), r.between(12, 99)];
    else if (level === 2) factors = [r.between(100, 999), r.between(12, 99)];
    else if (r.nextBool()) factors = [r.between(100, 999), r.between(100, 999)];
    else factors = [r.between(12, 99), r.between(12, 99), r.between(12, 99)];
    return plain(factors.reduce((a, b) => a * b));
  },
  us(r, level) {
    let base;
    let exponent;
    if (level === 1) {
      base = 2;
      exponent = r.between(8, 16);
    } else if (level === 2) {
      base = r.pick([3, 5, 6, 7]);
      exponent = {
        3: () => r.between(9, 14),
        5: () => r.between(6, 10),
        6: () => r.between(6, 9),
        7: () => r.between(5, 8),
      }[base]();
    } else if (r.nextBool()) {
      base = r.between(11, 19);
      exponent = r.between(5, 8);
    } else {
      base = 2;
      exponent = r.between(25, 39);
    }
    return plain(Math.trunc(Math.pow(base, exponent)));
  },
  kok(r, level) {
    let n;
    if (level === 3) {
      do n = r.between(1000, 999999);
      while (isCube(n));
      return plain(roundTo(Math.pow(n, 1 / 3), 1));
    }
    do n = level === 1 ? r.between(50, 999) : r.between(1000, 99999);
    while (isSquare(n));
    return plain(roundTo(Math.sqrt(n), 1));
  },
  faktoriyel(r, level) {
    const n =
      level === 1 ? r.between(5, 7) : level === 2 ? r.between(8, 10) : r.between(11, 14);
    return plain(factorial(n));
  },
  kombinasyon(r, level) {
    if (level === 1) return plain(choose(r.between(8, 30), 2));
    if (level === 2) {
      const n = r.between(10, 30);
      return plain(choose(n, r.between(3, 4)));
    }
    const n = r.between(40, 60);
    return plain(choose(n, r.between(5, 6)));
  },
  toplam(r, level) {
    if (level === 3) {
      const n = r.between(20, 100);
      return plain(Math.trunc((n * (n + 1) * (2 * n + 1)) / 6));
    }
    const n = level === 1 ? r.between(20, 100) : r.between(101, 2000);
    return plain(Math.trunc((n * (n + 1)) / 2));
  },
  faiz(r, level) {
    if (level === 3) {
      const rate = r.between(3, 15);
      return { answer: roundTo(Math.log(2) / Math.log(1 + rate / 100), 1), unit: 'yıl' };
    }
    const principal = r.pick([1000, 2000, 5000, 10000]);
    let rate;
    let years;
    if (level === 1) {
      rate = r.pick([10, 20, 25, 50]);
      years = r.between(2, 3);
    } else {
      rate = r.between(5, 30);
      years = r.between(5, 10);
    }
    return { answer: dartRound(principal * Math.pow(1 + rate / 100, years)), unit: 'TL' };
  },
  yuzde(r, level) {
    if (level === 1) {
      const x = r.between(2, 90) * 100;
      const p = r.stepped(5, 95, 5);
      return plain(Math.trunc((x * p) / 100));
    }
    if (level === 2) {
      const x = r.between(5, 50) * 100;
      const up = r.stepped(10, 50, 5);
      const down = r.stepped(10, 50, 5);
      return { answer: roundTo(x * (1 + up / 100) * (1 - down / 100), 2), unit: 'TL' };
    }
    const p = r.between(2, 5);
    return percent(roundTo((Math.pow(1 + p / 100, 12) - 1) * 100, 1));
  },
  birim(r, level) {
    if (level === 1) {
      if (r.nextBool()) return { answer: roundTo(r.between(20, 200) / 3.6, 1), unit: 'm/sn' };
      return { answer: r.between(2, 30) * 24 * 60, unit: 'dakika' };
    }
    if (level === 2) {
      if (r.nextBool()) return { answer: roundTo(r.between(10, 500) * 1.609344, 1), unit: 'km' };
      return { answer: r.between(1, 20) * 365 * 24 * 3600, unit: 'saniye' };
    }
    const days = r.between(1, 60);
    return { answer: roundTo((299792.458 * 86400 * days) / 1e9, 1), unit: 'milyar km' };
  },
  geometri(r, level) {
    if (level === 1) {
      const radius = r.between(3, 30);
      return { answer: roundTo(Math.PI * radius * radius, 1), unit: 'cm²' };
    }
    if (level === 2) {
      const d = r.between(4, 40);
      return { answer: roundTo((4 / 3) * Math.PI * Math.pow(d / 2, 3), 1), unit: 'cm³' };
    }
    const a = r.between(5, 40);
    const b = r.between(5, 40);
    const c = r.between(Math.abs(a - b) + 1, a + b - 1);
    const s = (a + b + c) / 2;
    return { answer: roundTo(Math.sqrt(s * (s - a) * (s - b) * (s - c)), 1), unit: 'cm²' };
  },
  olasilik(r, level) {
    if (level === 1) {
      return percent(roundTo((1 - Math.pow(5 / 6, r.between(2, 12))) * 100, 1));
    }
    if (level === 2) return percent(roundTo(sharedBirthday(r.between(10, 50)) * 100, 1));
    return percent(roundTo((1 - Math.pow(364 / 365, r.between(50, 500))) * 100, 1));
  },
  asal(r, level) {
    const n =
      level === 1
        ? r.stepped(50, 300, 10)
        : level === 2
          ? r.stepped(1000, 20000, 500)
          : r.stepped(100000, 2000000, 50000);
    return plain(primesUpTo(n));
  },
  basamak(r, level) {
    if (level === 1) return plain(powerDigits(2, r.between(20, 60)));
    if (level === 2) {
      const base = r.between(3, 9);
      return plain(powerDigits(base, r.between(20, 80)));
    }
    return plain(factorialDigits(r.between(20, 80)));
  },
  fibonacci(r, level) {
    const n =
      level === 1 ? r.between(12, 20) : level === 2 ? r.between(21, 35) : r.between(36, 55);
    return plain(fibonacci(n));
  },
  katlama(r, level) {
    const [folds, unit, perUnit] =
      level === 1
        ? [r.between(8, 12), 'cm', 0.01]
        : level === 2
          ? [r.between(15, 25), 'm', 0.0001]
          : [r.between(30, 42), 'km', 0.0000001];
    return { answer: roundTo(perUnit * Math.pow(2, folds), 1), unit };
  },

  // Further on (advanced.dart).
  trigonometri(r, level) {
    if (level === 1) {
      const length = r.between(3, 12);
      const angle = r.stepped(15, 75, 5);
      return { answer: dartRound(length * Math.sin(rad(angle)) * 100), unit: 'cm' };
    }
    if (level === 2) {
      const shadow = r.between(5, 40);
      const angle = r.stepped(20, 70, 5);
      return { answer: roundTo(shadow * Math.tan(rad(angle)), 1), unit: 'm' };
    }
    if (r.nextBool()) {
      const a = r.between(5, 40);
      const b = r.between(5, 40);
      const angle = r.stepped(20, 160, 5);
      return {
        answer: roundTo(Math.sqrt(a * a + b * b - 2 * a * b * Math.cos(rad(angle))), 1),
        unit: 'cm',
      };
    }
    const speed = r.between(10, 40);
    const angle = r.stepped(15, 75, 5);
    return { answer: roundTo((speed * speed * Math.sin(rad(2 * angle))) / 9.81, 1), unit: 'm' };
  },
  limit(r, level) {
    if (level === 1) return plain(2 * r.between(6, 50));
    if (level === 2) {
      const n = r.between(3, 5);
      const a = r.between(2, n === 3 ? 9 : n === 4 ? 6 : 4);
      return plain(n * Math.trunc(Math.pow(a, n - 1)));
    }
    if (r.nextBool()) return plain(roundTo(Math.exp(r.between(3, 9)), 1));
    const k = r.between(4, 20);
    return plain(roundTo((k * k) / 2, 1));
  },
  turev(r, level) {
    if (level === 1) {
      const a = r.between(2, 9);
      const n = r.between(2, 4);
      const c = r.between(2, 6);
      return plain(a * n * Math.trunc(Math.pow(c, n - 1)));
    }
    if (level === 2) {
      const a = r.between(1, 5);
      const b = r.between(1, 9);
      const c = r.between(1, 20);
      const x = r.between(2, 6);
      return plain(3 * a * x * x + 2 * b * x + c);
    }
    if (r.nextBool()) {
      const c = r.between(2, 6);
      return plain(roundTo(Math.exp(c) * (c * c + 2 * c), 1));
    }
    const c = r.between(3, 6);
    return plain(roundTo(Math.pow(c, c) * (Math.log(c) + 1), 1));
  },
  integral(r, level) {
    if (level === 1) {
      const b = r.between(3, 20);
      return plain(roundTo((b * b * b) / 3, 1));
    }
    if (level === 2) {
      const p = r.pick([3, 6, 9]);
      const q = r.pick([2, 4, 6]);
      const b = r.between(3, 15);
      return plain(Math.trunc(p / 3) * (b * b * b - 1) + Math.trunc(q / 2) * (b * b - 1));
    }
    if (r.nextBool()) return plain(roundTo(Math.exp(r.between(3, 12)) - 1, 1));
    const b = r.between(2, 9);
    return plain(roundTo((b - 1) * Math.exp(b) + 1, 1));
  },
  logaritma(r, level) {
    if (level === 1) return plain(roundTo(Math.log(r.between(1000, 1000000)) / Math.LN2, 1));
    if (level === 2) {
      const base = r.pick([3, 5, 7]);
      return plain(roundTo(Math.log(r.between(10000, 100000000)) / Math.log(base), 1));
    }
    if (r.nextBool()) {
      return plain(roundTo((r.between(5, 15) * Math.log(10)) / Math.LN2, 1));
    }
    r.stepped(40, 60, 5); // the smaller magnitude: only in the text
    const step = r.stepped(10, 30, 5) / 10;
    return { answer: roundTo(Math.pow(10, 1.5 * step), 1), unit: 'kat' };
  },
  ustel(r, level) {
    if (level === 1) {
      const every = r.pick([15, 20, 30]);
      const hours = r.between(2, 6);
      return plain(Math.trunc(Math.pow(2, Math.trunc((hours * 60) / every))));
    }
    if (level === 2) {
      const grams = r.stepped(100, 1000, 100);
      const half = r.pick([5, 10, 20, 30]);
      const years = r.stepped(half, half * 6, 5);
      return { answer: roundTo(grams * 1000 * Math.pow(0.5, years / half), 1), unit: 'mg' };
    }
    const times = r.pick([3, 5, 10]);
    const rate = r.between(2, 9);
    return { answer: roundTo(Math.log(times) / Math.log(1 + rate / 100), 1), unit: 'yıl' };
  },
  dizi(r, level) {
    if (level === 1) {
      const first = r.between(3, 50);
      const d = r.between(2, 15);
      const n = r.between(20, 100);
      return plain(Math.trunc((n * (2 * first + (n - 1) * d)) / 2));
    }
    if (level === 2) {
      if (r.nextBool()) {
        const n = r.between(10, 50);
        return plain(Math.pow(Math.trunc((n * (n + 1)) / 2), 2));
      }
      const a = r.between(1, 9);
      const ratio = r.between(2, 3);
      const n = r.between(8, ratio === 2 ? 30 : 18);
      return plain(Math.trunc((a * (Math.trunc(Math.pow(ratio, n)) - 1)) / (ratio - 1)));
    }
    const [p, q] = r.pick([
      [1, 2],
      [2, 3],
      [3, 4],
      [4, 5],
      [9, 10],
    ]);
    const a = q * q * r.between(1, 9) * (q <= 3 ? 10 : 1);
    return plain(roundTo((a * q) / (q - p), 1));
  },
  istatistik(r, level) {
    if (level === 1) {
      const xs = Array.from({ length: 6 }, () => r.between(10, 99));
      return plain(roundTo(xs.reduce((a, b) => a + b) / xs.length, 1));
    }
    if (level === 2) {
      let sd;
      do {
        const xs = Array.from({ length: 5 }, () => r.between(10, 99));
        const mean = xs.reduce((a, b) => a + b) / xs.length;
        const variance =
          xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / xs.length;
        sd = Math.sqrt(variance);
      } while (sd < 1);
      return plain(roundTo(sd, 1));
    }
    const mean = r.stepped(150, 190, 5);
    const sd = r.between(5, 12);
    let z;
    do {
      const cut = mean + r.between(-2 * sd, 2 * sd);
      z = (cut - mean) / sd;
    } while (Math.abs(z) < 0.1);
    return percent(roundTo(normalCdf(z) * 100, 1));
  },
  matris(r, level) {
    const [size, low, high] = level === 1 ? [2, 1, 20] : level === 2 ? [3, 0, 9] : [3, -9, 9];
    let det;
    do {
      const a = Array.from({ length: size }, () =>
        Array.from({ length: size }, () => r.between(low, high)),
      );
      det = determinant(a);
    } while (det < 1);
    return plain(det);
  },
  karmasik(r, level) {
    if (level === 1) {
      const a = r.between(1, 30);
      const b = r.between(1, 30);
      return plain(roundTo(Math.sqrt(a * a + b * b), 1));
    }
    if (level === 2) {
      const a = r.between(1, 5);
      const b = r.between(1, 5);
      const n = r.between(3, 6);
      return plain(roundTo(Math.pow(a * a + b * b, n / 2), 1));
    }
    let angle;
    do {
      const a = r.between(1, 9);
      const b = r.between(1, 9);
      const n = r.between(2, 6);
      angle = (deg(Math.atan2(b, a)) * n) % 360;
    } while (angle < 1);
    return { answer: roundTo(angle, 1), unit: '°' };
  },
  vektor(r, level) {
    if (level === 1) {
      const v = Array.from({ length: 3 }, () => r.between(1, 20));
      return plain(roundTo(Math.sqrt(v.map((x) => x * x).reduce((a, b) => a + b)), 1));
    }
    if (level === 2) {
      let angle;
      do {
        const u = [r.between(-9, 9), r.between(-9, 9)];
        const v = [r.between(-9, 9), r.between(-9, 9)];
        angle = angleBetween(u, v);
      } while (Number.isNaN(angle) || angle < 5);
      return { answer: roundTo(angle, 1), unit: '°' };
    }
    let area;
    do {
      const u = Array.from({ length: 3 }, () => r.between(-9, 9));
      const v = Array.from({ length: 3 }, () => r.between(-9, 9));
      const cross = [
        u[1] * v[2] - u[2] * v[1],
        u[2] * v[0] - u[0] * v[2],
        u[0] * v[1] - u[1] * v[0],
      ];
      area = Math.sqrt(cross.map((x) => x * x).reduce((a, b) => a + b)) / 2;
    } while (area < 1);
    return plain(roundTo(area, 1));
  },
  sayilar(r, level) {
    if (level === 1) {
      const a = r.between(6, 60);
      return plain(lcm(a, r.between(6, 60)));
    }
    if (level === 2) {
      if (r.nextBool()) {
        const xs = Array.from({ length: 3 }, () => r.between(4, 30));
        return plain(lcm(lcm(xs[0], xs[1]), xs[2]));
      }
      return plain(divisorCount(r.between(100, 10000)));
    }
    return plain(totient(r.between(1000, 100000)));
  },
};

export const MATH_TOPICS = Object.keys(GENERATORS);

/** A math question id's parts, or null when it is not one. */
export function parseMathId(id) {
  if (typeof id !== 'string') return null;
  const parts = id.split(':');
  if (parts.length !== 4 || parts[0] !== 'math') return null;
  const [, topic, level, seed] = parts;
  if (!(topic in GENERATORS)) return null;
  if (!/^[123]$/.test(level) || !/^\d+$/.test(seed)) return null;
  return { topic, level: Number(level), seed: Number(seed) };
}

export const isMathId = (id) => parseMathId(id) !== null;

/** {answer, unit} of a math question id, or null. */
export function mathAnswer(id) {
  const p = parseMathId(id);
  if (!p) return null;
  return GENERATORS[p.topic](new SeededRandom(p.seed), p.level);
}

/** A math duel's ids: five topics, easy to hard ([levels]). */
export function pickMathQuestions(randomInt, levels = [1, 1, 2, 2, 3]) {
  const topics = [...MATH_TOPICS];
  const ids = [];
  for (const level of levels) {
    const [topic] = topics.splice(randomInt(topics.length), 1);
    const seed = randomInt(0x10000) * 0x10000 + randomInt(0x10000);
    ids.push(`math:${topic}:${level}:${seed}`);
  }
  return ids;
}

// Scoring (lib/core/answer_scale.dart, mathScaleOf / mathMinPoints).
export const MATH_MAX_FACTOR = 2;
export const MATH_MAX_PERCENT_HALF = 10;
export const MATH_MIN_POINTS = 0;

export function mathScale(unit) {
  return unit === PERCENT
    ? { maxFactor: 0, maxYearHalf: 0, linearHalf: MATH_MAX_PERCENT_HALF }
    : { maxFactor: MATH_MAX_FACTOR, maxYearHalf: 0, linearHalf: 0 };
}
