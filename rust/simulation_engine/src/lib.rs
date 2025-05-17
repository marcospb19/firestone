#![feature(array_windows)]
#![allow(irrefutable_let_patterns)]

mod component;

use std::{
    array,
    collections::{BTreeMap, BTreeSet},
};

use component::{Component, ComponentIdGenerator};
pub use component::{ComponentId, ComponentKind};
use petgraph::{
    acyclic::Acyclic,
    data::Build,
    prelude::{Directed, Direction::Outgoing, GraphMap},
};
use rustc_hash::FxHashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
struct Edge {
    parent_kind: ComponentKind,
    child_kind: ComponentKind,
    parent_output: usize,
    child_input: usize,
}

#[derive(Default)]
pub struct SimulationEngine {
    nodes: FxHashMap<ComponentId, Component>,
    incoming_edges: FxHashMap<ComponentId, BTreeMap<ComponentId, BTreeSet<Edge>>>,
    outgoing_edges: FxHashMap<ComponentId, BTreeMap<ComponentId, BTreeSet<Edge>>>,
    tickless_dag: Acyclic<GraphMap<ComponentId, (), Directed>>,
    id_gen: ComponentIdGenerator,
    current_tick: u64,
}

impl SimulationEngine {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn current_tick(&self) -> u64 {
        self.current_tick
    }

    pub fn add(&mut self, kind: ComponentKind) -> ComponentId {
        let component_id = self.id_gen.next_id();
        if !kind.is_delay() {
            self.tickless_dag.add_node(component_id);
        }
        self.nodes.insert(component_id, Component::new(kind));
        component_id
    }

    pub fn components(&self) -> &FxHashMap<ComponentId, Component> {
        &self.nodes
    }

    pub fn add_array<const N: usize>(&mut self, array: [ComponentKind; N]) -> [ComponentId; N] {
        array.map(|component| self.add(component))
    }

    pub fn add_array_of<const N: usize>(&mut self, component: ComponentKind) -> [ComponentId; N] {
        array::from_fn(|_| self.add(component))
    }

    pub fn add_array_wired<const N: usize>(
        &mut self,
        array: [ComponentKind; N],
    ) -> [ComponentId; N] {
        let components = self.add_array(array);
        for &[parent, child] in components.array_windows::<2>() {
            self.wire0(parent, child);
        }
        components
    }

    pub fn add_array_wired_of<const N: usize>(
        &mut self,
        component: ComponentKind,
    ) -> [ComponentId; N] {
        let components = self.add_array_of(component);
        for &[parent, child] in components.array_windows::<2>() {
            self.wire0(parent, child);
        }
        components
    }

    pub fn add_array_wired_loop<const N: usize>(
        &mut self,
        array: [ComponentKind; N],
    ) -> [ComponentId; N] {
        let components = self.add_array_wired(array);
        if let Some((&first, &last)) = components.first().zip(components.last()) {
            self.wire0(last, first); // close the loop
        }
        components
    }

    pub fn add_array_wired_loop_of<const N: usize>(
        &mut self,
        component: ComponentKind,
    ) -> [ComponentId; N] {
        let components = self.add_array_wired_of(component);
        if let Some((&first, &last)) = components.first().zip(components.last()) {
            self.wire0(last, first); // close the loop
        }
        components
    }

    pub fn wire0(&mut self, parent: ComponentId, child: ComponentId) {
        self.wire(parent, child, 0, 0);
    }

    pub fn wire(
        &mut self,
        parent: ComponentId,
        child: ComponentId,
        parent_output: usize,
        child_input: usize,
    ) {
        let parent_kind = self.nodes.get(&parent).expect("unexpected parent").kind;
        let child_kind = self.nodes.get(&child).expect("unexpected parent").kind;

        if !parent_kind.is_delay() && !child_kind.is_delay() {
            self.tickless_dag
                .try_update_edge(parent, child, ())
                .expect("detected cycle");
        }

        let edge = Edge {
            parent_kind,
            child_kind,
            parent_output,
            child_input,
        };

        self.outgoing_edges
            .entry(parent)
            .or_default()
            .entry(child)
            .or_default()
            .insert(edge);
        self.incoming_edges
            .entry(child)
            .or_default()
            .entry(parent)
            .or_default()
            .insert(edge);
    }

