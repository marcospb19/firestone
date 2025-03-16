#![feature(array_windows)]
#![allow(irrefutable_let_patterns)]

use petgraph::{
    acyclic::Acyclic,
    data::Build,
    prelude::{Directed, Direction::Outgoing, GraphMap},
};
use std::{array, collections::HashMap};
use strum::EnumIs;

#[derive(Default)]
pub struct Simulation {
    components: HashMap<usize, Component>,
    supergraph: GraphMap<usize, SupergraphEdgeKind, Directed>,
    subgraph: Acyclic<GraphMap<usize, (), Directed>>,
    inputs: HashMap<usize, State>, // state
    id_gen: usize,
    version_gen: u64,
}

#[derive(Clone, Copy)]
struct State {
    value: bool,
    version: u64,
}

impl State {
    fn new(value: bool) -> Self {
        Self { value, version: 0 }
    }

    fn versioned(value: bool, version: u64) -> State {
        Self { value, version }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, EnumIs)]
enum SupergraphEdgeKind {
    EntersSupergraph,
    Internal,
    ExitsSupergraph,
}

impl Simulation {
    pub fn add(&mut self, kind: ComponentKind) -> usize {
        let id = self.id_gen;
        self.id_gen += 1;
        self.components.insert(id, Component::from(kind));

        self.supergraph.add_node(id);
        if !kind.is_delay() {
            self.subgraph.add_node(id);
        }

        self.inputs.insert(id, State::new(false));
        id
    }

    pub fn add_array<const N: usize>(&mut self, array: [ComponentKind; N]) -> [usize; N] {
        array.map(|component| self.add(component))
    }

    pub fn add_array_of<const N: usize>(&mut self, component: ComponentKind) -> [usize; N] {
        array::from_fn(|_| self.add(component))
    }

    pub fn add_array_wired<const N: usize>(&mut self, array: [ComponentKind; N]) -> [usize; N] {
        let components = self.add_array(array);
        for &[parent, child] in components.array_windows::<2>() {
            self.wire(parent, child);
        }
        components
    }

    pub fn add_array_wired_of<const N: usize>(&mut self, component: ComponentKind) -> [usize; N] {
        let components = self.add_array_of(component);
        for &[parent, child] in components.array_windows::<2>() {
            self.wire(parent, child);
        }
        components
    }

    pub fn add_array_wired_loop<const N: usize>(
        &mut self,
        array: [ComponentKind; N],
    ) -> [usize; N] {
        let components = self.add_array_wired(array);
        if let Some((&first, &last)) = components.first().zip(components.last()) {
            self.wire(last, first); // close the loop
        }
        components
    }

    pub fn add_array_wired_loop_of<const N: usize>(
        &mut self,
        component: ComponentKind,
    ) -> [usize; N] {
        let components = self.add_array_wired_of(component);
        if let Some((&first, &last)) = components.first().zip(components.last()) {
            self.wire(last, first); // close the loop
        }
        components
    }

    pub fn wire(&mut self, parent: usize, child: usize) {
        let parent_component = self.components.get(&parent).expect("unexpected parent");
        let child_component = self.components.get(&child).expect("unexpected parent");

        let edge_kind = match (parent_component.is_delay(), child_component.is_delay()) {
            (false, true) => Some(SupergraphEdgeKind::EntersSupergraph),
            (true, true) => Some(SupergraphEdgeKind::Internal),
            (true, false) => Some(SupergraphEdgeKind::ExitsSupergraph),
            (false, false) => None,
        };

        if let Some(edge_kind) = edge_kind {
            self.supergraph.add_edge(parent, child, edge_kind);
        } else {
            self.subgraph
                .try_add_edge(parent, child, ())
                .expect("found cycle");
        }

        *self
            .components
            .get_mut(&child)
            .expect("unexpected parent")
            .parent_mut() = Some(parent);
    }

