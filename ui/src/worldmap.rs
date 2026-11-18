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

/// A decoration sprite: file name (`deko_<name>` or `flach_<name>`), size in art pixels.
type Sprite = (&'static str, u32, u32);

/// A small scene for one spot of the board: an optional flat piece lying on the
/// ground (pond, flowers, ...) with upright sprites around it.
struct Theme {
    flat: Option<Sprite>,
    main: &'static [Sprite],
    extra: &'static [Sprite],
}

const TANNE: Sprite = ("tanne", 11, 13);
const BAUM: Sprite = ("baum", 12, 12);
const BIRKE: Sprite = ("birke", 11, 12);
const BUSCH: Sprite = ("busch", 10, 6);
const STEIN: Sprite = ("stein", 9, 6);
const PILZ: Sprite = ("pilz", 7, 6);
const STUMPF: Sprite = ("stumpf", 9, 7);
const KAKTUS: Sprite = ("kaktus", 10, 11);
const FELS: Sprite = ("fels", 12, 7);
const TOTBAUM: Sprite = ("totbaum", 10, 9);
const KNOCHEN: Sprite = ("knochen", 10, 5);
const PALME: Sprite = ("palme", 14, 12);
const SAEULE: Sprite = ("saeule", 8, 12);
const SCHAEDEL: Sprite = ("schaedel", 12, 8);
const SCHNEETANNE: Sprite = ("schneetanne", 11, 13);
const EIS: Sprite = ("eis", 10, 8);
const SCHNEEFELS: Sprite = ("schneefels", 12, 7);
const EISZAPFEN: Sprite = ("eiszapfen", 10, 8);
const BANNER: Sprite = ("banner", 8, 12);
const MAUER: Sprite = ("mauer", 14, 8);

fn themes(region: &str) -> &'static [Theme] {
    match region {
        "desert" => &[
            Theme {
                flat: Some(("oase", 20, 9)),
                main: &[PALME, PALME],
                extra: &[KAKTUS, STEIN],
            },
            Theme {
                flat: None,
                main: &[KAKTUS, KAKTUS],
                extra: &[STEIN, KNOCHEN],
            },
            Theme {
                flat: None,
                main: &[SAEULE, SAEULE],
                extra: &[FELS, STEIN],
            },
            Theme {
                flat: Some(("knochenfeld", 14, 6)),
                main: &[SCHAEDEL],
                extra: &[KNOCHEN, TOTBAUM],
            },
            Theme {
                flat: None,
                main: &[FELS],
                extra: &[STEIN, TOTBAUM],
            },
        ],
        "fortress" => &[
            Theme {
                flat: None,
                main: &[SCHNEETANNE, SCHNEETANNE],
                extra: &[SCHNEEFELS, STEIN],
            },
            Theme {
                flat: Some(("eissee", 24, 10)),
                main: &[EISZAPFEN],
                extra: &[EIS],
            },
            Theme {
                flat: None,
                main: &[MAUER, BANNER],
                extra: &[SCHNEEFELS, STEIN],
            },
            Theme {
                flat: Some(("verwehung", 14, 6)),
                main: &[EIS],
                extra: &[SCHNEETANNE],
            },
        ],
        _ => &[
            Theme {
                flat: None,
                main: &[TANNE, TANNE, BAUM],
                extra: &[BUSCH, STUMPF, PILZ],
            },
            Theme {
                flat: Some(("teich", 22, 10)),
                main: &[BUSCH],
                extra: &[STEIN, BIRKE],
            },
            Theme {
                flat: None,
                main: &[BIRKE, BIRKE, BAUM],
                extra: &[BUSCH, PILZ],
            },
            Theme {
                flat: Some(("blumen", 12, 6)),
                main: &[STUMPF],
                extra: &[PILZ, STEIN],
            },
            Theme {
                flat: None,
                main: &[STEIN],
                extra: &[BUSCH, TANNE],
            },
        ],
    }
}

/// Plane percentages are stretched (the plane is much wider than deep); this
/// scales x so distances are roughly even on screen.
const XS: f64 = 3.0;

