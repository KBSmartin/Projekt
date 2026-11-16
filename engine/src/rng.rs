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
