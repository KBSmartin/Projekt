//! Rule tests for the combat port. Each test pins one rule of the prototype.

use super::*;

const TEST_CARDS: &str = r#"[
  {"id":"strike","name":"Schlag","kind":"attack","cost":1,"rarity":"starter","tags":["slash"],"effects":{"damage":6}},
  {"id":"defend","name":"Block","kind":"skill","cost":1,"rarity":"starter","tags":["block"],"effects":{"block":5}},
  {"id":"heavy","name":"Wuchtschlag","kind":"attack","cost":2,"rarity":"uncommon","tags":["slash"],"effects":{"damage":14}},
  {"id":"twin","name":"Doppelhieb","kind":"attack","cost":1,"rarity":"common","tags":["slash"],"effects":{"damage":4,"hits":2}},
  {"id":"whirl","name":"Wirbel","kind":"attack","cost":1,"rarity":"common","tags":["slash","area"],"effects":{"damage":5,"all_enemies":true}},
  {"id":"venom","name":"Giftpfeil","kind":"attack","cost":1,"rarity":"common","tags":["poison","throw"],"effects":{"damage":3,"poison":4}},
  {"id":"decay","name":"Ausbluten","kind":"skill","cost":1,"rarity":"rare","tags":["poison"],"effects":{"double_poison":true}},
  {"id":"slam","name":"Schildhieb","kind":"attack","cost":1,"rarity":"common","tags":["shield"],"effects":{"block_damage":true}},
  {"id":"thorn","name":"Dornenpanzer","kind":"skill","cost":1,"rarity":"common","tags":["block"],"effects":{"block":4,"thorns":3}},
  {"id":"warcry","name":"Kriegsruf","kind":"power","cost":1,"rarity":"uncommon","tags":["slash"],"effects":{"strength":2}},
  {"id":"focus","name":"Sammeln","kind":"skill","cost":0,"rarity":"common","tags":["draw"],"effects":{"energy":1,"exhaust":true}},
  {"id":"bandage","name":"Verband","kind":"skill","cost":1,"rarity":"common","tags":["block"],"effects":{"heal":6,"exhaust":true}},
  {"id":"pact","name":"Blutpakt","kind":"skill","cost":0,"rarity":"common","tags":["draw"],"effects":{"hp_loss":3,"energy":2}},
  {"id":"draw5","name":"Test","kind":"skill","cost":0,"rarity":"common","tags":["draw"],"effects":{"draw":5}},
  {"id":"burn","name":"Brand","kind":"status","cost":0,"rarity":"junk","tags":[],"effects":{"unplayable":true,"burn":true}},
  {"id":"frost","name":"Frost","kind":"status","cost":0,"rarity":"junk","tags":[],"effects":{"unplayable":true,"ethereal":true}}
]"#;

const TEST_ENEMIES: &str = r#"[
  {"id":"dummy","name":"Puppe","hp":[40,40],"moves":[{"damage":5}]},
  {"id":"idle","name":"Stein","hp":[20,20],"moves":[{}]},
  {"id":"cycler","name":"Kreisel","hp":[30,30],"moves":[{"damage":1},{"damage":2},{"damage":3}]},
  {"id":"buffer","name":"Kraftprotz","hp":[30,30],"moves":[{"strength":2},{"damage":5}]},
  {"id":"healer","name":"Heiler","hp":[30,30],"moves":[{"heal":10,"block":3}]},
  {"id":"debuffer","name":"Fluchwerfer","hp":[30,30],"moves":[{"weak":2,"vulnerable":2,"poison":3}]},
  {"id":"burner","name":"Zündler","hp":[30,30],"moves":[{"burn":2,"frost":1}]},
  {"id":"multi","name":"Hagel","hp":[30,30],"moves":[{"damage":3,"hits":3}]},
  {"id":"ranged","name":"Schwankend","hp":[10,20],"moves":[{"damage":1}]}
]"#;

fn cards() -> CardDb {
    CardDb::from_json(TEST_CARDS).unwrap()
}

fn enemies() -> EnemyDb {
    EnemyDb::from_json(TEST_ENEMIES).unwrap()
}