    pub fn run_step(&mut self) {
        self.current_tick += 1;
        let version = self.current_tick;

        // tick it, propagate all the delay states
        if let mut edits = vec![] {
            for (&delay_id, node) in self.nodes.iter() {
                if !node.kind.is_delay() {
                    continue;
                }

                for (parent_id, edge) in self.incoming_to(delay_id) {
                    edits.push((
                        delay_id,
                        edge.child_input,
                        self.nodes[&parent_id].state.values[edge.parent_output],
                    ));
                }
            }

            for (delay_id, child_input, parent_output_value) in edits {
                self.nodes.get_mut(&delay_id).unwrap().state.values[child_input] =
                    parent_output_value;
            }
        }

        // for all leaves, eval with recursion
        if let leaves = self.subgraph_leaves().collect::<Vec<ComponentId>>() {
            for leaf in leaves {
                assert!(!self.nodes[&leaf].kind.is_delay());
                self.recursive_eval_and_update(leaf, version);
            }
        }
    }

    fn recursive_eval_and_update(&mut self, id: ComponentId, version: u64) -> Vec<bool> {
        let component = &self.nodes[&id];
        let component_kind = component.kind;

        let values = if component.state.version == version {
            component.state.values.clone()
        } else {
            let inputs = {
                let mut inputs = vec![false; component_kind.arity().0];
                let incoming_edges: Vec<(ComponentId, Edge)> = self.incoming_to(id).collect();
                for (parent_id, edge) in incoming_edges {
                    let parent_component = &self.nodes[&parent_id];

                    let parent_eval = match parent_component.kind {
                        ComponentKind::Delay => parent_component.state.values[edge.parent_output],
                        _ => self.recursive_eval_and_update(parent_id, version)[edge.parent_output],
                    };
                    inputs[edge.child_input] |= parent_eval;
                }
                inputs
            };

            match component_kind {
                ComponentKind::Not => vec![inputs.into_iter().all(|x| !x)],
                ComponentKind::And(_) => vec![inputs.into_iter().all(|x| x)],
                ComponentKind::HalfAdder => {
                    let sum = inputs[0] as u8 + inputs[1] as u8;
                    vec![sum & 1 != 0, sum & 2 != 0]
                }
                ComponentKind::FullAdder => {
                    let sum = inputs[0] as u8 + inputs[1] as u8 + inputs[2] as u8;
                    vec![sum & 1 != 0, sum & 2 != 0]
                }
                ComponentKind::Delay => unreachable!(),
            }
        };

        self.nodes.get_mut(&id).unwrap().state = State {
            values: values.clone(),
            version,
        };
        values
    }

    fn get_state(&self, id: ComponentId) -> &State {
        &self.nodes.get(&id).expect("didn't find node").state
    }

    pub fn is_on(&self, id: ComponentId) -> bool {
        self.get_state(id).values[0]
    }

    pub fn is_off(&self, id: ComponentId) -> bool {
        !self.is_on(id)
    }

    pub fn is_on_at(&self, id: ComponentId, index: usize) -> bool {
        self.get_state(id).values[index]
    }

    pub fn is_off_at(&self, id: ComponentId, index: usize) -> bool {
        !self.is_on_at(id, index)
    }

    #[cfg(test)]
    pub fn set_value(&mut self, id: ComponentId, value: bool) {
        self.nodes
            .get_mut(&id)
            .expect("didn't find node")
            .state
            .values
            .insert(0, value);
    }

    fn incoming_to(&self, id: ComponentId) -> impl Iterator<Item = (ComponentId, Edge)> {
        self.incoming_edges
            .get(&id)
            .into_iter()
            .flatten()
            .flat_map(|(&component_id, edges)| edges.iter().map(move |&edge| (component_id, edge)))
    }

    // fn outgoing_from(&self, id: ComponentId) -> impl Iterator<Item = (ComponentId, Edge)> {
    //     self.outgoing_edges
    //         .get(&id)
    //         .into_iter()
    //         .flatten()
    //         .map(|(&a, &b)| (a, b))
    // }

    fn subgraph_leaves(&self) -> impl Iterator<Item = ComponentId> {
        let is_leaf = |&node: &ComponentId| {
            self.tickless_dag
                .edges_directed(node, Outgoing)
                .next()
                .is_none()
        };

        self.tickless_dag.nodes().filter(is_leaf)
    }
}

#[derive(Debug)]
pub struct State {
    values: Vec<bool>,
    version: u64,
}

impl State {
    pub fn values(&self) -> &[bool] {
        &self.values
    }
}

#[cfg(test)]
mod tests {
    use super::{ComponentKind::*, *};

