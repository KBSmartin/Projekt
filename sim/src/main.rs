//! Command line bot simulation: plays many whole runs per character with the
//! naive bot from `engine::bot` and prints how far it gets.

use engine::{GameData, Phase, bot};
use std::process::ExitCode;

const RUNS_PER_CHARACTER: u64 = 500;

fn main() -> ExitCode {
    let data = match GameData::builtin() {
        Ok(d) => d,
        Err(e) => {
            eprintln!("Spieldaten fehlerhaft: {e}");
            return ExitCode::FAILURE;
        }
    };
    let regions = data.regions.len();

    println!("Verlorene Lande – Simulation");
    println!(
        "{RUNS_PER_CHARACTER} Läufe je Charakter, einfacher Bot (erste spielbare Karte, erster Weg, kauft nichts).\n"
    );
    print!("{:<10} {:>7}", "Charakter", "Siege");
    for i in 1..=regions {
        print!(" {:>9}", format!("† Gebiet {i}"));
    }
    println!(" {:>9} {:>8}", "Ø Orte", "Ø Deck");

    for ch in &data.characters {
        let mut wins = 0u64;
        let mut deaths = vec![0u64; regions];
        let (mut nodes, mut deck) = (0u64, 0u64);
        for seed in 0..RUNS_PER_CHARACTER {
            let run = match bot::play_run(&data, &ch.id, seed) {
                Ok(r) => r,
                Err(e) => {
                    eprintln!("{} Seed {seed}: Fehler im Ablauf: {e}", ch.name);
                    return ExitCode::FAILURE;
                }
            };
            match run.phase {
                Phase::Victory => wins += 1,
                Phase::Defeat => deaths[run.region] += 1,
                _ => {
                    eprintln!("{} Seed {seed}: Lauf nicht beendet", ch.name);
                    return ExitCode::FAILURE;
                }
            }
            nodes += u64::from(run.stats.nodes);
            deck += run.deck.len() as u64;
        }
        let pct = |n: u64| format!("{:.1}%", n as f64 * 100.0 / RUNS_PER_CHARACTER as f64);
        print!("{:<10} {:>7}", ch.name, pct(wins));
        for d in &deaths {
            print!(" {:>9}", pct(*d));
        }
        println!(
            " {:>9.1} {:>8.1}",
            nodes as f64 / RUNS_PER_CHARACTER as f64,
            deck as f64 / RUNS_PER_CHARACTER as f64
        );
    }
    ExitCode::SUCCESS
}