fn deck(ids: &[&str]) -> Vec<CardInstance> {
    ids.iter().map(|id| CardInstance::new(*id)).collect()
}

fn start_with(
    enemy_ids: &[&str],
    kind: CombatKind,
    relics: &[Relic],
    seed: u64,
) -> (Combat, GameRng) {
    let mut rng = GameRng::new(seed);
    let d = deck(&["strike"; 10]);
    let setup = CombatSetup {
        hp: 50,
        max_hp: 75,
        deck: &d,
        relics,
        bonus: CombatBonus::default(),
        enemy_scale_pct: 100,
    };
    let c = Combat::start(setup, kind, enemy_ids, &enemies(), &cards(), &mut rng).unwrap();
    (c, rng)
}

fn start(enemy_ids: &[&str]) -> (Combat, GameRng) {
    start_with(enemy_ids, CombatKind::Boss, &[], 1)
}

/// Replaces the hand and gives 3 energy; leaves the piles empty.
fn set_hand(c: &mut Combat, ids: &[&str]) {
    c.hand = deck(ids);
    c.draw_pile.clear();
    c.discard.clear();
    c.energy = 3;
}

fn play(c: &mut Combat, rng: &mut GameRng, index: usize, target: Option<usize>) {
    c.play_card(index, target, &cards(), rng).unwrap();
}

fn end(c: &mut Combat, rng: &mut GameRng) {
    c.end_turn(&cards(), rng).unwrap();
}

// ---------- damage formula ----------

fn st(strength: i32, weak: u32, vulnerable: u32) -> Statuses {
    Statuses {
        strength,
        weak,
        vulnerable,
        ..Statuses::default()
    }
}

#[test]
fn damage_adds_strength() {
    let n = DamageMods::NEUTRAL;
    assert_eq!(calc_damage(6, n, &st(0, 0, 0), &st(0, 0, 0)), 6);
    assert_eq!(calc_damage(6, n, &st(2, 0, 0), &st(0, 0, 0)), 8);
}

#[test]
fn damage_weak_and_vulnerable_round_down_in_order() {
    let n = DamageMods::NEUTRAL;
    assert_eq!(calc_damage(10, n, &st(0, 1, 0), &st(0, 0, 0)), 7); // 7.5
    assert_eq!(calc_damage(5, n, &st(0, 0, 0), &st(0, 0, 1)), 7); // 7.5
    // Weak first: 10 -> 7, then vulnerable: 7 -> 10 (not 10 -> 15 -> 11).
    assert_eq!(calc_damage(10, n, &st(0, 1, 0), &st(0, 0, 1)), 10);
}

#[test]
fn damage_never_negative() {
    let n = DamageMods::NEUTRAL;
    assert_eq!(calc_damage(3, n, &st(-10, 0, 0), &st(0, 0, 0)), 0);
}

#[test]
fn damage_mods_follow_konzept_order() {
    let mods = DamageMods {
        weapon: 2,
        tag_multiplier_pct: 150,
    };
    // (6 + 2 + 1) * 1.5 = 13.5 -> 13, then weak: 9.75 -> 9.
    assert_eq!(calc_damage(6, mods, &st(1, 0, 0), &st(0, 0, 0)), 13);
    assert_eq!(calc_damage(6, mods, &st(1, 1, 0), &st(0, 0, 0)), 9);
}

// ---------- combat start ----------

#[test]
fn first_turn_draws_five_with_three_energy() {
    let (c, _) = start(&["idle"]);
    assert_eq!(c.turn, 1);
    assert_eq!(c.hand.len(), 5);
    assert_eq!(c.draw_pile.len(), 5);
    assert_eq!(c.energy, 3);
    assert_eq!(c.player.hp, 50);
    assert_eq!(c.outcome, None);
}

#[test]
fn relics_change_combat_start() {
    let (c, _) = start_with(&["idle"], CombatKind::Boss, &Relic::ALL, 1);
    assert_eq!(c.energy, 4, "Energiekern");
    assert_eq!(c.player.block, 8, "Anker");
    assert_eq!(c.player.status.strength, 1, "Blutrubin");
    assert_eq!(c.hand.len(), 6, "Linse");
}

