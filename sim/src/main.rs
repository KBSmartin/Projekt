//! Command line bot simulation. For now it only checks that the engine works natively.

use engine::{CardDb, GameRng};
use std::process::ExitCode;

const SEED: u64 = 42;

fn main() -> ExitCode {
    let db = match CardDb::builtin() {
        Ok(db) => db,
        Err(e) => {
            eprintln!("Kartendaten fehlerhaft: {e}");
            return ExitCode::FAILURE;
        }
    };

    println!("Verlorene Lande – Simulation (Testlauf)");
    println!("Karten geladen: {}", db.len());
    for card in db.cards() {
        let tags: Vec<&str> = card.tags.iter().map(|t| t.name()).collect();
        println!(
            "  {:<14} Kosten {}  [{}]",
            card.name,
            card.cost,
            tags.join(", ")
        );
    }

    let mut rng = GameRng::new(SEED);
    let rolls: Vec<i32> = (0..10).map(|_| rng.range(1, 6)).collect();
    println!("Seed {SEED}, zehn Würfe 1..=6: {rolls:?}");

    ExitCode::SUCCESS
}
