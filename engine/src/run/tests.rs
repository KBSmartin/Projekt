use super::*;
use crate::content::EventDef;

fn data() -> GameData {
    GameData::builtin().unwrap()
}

fn event_index(data: &GameData, id: &str) -> usize {
    data.events
        .iter()
        .position(|e: &EventDef| e.id == id)
        .unwrap()
}

fn run(data: &GameData, character: &str) -> Run {
    Run::new(data, character, 7).unwrap()
}

/// Enters the first fight of the map and returns the run in combat.
fn in_first_fight(data: &GameData) -> Run {
    let mut r = run(data, "warrior");
    r.continue_from_intro().unwrap();
    let first = r.available_nodes()[0];
    r.choose_node(data, first).unwrap();
    r
}

fn force_outcome(r: &mut Run, outcome: Outcome) {
    let Phase::Combat(c) = &mut r.phase else {
        panic!("not in combat")
    };
    c.outcome = Some(outcome);
}

// ---------- start ----------

#[test]
fn new_run_uses_character_data() {
    let d = data();
    for (id, first_card) in [
        ("warrior", "strike"),
        ("marksman", "arrow"),
        ("mage", "spark"),
    ] {
        let r = run(&d, id);
        let hp = d.character(id).unwrap().max_hp;
        assert_eq!((r.hp, r.max_hp), (hp, hp));
        assert_eq!(r.gold, START_GOLD);
        assert_eq!(r.deck.len(), 10);
        assert_eq!(r.deck[0].id, first_card);
        assert_eq!(r.phase, Phase::RegionIntro);
    }
    assert_eq!(
        Run::new(&d, "nobody", 1).unwrap_err(),
        ActionError::NotAllowed
    );
}

#[test]
fn map_moves_follow_connections() {
    let d = data();
    let mut r = run(&d, "warrior");
    assert_eq!(r.choose_node(&d, 0), Err(ActionError::WrongPhase));
    r.continue_from_intro().unwrap();
    let boss = r.map.boss();
    assert_eq!(r.choose_node(&d, boss), Err(ActionError::NotAllowed));
    let first = r.available_nodes()[0];
    r.choose_node(&d, first).unwrap();
    assert!(
        matches!(r.phase, Phase::Combat(_)),
        "row 0 is always a fight"
    );
    assert_eq!(r.current, Some(first));
    assert_eq!(r.stats.nodes, 1);
}

#[test]
fn a_start_point_limits_the_first_step() {
    let d = data();
    let mut r = run(&d, "warrior");
    assert_eq!(r.choose_start(0), Err(ActionError::WrongPhase));
    r.continue_from_intro().unwrap();
    assert_eq!(r.choose_start(3), Err(ActionError::NotAllowed));
    r.choose_start(2).unwrap();
    assert_eq!(r.choose_start(1), Err(ActionError::NotAllowed), "only once");
    assert_eq!(r.available_nodes(), r.map.starts[2]);
    if let Some(&other) = r.map.rows[0]
        .iter()
        .find(|id| !r.map.starts[2].contains(id))
    {
        assert_eq!(r.choose_node(&d, other), Err(ActionError::NotAllowed));
    }
    let first = r.map.starts[2][0];
    r.choose_node(&d, first).unwrap();
    assert_eq!(r.start, Some(2));
}

#[test]
fn first_fight_uses_easy_encounters_and_character_bonus() {
    let d = data();
    let r = in_first_fight(&d);
    let Phase::Combat(c) = &r.phase else { panic!() };
    let ids: Vec<String> = c.enemies.iter().map(|e| e.def.id.clone()).collect();
    assert!(d.regions[0].easy.contains(&ids));
    let turn_block = d
        .character("warrior")
        .unwrap()
        .trait_rule
        .combat_bonus()
        .turn_block;
    assert_eq!(c.player.block, turn_block, "Krieger: Eisenhaut");
}

// ---------- combat results ----------

#[test]
fn unfinished_combat_cannot_be_left() {
    let d = data();
    let mut r = in_first_fight(&d);
    assert_eq!(r.finish_combat(&d), Err(ActionError::NotAllowed));
}