    pub fn run_step(&mut self) {
        self.version_gen += 1;
        let version = self.version_gen;

        // tick all delays, and for all edge starting from a delay, set child input
        if let edits = self
            .supergraph
            .all_edges()
            .filter(|(_, _, edge_kind)| !edge_kind.is_enters_supergraph())
            .map(|(parent, child, _)| (child, self.inputs[&parent].value))
            .collect::<Vec<_>>()
        {
            for (child, new_child_value) in edits {
                let previously_set = self
                    .inputs
                    .insert(child, State::versioned(new_child_value, version));
                assert!(previously_set.is_some());
            }
        }

        // for all leaves, eval with recursion
        let leaves = self.subgraph_leaves().collect::<Vec<usize>>();
        for leaf in leaves {
            assert!(!self.components[&leaf].is_delay());
            let value = self.recursive_eval_and_update(leaf, version);

            // update input of all touched delays
            for (_, child, &edge_kind) in self.supergraph.edges_directed(leaf, Outgoing) {
                assert_eq!(edge_kind, SupergraphEdgeKind::EntersSupergraph);
                self.inputs.insert(child, State::versioned(value, version));
            }
        }
    }

    fn recursive_eval_and_update(&mut self, node: usize, version: u64) -> bool {
        let component = self.components[&node];
        let parent = component.parent();

        let updated_input = 'updated_input: {
            let input = self.inputs[&node];

            if input.version == version {
                break 'updated_input input.value;
            }

            let Some(parent) = parent else {
                break 'updated_input false;
            };

            match self.components[&parent].kind() {
                ComponentKind::Not => self.recursive_eval_and_update(parent, version),
                ComponentKind::Delay => unreachable!("checked in `version`"),
            }
        };

        self.inputs
            .insert(node, State::versioned(updated_input, version));

        match component.kind() {
            ComponentKind::Not => !updated_input,
            ComponentKind::Delay => unreachable!(),
        }
    }

    pub fn get_input(&self, id: usize) -> bool {
        self.inputs[&id].value
    }

    fn subgraph_leaves(&self) -> impl Iterator<Item = usize> {
        let is_leaf = |&node: &usize| {
            self.subgraph
                .edges_directed(node, Outgoing)
                .next()
                .is_none()
        };

        self.subgraph.nodes().filter(is_leaf)
    }

    #[cfg(test)]
    pub fn set_input(&mut self, id: usize, value: bool) {
        let previous = self.inputs.insert(id, State::new(value));
        assert!(previous.is_some(), "set_input of unknown {id}");
        assert!(
            previous.is_some_and(|previous| previous.version == 0),
            "messed up version of `set_input`",
        );
    }
}

#[derive(Clone, Copy, EnumIs)]
pub enum Component {
    Not { parent: Option<usize> },
    Delay { parent: Option<usize> },
}

impl Component {
    pub fn parent(self) -> Option<usize> {
        match self {
            Component::Not { parent } | Component::Delay { parent } => parent,
        }
    }

    pub fn parent_mut(&mut self) -> &mut Option<usize> {
        match self {
            Component::Not { parent } | Component::Delay { parent } => parent,
        }
    }

    pub fn kind(self) -> ComponentKind {
        match self {
            Component::Not { .. } => ComponentKind::Not,
            Component::Delay { .. } => ComponentKind::Delay,
        }
    }
}

#[derive(Clone, Copy, EnumIs)]
pub enum ComponentKind {
    Not,
    Delay,
}