#[test]
fn same_seed_gives_same_combat() {
    let run = |seed| {
        let (mut c, mut rng) = start_with(&["ranged", "cycler"], CombatKind::Fight, &[], seed);
        for _ in 0..3 {
            while c.playable_card(0, &cards()).is_ok() {
                play(&mut c, &mut rng, 0, None);
            }
            if c.is_over() {
                break;
            }
            end(&mut c, &mut rng);
        }
        c
    };
    assert_eq!(run(9), run(9));
}

#[test]
fn enemy_hp_is_rolled_in_range() {
    let mut seen = std::collections::BTreeSet::new();
    for seed in 0..100 {
        let (c, _) = start_with(&["ranged"], CombatKind::Fight, &[], seed);
        assert!((10..=20).contains(&c.enemies[0].hp));
        assert_eq!(c.enemies[0].hp, c.enemies[0].max_hp);
        seen.insert(c.enemies[0].hp);
    }
    assert!(seen.len() > 5);
}

#[test]
fn normal_fights_start_at_random_move_elites_and_bosses_at_first() {
    let mut seen = std::collections::BTreeSet::new();
    for seed in 0..50 {
        let (c, _) = start_with(&["cycler"], CombatKind::Fight, &[], seed);
        seen.insert(c.enemies[0].move_index);
        for kind in [CombatKind::Elite, CombatKind::Boss] {
            let (c, _) = start_with(&["cycler"], kind, &[], seed);
            assert_eq!(c.enemies[0].move_index, 0);
        }
    }
    assert_eq!(seen.len(), 3);
}

#[test]
fn start_rejects_unknown_data() {
    let mut rng = GameRng::new(1);
    let d = deck(&["nope"]);
    let setup = CombatSetup {
        hp: 50,
        max_hp: 75,
        deck: &d,
        relics: &[],
        bonus: CombatBonus::default(),
        enemy_scale_pct: 100,
    };
    let r = Combat::start(
        setup,
        CombatKind::Fight,
        &["idle"],
        &enemies(),
        &cards(),
        &mut rng,
    );
    assert_eq!(r, Err(CombatError::UnknownCard("nope".into())));
    let setup = CombatSetup { deck: &[], ..setup };
    let r = Combat::start(
        setup,
        CombatKind::Fight,
        &["nope"],
        &enemies(),
        &cards(),
        &mut rng,
    );
    assert_eq!(r, Err(CombatError::UnknownEnemy("nope".into())));
    let r = Combat::start(
        setup,
        CombatKind::Fight,
        &[],
        &enemies(),
        &cards(),
        &mut rng,
    );
    assert_eq!(r, Err(CombatError::NoEnemies));
}

// ---------- playing cards ----------

#[test]
fn attack_hits_block_first() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &["strike"]);
    c.enemies[0].block = 4;
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.enemies[0].block, 0);
    assert_eq!(c.enemies[0].hp, 18);
}

#[test]
fn playing_costs_energy_and_discards() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &["heavy", "strike"]);
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.energy, 1);
    assert_eq!(c.discard, deck(&["heavy"]));
    assert_eq!(c.hand, deck(&["strike"]));
}

#[test]
fn invalid_plays_are_rejected_without_change() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &["heavy", "burn"]);
    c.energy = 1;
    let before = c.clone();
    let db = cards();
    assert_eq!(
        c.play_card(0, None, &db, &mut rng),
        Err(PlayError::NotEnoughEnergy)
    );
    assert_eq!(
        c.play_card(1, None, &db, &mut rng),
        Err(PlayError::Unplayable)
    );
    assert_eq!(
        c.play_card(5, None, &db, &mut rng),
        Err(PlayError::NoSuchCard)
    );
    assert_eq!(c, before);
}

#[test]
fn power_and_exhaust_cards_are_exhausted() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &["warcry", "focus"]);
    play(&mut c, &mut rng, 0, None);
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.exhaust, deck(&["warcry", "focus"]));
    assert_eq!(c.player.status.strength, 2);
    assert_eq!(c.energy, 3, "3 - 1 + 0 + 1");
}