#[test]
fn won_fight_gives_gold_and_three_pool_cards() {
    let d = data();
    let mut r = in_first_fight(&d);
    force_outcome(&mut r, Outcome::Win);
    r.finish_combat(&d).unwrap();
    let Phase::Reward(reward) = &r.phase else {
        panic!()
    };
    assert!((10..=18).contains(&reward.gold));
    assert_eq!(r.gold, START_GOLD + reward.gold);
    assert_eq!(reward.relic, None);
    assert_eq!(reward.cards.len(), 3);
    for (i, c) in reward.cards.iter().enumerate() {
        assert!(d.cards.get(&c.id).unwrap().in_pool_of("warrior"));
        assert!(!reward.cards[..i].contains(c), "cards are different");
    }
    let picked = reward.cards[1].clone();
    r.take_reward_card(&d, 1).unwrap();
    assert_eq!(r.deck.last(), Some(&picked));
    assert_eq!(r.phase, Phase::Map);
    assert_eq!(r.stats.fights, 1);
}

#[test]
fn elite_reward_has_relic_and_relics_apply() {
    let d = data();
    let mut r = in_first_fight(&d);
    r.relics = vec![Relic::Coin, Relic::Tea];
    r.hp = 50;
    let Phase::Combat(c) = &mut r.phase else {
        panic!()
    };
    c.kind = CombatKind::Elite;
    c.player.hp = 50;
    force_outcome(&mut r, Outcome::Win);
    r.finish_combat(&d).unwrap();
    let Phase::Reward(reward) = &r.phase else {
        panic!()
    };
    assert!((37..=52).contains(&reward.gold), "elite gold × 1.5");
    let relic = reward.relic.expect("elite gives a relic");
    assert!(r.relics.contains(&relic));
    assert_eq!(r.hp, 56, "Kräutertee");
    assert_eq!(r.stats.elites, 1);
}

#[test]
fn lost_fight_ends_the_run() {
    let d = data();
    let mut r = in_first_fight(&d);
    let Phase::Combat(c) = &mut r.phase else {
        panic!()
    };
    c.player.hp = -4;
    force_outcome(&mut r, Outcome::Lose);
    r.finish_combat(&d).unwrap();
    assert_eq!(r.phase, Phase::Defeat);
    assert_eq!(r.hp, 0);
    assert!(r.is_over());
}

#[test]
fn bosses_lead_to_the_next_region_and_finally_to_victory() {
    let d = data();
    let mut r = run(&d, "mage");
    for region in 0..d.regions.len() {
        assert_eq!(r.region, region);
        r.phase = Phase::Map;
        r.current = Some(r.map.boss());
        r.hp = 10;
        r.phase = r.start_combat(&d, CombatKind::Boss, 8).unwrap();
        force_outcome(&mut r, Outcome::Win);
        // Tea heals from the fight after it was found, as in the prototype.
        let tea = if r.relics.contains(&Relic::Tea) { 6 } else { 0 };
        r.finish_combat(&d).unwrap();
        let Phase::Reward(reward) = &r.phase else {
            panic!()
        };
        assert!(
            reward
                .cards
                .iter()
                .all(|c| d.cards.get(&c.id).unwrap().rarity == Rarity::Rare)
        );
        r.skip_reward(&d).unwrap();
        assert_eq!(r.hp, 10 + tea + r.max_hp * 4 / 10, "40 % heal after a boss");
    }
    assert_eq!(r.phase, Phase::Victory);
}

// ---------- shop ----------

fn in_shop(d: &GameData) -> Run {
    let mut r = run(d, "marksman");
    r.phase = Phase::Shop(r.generate_shop(d));
    r
}