impl From<ComponentKind> for Component {
    fn from(kind: ComponentKind) -> Self {
        match kind {
            ComponentKind::Not => Component::Not { parent: None },
            ComponentKind::Delay => Component::Delay { parent: None },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::ComponentKind::*;
    use super::*;

    #[test]
    #[should_panic]
    fn panic_on_trivial_self_cycle() {
        let mut sim = Simulation::default();
        let not = sim.add(Not);
        sim.wire(not, not);
    }

    #[test]
    #[should_panic]
    fn panic_on_short_cycle() {
        let mut sim = Simulation::default();
        let [v, u] = sim.add_array_of(Not);
        sim.wire(v, u);
        sim.wire(u, v);
    }

    #[test]
    fn test_disconnected_components() {
        let mut sim = Simulation::default();
        let components = sim.add_array([Not, Not, Delay, Delay]);
        for _ in 0..100 {
            sim.run_step();
            assert!(components.iter().all(|&id| !sim.get_input(id)));
        }
    }

    #[test]
    fn test_flipping_loop_with_two_delays() {
        let mut sim = Simulation::default();
        let [first, second] = sim.add_array_wired_loop([Delay, Delay]);

        sim.set_input(first, true);

        for i in 0..100 {
            assert_eq!(i % 2 == 0, sim.get_input(first));
            assert_eq!(i % 2 == 1, sim.get_input(second));
            sim.run_step();
        }
    }

    #[test]
    fn test_flipping_loop_with_not_and_delay() {
        let mut sim = Simulation::default();
        let [not, delay] = sim.add_array_wired_loop([Not, Delay]);

        assert!(!sim.get_input(not));
        assert!(!sim.get_input(delay));
        for i in 0..100 {
            sim.run_step();
            assert_eq!(i % 2 == 0, sim.get_input(delay), "at {i}");
            assert_eq!(i % 2 == 1, sim.get_input(not), "at {i}");
        }
    }

    #[test]
    fn test_loop_with_three_delays() {
        let mut sim = Simulation::default();
        let [delay_1, delay_2, delay_3] = sim.add_array_wired_loop_of(Delay);
        sim.set_input(delay_1, true);

        for _ in 0..100 {
            sim.run_step();
            assert!(!sim.get_input(delay_1));
            assert!(sim.get_input(delay_2));
            assert!(!sim.get_input(delay_3));

            sim.run_step();
            assert!(!sim.get_input(delay_1));
            assert!(!sim.get_input(delay_2));
            assert!(sim.get_input(delay_3));

            sim.run_step();
            assert!(sim.get_input(delay_1));
            assert!(!sim.get_input(delay_2));
            assert!(!sim.get_input(delay_3));
        }
    }

    #[test]
    fn test_loop_circuit_with_consecutive_nots_and_delays() {
        let mut sim = Simulation::default();
        let [not_1, not_2, not_3, delay_1, delay_2] =
            sim.add_array_wired_loop([Not, Not, Not, Delay, Delay]);

        for _ in 0..100 {
            sim.run_step();
            assert!(!sim.get_input(not_1));
            assert!(sim.get_input(not_2));
            assert!(!sim.get_input(not_3));
            assert!(sim.get_input(delay_1));
            assert!(!sim.get_input(delay_2));

            sim.run_step();
            assert!(!sim.get_input(not_1));
            assert!(sim.get_input(not_2));
            assert!(!sim.get_input(not_3));
            assert!(sim.get_input(delay_1));
            assert!(sim.get_input(delay_2));

            sim.run_step();
            assert!(sim.get_input(not_1));
            assert!(!sim.get_input(not_2));
            assert!(sim.get_input(not_3));
            assert!(!sim.get_input(delay_1));
            assert!(sim.get_input(delay_2));

            sim.run_step();
            assert!(sim.get_input(not_1));
            assert!(!sim.get_input(not_2));
            assert!(sim.get_input(not_3));
            assert!(!sim.get_input(delay_1));
            assert!(!sim.get_input(delay_2));
        }
    }

    #[test]
    fn test_loop_circuit_with_consecutive_nots_and_delays_stable() {
        let mut sim = Simulation::default();
        let [not_1, not_2, not_3, not_4, delay_1, delay_2] =
            sim.add_array_wired_loop([Not, Not, Not, Not, Delay, Delay]);

        for _ in 0..100 {
            sim.run_step();
            assert!(!sim.get_input(not_1));
            assert!(sim.get_input(not_2));
            assert!(!sim.get_input(not_3));
            assert!(sim.get_input(not_4));
            assert!(!sim.get_input(delay_1));
            assert!(!sim.get_input(delay_2));
        }
    }
}
