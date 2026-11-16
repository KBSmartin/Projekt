//! Command line bot simulation. For now: a smoke test that runs many single
//! fights with the prototype's starting deck and a naive bot.

use engine::{
    CardDb, CardInstance, Combat, CombatKind, CombatSetup, EnemyDb, GameRng, Outcome, needs_target,
};
use std::process::ExitCode;

const FIGHTS_PER_ENCOUNTER: u64 = 1000;
const MAX_TURNS: u32 = 100;
const START_HP: i32 = 75;

/// Easy encounters of the Düsterwald (prototype `REGIONS[0].easy`).
const ENCOUNTERS: [&[&str]; 3] = [&["rat", "rat"], &["shroom", "rat"], &["wolf"]];

fn main() -> ExitCode {
    let (cards, enemies) = match (CardDb::builtin(), EnemyDb::builtin()) {
        (Ok(c), Ok(e)) => (c, e),
        (Err(e), _) => return fail(&format!("Kartendaten fehlerhaft: {e}")),
        (_, Err(e)) => return fail(&format!("Gegnerdaten fehlerhaft: {e}")),
    };
    let deck = starting_deck();

    println!("Verlorene Lande – Simulation (Testlauf)");
    println!(
        "Karten: {}, Gegner: {}, Startdeck: {} Karten, {} Kämpfe je Begegnung",
        cards.len(),
        enemies.len(),
        deck.len(),
        FIGHTS_PER_ENCOUNTER
    );
    println!("Bot: spielt die erste spielbare Karte, Ziel ist der Gegner mit den wenigsten LP.\n");
    println!(
        "{:<20} {:>8} {:>10} {:>14}",
        "Begegnung", "Siege", "Ø Runden", "Ø LP danach"
    );

    for encounter in ENCOUNTERS {
        let mut wins = 0u64;
        let mut turns = 0u64;
        let mut hp_left = 0i64;
        for seed in 0..FIGHTS_PER_ENCOUNTER {
            let mut rng = GameRng::new(seed);
            let setup = CombatSetup {
                hp: START_HP,
                max_hp: START_HP,
                deck: &deck,
                relics: &[],
            };
            let mut combat = match Combat::start(
                setup,
                CombatKind::Fight,
                encounter,
                &enemies,
                &cards,
                &mut rng,
            ) {
                Ok(c) => c,
                Err(e) => return fail(&format!("Kampfstart fehlgeschlagen: {e}")),
            };
            run_naive_bot(&mut combat, &cards, &mut rng);
            if combat.outcome == Some(Outcome::Win) {
                wins += 1;
                hp_left += i64::from(combat.player.hp);
            }
            turns += u64::from(combat.turn);
        }
        let names: Vec<&str> = encounter
            .iter()
            .map(|id| enemies.get(id).map_or(*id, |e| e.name.as_str()))
            .collect();
        println!(
            "{:<20} {:>7.1}% {:>10.1} {:>14.1}",
            names.join(" + "),
            wins as f64 * 100.0 / FIGHTS_PER_ENCOUNTER as f64,
            turns as f64 / FIGHTS_PER_ENCOUNTER as f64,
            if wins > 0 {
                hp_left as f64 / wins as f64
            } else {
                0.0
            },
        );
    }
    ExitCode::SUCCESS
}

/// Prototype `newRun`: 5× Schlag, 4× Block, 1× Schildstoß.
fn starting_deck() -> Vec<CardInstance> {
    let mut deck = Vec::new();
    deck.extend((0..5).map(|_| CardInstance::new("strike")));
    deck.extend((0..4).map(|_| CardInstance::new("defend")));
    deck.push(CardInstance::new("bash"));
    deck
}

fn run_naive_bot(combat: &mut Combat, cards: &CardDb, rng: &mut GameRng) {
    while !combat.is_over() && combat.turn <= MAX_TURNS {
        while let Some(i) = (0..combat.hand.len()).find(|&i| combat.playable_card(i, cards).is_ok())
        {
            let card = combat.hand[i].resolve(cards);
            let target = if card.as_ref().is_some_and(needs_target) {
                weakest_enemy(combat)
            } else {
                None
            };
            if combat.play_card(i, target, cards, rng).is_err() || combat.is_over() {
                break;
            }
        }
        if combat.is_over() {
            break;
        }
        let _ = combat.end_turn(cards, rng);
    }
}

fn weakest_enemy(combat: &Combat) -> Option<usize> {
    combat
        .enemies
        .iter()
        .enumerate()
        .filter(|(_, e)| !e.dead)
        .min_by_key(|(_, e)| e.hp)
        .map(|(i, _)| i)
}

fn fail(msg: &str) -> ExitCode {
    eprintln!("{msg}");
    ExitCode::FAILURE
}
