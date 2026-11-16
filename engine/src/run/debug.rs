//! Cheats for the debug build and manual testing. They change the run
//! directly and skip the normal rules, so bots and the sim never call them.

use super::{ActionError, ActionResult, Phase, Run};
use crate::card::CardInstance;
use crate::combat::Outcome;
use crate::content::GameData;
use crate::relic::Relic;

impl Run {
    /// Kills every enemy; the fight then ends like a normal win.
    pub fn debug_win_combat(&mut self) -> ActionResult {
        let combat = self.combat_mut()?;
        if combat.outcome.is_some() {
            return Err(ActionError::NotAllowed);
        }
        for e in &mut combat.enemies {
            e.hp = 0;
            e.dead = true;
        }
        combat.outcome = Some(Outcome::Win);
        Ok(())
    }

    pub fn debug_gold(&mut self, amount: u32) -> ActionResult {
        self.gold += amount;
        Ok(())
    }

    /// Full HP, also inside a running fight.
    pub fn debug_heal(&mut self) -> ActionResult {
        self.hp = self.max_hp;
        if let Phase::Combat(c) = &mut self.phase
            && c.outcome.is_none()
        {
            c.player.hp = c.player.max_hp;
        }
        Ok(())
    }

    /// Energy for the current turn.
    pub fn debug_energy(&mut self, amount: u32) -> ActionResult {
        let combat = self.combat_mut()?;
        combat.energy += amount;
        Ok(())
    }

    pub fn debug_add_card(&mut self, data: &GameData, id: &str) -> ActionResult {
        if data.cards.get(id).is_none() {
            return Err(ActionError::NotAllowed);
        }
        self.deck.push(CardInstance::new(id));
        Ok(())
    }

    /// Takes effect from the next fight on, like a bought relic.
    pub fn debug_add_relic(&mut self, relic: Relic) -> ActionResult {
        if self.relics.contains(&relic) {
            return Err(ActionError::NotAllowed);
        }
        self.relics.push(relic);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::map::NodeKind;

    #[test]
    fn win_combat_leads_to_reward() {
        let data = GameData::builtin().unwrap();
        let mut run = Run::new(&data, "warrior", 7).unwrap();
        run.continue_from_intro().unwrap();
        let fight = run
            .available_nodes()
            .into_iter()
            .find(|&id| run.map.nodes[id].kind == NodeKind::Fight)
            .expect("first row has a fight");
        run.choose_node(&data, fight).unwrap();
        run.debug_win_combat().unwrap();
        run.finish_combat(&data).unwrap();
        assert!(matches!(run.phase, Phase::Reward(_)));
    }

    #[test]
    fn add_card_checks_id() {
        let data = GameData::builtin().unwrap();
        let mut run = Run::new(&data, "mage", 1).unwrap();
        let n = run.deck.len();
        assert!(run.debug_add_card(&data, "meteor").is_ok());
        assert!(run.debug_add_card(&data, "gibt-es-nicht").is_err());
        assert_eq!(run.deck.len(), n + 1);
    }
}
