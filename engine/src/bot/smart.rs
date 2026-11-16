//! A heuristic bot for balancing.
//!
//! Combat: beam search over card sequences. Every candidate end state is
//! scored by actually running the enemy phase on a copy of the combat, so
//! block, thorns, poison, weak and vulnerable count exactly as in the game.
//! Lookahead uses its own RNG, so the bot never sees the real draw pile.
//!
//! Outside combat: path planning to the boss, card values for rewards,
//! shop and rest decisions, and event options scored from their effects.

use crate::card::{Card, CardInstance, CardKind};
use crate::combat::{Combat, CombatBonus, Outcome, needs_target};
use crate::content::{EventEffect, GameData, PickMode};
use crate::map::NodeKind;
use crate::rng::GameRng;
use crate::run::{ActionError, EventState, Phase, PickState, Run, Shop};

/// States kept per search depth.
const BEAM_WIDTH: usize = 12;
/// Maximum card plays considered in one turn.
const MAX_DEPTH: usize = 8;
/// Seed of the lookahead RNG (independent from the run's RNG).
const LOOKAHEAD_SEED: u64 = 0xB07_5EED;

/// Decks larger than this stop taking average cards.
const DECK_SOFT_LIMIT: usize = 28;

pub fn step(run: &mut Run, data: &GameData) -> Result<(), ActionError> {
    let bonus = character_bonus(run, data);
    match &run.phase {
        Phase::RegionIntro => run.continue_from_intro(),
        Phase::Map => {
            let node = choose_node(run);
            run.choose_node(data, node)
        }
        Phase::Combat(c) => {
            if c.is_over() {
                return run.finish_combat(data);
            }
            match plan_action(c, data) {
                Some((i, t)) => run.play_card(data, i, t),
                None => run.end_turn(data),
            }
        }
        Phase::Reward(reward) => match choose_reward(run, data, &reward.cards, &bonus) {
            Some(i) => run.take_reward_card(data, i),
            None => run.skip_reward(data),
        },
        Phase::Shop(shop) => {
            let shop = shop.clone();
            shop_step(run, data, &shop, &bonus)
        }
        Phase::Rest => {
            let next_is_boss = run
                .current
                .is_some_and(|id| run.map.nodes[id].next.contains(&run.map.boss()));
            let ratio = f64::from(run.hp) / f64::from(run.max_hp);
            if ratio < 0.55 || (next_is_boss && ratio < 0.8) || !run.can_upgrade(data) {
                run.rest_heal()
            } else {
                run.rest_upgrade(data)
            }
        }
        Phase::Event(EventState {
            result: Some(_), ..
        }) => run.leave_event(data),
        Phase::Event(EventState { event, .. }) => {
            let option = choose_event_option(run, data, *event);
            run.choose_event_option(data, option)
        }
        Phase::Pick(pick) => {
            let pick = pick.clone();
            match choose_pick(run, data, &pick, &bonus) {
                Some(i) => run.pick_card(data, i),
                None => run.cancel_pick(),
            }
        }
        Phase::Victory | Phase::Defeat => Err(ActionError::WrongPhase),
    }
}

/// Plays a whole run with the smart bot.
pub fn play_run(data: &GameData, character: &str, seed: u64) -> Result<Run, ActionError> {
    super::play_run_with(data, character, seed, step)
}

fn character_bonus(run: &Run, data: &GameData) -> CombatBonus {
    data.character(&run.character)
        .map(|c| c.trait_rule.combat_bonus())
        .unwrap_or_default()
}

// ---------- combat ----------

type Action = (usize, Option<usize>);

/// The first action of the best card sequence this turn, or `None` to end the turn.
fn plan_action(combat: &Combat, data: &GameData) -> Option<Action> {
    let mut best_score = evaluate(combat, data);
    let mut best_action = None;
    let mut beam: Vec<(Combat, Action)> = Vec::new();

    // Depth 1: every distinct first play.
    for (action, next) in expansions(combat, data) {
        let score = evaluate(&next, data);
        if score > best_score {
            best_score = score;
            best_action = Some(action);
        }
        beam.push((next, action));
    }

    for _ in 1..MAX_DEPTH {
        let mut candidates: Vec<(f64, Combat, Action)> = Vec::new();
        for (state, first) in &beam {
            if state.is_over() {
                continue;
            }
            for (_, next) in expansions(state, data) {
                let score = evaluate(&next, data);
                if score > best_score {
                    best_score = score;
                    best_action = Some(*first);
                }
                candidates.push((score, next, *first));
            }
        }
        if candidates.is_empty() {
            break;
        }
        candidates.sort_by(|a, b| b.0.total_cmp(&a.0));
        candidates.truncate(BEAM_WIDTH);
        beam = candidates.into_iter().map(|(_, c, a)| (c, a)).collect();
    }
    best_action
}

