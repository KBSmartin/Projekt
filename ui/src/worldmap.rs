//! The 2.5D world map: a ground plane tilted away in CSS 3D, with upright pixel
//! sprites standing on it (node signs, decoration, the hero figure). Fog covers
//! everything more than two steps ahead, so a route can't be planned through
//! the whole region in advance. Positions are percentages of the plane.

use crate::{Game, data};
use engine::{MAP_COLS, MAP_ROWS, MapNode, NodeKind, Run};
use leptos::prelude::*;

/// How many rows beyond the current one are visible.
const SIGHT: i32 = 2;
/// Width of the plane in percent of the view; the camera follows the hero.
const SPAN: f64 = 230.0;
/// Where the hero stands before the first step.
const START: (f64, f64) = (3.5, 58.0);

/// A point on the plane, in percent.
type Pt = (f64, f64);

/// Deterministic hash, so decoration and jitter stay put between renders.
fn mix(mut z: u64) -> u64 {
    z = z.wrapping_add(0x9E37_79B9_7F4A_7C15);
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

/// Uniform value in [-1, 1] from a hash.
fn unit(h: u64) -> f64 {
    (h >> 11) as f64 / (1u64 << 53) as f64 * 2.0 - 1.0
}

/// Map rows run from left to right, the lanes (columns) from back to front.
fn node_pos(n: &MapNode, salt: u64) -> (f64, f64) {
    let x = 12.0 + n.row as f64 * 80.0 / MAP_ROWS as f64;
    if n.kind == NodeKind::Boss {
        return (x, 58.0);
    }
    let y = 24.0 + n.col as f64 * 68.0 / (MAP_COLS - 1) as f64;
    let h = mix(salt ^ (n.id as u64 * 0x1F3D));
    (x + unit(h) * 2.4, y + unit(mix(h)) * 4.0)
}

fn kind_file(kind: NodeKind) -> &'static str {
    match kind {
        NodeKind::Fight => "kampf",
        NodeKind::Elite => "elite",
        NodeKind::Event => "ereignis",
        NodeKind::Shop => "haendler",
        NodeKind::Rest => "rast",
        NodeKind::Boss => "boss",
    }
}

fn kind_name(kind: NodeKind) -> &'static str {
    match kind {
        NodeKind::Fight => "Kampf",
        NodeKind::Elite => "Elite",
        NodeKind::Event => "Ereignis",
        NodeKind::Shop => "Händler",
        NodeKind::Rest => "Rastplatz",
        NodeKind::Boss => "Boss",
    }
}

/// Decoration per region: sprite name, size in art pixels, weight.
fn decor_set(region: &str) -> &'static [(&'static str, u32, u32, u32)] {
    match region {
        "desert" => &[
            ("kaktus", 10, 11, 4),
            ("fels", 12, 7, 3),
            ("totbaum", 10, 9, 2),
            ("knochen", 10, 5, 2),
            ("stein", 9, 6, 2),
        ],
        "fortress" => &[
            ("schneetanne", 11, 13, 5),
            ("eis", 10, 8, 2),
            ("schneefels", 12, 7, 3),
            ("stein", 9, 6, 1),
        ],
        _ => &[
            ("tanne", 11, 13, 5),
            ("baum", 12, 12, 3),
            ("busch", 10, 6, 3),
            ("stein", 9, 6, 1),
            ("pilz", 7, 6, 1),
        ],
    }
}

/// Distance from point p to the segment a-b (in plane percent).
fn seg_dist(p: (f64, f64), a: (f64, f64), b: (f64, f64)) -> f64 {
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    let len2 = dx * dx + dy * dy;
    let t = if len2 > 0.0 {
        (((p.0 - a.0) * dx + (p.1 - a.1) * dy) / len2).clamp(0.0, 1.0)
    } else {
        0.0
    };
    let (qx, qy) = (a.0 + t * dx - p.0, a.1 + t * dy - p.1);
    (qx * qx + qy * qy).sqrt()
}

/// Upright sprite standing at a point of the plane.
fn standing(x: f64, y: f64, class: &str, inner: AnyView) -> AnyView {
    view! { <div class=format!("bb {class}") style=format!("left:{x:.2}%;top:{y:.2}%")>{inner}</div> }.into_any()
}