#[test]
fn shop_offers_five_pool_cards_and_a_relic() {
    let d = data();
    let r = in_shop(&d);
    let Phase::Shop(shop) = &r.phase else {
        panic!()
    };
    assert_eq!(shop.cards.len(), SHOP_CARDS);
    for item in &shop.cards {
        let card = d.cards.get(&item.card.id).unwrap();
        assert!(card.in_pool_of("marksman"));
        assert!((39..=131).contains(&item.price));
    }
    assert_eq!(shop.relic.as_ref().unwrap().price, SHOP_RELIC_PRICE);
    assert_eq!(shop.remove_cost, SHOP_REMOVE_COST);
}

#[test]
fn buying_costs_gold() {
    let d = data();
    let mut r = in_shop(&d);
    r.gold = 1000;
    r.buy_card(0).unwrap();
    assert_eq!(r.deck.len(), 11);
    assert_eq!(r.buy_card(0), Err(ActionError::NotAllowed), "already sold");
    r.buy_relic().unwrap();
    assert_eq!(r.relics.len(), 1);
    r.gold = 0;
    assert_eq!(r.buy_card(1), Err(ActionError::NotEnoughGold));
}

#[test]
fn shop_removal_raises_the_price() {
    let d = data();
    let mut r = in_shop(&d);
    r.gold = 100;
    r.shop_remove().unwrap();
    assert!(matches!(r.phase, Phase::Pick(_)));
    r.cancel_pick().unwrap();
    assert!(matches!(r.phase, Phase::Shop(_)));
    r.shop_remove().unwrap();
    r.pick_card(&d, 0).unwrap();
    assert_eq!(r.deck.len(), 9);
    assert_eq!(r.gold, 100 - SHOP_REMOVE_COST);
    assert_eq!(r.notice.as_ref().unwrap().mode, PickMode::Remove);
    let Phase::Shop(shop) = &r.phase else {
        panic!()
    };
    assert_eq!(shop.remove_cost, SHOP_REMOVE_COST + SHOP_REMOVE_STEP);
    r.deck.truncate(MIN_DECK);
    assert_eq!(r.shop_remove(), Err(ActionError::NotAllowed));
}

// ---------- rest ----------

#[test]
fn resting_heals_thirty_percent() {
    let d = data();
    let mut r = run(&d, "warrior");
    r.phase = Phase::Rest;
    r.hp = 10;
    r.rest_heal().unwrap();
    assert_eq!(r.hp, 34);
    assert_eq!(r.phase, Phase::Map);
}

#[test]
fn resting_can_upgrade_a_card() {
    let d = data();
    let mut r = run(&d, "warrior");
    r.phase = Phase::Rest;
    r.rest_upgrade(&d).unwrap();
    r.pick_card(&d, 9).unwrap();
    assert!(r.deck[9].upgraded);
    assert_eq!(r.phase, Phase::Map);
    let notice = r.notice.as_ref().unwrap();
    assert_eq!(notice.card.id, "bash");
    // Upgraded cards cannot be upgraded again.
    r.phase = Phase::Rest;
    r.rest_upgrade(&d).unwrap();
    assert!(!r.pick_allowed(&d, 9));
    assert_eq!(r.pick_card(&d, 9), Err(ActionError::NotAllowed));
}

// ---------- events ----------

fn at_event(d: &GameData, id: &str) -> Run {
    let mut r = run(d, "mage");
    r.phase = Phase::Event(EventState {
        event: event_index(d, id),
        result: None,
    });
    r
}

fn message(r: &Run) -> String {
    match &r.phase {
        Phase::Event(EventState {
            result: Some(EventResult::Message(m)),
            ..
        }) => m.clone(),
        other => panic!("no message: {other:?}"),
    }
}

#[test]
fn spring_heals_and_shows_the_amount() {
    let d = data();
    let mut r = at_event(&d, "spring");
    r.hp = r.max_hp - 10;
    r.choose_event_option(&d, 0).unwrap();
    assert_eq!(r.hp, r.max_hp, "heal is capped");
    assert_eq!(message(&r), "Du heilst 10 LP.");
    r.leave_event(&d).unwrap();
    assert_eq!(r.phase, Phase::Map);

    let mut r = at_event(&d, "spring");
    let max = r.max_hp;
    r.choose_event_option(&d, 1).unwrap();
    assert_eq!((r.hp, r.max_hp), (max + 6, max + 6));
}

