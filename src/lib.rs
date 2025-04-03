#![feature(array_windows)]
#![allow(irrefutable_let_patterns)]

mod id;

use id::{Id, IdGenerator};
use petgraph::{
    acyclic::Acyclic,
    data::Build,
    prelude::{Directed, Direction::Outgoing, GraphMap},
};
use std::{array, collections::HashMap};
use strum::EnumIs;

#[derive(Default)]
pub struct Simulation {
    components: HashMap<Id, Component>,
    tickful_graph: GraphMap<Id, SupergraphEdgeKind, Directed>,
    tickless_graph: Acyclic<GraphMap<Id, (), Directed>>,
    id_gen: IdGenerator,
    eval_version: u64,
}

#[derive(Default, Clone, Copy)]
struct State {
    value: bool,
    version: u64,
}

impl State {
    fn new(value: bool, version: u64) -> State {
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
    pub fn add(&mut self, kind: ComponentKind) -> Id {
        let id = self.id_gen.next_id();

        self.components.insert(id, Component::new(kind));
        self.tickful_graph.add_node(id);
        if !kind.is_delay() {
            self.tickless_graph.add_node(id);
        }
        id
    }

    pub fn add_array<const N: usize>(&mut self, array: [ComponentKind; N]) -> [Id; N] {
        array.map(|component| self.add(component))
    }

    pub fn add_array_of<const N: usize>(&mut self, component: ComponentKind) -> [Id; N] {
        array::from_fn(|_| self.add(component))
    }

    pub fn add_array_wired<const N: usize>(&mut self, array: [ComponentKind; N]) -> [Id; N] {
        let components = self.add_array(array);
        for &[parent, child] in components.array_windows::<2>() {
            self.wire(parent, child);
        }
        components
    }

    pub fn add_array_wired_of<const N: usize>(&mut self, component: ComponentKind) -> [Id; N] {
        let components = self.add_array_of(component);
        for &[parent, child] in components.array_windows::<2>() {
            self.wire(parent, child);
        }
        components
    }

    pub fn add_array_wired_loop<const N: usize>(&mut self, array: [ComponentKind; N]) -> [Id; N] {
        let components = self.add_array_wired(array);
        if let Some((&first, &last)) = components.first().zip(components.last()) {
            self.wire(last, first); // close the loop
        }
        components
    }

    pub fn add_array_wired_loop_of<const N: usize>(&mut self, component: ComponentKind) -> [Id; N] {
        let components = self.add_array_wired_of(component);
        if let Some((&first, &last)) = components.first().zip(components.last()) {
            self.wire(last, first); // close the loop
        }
        components
    }

    pub fn wire(&mut self, parent: Id, child: Id) {
        let parent_component = self.components.get(&parent).expect("unexpected parent");
        let child_component = self.components.get(&child).expect("unexpected parent");

        let edge_kind = match (
            parent_component.kind.is_delay(),
            child_component.kind.is_delay(),
        ) {
            (false, true) => Some(SupergraphEdgeKind::EntersSupergraph),
            (true, true) => Some(SupergraphEdgeKind::Internal),
            (true, false) => Some(SupergraphEdgeKind::ExitsSupergraph),
            (false, false) => None,
        };

        if let Some(edge_kind) = edge_kind {
            self.tickful_graph.add_edge(parent, child, edge_kind);
        } else {
            self.tickless_graph
                .try_add_edge(parent, child, ())
                .expect("found cycle");
        }

        self.components
            .get_mut(&child)
            .expect("unexpected parent")
            .parent = Some(parent);
    }

    pub fn run_step(&mut self) {
        self.eval_version += 1;
        let version = self.eval_version;

        // tick all delays, and for all edge starting from a delay, set child input
        if let edits = self
            .tickful_graph
            .all_edges()
            .filter(|(_, _, edge_kind)| !edge_kind.is_enters_supergraph())
            .map(|(parent, child, _)| (child, self.components[&parent].state.value))
            .collect::<Vec<_>>()
        {
            for (child, new_child_value) in edits {
                self.components.get_mut(&child).unwrap().state =
                    State::new(new_child_value, version);
            }
        }

        // for all leaves, eval with recursion
        let leaves = self.subgraph_leaves().collect::<Vec<Id>>();
        for leaf in leaves {
            assert!(!self.components[&leaf].kind.is_delay());
            let value = self.recursive_eval_and_update(leaf, version);

            // update input of all touched delays
            for (_, child, &edge_kind) in self.tickful_graph.edges_directed(leaf, Outgoing) {
                assert_eq!(edge_kind, SupergraphEdgeKind::EntersSupergraph);
                self.components.get_mut(&child).unwrap().state = State::new(value, version);
            }
        }
    }

    fn recursive_eval_and_update(&mut self, node: Id, version: u64) -> bool {
        let component = self.components[&node];

        let updated_input = 'updated_input: {
            let input = self.components[&node].state;

            if input.version == version {
                break 'updated_input input.value;
            }

            let Some(parent) = component.parent else {
                break 'updated_input false;
            };

            match self.components[&parent].kind {
                ComponentKind::Not => self.recursive_eval_and_update(parent, version),
                ComponentKind::Delay => unreachable!("checked in `version`"),
            }
        };

        self.set_state(node, State::new(updated_input, version));

        match component.kind {
            ComponentKind::Not => !updated_input,
            ComponentKind::Delay => unreachable!(),
        }
    }