pub fn world(game: Game, run: &Run) -> AnyView {
    let d = data();
    let region = &d.regions[run.region];
    let rid = region.id.clone();
    let salt = run.seed ^ (run.region as u64).wrapping_mul(0xA5A5_1234);
    let map = &run.map;
    let pos = |id: usize| node_pos(&map.nodes[id], salt);

    let cur_row = run.current.map_or(-1, |id| map.nodes[id].row as i32);
    let sight = cur_row + SIGHT;
    let seen = |n: &MapNode| n.row as i32 <= sight;
    // The fog starts halfway between the last visible row and the next one.
    let fog_x =
        (sight < MAP_ROWS as i32).then(|| 12.0 + (sight as f64 + 0.5) * 80.0 / MAP_ROWS as f64);

    let available = run.available_nodes();
    let here = run.current.map_or(START, pos);
    let run_started = run.current.is_some();
    // Camera: the hero stands about a fifth into the view, without leaving the plane.
    let cam = (16.0 - here.0 * SPAN / 100.0).clamp(98.0 - SPAN, 2.0);

    // --- Paths: every link out of a visible node (links into the fog vanish in it).
    let mut links: Vec<(Pt, Pt, &'static str)> = Vec::new();
    if run.current.is_none() {
        for &b in &map.rows[0] {
            links.push((START, pos(b), "open"));
        }
    } else if let Some(first) = run.visited.first() {
        links.push((START, pos(*first), "done"));
    }
    for n in map.nodes.iter().filter(|n| seen(n)) {
        for &b in &n.next {
            let taken = run.visited.contains(&n.id) && run.visited.contains(&b);
            let open = run.current == Some(n.id) && available.contains(&b);
            let class = if taken {
                "done"
            } else if open {
                "open"
            } else {
                "plain"
            };
            links.push((pos(n.id), pos(b), class));
        }
    }
    let paths = links
        .iter()
        .map(|&(a, b, class)| {
            let bend = unit(mix((a.0 * 977.0 + b.1 * 131.0) as u64 ^ salt)) * 3.0;
            let (cx, cy) = ((a.0 + b.0) / 2.0, (a.1 + b.1) / 2.0 + bend);
            let d = format!("M{:.2},{:.2} Q{cx:.2},{cy:.2} {:.2},{:.2}", a.0, a.1, b.0, b.1);
            view! {
                <path class=format!("trail {class}") d=d.clone() vector-effect="non-scaling-stroke" />
                <path class=format!("trailc {class}") d=d vector-effect="non-scaling-stroke" />
            }
        })
        .collect_view();

    // --- Decoration, kept away from nodes and paths and out of the fog.
    let set = decor_set(&rid);
    let total: u32 = set.iter().map(|s| s.3).sum();
    let all_links: Vec<((f64, f64), (f64, f64))> = map
        .nodes
        .iter()
        .flat_map(|n| n.next.iter().map(move |&b| (n.id, b)))
        .map(|(a, b)| (pos(a), pos(b)))
        .chain(map.rows[0].iter().map(|&b| (START, pos(b))))
        .collect();
    let mut decor = Vec::new();
    let mut h = mix(salt ^ 0xDEC0);
    for _ in 0..240 {
        h = mix(h);
        let x = 1.0 + (unit(h) + 1.0) * 49.0;
        let y = 3.0 + (unit(mix(h ^ 7)) + 1.0) * 47.0;
        if fog_x.is_some_and(|f| x > f - 1.5) {
            continue;
        }
        let near_node = map.nodes.iter().any(|n| {
            let p = pos(n.id);
            ((p.0 - x) / 1.4).powi(2) + (p.1 - y).powi(2) < 64.0
        }) || ((START.0 - x).powi(2) + (START.1 - y).powi(2)) < 49.0;
        if near_node || all_links.iter().any(|&(a, b)| seg_dist((x, y), a, b) < 3.6) {
            continue;
        }
        let mut pick = (mix(h ^ 99) % total as u64) as u32;
        let (name, w, ht, _) = *set
            .iter()
            .find(|s| {
                if pick < s.3 {
                    true
                } else {
                    pick -= s.3;
                    false
                }
            })
            .unwrap_or(&set[0]);
        decor.push((x, y, name, w, ht));
        if decor.len() >= 46 {
            break;
        }
    }
    let decor = decor
        .into_iter()
        .map(|(x, y, name, w, ht)| {
            standing(
                x,
                y,
                "deco",
                view! {
                    <img
                        src=format!("assets/karte/deko_{name}.png")
                        alt=""
                        style=format!("width:{}px;height:{}px", w * 4, ht * 4)
                    />
                }
                .into_any(),
            )
        })
        .collect_view();

    // --- Nodes: a glowing ring on the ground and a sign standing on a post.
    let walking = game.walking;
    let nodes = map
        .nodes
        .iter()
        .filter(|n| seen(n))
        .map(|n| {
            let (x, y) = pos(n.id);
            let id = n.id;
            let av = available.contains(&id);
            let state = if av {
                " av"
            } else if run.current == Some(id) {
                " cur"
            } else if run.visited.contains(&id) {
                " vis"
            } else {
                ""
            };
            let boss = if n.kind == NodeKind::Boss { " boss" } else { "" };
            let name = kind_name(n.kind);
            let file = kind_file(n.kind);
            let sign = view! {
                <button
                    class="sign"
                    title=name
                    aria-label=name
                    disabled=!av
                    on:click=move |_| {
                        if walking.get_untracked().is_none() {
                            game.walk_to(id);
                        }
                    }
                >
                    <img src=format!("assets/karte/symbol_{file}.png") alt="" />
                </button>
                <i class="post"></i>
            }
            .into_any();
            view! {
                <div class=format!("pad{state}{boss}") style=format!("left:{x:.2}%;top:{y:.2}%")></div>
                {standing(x, y, &format!("mnode{state}{boss}"), sign)}
            }
        })
        .collect_view();

    // --- Hero figure: stands on the current node, walks to the chosen one.
    let hero = crate::views::hero_file(&run.character);
    let targets: Vec<(usize, (f64, f64))> = available.iter().map(|&id| (id, pos(id))).collect();
    // The figure stands just in front of a node's sign, not on it.
    let in_front = |p: (f64, f64)| (p.0 - 1.2, p.1 + 6.0);
    let hero_at = move || {
        let p = walking
            .get()
            .and_then(|id| targets.iter().find(|t| t.0 == id).map(|t| t.1));
        match p {
            Some(p) => in_front(p),
            None if run_started => in_front(here),
            None => here,
        }
    };
    let hero_at2 = hero_at.clone();
    let hero_view = view! {
        <div
            class="bb hero"
            class:walk=move || walking.get().is_some()
            style:left=move || format!("{:.2}%", hero_at().0)
            style:top=move || format!("{:.2}%", hero_at2().1)
        >
            <div
                class="hfig"
                style=format!(
                    "--idle:url(assets/karte/held_{hero}_idle.png);--walk:url(assets/karte/held_{hero}_lauf.png)",
                )
            ></div>
        </div>
    };

    // --- Fog: a flat layer with a ragged edge and puffs standing along it.
    let fog = fog_x.map(|fx| {
        let left = fx - 2.0;
        let width = 102.0 - left;
        let mut pts = Vec::new();
        for i in 0..=24 {
            let t = i as f64 / 24.0;
            let wob = 2.0 + 1.6 * (t * 23.0 + salt as f64 % 7.0).sin() + 1.0 * (t * 61.0).sin();
            pts.push(format!("{:.2}% {:.2}%", wob / width * 100.0, t * 100.0));
        }
        pts.push("100% 100%".into());
        pts.push("100% 0%".into());
        let clip = format!("polygon({})", pts.join(","));
        // A wall of puffs along the edge, then loose banks over the whole fog.
        let mut spots: Vec<(f64, f64, f64)> = (0..10)
            .map(|i| {
                (
                    fx + 0.5 + unit(mix(salt ^ i)) * 1.2,
                    2.0 + i as f64 * 10.6,
                    1.25,
                )
            })
            .collect();
        let mut h = mix(salt ^ 0xF06);
        let mut x = fx + 7.0;
        while x < 99.0 {
            let mut y = 4.0 + (unit(h) + 1.0) * 4.0;
            while y < 100.0 {
                h = mix(h);
                spots.push((x + unit(h) * 2.5, y, 0.8 + (unit(mix(h)) + 1.0) * 0.35));
                y += 14.0 + (unit(mix(h ^ 3)) + 1.0) * 4.0;
            }
            x += 8.5;
        }
        let puffs = spots
            .into_iter()
            .enumerate()
            .map(|(i, (x, y, s))| {
                standing(
                    x,
                    y,
                    "puff",
                    view! {
                        <img
                            src="assets/karte/nebelballen.png"
                            alt=""
                            style=format!(
                                "width:{:.0}px;height:{:.0}px;animation-delay:-{}s",
                                104.0 * s,
                                40.0 * s,
                                i * 7 % 5,
                            )
                        />
                    }
                    .into_any(),
                )
            })
            .collect_view();
        view! {
            <div class="fogwar" style=format!("left:{left:.2}%;clip-path:{clip}")></div>
            {puffs}
        }
    });

    let legend = [
        NodeKind::Fight,
        NodeKind::Elite,
        NodeKind::Event,
        NodeKind::Rest,
        NodeKind::Shop,
        NodeKind::Boss,
    ]
    .into_iter()
    .map(|k| {
        view! {
            <span>
                <img src=format!("assets/karte/symbol_{}.png", kind_file(k)) alt="" />
                {kind_name(k)}
            </span>
        }
    })
    .collect_view();

    view! {
        <div class=format!("world w-{rid}")>
            <div class="reg">
                {region.name.clone()}
                <small>
                    {format!("{} · Gebiet {} von {}", region.subtitle, run.region + 1, d.regions.len())}
                </small>
            </div>
            <div
                class="plane"
                style=format!(
                    "background-image:url(assets/karte/boden_{rid}.png);width:{SPAN}%;left:{cam:.2}%",
                )
            >
                <svg class="trails" viewBox="0 0 100 100" preserveAspectRatio="none">{paths}</svg>
                {nodes}
                {decor}
                {hero_view}
                {fog}
            </div>
            <div class="legend">{legend}</div>
        </div>
    }
    .into_any()
}