/// All distinct plays from a state: identical cards with the same target are tried once.
fn expansions(combat: &Combat, data: &GameData) -> Vec<(Action, Combat)> {
    let mut out = Vec::new();
    let mut tried: Vec<(&str, bool, Option<usize>)> = Vec::new();
    for i in 0..combat.hand.len() {
        let Ok(card) = combat.playable_card(i, &data.cards) else {
            continue;
        };
        let targets: Vec<Option<usize>> = if needs_target(&card) {
            (0..combat.enemies.len())
                .filter(|&e| !combat.enemies[e].dead)
                .map(Some)
                .collect()
        } else {
            vec![None]
        };
        for t in targets {
            let key = (combat.hand[i].id.as_str(), combat.hand[i].upgraded, t);
            if tried.contains(&key) {
                continue;
            }
            tried.push(key);
            let mut next = combat.clone();
            let mut rng = GameRng::new(LOOKAHEAD_SEED ^ u64::from(combat.turn));
            if next.play_card(i, t, &data.cards, &mut rng).is_ok() {
                out.push(((i, t), next));
            }
        }
    }
    out
}

/// Total damage poison will still deal, capped at the target's HP.
fn poison_left(poison: u32, hp: i32) -> f64 {
    let p = f64::from(poison);
    (p * (p + 1.0) / 2.0).min(f64::from(hp.max(0)))
}

/// Scores a state at the end of the player's turn by playing the enemy phase.
fn evaluate(combat: &Combat, data: &GameData) -> f64 {
    let mut sim = combat.clone();
    if !sim.is_over() {
        let mut rng = GameRng::new(LOOKAHEAD_SEED);
        let _ = sim.end_turn(&data.cards, &mut rng);
    }
    let enemy_hp: f64 = sim
        .enemies
        .iter()
        .filter(|e| !e.dead)
        .map(|e| {
            f64::from(e.hp) - poison_left(e.status.poison, e.hp) - poison_left(e.status.bleed, e.hp) * 0.6
                + f64::from(e.block) * 0.3
        })
        .sum();
    let p = &sim.player;
    match sim.outcome {
        Some(Outcome::Win) => 100_000.0 + f64::from(p.hp) * 10.0,
        Some(Outcome::Lose) => -100_000.0 - enemy_hp,
        None => {
            let alive = sim.enemies.iter().filter(|e| !e.dead).count() as f64;
            let enemy_debuffs: f64 = sim
                .enemies
                .iter()
                .filter(|e| !e.dead)
                .map(|e| f64::from(e.status.weak) * 1.5 + f64::from(e.status.vulnerable) * 2.0)
                .sum();
            let hp = f64::from(p.hp) - poison_left(p.status.poison, p.hp);
            hp * 1.0 - enemy_hp * 0.7 - alive * 6.0
                + f64::from(p.status.strength) * 6.0
                + f64::from(p.status.thorns) * 2.0
                - f64::from(p.status.weak) * 2.0
                - f64::from(p.status.vulnerable) * 2.0
                + enemy_debuffs
        }
    }
}

// ---------- card values ----------

/// Rough worth of a card per play, with the character's bonuses.
pub fn card_value(card: &Card, bonus: &CombatBonus) -> f64 {
    let e = &card.effects;
    if e.unplayable {
        return if e.ethereal { -4.0 } else { -12.0 };
    }
    let area = if e.all_enemies { 1.6 } else { 1.0 };
    let mut damage = f64::from(e.damage);
    if let Some((tag, n)) = bonus.tag_damage
        && card.has_tag(tag)
        && e.damage > 0
    {
        damage += f64::from(n);
    }
    let mut block = f64::from(e.block);
    if let Some((tag, n)) = bonus.tag_block
        && card.has_tag(tag)
    {
        block += f64::from(n);
    }
    let mut v = damage * f64::from(e.hits.max(1)) * area;
    v += block * 0.8;
    v += f64::from(e.poison) * 1.6 * area;
    // Bleeding only triggers on attacks, so it is worth a bit less than poison.
    v += f64::from(e.bleed) * 1.4 * area;
    v += f64::from(e.weak) * 2.5 * area;
    v += f64::from(e.vulnerable) * 3.0 * area;
    v += f64::from(e.thorns) * 2.5;
    v += f64::from(e.strength) * 7.0;
    v += f64::from(e.heal) * 0.8;
    v -= f64::from(e.hp_loss) * 0.8;
    v += f64::from(e.draw) * 3.5;
    v += f64::from(e.energy) * 5.0;
    if e.block_damage {
        v += 9.0;
    }
    if e.double_poison {
        v += 9.0;
    }
    if e.exhaust && card.kind != CardKind::Power {
        v *= 0.85;
    }
    // Value per energy, so cheap and expensive cards compare fairly.
    v / (f64::from(card.cost) + 1.0)
}

