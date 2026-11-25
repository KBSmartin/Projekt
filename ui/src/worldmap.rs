//! The 2.5D world map: a ground plane tilted away in CSS 3D, with upright pixel
//! sprites standing on it (node signs, decoration, the hero figure). Fog covers
//! everything more than two steps ahead, so a route can't be planned through
//! the whole region in advance. Positions are percentages of the plane.

use crate::{Game, data};
use engine::{MAP_COLS, MAP_ROWS, MapNode, NodeKind, Run, START_LANES};
use leptos::prelude::*;

/// How many rows beyond the current one are visible.
const SIGHT: i32 = 2;
/// Width of the plane in percent of the view; the camera follows the hero.
const SPAN: f64 = 320.0;
/// Where the hero stands, in percent of the window width.
const HERO_AT: f64 = 32.0;
/// Right edge of the side panel in pixels; the panel turns see-through when
/// the board reaches under it.
const HUD_EDGE: f64 = 192.0;
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

/// Board edges per region: tall sprites along the far edge (a wood, a ridge of
/// rocks), low ones along the near edge so they never hide a field.
fn edges(region: &str) -> (&'static [Sprite], &'static [Sprite]) {
    match region {
        "desert" => (&[FELS, KAKTUS, FELS, TOTBAUM], &[STEIN, KNOCHEN]),
        "fortress" => (
            &[SCHNEETANNE, SCHNEETANNE, SCHNEEFELS],
            &[SCHNEEFELS, STEIN, EIS],
        ),
        _ => (&[TANNE, TANNE, BAUM, TANNE, BIRKE], &[BUSCH, STEIN, BUSCH]),
    }
}

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
const XS: f64 = 3.8;

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

    // Before a start point is chosen only the start points can be clicked.
    let choosing = run.current.is_none() && run.start.is_none();
    let available = if choosing {
        Vec::new()
    } else {
        run.available_nodes()
    };
    // The three start points left of the first row, one per lane.
    let start_pos = |i: usize| {
        let lane = START_LANES[i];
        (START.0, 24.0 + lane as f64 * 68.0 / (MAP_COLS - 1) as f64)
    };
    let starts: Vec<Pt> = (0..START_LANES.len()).map(start_pos).collect();
    let here = match (run.current, run.start) {
        (Some(id), _) => pos(id),
        (None, Some(s)) => start_pos(s),
        (None, None) => START,
    };
    // Camera: the hero stands about a fifth into the view, without leaving the plane.
    // The board spans the whole window under the side panel; the hero stands
    // about a third in, right of the panel.
    let cam = (HERO_AT - here.0 * SPAN / 100.0).clamp(98.0 - SPAN, 20.0);

    // --- Paths: every link out of a visible node (links into the fog vanish in it).
    let mut links: Vec<(Pt, Pt, &'static str)> = Vec::new();
    for (i, s) in map.starts.iter().enumerate() {
        for &b in s {
            let class = if run.start == Some(i) {
                if run.current.is_none() {
                    "open"
                } else if run.visited.first() == Some(&b) {
                    "done"
                } else {
                    "plain"
                }
            } else if run.start.is_none() {
                "open"
            } else {
                "plain"
            };
            links.push((start_pos(i), pos(b), class));
        }
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
        .chain(
            map.starts
                .iter()
                .enumerate()
                .flat_map(|(i, s)| s.iter().map(move |&b| (i, b)))
                .map(|(i, b)| (start_pos(i), pos(b))),
        )
        .collect();
    let free = |x: f64, y: f64, room: f64| {
        (2.0..=98.0).contains(&x)
            && (1.0..=99.0).contains(&y)
            && !fog_x.is_some_and(|f| x > f - 2.0)
            && map
                .nodes
                .iter()
                .map(|n| pos(n.id))
                .chain(starts.iter().copied())
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
    for _ in 0..160 {
        if centres.len() >= 13 {
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
                .any(|c| ((c.0 - cx) * XS).hypot(c.1 - cy) < 19.0)
        {
            continue;
        }
        // Themes take turns, so neighbouring scenes differ.
        let theme = &set[(first + centres.len()) % set.len()];
        centres.push((cx, cy));
        if let Some(flat) = theme.flat {
            flats.push((cx, cy, flat));
        }
        let count = 3 + (mix(h ^ 3) % 4) as usize;
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
    // A wood (or ridge) along the far edge of the board, low growth along the
    // near edge; both stop at the fog.
    let (far, near) = edges(&rid);
    let mut x = 1.5;
    while x < 98.5 {
        h = mix(h);
        for (band, pool, y0) in [(0u64, far, 3.0), (1, near, 96.5)] {
            let hb = mix(h ^ band);
            let (xx, yy) = (x + unit(hb) * 0.6, y0 + unit(mix(hb)) * 1.6);
            if (band == 1 && hb.is_multiple_of(3)) || !free(xx, yy, -3.0) {
                continue;
            }
            uprights.push((xx, yy, pool[(mix(hb ^ 9) % pool.len() as u64) as usize]));
            // A second row on the far edge makes it read as a wood.
            if band == 0 && hb.is_multiple_of(2) && free(xx + 0.7, yy + 3.5, -3.0) {
                uprights.push((
                    xx + 0.7,
                    yy + 3.5,
                    pool[(mix(hb ^ 13) % pool.len() as u64) as usize],
                ));
            }
        }
        x += 1.5;
    }
    // Draw back to front, so nearer sprites cover farther ones.
    uprights.sort_by(|a, b| a.1.total_cmp(&b.1));
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

    // --- Start points: numbered fields left of the first row. Before the first
    // choice they are the only thing to click.
    let start_spots = starts
        .iter()
        .enumerate()
        .map(|(i, &(x, y))| {
            let state = if choosing {
                " av"
            } else if run.start == Some(i) {
                " cur"
            } else {
                " vis"
            };
            let label = format!("Startpunkt {}", i + 1);
            view! {
                <button
                    class=format!("spot k-start{state}")
                    style=format!("left:{x:.2}%;top:{y:.2}%")
                    title=label.clone()
                    aria-label=label
                    disabled=!choosing
                    on:click=move |_| {
                        if !game.map_dragged.get_untracked() {
                            game.place_start(i);
                        }
                    }
                >
                    <b>{i + 1}</b>
                </button>
            }
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
                        if walking.get_untracked().is_none() && !game.map_dragged.get_untracked() {
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
    let hero_view = (!choosing).then(|| {
        view! {
            <div
                class="bb hero"
                class:walk=move || walking.get().is_some()
                class:placing=move || game.placing.get()
                style:left=move || format!("{:.2}%", hero_at().0)
                style:top=move || format!("{:.2}%", hero_at2().1 + 1.5)
            >
                <img class="piece" src=format!("assets/karte/figur_{hero}.png") alt="" />
                <div class="hand">
                    <img src="assets/karte/hand.png" alt="" />
                </div>
            </div>
        }
    });

    // --- Fog: a flat layer on the board with a soft edge towards the open part.
    let fog = fog_x.map(|fx| {
        let left = fx - 2.0;
        view! {
            <div class="fogwar" style=format!("left:{left:.2}%")></div>
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

    // --- Panning: drag with the mouse (sideways always, up and down when
    // zoomed in); the wheel zooms. A move recentres sideways.
    let pan = game.map_pan;
    let pan_y = game.map_pan_y;
    let zoom = game.map_zoom;
    let dragged = game.map_dragged;
    let drag = StoredValue::new(None::<(f64, f64, f64, f64)>);
    let dragging = RwSignal::new(false);
    let view_w = || {
        window()
            .inner_width()
            .ok()
            .and_then(|w| w.as_f64())
            .unwrap_or(1280.0)
    };
    let clamp_pan = move |p: f64| p.clamp(98.0 - SPAN - cam, 20.0 - cam);
    // Zoomed in, the board may move up or down by as much as it grew.
    let clamp_y = move |y: f64, z: f64| {
        let room = (z - 1.0).max(0.0) * 420.0;
        y.clamp(-room * 0.4, room)
    };
    let on_down = move |e: leptos::ev::PointerEvent| {
        if e.button() == 0 {
            drag.set_value(Some((
                e.client_x() as f64,
                e.client_y() as f64,
                pan.get_untracked(),
                pan_y.get_untracked(),
            )));
            dragged.set(false);
        }
    };
    let on_move = move |e: leptos::ev::PointerEvent| {
        if let Some((x0, y0, p0, q0)) = drag.get_value() {
            let (dx, dy) = (e.client_x() as f64 - x0, e.client_y() as f64 - y0);
            if dx.hypot(dy) > 5.0 {
                dragged.set(true);
            }
            if dragged.get_untracked() {
                dragging.set(true);
                let z = zoom.get_untracked();
                pan.set(clamp_pan(p0 + dx / view_w() * 100.0 / z));
                pan_y.set(clamp_y(q0 + dy, z));
            }
        }
    };
    let on_up = move |_| {
        drag.set_value(None);
        dragging.set(false);
    };
    let on_wheel = move |e: leptos::ev::WheelEvent| {
        e.prevent_default();
        let d = e.delta_y();
        zoom.update(|z| *z = (*z * (1.0 - d * 0.0012)).clamp(0.7, 1.8));
        let z = zoom.get_untracked();
        pan_y.update(|y| *y = clamp_y(*y, z));
    };

    // Whether the board reaches under the side panel: measured on screen
    // (perspective makes the near edge wider), a moment after each move.
    let under_hud = RwSignal::new(false);
    let plane_ref = NodeRef::<leptos::html::Div>::new();
    Effect::new(move |_| {
        pan.track();
        zoom.track();
        pan_y.track();
        set_timeout(
            move || {
                // The map may be gone by now (left within the delay).
                if let Some(el) = plane_ref.try_get_untracked().flatten() {
                    under_hud.try_set(el.get_bounding_client_rect().left() < HUD_EDGE);
                }
            },
            std::time::Duration::from_millis(320),
        );
    });

    view! {
        <div
            class=format!("world w-{rid}")
            class:dragging=move || dragging.get()
            class:under-hud=move || under_hud.get()
            on:pointerdown=on_down
            on:pointermove=on_move
            on:pointerup=on_up
            on:pointerleave=on_up
            on:wheel=on_wheel
        >
            <div class="reg">
                {region.name.clone()}
                <small>
                    {format!("{} · Gebiet {} von {}", region.subtitle, run.region + 1, d.regions.len())}
                </small>
            </div>
            <div
                class="zoom"
                style:transform=move || format!("translateY({:.0}px) scale({:.3})", pan_y.get(), zoom.get())
            >
            <div
                class="plane"
                node_ref=plane_ref
                style=format!("background-image:url(assets/karte/boden_{rid}.png);width:{SPAN}%")
                style:left=move || format!("{:.2}%", cam + pan.get())
            >
                <i class="bside l"></i>
                <i class="bside r"></i>
                {flats}
                <svg class="trails" viewBox="0 0 100 100" preserveAspectRatio="none">{paths}</svg>
                {start_spots}
                {nodes}
                {decor}
                {hero_view}
                {fog}
            </div>
            </div>
            <div class="legendbox">
                <button
                    class="btn sm ghost"
                    aria-expanded=move || game.legend_open.get().to_string()
                    on:click=move |_| game.legend_open.update(|o| *o = !*o)
                >
                    {move || if game.legend_open.get() { "Legende ▴" } else { "Legende ▾" }}
                </button>
                <div class="legend" class:open=move || game.legend_open.get()>{legend}</div>
            </div>
        </div>
    }
    .into_any()
}