#[test]
fn multi_hit_stops_when_target_dies() {
    let (mut c, mut rng) = start(&["idle", "idle"]);
    set_hand(&mut c, &["twin", "twin"]);
    play(&mut c, &mut rng, 0, Some(0));
    assert_eq!(c.enemies[0].hp, 12);
    c.enemies[1].hp = 3;
    play(&mut c, &mut rng, 0, Some(1));
    assert_eq!(c.enemies[1].hp, -1, "second hit skipped");
    assert!(c.enemies[1].dead);
}

#[test]
fn area_attack_hits_all_living_enemies() {
    let (mut c, mut rng) = start(&["idle", "idle", "idle"]);
    set_hand(&mut c, &["whirl"]);
    c.enemies[1].dead = true;
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.enemies[0].hp, 15);
    assert_eq!(c.enemies[1].hp, 20);
    assert_eq!(c.enemies[2].hp, 15);
}

#[test]
fn invalid_target_falls_back_to_first_living_enemy() {
    let (mut c, mut rng) = start(&["idle", "idle", "idle"]);
    set_hand(&mut c, &["strike", "strike"]);
    c.enemies[0].dead = true;
    play(&mut c, &mut rng, 0, Some(0));
    assert_eq!(c.enemies[1].hp, 14);
    play(&mut c, &mut rng, 0, Some(9));
    assert_eq!(c.enemies[1].hp, 8);
    assert_eq!(c.enemies[2].hp, 20);
}

#[test]
fn double_poison_and_block_damage() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &["venom", "decay", "slam"]);
    play(&mut c, &mut rng, 0, None);
    assert_eq!((c.enemies[0].hp, c.enemies[0].status.poison), (17, 4));
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.enemies[0].status.poison, 8);
    c.player.block = 7;
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.enemies[0].hp, 10);
    assert_eq!(c.player.block, 7, "Schildhieb keeps the block");
}

#[test]
fn heal_is_capped_and_hp_loss_can_kill() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &["bandage", "pact"]);
    c.player.hp = 72;
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.player.hp, 75);
    c.player.hp = 3;
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.energy, 4, "3 - 1 + 2");
    assert_eq!(c.outcome, Some(Outcome::Lose));
}

#[test]
fn draw_effect_respects_hand_limit() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(
        &mut c,
        &[
            "draw5", "strike", "strike", "strike", "strike", "strike", "strike", "strike",
        ],
    );
    c.draw_pile = deck(&["defend"; 6]);
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.hand.len(), MAX_HAND);
    assert_eq!(c.draw_pile.len(), 3);
}

// ---------- turn flow ----------

#[test]
fn empty_draw_pile_reshuffles_discard() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &[]);
    c.discard = deck(&["defend"; 7]);
    end(&mut c, &mut rng);
    assert_eq!(c.turn, 2);
    assert_eq!(c.hand.len(), 5);
    assert_eq!(c.draw_pile.len(), 2);
    assert!(c.discard.is_empty());
}

#[test]
fn block_lasts_through_enemy_turn_then_resets() {
    let (mut c, mut rng) = start(&["dummy"]);
    set_hand(&mut c, &["defend", "defend"]);
    play(&mut c, &mut rng, 0, None);
    play(&mut c, &mut rng, 0, None);
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 50, "5 damage fully blocked");
    assert_eq!(c.player.block, 0, "reset at turn start");
}

#[test]
fn enemy_poison_ticks_before_its_move_and_ignores_block() {
    let (mut c, mut rng) = start(&["dummy"]);
    set_hand(&mut c, &["venom"]);
    play(&mut c, &mut rng, 0, None);
    c.enemies[0].block = 50;
    end(&mut c, &mut rng);
    assert_eq!(c.enemies[0].hp, 40 - 3 - 4);
    assert_eq!(c.enemies[0].status.poison, 3);
    assert_eq!(
        c.enemies[0].block, 0,
        "enemy block resets at its phase start"
    );
}