fn instance_value(inst: &CardInstance, data: &GameData, bonus: &CombatBonus) -> f64 {
    inst.resolve(&data.cards)
        .map_or(0.0, |c| card_value(&c, bonus))
}

fn deck_average(run: &Run, data: &GameData, bonus: &CombatBonus) -> f64 {
    let sum: f64 = run
        .deck
        .iter()
        .map(|c| instance_value(c, data, bonus))
        .sum();
    sum / run.deck.len().max(1) as f64
}

/// Whether a card with this value improves the deck enough to take it.
fn worth_taking(value: f64, run: &Run, data: &GameData, bonus: &CombatBonus) -> bool {
    let avg = deck_average(run, data, bonus);
    let bar = if run.deck.len() >= DECK_SOFT_LIMIT {
        avg * 1.4
    } else {
        avg * 1.05
    };
    value >= bar
}

fn choose_reward(
    run: &Run,
    data: &GameData,
    cards: &[CardInstance],
    bonus: &CombatBonus,
) -> Option<usize> {
    let (i, value) = cards
        .iter()
        .enumerate()
        .map(|(i, c)| (i, instance_value(c, data, bonus)))
        .max_by(|a, b| a.1.total_cmp(&b.1))?;
    worth_taking(value, run, data, bonus).then_some(i)
}

// ---------- map ----------

fn node_value(kind: NodeKind, run: &Run) -> f64 {
    let ratio = f64::from(run.hp) / f64::from(run.max_hp);
    match kind {
        NodeKind::Fight => {
            if ratio < 0.35 {
                -1.0
            } else {
                3.0
            }
        }
        NodeKind::Elite => {
            if ratio > 0.75 {
                6.0
            } else if ratio > 0.55 {
                1.0
            } else {
                -8.0
            }
        }
        NodeKind::Rest => {
            if ratio < 0.5 {
                8.0
            } else {
                3.0
            }
        }
        NodeKind::Shop => {
            if run.gold >= 150 {
                6.0
            } else if run.gold >= 80 {
                3.0
            } else {
                0.5
            }
        }
        NodeKind::Event => 2.5,
        NodeKind::Boss => 0.0,
    }
}

/// The available node with the best path value up to the boss.
fn choose_node(run: &Run) -> usize {
    let n = run.map.nodes.len();
    let mut best_from = vec![0.0f64; n];
    for row in run.map.rows.iter().rev() {
        for &id in row {
            let node = &run.map.nodes[id];
            let ahead = node
                .next
                .iter()
                .map(|&b| best_from[b])
                .fold(f64::NEG_INFINITY, f64::max);
            let ahead = if ahead.is_finite() { ahead } else { 0.0 };
            best_from[id] = node_value(node.kind, run) + ahead;
        }
    }
    let available = run.available_nodes();
    available
        .iter()
        .copied()
        .max_by(|&a, &b| best_from[a].total_cmp(&best_from[b]))
        .unwrap_or(available[0])
}

// ---------- shop, picks, events ----------

/// Cards below this value are removed when possible.
const REMOVE_BELOW: f64 = 2.6;

fn shop_step(
    run: &mut Run,
    data: &GameData,
    shop: &Shop,
    bonus: &CombatBonus,
) -> Result<(), ActionError> {
    if let Some(r) = &shop.relic
        && !r.sold
        && run.gold >= r.price
    {
        return run.buy_relic();
    }
    let worst = run
        .deck
        .iter()
        .map(|c| instance_value(c, data, bonus))
        .fold(f64::INFINITY, f64::min);
    if run.can_remove_at_shop() && run.gold >= shop.remove_cost && worst < REMOVE_BELOW {
        return run.shop_remove();
    }
    let best = shop
        .cards
        .iter()
        .enumerate()
        .filter(|(_, item)| !item.sold && item.price <= run.gold)
        .map(|(i, item)| (i, instance_value(&item.card, data, bonus)))
        .max_by(|a, b| a.1.total_cmp(&b.1));
    if let Some((i, value)) = best
        && worth_taking(value * 0.95, run, data, bonus)
    {
        return run.buy_card(i);
    }
    run.leave_shop()
}

