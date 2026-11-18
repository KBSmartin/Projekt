//! Region map generation (prototype `genMap`).

use crate::rng::GameRng;

/// Rows of regular nodes; the boss sits in an extra row above.
pub const MAP_ROWS: usize = 8;
pub const MAP_COLS: usize = 5;
/// Lanes of the three start points left of the first row.
pub const START_LANES: [usize; 3] = [0, 2, 4];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NodeKind {
    Fight,
    Elite,
    Event,
    Shop,
    Rest,
    Boss,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MapNode {
    pub id: usize,
    pub row: usize,
    pub col: usize,
    pub kind: NodeKind,
    /// Ids of the nodes in the next row this node leads to.
    pub next: Vec<usize>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Map {
    pub nodes: Vec<MapNode>,
    /// Node ids per row, `MAP_ROWS` regular rows plus the boss row.
    pub rows: Vec<Vec<usize>>,
    /// For each start point (see [`START_LANES`]) the first-row nodes it leads to.
    pub starts: Vec<Vec<usize>>,
}

impl Map {
    pub fn generate(rng: &mut GameRng) -> Self {
        let mut nodes: Vec<MapNode> = Vec::new();
        let mut rows: Vec<Vec<usize>> = Vec::new();
        for r in 0..MAP_ROWS {
            // Fix: the prototype placed 3-4 nodes per row (2-3 in the last);
            // the board map reads better with 2-3 (2 in the last row).
            // Three in the first row, one for each start point to aim at.
            let k = if r == 0 {
                3
            } else if r == MAP_ROWS - 1 {
                2
            } else {
                rng.range(2, 3) as usize
            };
            let mut cols: Vec<usize> = (0..MAP_COLS).collect();
            rng.shuffle(&mut cols);
            cols.truncate(k);
            cols.sort_unstable();
            let ids = cols
                .into_iter()
                .map(|col| {
                    let id = nodes.len();
                    nodes.push(MapNode {
                        id,
                        row: r,
                        col,
                        kind: NodeKind::Fight,
                        next: Vec::new(),
                    });
                    id
                })
                .collect();
            rows.push(ids);
        }
        let boss = nodes.len();
        nodes.push(MapNode {
            id: boss,
            row: MAP_ROWS,
            col: MAP_COLS / 2,
            kind: NodeKind::Boss,
            next: Vec::new(),
        });
        rows.push(vec![boss]);

        // Connections: each node links to up to two close nodes in the next
        // row, and every node in the next row gets at least one incoming link.
        let dist = |a: usize, b: usize| a.abs_diff(b);
        for r in 0..MAP_ROWS {
            let (a_ids, b_ids) = (rows[r].clone(), rows[r + 1].clone());
            for &a in &a_ids {
                let ac = nodes[a].col;
                let mut targets: Vec<usize> = b_ids
                    .iter()
                    .copied()
                    .filter(|&b| dist(nodes[b].col, ac) <= 1)
                    .collect();
                if targets.is_empty() {
                    let m = b_ids
                        .iter()
                        .map(|&b| dist(nodes[b].col, ac))
                        .min()
                        .unwrap_or(0);
                    targets = b_ids
                        .iter()
                        .copied()
                        .filter(|&b| dist(nodes[b].col, ac) == m)
                        .collect();
                }
                rng.shuffle(&mut targets);
                targets.truncate(2);
                nodes[a].next = targets;
            }
            for &b in &b_ids {
                if !a_ids.iter().any(|&a| nodes[a].next.contains(&b)) {
                    let bc = nodes[b].col;
                    let m = a_ids
                        .iter()
                        .map(|&a| dist(nodes[a].col, bc))
                        .min()
                        .unwrap_or(0);
                    let closest: Vec<usize> = a_ids
                        .iter()
                        .copied()
                        .filter(|&a| dist(nodes[a].col, bc) == m)
                        .collect();
                    if let Some(&a) = rng.pick(&closest) {
                        nodes[a].next.push(b);
                    }
                }
            }
        }

        // Node types by row.
        for n in nodes.iter_mut().filter(|n| n.kind != NodeKind::Boss) {
            n.kind = if n.row == 0 {
                NodeKind::Fight
            } else if n.row == MAP_ROWS - 1 {
                NodeKind::Rest
            } else {
                let early = n.row < 2;
                let weights = [
                    (NodeKind::Fight, 46),
                    (NodeKind::Event, 18),
                    (NodeKind::Shop, if early { 0 } else { 8 }),
                    (
                        NodeKind::Rest,
                        if early || n.row == MAP_ROWS - 2 {
                            0
                        } else {
                            13
                        },
                    ),
                    (NodeKind::Elite, if n.row >= 3 { 14 } else { 0 }),
                ];
                *rng.weighted(&weights).unwrap_or(&NodeKind::Fight)
            };
        }

        let starts = start_links(&nodes, &rows[0]);
        let mut map = Self {
            nodes,
            rows,
            starts,
        };
        map.force(NodeKind::Shop, 2, 5, rng);
        map.force(NodeKind::Elite, 3, 6, rng);
        map.force(NodeKind::Rest, 2, 5, rng);
        map
    }

    /// Makes sure at least one node of `kind` exists in rows `lo..=hi`.
    fn force(&mut self, kind: NodeKind, lo: usize, hi: usize, rng: &mut GameRng) {
        let in_range = |n: &MapNode| (lo..=hi).contains(&n.row);
        if self.nodes.iter().any(|n| n.kind == kind && in_range(n)) {
            return;
        }
        // Fix: the prototype could overwrite a node forced just before
        // (e.g. the only shop). Prefer fights and events.
        let mut candidates: Vec<usize> = self
            .nodes
            .iter()
            .filter(|n| in_range(n) && matches!(n.kind, NodeKind::Fight | NodeKind::Event))
            .map(|n| n.id)
            .collect();
        if candidates.is_empty() {
            candidates = self
                .nodes
                .iter()
                .filter(|n| in_range(n))
                .map(|n| n.id)
                .collect();
        }
        if let Some(&id) = rng.pick(&candidates) {
            self.nodes[id].kind = kind;
        }
    }

    pub fn boss(&self) -> usize {
        self.rows[MAP_ROWS][0]
    }
}

/// Links each start point to the first-row nodes in or next to its lane (or
/// the nearest ones), and makes sure every first-row node can be reached.
fn start_links(nodes: &[MapNode], first: &[usize]) -> Vec<Vec<usize>> {
    let dist = |id: usize, lane: usize| nodes[id].col.abs_diff(lane);
    let mut starts: Vec<Vec<usize>> = START_LANES
        .iter()
        .map(|&lane| {
            let near: Vec<usize> = first
                .iter()
                .copied()
                .filter(|&id| dist(id, lane) <= 1)
                .collect();
            if !near.is_empty() {
                return near;
            }
            let m = first.iter().map(|&id| dist(id, lane)).min().unwrap_or(0);
            first
                .iter()
                .copied()
                .filter(|&id| dist(id, lane) == m)
                .collect()
        })
        .collect();
    for &id in first {
        if !starts.iter().any(|s| s.contains(&id)) {
            let (best, _) = START_LANES
                .iter()
                .enumerate()
                .min_by_key(|&(_, &lane)| dist(id, lane))
                .unwrap_or((0, &0));
            starts[best].push(id);
            starts[best].sort_unstable();
        }
    }
    starts
}
#[cfg(test)]
mod tests {
    use super::*;

    fn maps() -> impl Iterator<Item = Map> {
        (0..300).map(|seed| Map::generate(&mut GameRng::new(seed)))
    }

    #[test]
    fn same_seed_same_map() {
        assert_eq!(
            Map::generate(&mut GameRng::new(5)),
            Map::generate(&mut GameRng::new(5))
        );
    }

    #[test]
    fn every_node_is_reachable_and_leads_on() {
        for map in maps() {
            for r in 0..MAP_ROWS {
                for &id in &map.rows[r] {
                    let n = &map.nodes[id];
                    assert!(!n.next.is_empty(), "dead end at node {id}");
                    let mut unique = n.next.clone();
                    unique.sort_unstable();
                    unique.dedup();
                    assert_eq!(unique.len(), n.next.len(), "duplicate link at node {id}");
                    assert!(n.next.iter().all(|&b| map.nodes[b].row == r + 1));
                }
                for &b in &map.rows[r + 1] {
                    assert!(map.rows[r].iter().any(|&a| map.nodes[a].next.contains(&b)));
                }
            }
            assert_eq!(map.nodes[map.boss()].kind, NodeKind::Boss);
        }
    }

    #[test]
    fn every_start_leads_on_and_reaches_the_first_row() {
        for map in maps() {
            assert_eq!(map.starts.len(), START_LANES.len());
            for s in &map.starts {
                assert!(!s.is_empty());
                assert!(s.iter().all(|id| map.rows[0].contains(id)));
            }
            for id in &map.rows[0] {
                assert!(
                    map.starts.iter().any(|s| s.contains(id)),
                    "node {id} unreachable"
                );
            }
        }
    }

    #[test]
    fn rows_stay_small() {
        for map in maps() {
            for (r, row) in map.rows.iter().take(MAP_ROWS).enumerate() {
                let n = row.len();
                assert!((2..=3).contains(&n), "row {r} has {n} nodes");
            }
            assert_eq!(map.rows[0].len(), 3);
            assert_eq!(map.rows[MAP_ROWS - 1].len(), 2);
        }
    }

    #[test]
    fn row_rules_hold() {
        for map in maps() {
            for n in &map.nodes {
                match n.row {
                    0 => assert_eq!(n.kind, NodeKind::Fight),
                    r if r == MAP_ROWS - 1 => assert_eq!(n.kind, NodeKind::Rest),
                    r if r == MAP_ROWS => assert_eq!(n.kind, NodeKind::Boss),
                    1 => assert!(matches!(n.kind, NodeKind::Fight | NodeKind::Event)),
                    2 => assert_ne!(n.kind, NodeKind::Elite),
                    _ => {}
                }
            }
            let has = |kind, lo, hi| {
                map.nodes
                    .iter()
                    .any(|n| n.kind == kind && (lo..=hi).contains(&n.row))
            };
            assert!(has(NodeKind::Shop, 2, 5));
            assert!(has(NodeKind::Elite, 3, 6));
            assert!(has(NodeKind::Rest, 2, 5));
        }
    }
}