#[test]
fn poison_can_win_the_fight() {
    let (mut c, mut rng) = start(&["dummy"]);
    set_hand(&mut c, &[]);
    c.enemies[0].hp = 2;
    c.enemies[0].status.poison = 5;
    end(&mut c, &mut rng);
    assert!(c.enemies[0].dead);
    assert_eq!(c.player.hp, 50, "dead enemy does not attack");
    assert_eq!(c.outcome, Some(Outcome::Win));
}

#[test]
fn player_poison_ticks_at_turn_start_and_ignores_block() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &[]);
    c.player.status.poison = 3;
    c.player.block = 10;
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 47);
    assert_eq!(c.player.status.poison, 2);
}

#[test]
fn thorns_hurt_the_attacker_on_every_hit() {
    let (mut c, mut rng) = start(&["multi"]);
    set_hand(&mut c, &["thorn"]);
    play(&mut c, &mut rng, 0, None);
    c.player.block = 100;
    end(&mut c, &mut rng);
    assert_eq!(c.enemies[0].hp, 30 - 9);
    assert_eq!(c.player.hp, 50);
}

#[test]
fn player_vulnerable_lasts_one_enemy_attack_per_stack() {
    // Fix: in the prototype 1 stack dropped before the enemies acted.
    let (mut c, mut rng) = start(&["dummy"]);
    set_hand(&mut c, &[]);
    c.player.status.vulnerable = 1;
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 43, "floor(5 * 1.5)");
    assert_eq!(c.player.status.vulnerable, 0);
}

#[test]
fn player_weak_from_enemy_weakens_the_next_player_turn() {
    let (mut c, mut rng) = start(&["debuffer"]);
    set_hand(&mut c, &[]);
    end(&mut c, &mut rng);
    // Weak 2 from an enemy weakens exactly the next two player turns.
    c.enemies[0].def.moves = vec![Move::default()]; // no further debuffs
    for turn in 0..3 {
        set_hand(&mut c, &["strike"]);
        let before = c.enemies[0].hp;
        play(&mut c, &mut rng, 0, None);
        let expected = if turn < 2 { 4 } else { 6 };
        assert_eq!(before - c.enemies[0].hp, expected, "turn {turn}");
        end(&mut c, &mut rng);
    }
}

#[test]
fn player_vulnerable_from_enemy_lasts_its_full_count() {
    let (mut c, mut rng) = start(&["debuffer", "dummy"]);
    // Debuffer acts first and applies vulnerable 2, so the dummy's hit in the
    // same phase is already boosted; then two more full phases follow.
    c.enemies[0].def.moves = vec![Move {
        vulnerable: 2,
        ..Move::default()
    }];
    set_hand(&mut c, &[]);
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 43, "boosted in the applying phase");
    assert_eq!(c.player.status.vulnerable, 2, "no stack lost yet");
    c.enemies[0].def.moves = vec![Move::default()];
    let mut losses = Vec::new();
    for _ in 0..3 {
        let before = c.player.hp;
        set_hand(&mut c, &[]);
        end(&mut c, &mut rng);
        losses.push(before - c.player.hp);
    }
    assert_eq!(losses, vec![7, 7, 5]);
}

#[test]
fn poison_win_is_not_lost_to_player_poison() {
    // Fix: the prototype ticked the player's poison before noticing the win.
    let (mut c, mut rng) = start(&["dummy"]);
    set_hand(&mut c, &[]);
    c.enemies[0].hp = 1;
    c.enemies[0].status.poison = 3;
    c.player.hp = 2;
    c.player.status.poison = 5;
    end(&mut c, &mut rng);
    assert_eq!(c.outcome, Some(Outcome::Win));
    assert_eq!(c.player.hp, 2);
}

