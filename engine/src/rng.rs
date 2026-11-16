//! Seeded random number generator.
//!
//! Every random roll in the game goes through [`GameRng`]. It wraps ChaCha8,
//! whose output is fully specified, so the same seed yields the same sequence
//! on every platform (native, WASM, 32 or 64 bit). This is what makes bugs
//! reproducible and bot simulations comparable.

use rand_chacha::ChaCha8Rng;
use rand_chacha::rand_core::{Rng, SeedableRng};

/// Deterministic random number generator for all game logic.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GameRng {
    inner: ChaCha8Rng,
}

impl GameRng {
    /// Creates a generator from a 64-bit seed.
    pub fn new(seed: u64) -> Self {
        Self {
            inner: ChaCha8Rng::seed_from_u64(seed),
        }
    }

    /// Next raw 32-bit value.
    pub fn next_u32(&mut self) -> u32 {
        self.inner.next_u32()
    }

    /// Next raw 64-bit value.
    pub fn next_u64(&mut self) -> u64 {
        self.inner.next_u64()
    }

    /// Uniform integer in `lo..=hi` (both inclusive, like `rnd(a, b)` in the
    /// JS prototype). Uses rejection sampling, so there is no modulo bias.
    ///
    /// # Panics
    /// Panics if `lo > hi`.
    pub fn range(&mut self, lo: i32, hi: i32) -> i32 {
        assert!(lo <= hi, "GameRng::range: lo ({lo}) > hi ({hi})");
        let span = (i64::from(hi) - i64::from(lo) + 1) as u64;
        const OUTCOMES: u64 = 1 << 32;
        if span == OUTCOMES {
            return self.next_u32() as i32;
        }
        // Largest multiple of `span` that fits into the u32 range.
        let limit = OUTCOMES - OUTCOMES % span;
        loop {
            let x = u64::from(self.next_u32());
            if x < limit {
                return (i64::from(lo) + (x % span) as i64) as i32;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn same_seed_gives_same_sequence() {
        let mut a = GameRng::new(1234);
        let mut b = GameRng::new(1234);
        for _ in 0..1000 {
            assert_eq!(a.next_u64(), b.next_u64());
            assert_eq!(a.next_u32(), b.next_u32());
            assert_eq!(a.range(-50, 50), b.range(-50, 50));
        }
    }

    #[test]
    fn different_seeds_give_different_sequences() {
        let a: Vec<u64> = {
            let mut r = GameRng::new(1);
            (0..8).map(|_| r.next_u64()).collect()
        };
        let b: Vec<u64> = {
            let mut r = GameRng::new(2);
            (0..8).map(|_| r.next_u64()).collect()
        };
        assert_ne!(a, b);
    }

    #[test]
    fn clone_continues_identically() {
        let mut a = GameRng::new(99);
        a.next_u64();
        let mut b = a.clone();
        for _ in 0..100 {
            assert_eq!(a.next_u32(), b.next_u32());
        }
    }

    /// Locks the exact output for one seed. If this fails, saved seeds and
    /// simulation results are no longer comparable, so only update it on purpose.
    #[test]
    fn known_sequence_for_seed_42() {
        let mut rng = GameRng::new(42);
        let rolls: Vec<i32> = (0..10).map(|_| rng.range(1, 6)).collect();
        assert_eq!(rolls, vec![4, 4, 5, 1, 3, 3, 5, 4, 1, 3]);
    }

    #[test]
    fn range_stays_in_bounds_and_hits_every_value() {
        let mut rng = GameRng::new(7);
        let mut seen = [false; 6];
        for _ in 0..10_000 {
            let v = rng.range(1, 6);
            assert!((1..=6).contains(&v));
            seen[(v - 1) as usize] = true;
        }
        assert!(seen.iter().all(|&s| s));
    }

    #[test]
    fn range_edge_cases() {
        let mut rng = GameRng::new(3);
        assert_eq!(rng.range(5, 5), 5);
        for _ in 0..1000 {
            assert!((-3..=-1).contains(&rng.range(-3, -1)));
        }
        // Full i32 range must not overflow.
        rng.range(i32::MIN, i32::MAX);
    }

    #[test]
    #[should_panic]
    fn range_panics_when_lo_greater_than_hi() {
        GameRng::new(0).range(2, 1);
    }
}