    fn get_state(&self, id: Id) -> State {
        self.components.get(&id).expect("didn't find node").state
    }

    pub fn is_on(&self, id: Id) -> bool {
        self.get_state(id).value
    }

    pub fn is_off(&self, id: Id) -> bool {
        !self.is_on(id)
    }

    fn set_state(&mut self, id: Id, state: State) {
        self.components
            .get_mut(&id)
            .expect("didn't find node")
            .state = state;
    }

    #[cfg(test)]
    pub fn set_value(&mut self, id: Id, value: bool) {
        self.components
            .get_mut(&id)
            .expect("didn't find node")
            .state
            .value = value;
    }

    fn subgraph_leaves(&self) -> impl Iterator<Item = Id> {
        let is_leaf = |&node: &Id| {
            self.tickless_graph
                .edges_directed(node, Outgoing)
                .next()
                .is_none()
        };

        self.tickless_graph.nodes().filter(is_leaf)
    }
}

#[derive(Clone, Copy)]
struct Component {
    state: State,
    pub parent: Option<Id>,
    kind: ComponentKind,
}

impl Component {
    fn new(kind: ComponentKind) -> Self {
        Self {
            kind,
            parent: None,
            state: State::default(),
        }
    }
}

#[derive(Clone, Copy, EnumIs)]
pub enum ComponentKind {
    Not,
    Delay,
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
            assert!(components.iter().all(|&id| sim.is_off(id)));
        }
    }

    #[test]
    fn test_flipping_loop_with_two_delays() {
        let mut sim = Simulation::default();
        let [first, second] = sim.add_array_wired_loop([Delay, Delay]);

        sim.set_value(first, true);

        for i in 0..100 {
            assert_eq!(i % 2 == 0, sim.is_on(first));
            assert_eq!(i % 2 == 1, sim.is_on(second));
            sim.run_step();
        }
    }

    #[test]
    fn test_flipping_loop_with_not_and_delay() {
        let mut sim = Simulation::default();
        let [not, delay] = sim.add_array_wired_loop([Not, Delay]);

        assert!(sim.is_off(not));
        assert!(sim.is_off(delay));
        for i in 0..100 {
            sim.run_step();
            assert_eq!(i % 2 == 0, sim.is_on(delay), "at {i}");
            assert_eq!(i % 2 == 1, sim.is_on(not), "at {i}");
        }
    }

    #[test]
    fn test_loop_with_three_delays() {
        let mut sim = Simulation::default();
        let [delay_1, delay_2, delay_3] = sim.add_array_wired_loop_of(Delay);
        sim.set_value(delay_1, true);

        for _ in 0..100 {
            sim.run_step();
            assert!(sim.is_off(delay_1));
            assert!(sim.is_on(delay_2));
            assert!(sim.is_off(delay_3));

            sim.run_step();
            assert!(sim.is_off(delay_1));
            assert!(sim.is_off(delay_2));
            assert!(sim.is_on(delay_3));

            sim.run_step();
            assert!(sim.is_on(delay_1));
            assert!(sim.is_off(delay_2));
            assert!(sim.is_off(delay_3));
        }
    }

    #[test]
    fn test_loop_circuit_with_consecutive_nots_and_delays() {
        let mut sim = Simulation::default();
        let [not_1, not_2, not_3, delay_1, delay_2] =
            sim.add_array_wired_loop([Not, Not, Not, Delay, Delay]);

        for _ in 0..100 {
            sim.run_step();
            assert!(sim.is_off(not_1));
            assert!(sim.is_on(not_2));
            assert!(sim.is_off(not_3));
            assert!(sim.is_on(delay_1));
            assert!(sim.is_off(delay_2));

            sim.run_step();
            assert!(sim.is_off(not_1));
            assert!(sim.is_on(not_2));
            assert!(sim.is_off(not_3));
            assert!(sim.is_on(delay_1));
            assert!(sim.is_on(delay_2));

            sim.run_step();
            assert!(sim.is_on(not_1));
            assert!(sim.is_off(not_2));
            assert!(sim.is_on(not_3));
            assert!(sim.is_off(delay_1));
            assert!(sim.is_on(delay_2));

            sim.run_step();
            assert!(sim.is_on(not_1));
            assert!(sim.is_off(not_2));
            assert!(sim.is_on(not_3));
            assert!(sim.is_off(delay_1));
            assert!(sim.is_off(delay_2));
        }
    }

    #[test]
    fn test_loop_circuit_with_consecutive_nots_and_delays_stable() {
        let mut sim = Simulation::default();
        let [not_1, not_2, not_3, not_4, delay_1, delay_2] =
            sim.add_array_wired_loop([Not, Not, Not, Not, Delay, Delay]);

        for _ in 0..100 {
            sim.run_step();
            assert!(sim.is_off(not_1));
            assert!(sim.is_on(not_2));
            assert!(sim.is_off(not_3));
            assert!(sim.is_on(not_4));
            assert!(sim.is_off(delay_1));
            assert!(sim.is_off(delay_2));
        }
    }
}
