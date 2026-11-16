//! Bots that play whole runs through the same actions as the UI.
//! Used by tests and by the `sim` crate.
//!
//! [`step`] is deliberately naive (a smoke test and baseline);
//! [`smart::step`] plays reasonably well and is meant for balancing.

pub mod smart;

use crate::combat::needs_target;
use crate::content::GameData;
use crate::run::{ActionError, EventState, Phase, Run};

/// Upper bound for actions in one run, so a broken rule cannot hang the bot.
pub const MAX_STEPS: usize = 20_000;

/// Performs one action. Plays the first playable card at the weakest enemy,
/// takes the first reward card, buys nothing, rests when below half HP and
/// otherwise upgrades, and picks the first selectable event option.
pub fn step(run: &mut Run, data: &GameData) -> Result<(), ActionError> {
    match &run.phase {
        Phase::RegionIntro => run.continue_from_intro(),
        Phase::Map => {
            let next = run.available_nodes()[0];
            run.choose_node(data, next)
        }
        Phase::Combat(c) => {
            if c.is_over() {
                return run.finish_combat(data);
            }
            let playable = (0..c.hand.len()).find(|&i| c.playable_card(i, &data.cards).is_ok());
            let Some(i) = playable else {
                return run.end_turn(data);
            };
            let card = c.hand[i]
                .resolve(&data.cards)
                .ok_or_else(|| ActionError::Data(format!("unknown card '{}'", c.hand[i].id)))?;
            let target = if needs_target(&card) {
                (0..c.enemies.len())
                    .filter(|&e| !c.enemies[e].dead)
                    .min_by_key(|&e| c.enemies[e].hp)
            } else {
                None
            };
            run.play_card(data, i, target)
        }
        Phase::Reward(_) => run.take_reward_card(data, 0),
        Phase::Shop(_) => run.leave_shop(),
        Phase::Rest => {
            if run.hp < run.max_hp / 2 || !run.can_upgrade(data) {
                run.rest_heal()
            } else {
                run.rest_upgrade(data)
            }
        }
        Phase::Event(EventState {
            result: Some(_), ..
        }) => run.leave_event(data),
        Phase::Event(EventState { event, .. }) => {
            let options = &data.events[*event].options;
            let i = (0..options.len())
                .find(|&i| run.requirement_met(data, &options[i].requires))
                .ok_or(ActionError::NotAllowed)?;
            run.choose_event_option(data, i)
        }
        Phase::Pick(_) => match (0..run.deck.len()).find(|&i| run.pick_allowed(data, i)) {
            Some(i) => run.pick_card(data, i),
            None => run.cancel_pick(),
        },
        Phase::Victory | Phase::Defeat => Err(ActionError::WrongPhase),
    }
}

/// Plays a whole run with the naive [`step`] until victory, defeat or [`MAX_STEPS`].
pub fn play_run(data: &GameData, character: &str, seed: u64) -> Result<Run, ActionError> {
    play_run_with(data, character, seed, step)
}

/// One bot action; see [`step`] and [`smart::step`].
pub type StepFn = fn(&mut Run, &GameData) -> Result<(), ActionError>;

/// Plays a whole run with any step function.
pub fn play_run_with(
    data: &GameData,
    character: &str,
    seed: u64,
    step: StepFn,
) -> Result<Run, ActionError> {
    let mut run = Run::new(data, character, seed)?;
    for _ in 0..MAX_STEPS {
        if run.is_over() {
            break;
        }
        step(&mut run, data)?;
    }
    Ok(run)
}
