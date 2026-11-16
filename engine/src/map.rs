//! Region map generation (prototype `genMap`).

use crate::rng::GameRng;

/// Rows of regular nodes; the boss sits in an extra row above.
pub const MAP_ROWS: usize = 8;
pub const MAP_COLS: usize = 5;

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
}

impl Map {
    pub fn generate(rng: &mut GameRng) -> Self {
        let mut nodes: Vec<MapNode> = Vec::new();
        let mut rows: Vec<Vec<usize>> = Vec::new();
        for r in 0..MAP_ROWS {
            let k = if r == MAP_ROWS - 1 {
                rng.range(2, 3)
            } else {
                rng.range(3, 4)
            } as usize;
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

        let mut map = Self { nodes, rows };
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