fn choose_pick(run: &Run, data: &GameData, pick: &PickState, bonus: &CombatBonus) -> Option<usize> {
    let allowed = (0..run.deck.len()).filter(|&i| run.pick_allowed(data, i));
    let value = |i: usize| instance_value(&run.deck[i], data, bonus);
    match pick.mode {
        PickMode::Upgrade => allowed
            .map(|i| {
                let gain = run.deck[i].resolve(&data.cards).map_or(0.0, |c| {
                    card_value(&c.upgraded(), bonus) - card_value(&c, bonus)
                });
                (i, gain)
            })
            .max_by(|a, b| a.1.total_cmp(&b.1))
            .map(|(i, _)| i),
        PickMode::Remove | PickMode::Trade => allowed
            .map(|i| (i, value(i)))
            .min_by(|a, b| a.1.total_cmp(&b.1))
            .map(|(i, _)| i),
    }
}

fn effect_value(effect: &EventEffect, run: &Run) -> f64 {
    let missing = f64::from(run.max_hp - run.hp);
    let ratio = f64::from(run.hp) / f64::from(run.max_hp);
    match effect {
        EventEffect::Heal(n) => f64::from(*n).min(missing),
        EventEffect::GainMaxHp(n) => f64::from(*n) * 1.3,
        EventEffect::LoseHp(n) => -f64::from(*n) * if ratio < 0.5 { 2.0 } else { 0.8 },
        EventEffect::GainGold(n) => f64::from(*n) * 0.12,
        EventEffect::LoseGold(n) => -f64::from(*n) * 0.12,
        EventEffect::AddCard(_) => -12.0,
        EventEffect::RareCardChoice => 14.0,
        EventEffect::Pick { mode, cost } => {
            let base = match mode {
                PickMode::Upgrade => 7.0,
                PickMode::Remove => 6.0,
                PickMode::Trade => 8.0,
            };
            base - f64::from(*cost) * 0.12
        }
    }
}

fn choose_event_option(run: &Run, data: &GameData, event: usize) -> usize {
    let options = &data.events[event].options;
    (0..options.len())
        .filter(|&i| run.requirement_met(data, &options[i].requires))
        .map(|i| {
            let opt = &options[i];
            let total: u32 = opt.outcomes.iter().map(|o| o.weight).sum();
            let expected: f64 = opt
                .outcomes
                .iter()
                .map(|o| {
                    let v: f64 = o.effects.iter().map(|e| effect_value(e, run)).sum();
                    v * f64::from(o.weight) / f64::from(total.max(1))
                })
                .sum();
            (i, expected)
        })
        .max_by(|a, b| a.1.total_cmp(&b.1))
        .map_or(0, |(i, _)| i)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bot;

    fn data() -> GameData {
        GameData::builtin().unwrap()
    }

    #[test]
    fn smart_bot_finishes_runs() {
        let d = data();
        for ch in ["warrior", "marksman", "mage"] {
            for seed in 0..8 {
                let r = play_run(&d, ch, seed).unwrap();
                assert!(r.is_over(), "{ch} seed {seed}");
            }
        }
    }

    #[test]
    fn smart_bot_beats_naive_bot() {
        let d = data();
        let wins = |step: bot::StepFn| {
            (0..30)
                .filter(|&seed| {
                    let r = bot::play_run_with(&d, "warrior", seed, step).unwrap();
                    r.phase == Phase::Victory
                })
                .count()
        };
        let (smart, naive) = (wins(step), wins(bot::step));
        assert!(smart > naive, "smart {smart} vs naive {naive}");
    }

    #[test]
    fn plan_finds_lethal() {
        let d = data();
        let mut run = Run::new(&d, "warrior", 1).unwrap();
        run.continue_from_intro().unwrap();
        let first = run.available_nodes()[0];
        run.choose_node(&d, first).unwrap();
        let Phase::Combat(c) = &mut run.phase else {
            panic!()
        };
        for e in &mut c.enemies {
            e.hp = 5;
            e.block = 0;
        }
        c.enemies.truncate(1);
        c.hand = vec![CardInstance::new("defend"), CardInstance::new("strike")];
        c.energy = 1;
        let action = plan_action(c, &d);
        assert_eq!(action, Some((1, Some(0))), "Schlag kills, Block does not");
    }

    #[test]
    fn card_values_rank_sensibly() {
        let d = data();
        let none = CombatBonus::default();
        let v = |id: &str| card_value(d.cards.get(id).unwrap(), &none);
        assert!(v("heavy") > v("strike"));
        assert!(v("strike") > v("curse"));
        assert!(v("finish") > v("kick") * 0.5);
        let marksman = d.character("marksman").unwrap().trait_rule.combat_bonus();
        assert!(card_value(d.cards.get("arrow").unwrap(), &marksman) > v("arrow"));
    }
}