#[test]
fn character_bonus_applies() {
    let mut rng = GameRng::new(1);
    let d = deck(&["strike"; 10]);
    let setup = CombatSetup {
        hp: 50,
        max_hp: 75,
        deck: &d,
        relics: &[Relic::Anchor],
        bonus: CombatBonus {
            start_block: 6,
            extra_draw: 1,
            tag_damage: Some((Tag::Slash, 2)),
            tag_block: Some((Tag::Poison, 3)),
            turn_block: 0,
        },
        enemy_scale_pct: 100,
    };
    let mut c = Combat::start(
        setup,
        CombatKind::Boss,
        &["idle"],
        &enemies(),
        &cards(),
        &mut rng,
    )
    .unwrap();
    assert_eq!(c.player.block, 14, "6 + Anker 8");
    assert_eq!(c.hand.len(), 6);
    set_hand(&mut c, &["strike", "venom"]);
    let strike = c.hand[0].resolve(&cards()).unwrap();
    assert_eq!(c.card_damage(&strike, None), 8);
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.enemies[0].hp, 12, "Hieb +2");
    let block = c.player.block;
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.enemies[0].hp, 9, "Giftpfeil has no Hieb tag");
    assert_eq!(c.player.block, block + 3, "Gift card gives block");
}

#[test]
fn turn_block_comes_every_turn() {
    let mut rng = GameRng::new(1);
    let d = deck(&["strike"; 10]);
    let setup = CombatSetup {
        hp: 50,
        max_hp: 75,
        deck: &d,
        relics: &[],
        bonus: CombatBonus {
            turn_block: 3,
            ..CombatBonus::default()
        },
        enemy_scale_pct: 100,
    };
    let mut c = Combat::start(
        setup,
        CombatKind::Boss,
        &["dummy"],
        &enemies(),
        &cards(),
        &mut rng,
    )
    .unwrap();
    assert_eq!(c.player.block, 3);
    set_hand(&mut c, &[]);
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 48, "5 damage, 3 blocked");
    assert_eq!(c.player.block, 3, "fresh block next turn");
}

#[test]
fn enemy_scaling_raises_hp_and_damage() {
    let mut rng = GameRng::new(1);
    let d = deck(&["strike"; 10]);
    let setup = CombatSetup {
        hp: 50,
        max_hp: 75,
        deck: &d,
        relics: &[],
        bonus: CombatBonus::default(),
        enemy_scale_pct: 156,
    };
    let c = Combat::start(
        setup,
        CombatKind::Boss,
        &["dummy"],
        &enemies(),
        &cards(),
        &mut rng,
    )
    .unwrap();
    assert_eq!(c.enemies[0].hp, 62, "40 * 1.56 = 62.4");
    assert_eq!(c.intent_damage(0), Some(8), "5 * 1.56 = 7.8");
}

#[test]
fn intent_damage_includes_statuses() {
    let (mut c, _) = start(&["dummy"]);
    assert_eq!(c.intent_damage(0), Some(5));
    c.enemies[0].status.strength = 2;
    c.player.status.vulnerable = 1;
    assert_eq!(c.intent_damage(0), Some(10));
}

#[test]
fn enemy_phase_is_logged() {
    let (mut c, mut rng) = start(&["dummy", "idle"]);
    set_hand(&mut c, &[]);
    c.enemies[1].status.poison = 2;
    c.player.block = 3;
    end(&mut c, &mut rng);
    assert_eq!(
        c.log,
        vec![
            LogEntry::EnemyAttack {
                enemy: 0,
                hp_lost: 2
            },
            LogEntry::Poison {
                who: Who::Enemy(1),
                damage: 2
            },
        ]
    );
}

#[test]
fn enemy_weak_reduces_damage_then_drops() {
    let (mut c, mut rng) = start(&["dummy"]);
    set_hand(&mut c, &[]);
    c.enemies[0].status.weak = 1;
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 47, "floor(5 * 0.75)");
    assert_eq!(c.enemies[0].status.weak, 0);
}

#[test]
fn enemy_moves_cycle_in_order() {
    let (mut c, mut rng) = start(&["cycler"]);
    let mut hp = Vec::new();
    for _ in 0..4 {
        set_hand(&mut c, &[]);
        end(&mut c, &mut rng);
        hp.push(c.player.hp);
    }
    assert_eq!(hp, vec![49, 47, 44, 43]);
}