    #[test]
    #[should_panic]
    fn panic_on_trivial_self_cycle() {
        let mut sim = SimulationEngine::default();
        let not = sim.add(Not);
        sim.wire0(not, not);
    }

    #[test]
    #[should_panic]
    fn panic_on_short_cycle() {
        let mut sim = SimulationEngine::default();
        let [v, u] = sim.add_array_of(Not);
        sim.wire0(v, u);
        sim.wire0(u, v);
    }

    #[test]
    fn test_disconnected_components() {
        let mut sim = SimulationEngine::default();
        let components = sim.add_array([Not, Not, Delay, Delay]);
        for i in 0..100 {
            sim.run_step();
            assert!(sim.is_on(components[0]), "{i}");
            assert!(sim.is_on(components[1]), "{i}");
            assert!(sim.is_off(components[2]), "{i}");
            assert!(sim.is_off(components[3]), "{i}");
        }
    }

    #[test]
    fn test_flipping_loop_with_two_delays() {
        let mut sim = SimulationEngine::default();
        let [first, second] = sim.add_array_wired_loop([Delay, Delay]);

        sim.set_value(first, true);

        for i in 0..100 {
            assert_eq!(i % 2 == 0, sim.is_on(first), "{i}");
            assert_eq!(i % 2 == 1, sim.is_on(second), "{i}");
            sim.run_step();
        }
    }

    #[test]
    fn test_flipping_loop_with_not_and_delay() {
        let mut sim = SimulationEngine::default();
        let [not, delay] = sim.add_array_wired_loop([Not, Delay]);

        for i in 0..100 {
            sim.run_step();
            assert_eq!(i % 2 == 0, sim.is_on(not), "{i}");
            assert_eq!(i % 2 == 1, sim.is_on(delay), "{i}");
        }
    }

    #[test]
    fn test_loop_with_three_delays() {
        let mut sim = SimulationEngine::default();
        let [delay_1, delay_2, delay_3] = sim.add_array_wired_loop_of(Delay);
        sim.set_value(delay_1, true);

        for i in 0..100 {
            sim.run_step();
            assert!(sim.is_off(delay_1), "{i}");
            assert!(sim.is_on(delay_2), "{i}");
            assert!(sim.is_off(delay_3), "{i}");

            sim.run_step();
            assert!(sim.is_off(delay_1), "{i}");
            assert!(sim.is_off(delay_2), "{i}");
            assert!(sim.is_on(delay_3), "{i}");

            sim.run_step();
            assert!(sim.is_on(delay_1), "{i}");
            assert!(sim.is_off(delay_2), "{i}");
            assert!(sim.is_off(delay_3), "{i}");
        }
    }

    #[test]
    fn test_loop_circuit_with_consecutive_nots_and_delays() {
        let mut sim = SimulationEngine::default();
        let [not_1, not_2, not_3, delay_1, delay_2] =
            sim.add_array_wired_loop([Not, Not, Not, Delay, Delay]);

        for i in 0..100 {
            sim.run_step();
            assert!(sim.is_on(not_1), "{i}");
            assert!(sim.is_off(not_2), "{i}");
            assert!(sim.is_on(not_3), "{i}");
            assert!(sim.is_off(delay_1), "{i}");
            assert!(sim.is_off(delay_2), "{i}");

            sim.run_step();
            assert!(sim.is_on(not_1), "{i}");
            assert!(sim.is_off(not_2), "{i}");
            assert!(sim.is_on(not_3), "{i}");
            assert!(sim.is_on(delay_1), "{i}");
            assert!(sim.is_off(delay_2), "{i}");

            sim.run_step();
            assert!(sim.is_off(not_1), "{i}");
            assert!(sim.is_on(not_2), "{i}");
            assert!(sim.is_off(not_3), "{i}");
            assert!(sim.is_on(delay_1), "{i}");
            assert!(sim.is_on(delay_2), "{i}");

            sim.run_step();
            assert!(sim.is_off(not_1), "{i}");
            assert!(sim.is_on(not_2), "{i}");
            assert!(sim.is_off(not_3), "{i}");
            assert!(sim.is_off(delay_1), "{i}");
            assert!(sim.is_on(delay_2), "{i}");
        }
    }