#[test]
fn altar_costs_hp_for_a_rare_card() {
    let d = data();
    let mut r = at_event(&d, "altar");
    r.choose_event_option(&d, 0).unwrap();
    assert_eq!(r.hp, r.max_hp - 8);
    let Phase::Reward(reward) = &r.phase else {
        panic!()
    };
    assert_eq!(reward.source, RewardSource::Event(event_index(&d, "altar")));
    assert!(
        reward
            .cards
            .iter()
            .all(|c| d.cards.get(&c.id).unwrap().in_pool_of("mage"))
    );
    r.hp = 10;
    r.phase = Phase::Event(EventState {
        event: event_index(&d, "altar"),
        result: None,
    });
    assert_eq!(r.choose_event_option(&d, 0), Err(ActionError::NotAllowed));
}

#[test]
fn chest_and_dice_have_two_outcomes() {
    let d = data();
    let (mut gold, mut curse, mut won, mut lost) = (0, 0, 0, 0);
    for seed in 0..60 {
        let mut r = at_event(&d, "chest");
        r.rng = GameRng::new(seed);
        r.choose_event_option(&d, 0).unwrap();
        if r.gold == START_GOLD + 90 {
            gold += 1;
        } else if r.deck.iter().any(|c| c.id == "curse") {
            curse += 1;
        }
        let mut r = at_event(&d, "dice");
        r.rng = GameRng::new(seed);
        r.choose_event_option(&d, 0).unwrap();
        match r.gold {
            120 => won += 1,
            20 => lost += 1,
            g => panic!("unexpected gold {g}"),
        }
    }
    assert_eq!(gold + curse, 60);
    assert!(gold > 10 && curse > 10);
    assert!(won > 10 && lost > 10);
}

#[test]
fn smith_upgrade_is_paid_on_pick() {
    let d = data();
    let mut r = at_event(&d, "smith");
    r.choose_event_option(&d, 0).unwrap();
    assert_eq!(r.gold, START_GOLD, "not paid yet");
    r.cancel_pick().unwrap();
    assert!(matches!(
        r.phase,
        Phase::Event(EventState { result: None, .. })
    ));
    r.choose_event_option(&d, 0).unwrap();
    r.pick_card(&d, 0).unwrap();
    assert_eq!(r.gold, START_GOLD - 30);
    assert!(r.deck[0].upgraded);
    assert!(matches!(
        r.phase,
        Phase::Event(EventState {
            result: Some(EventResult::Picked(_)),
            ..
        })
    ));
    r.gold = 10;
    r.phase = Phase::Event(EventState {
        event: event_index(&d, "smith"),
        result: None,
    });
    assert_eq!(r.choose_event_option(&d, 0), Err(ActionError::NotAllowed));
}

#[test]
fn trader_swaps_for_a_rare_pool_card() {
    let d = data();
    let mut r = at_event(&d, "trader");
    r.choose_event_option(&d, 0).unwrap();
    r.pick_card(&d, 0).unwrap();
    let card = d.cards.get(&r.deck[0].id).unwrap();
    assert_eq!(card.rarity, Rarity::Rare);
    assert!(card.in_pool_of("mage"));
}

// ---------- whole runs ----------

fn play_whole_run(d: &GameData, character: &str, seed: u64) -> Run {
    crate::bot::play_run(d, character, seed)
        .unwrap_or_else(|e| panic!("{character} seed {seed}: {e}"))
}

#[test]
fn bots_finish_whole_runs_for_every_character() {
    let d = data();
    for ch in ["warrior", "marksman", "mage"] {
        for seed in 0..25 {
            let r = play_whole_run(&d, ch, seed);
            assert!(r.is_over(), "{ch} seed {seed} did not finish");
            assert!(r.hp >= 0 && r.hp <= r.max_hp);
        }
    }
}

#[test]
fn same_seed_same_run() {
    let d = data();
    assert_eq!(
        play_whole_run(&d, "marksman", 3),
        play_whole_run(&d, "marksman", 3)
    );
}