#[test]
fn enemy_strength_adds_to_later_attacks() {
    let (mut c, mut rng) = start(&["buffer"]);
    set_hand(&mut c, &[]);
    end(&mut c, &mut rng);
    assert_eq!(c.enemies[0].status.strength, 2);
    set_hand(&mut c, &[]);
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 43);
}

#[test]
fn enemy_heal_is_capped_and_block_is_gained() {
    let (mut c, mut rng) = start(&["healer"]);
    set_hand(&mut c, &[]);
    c.enemies[0].hp = 25;
    end(&mut c, &mut rng);
    assert_eq!(c.enemies[0].hp, 30);
    assert_eq!(c.enemies[0].block, 3);
}

#[test]
fn enemy_debuffs_hit_the_player() {
    let (mut c, mut rng) = start(&["debuffer"]);
    set_hand(&mut c, &[]);
    end(&mut c, &mut rng);
    // Poison 3 ticks once at the start of the new turn.
    assert_eq!(c.player.hp, 47);
    assert_eq!(c.player.status.poison, 2);
    assert_eq!(c.player.status.weak, 2);
    assert_eq!(c.player.status.vulnerable, 2);
}

#[test]
fn enemies_add_junk_cards_to_discard() {
    let (mut c, mut rng) = start(&["burner"]);
    set_hand(&mut c, &[]);
    c.draw_pile = deck(&["strike"; 5]);
    end(&mut c, &mut rng);
    assert_eq!(c.discard, deck(&["burn", "burn", "frost"]));
}

#[test]
fn burn_hurts_and_frost_vanishes_at_turn_end() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &["burn", "burn", "frost", "strike"]);
    c.player.block = 1;
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 47, "2 + 2 damage, 1 blocked");
    assert_eq!(c.exhaust, deck(&["frost"]));
    let total = c.hand.len() + c.draw_pile.len() + c.discard.len();
    assert_eq!(total, 3, "burn, burn and strike stay in the deck");
}

// ---------- end of combat ----------

#[test]
fn killing_the_last_enemy_wins_and_locks_the_combat() {
    let (mut c, mut rng) = start(&["idle"]);
    set_hand(&mut c, &["strike", "strike"]);
    c.enemies[0].hp = 6;
    play(&mut c, &mut rng, 0, None);
    assert_eq!(c.outcome, Some(Outcome::Win));
    let db = cards();
    assert_eq!(
        c.play_card(0, None, &db, &mut rng),
        Err(PlayError::CombatOver)
    );
    assert_eq!(c.end_turn(&db, &mut rng), Err(PlayError::CombatOver));
}

#[test]
fn dropping_to_zero_hp_loses() {
    let (mut c, mut rng) = start(&["dummy"]);
    set_hand(&mut c, &[]);
    c.player.hp = 5;
    end(&mut c, &mut rng);
    assert_eq!(c.player.hp, 0);
    assert_eq!(c.outcome, Some(Outcome::Lose));
}

#[test]
fn greedy_fights_always_end() {
    let db = cards();
    let d = deck(&[
        "strike", "strike", "strike", "strike", "strike", "defend", "defend", "defend", "defend",
        "heavy",
    ]);
    for seed in 0..200 {
        let mut rng = GameRng::new(seed);
        let setup = CombatSetup {
            hp: 75,
            max_hp: 75,
            deck: &d,
            relics: &[],
            bonus: CombatBonus::default(),
            enemy_scale_pct: 100,
        };
        let mut c = Combat::start(
            setup,
            CombatKind::Fight,
            &["ranged", "buffer"],
            &enemies(),
            &db,
            &mut rng,
        )
        .unwrap();
        for _ in 0..100 {
            while let Some(i) = (0..c.hand.len()).find(|&i| c.playable_card(i, &db).is_ok()) {
                c.play_card(i, None, &db, &mut rng).unwrap();
            }
            if c.is_over() {
                break;
            }
            c.end_turn(&db, &mut rng).unwrap();
        }
        assert!(c.is_over(), "seed {seed} did not finish");
    }
}
