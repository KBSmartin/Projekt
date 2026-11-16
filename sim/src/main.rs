//! Command line bot simulation: plays many whole runs per character and
//! prints how far the bot gets.
//!
//! Usage: `cargo run --release -p sim -- [--bot smart|naive] [--runs N] [--seed S]`

use engine::{GameData, NodeKind, Phase, bot};
use std::process::ExitCode;
use std::time::Instant;

struct Args {
    smart: bool,
    runs: u64,
    first_seed: u64,
}

fn parse_args() -> Result<Args, String> {
    let mut args = Args {
        smart: true,
        runs: 300,
        first_seed: 0,
    };
    let mut it = std::env::args().skip(1);
    while let Some(a) = it.next() {
        let mut value = || it.next().ok_or(format!("{a} braucht einen Wert"));
        match a.as_str() {
            "--bot" => {
                args.smart = match value()?.as_str() {
                    "smart" => true,
                    "naive" => false,
                    other => return Err(format!("unbekannter Bot '{other}' (smart oder naive)")),
                }
            }
            "--runs" => args.runs = value()?.parse().map_err(|_| "--runs braucht eine Zahl")?,
            "--seed" => {
                args.first_seed = value()?.parse().map_err(|_| "--seed braucht eine Zahl")?
            }
            other => return Err(format!("unbekanntes Argument '{other}'")),
        }
    }
    Ok(args)
}

fn main() -> ExitCode {
    let args = match parse_args() {
        Ok(a) => a,
        Err(e) => {
            eprintln!("{e}\nAufruf: sim [--bot smart|naive] [--runs N] [--seed S]");
            return ExitCode::FAILURE;
        }
    };
    let data = match GameData::builtin() {
        Ok(d) => d,
        Err(e) => {
            eprintln!("Spieldaten fehlerhaft: {e}");
            return ExitCode::FAILURE;
        }
    };
    let regions = data.regions.len();
    let (step, bot_name): (bot::StepFn, &str) = if args.smart {
        (
            bot::smart::step,
            "Smart-Bot (Zugsuche mit Gegnersimulation)",
        )
    } else {
        (bot::step, "einfacher Bot (erste spielbare Karte)")
    };

    println!("Verlorene Lande – Simulation");
    println!(
        "{} Läufe je Charakter, Seeds {}..{}, {bot_name}\n",
        args.runs,
        args.first_seed,
        args.first_seed + args.runs
    );
    print!("{:<10} {:>7}", "Charakter", "Siege");
    for i in 1..=regions {
        print!(" {:>9}", format!("† Gebiet {i}"));
    }
    println!(
        " {:>8} {:>8} {:>8} {:>9}",
        "† Boss", "Ø Orte", "Ø Deck", "Ø LP Sieg"
    );

    let started = Instant::now();
    for ch in &data.characters {
        let mut wins = 0u64;
        let mut deaths = vec![0u64; regions];
        let (mut boss_deaths, mut nodes, mut deck, mut win_hp) = (0u64, 0u64, 0u64, 0i64);
        for seed in args.first_seed..args.first_seed + args.runs {
            let run = match bot::play_run_with(&data, &ch.id, seed, step) {
                Ok(r) => r,
                Err(e) => {
                    eprintln!("{} Seed {seed}: Fehler im Ablauf: {e}", ch.name);
                    return ExitCode::FAILURE;
                }
            };
            match run.phase {
                Phase::Victory => {
                    wins += 1;
                    win_hp += i64::from(run.hp);
                }
                Phase::Defeat => {
                    deaths[run.region] += 1;
                    if run
                        .current
                        .is_some_and(|id| run.map.nodes[id].kind == NodeKind::Boss)
                    {
                        boss_deaths += 1;
                    }
                }
                _ => {
                    eprintln!("{} Seed {seed}: Lauf nicht beendet", ch.name);
                    return ExitCode::FAILURE;
                }
            }
            nodes += u64::from(run.stats.nodes);
            deck += run.deck.len() as u64;
        }
        let n = args.runs.max(1) as f64;
        let pct = |v: u64| format!("{:.1}%", v as f64 * 100.0 / n);
        print!("{:<10} {:>7}", ch.name, pct(wins));
        for d in &deaths {
            print!(" {:>9}", pct(*d));
        }
        let avg_win_hp = if wins > 0 {
            format!("{:.1}", win_hp as f64 / wins as f64)
        } else {
            "-".into()
        };
        println!(
            " {:>8} {:>8.1} {:>8.1} {:>9}",
            pct(boss_deaths),
            nodes as f64 / n,
            deck as f64 / n,
            avg_win_hp
        );
    }
    println!("\nDauer: {:.1} s", started.elapsed().as_secs_f64());
    ExitCode::SUCCESS
}