/// Distance from point p to the segment a-b, in the evened-out scale.
fn seg_dist(p: Pt, a: Pt, b: Pt) -> f64 {
    let (p, a, b) = ((p.0 * XS, p.1), (a.0 * XS, a.1), (b.0 * XS, b.1));
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

    // --- Decoration: a few small scenes (grove, pond, ruins, ...) with open
    // ground between them, kept away from fields and paths and out of the fog.
    let all_links: Vec<(Pt, Pt)> = map
        .nodes
        .iter()
        .flat_map(|n| n.next.iter().map(move |&b| (n.id, b)))
        .map(|(a, b)| (pos(a), pos(b)))
        .chain(map.rows[0].iter().map(|&b| (START, pos(b))))
        .collect();
    let free = |x: f64, y: f64, room: f64| {
        (2.0..=98.0).contains(&x)
            && (4.0..=96.0).contains(&y)
            && !fog_x.is_some_and(|f| x > f - 2.0)
            && map
                .nodes
                .iter()
                .map(|n| pos(n.id))
                .chain(std::iter::once(START))
                .all(|p| ((p.0 - x) * XS).hypot(p.1 - y) > 9.0 + room)
            && all_links
                .iter()
                .all(|&(a, b)| seg_dist((x, y), a, b) > 3.5 + room)
    };
    let set = themes(&rid);
    let mut flats: Vec<(f64, f64, Sprite)> = Vec::new();
    let mut uprights: Vec<(f64, f64, Sprite)> = Vec::new();
    let mut centres: Vec<Pt> = Vec::new();
    let mut h = mix(salt ^ 0xDEC0);
    let first = (h % set.len() as u64) as usize;
    for _ in 0..90 {
        if centres.len() >= 9 {
            break;
        }
        h = mix(h);
        let (cx, cy) = (
            2.0 + (unit(h) + 1.0) * 48.0,
            6.0 + (unit(mix(h ^ 7)) + 1.0) * 45.0,
        );
        if !free(cx, cy, 2.5)
            || centres
                .iter()
                .any(|c| ((c.0 - cx) * XS).hypot(c.1 - cy) < 22.0)
        {
            continue;
        }
        // Themes take turns, so neighbouring scenes differ.
        let theme = &set[(first + centres.len()) % set.len()];
        centres.push((cx, cy));
        if let Some(flat) = theme.flat {
            flats.push((cx, cy, flat));
        }
        let count = 2 + (mix(h ^ 3) % 4) as usize;
        for k in 0..count {
            let hk = mix(h ^ (k as u64 + 11));
            let angle = unit(hk) * std::f64::consts::PI;
            let r = if theme.flat.is_some() { 6.5 } else { 2.0 } + (unit(mix(hk)) + 1.0) * 2.5;
            let (x, y) = (cx + angle.cos() * r / XS, cy + angle.sin() * r);
            if !free(x, y, 0.0)
                || uprights
                    .iter()
                    .any(|u| ((u.0 - x) * XS).hypot(u.1 - y) < 3.0)
            {
                continue;
            }
            let pool = if k < theme.main.len() {
                theme.main
            } else {
                theme.extra
            };
            if pool.is_empty() {
                continue;
            }
            uprights.push((x, y, pool[(mix(hk ^ 5) % pool.len() as u64) as usize]));
        }
    }
    let flats = flats
        .into_iter()
        .map(|(x, y, (name, w, ht))| {
            view! {
                <img
                    class="flat"
                    src=format!("assets/karte/flach_{name}.png")
                    alt=""
                    style=format!("left:{x:.2}%;top:{y:.2}%;width:{}px;height:{}px", w * 4, ht * 4)
                />
            }
        })
        .collect_view();
    let decor = uprights
        .into_iter()
        .map(|(x, y, (name, w, ht))| {
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

    // --- Nodes: round fields painted on the board, the icon on top.
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
            let name = kind_name(n.kind);
            let file = kind_file(n.kind);
            view! {
                <button
                    class=format!("spot k-{file}{state}")
                    style=format!("left:{x:.2}%;top:{y:.2}%")
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
            }
        })
        .collect_view();

    // --- Hero piece: stands on the current field, is lifted and set onto the chosen one.
    let hero = crate::views::hero_file(&run.character);
    let targets: Vec<(usize, Pt)> = available.iter().map(|&id| (id, pos(id))).collect();
    let hero_at = move || {
        walking
            .get()
            .and_then(|id| targets.iter().find(|t| t.0 == id).map(|t| t.1))
            .unwrap_or(here)
    };
    let hero_at2 = hero_at.clone();
    let hero_view = view! {
        <div
            class="bb hero"
            class:walk=move || walking.get().is_some()
            style:left=move || format!("{:.2}%", hero_at().0)
            style:top=move || format!("{:.2}%", hero_at2().1 + 1.5)
        >
            <img class="piece" src=format!("assets/karte/figur_{hero}.png") alt="" />
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
                y += 18.0 + (unit(mix(h ^ 3)) + 1.0) * 5.0;
            }
            x += 11.0;
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
                {flats}
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