    #[test]
    fn test_loop_circuit_with_consecutive_nots_and_delays_stable() {
        let mut sim = SimulationEngine::default();
        let [not_1, not_2, not_3, not_4, delay_1, delay_2] =
            sim.add_array_wired_loop([Not, Not, Not, Not, Delay, Delay]);

        for i in 0..100 {
            sim.run_step();
            assert!(sim.is_on(not_1), "{i}");
            assert!(sim.is_off(not_2), "{i}");
            assert!(sim.is_on(not_3), "{i}");
            assert!(sim.is_off(not_4), "{i}");
            assert!(sim.is_off(delay_1), "{i}");
            assert!(sim.is_off(delay_2), "{i}");
        }
    }

    #[test]
    fn test_and() {
        let new_sim = || {
            let mut sim = SimulationEngine::default();
            let [not, and] = sim.add_array([Not, And(2)]);
            (sim, not, and)
        };

        let (mut sim, _, and) = new_sim();
        sim.run_step();
        assert!(sim.is_off(and));

        let (mut sim, not, and) = new_sim();
        sim.wire(not, and, 0, 0);
        sim.run_step();
        assert!(sim.is_off(and));

        let (mut sim, not, and) = new_sim();
        sim.wire(not, and, 0, 1);
        sim.run_step();
        assert!(sim.is_off(and));

        let (mut sim, not, and) = new_sim();
        sim.wire(not, and, 0, 0);
        sim.wire(not, and, 0, 1);
        sim.run_step();
        assert!(sim.is_on(and));
    }

    #[test]
    fn test_half_adder() {
        let new_sim = || {
            let mut sim = SimulationEngine::default();
            let [not, half_adder] = sim.add_array([Not, HalfAdder]);
            (sim, not, half_adder)
        };

        let (mut sim, _, half_adder) = new_sim();
        sim.run_step();
        assert!(sim.is_off_at(half_adder, 0));
        assert!(sim.is_off_at(half_adder, 1));

        let (mut sim, not, half_adder) = new_sim();
        sim.wire(not, half_adder, 0, 0);
        sim.run_step();
        assert!(sim.is_on_at(half_adder, 0));
        assert!(sim.is_off_at(half_adder, 1));

        let (mut sim, not, half_adder) = new_sim();
        sim.wire(not, half_adder, 0, 1);
        sim.run_step();
        assert!(sim.is_on_at(half_adder, 0));
        assert!(sim.is_off_at(half_adder, 1));

        let (mut sim, not, half_adder) = new_sim();
        sim.wire(not, half_adder, 0, 0);
        sim.wire(not, half_adder, 0, 1);
        sim.run_step();
        assert!(sim.is_on_at(half_adder, 1));
        assert!(sim.is_off_at(half_adder, 0));
    }

    #[test]
    fn test_full_adder() {
        let new_sim = || {
            let mut sim = SimulationEngine::default();
            let [not, full_adder] = sim.add_array([Not, FullAdder]);
            (sim, not, full_adder)
        };

        let (mut sim, _, full_adder) = new_sim();
        sim.run_step();
        assert!(sim.is_off_at(full_adder, 0));
        assert!(sim.is_off_at(full_adder, 1));

        let (mut sim, not, full_adder) = new_sim();
        sim.wire(not, full_adder, 0, 0);
        sim.run_step();
        assert!(sim.is_on_at(full_adder, 0));
        assert!(sim.is_off_at(full_adder, 1));

        let (mut sim, not, full_adder) = new_sim();
        sim.wire(not, full_adder, 0, 1);
        sim.run_step();
        assert!(sim.is_on_at(full_adder, 0));
        assert!(sim.is_off_at(full_adder, 1));

        let (mut sim, not, full_adder) = new_sim();
        sim.wire(not, full_adder, 0, 2);
        sim.run_step();
        assert!(sim.is_on_at(full_adder, 0));
        assert!(sim.is_off_at(full_adder, 1));

        let two_inputs_combinations = [(0, 1), (0, 2), (1, 2)];

        for (first, second) in two_inputs_combinations {
            let (mut sim, not, full_adder) = new_sim();
            sim.wire(not, full_adder, 0, first);
            sim.wire(not, full_adder, 0, second);
            sim.run_step();
            assert!(sim.is_off_at(full_adder, 0));
            assert!(sim.is_on_at(full_adder, 1));
        }

        let (mut sim, not, full_adder) = new_sim();
        sim.wire(not, full_adder, 0, 0);
        sim.wire(not, full_adder, 0, 1);
        sim.wire(not, full_adder, 0, 2);
        sim.run_step();
        assert!(sim.is_on_at(full_adder, 1));
        assert!(sim.is_on_at(full_adder, 1));
    }
}
