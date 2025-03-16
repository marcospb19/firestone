#![feature(array_windows)]
#![allow(irrefutable_let_patterns)]

use self::Component::*;
use petgraph::{Directed, acyclic::Acyclic, data::Build, prelude::GraphMap};
use std::{
    array,
    collections::{HashMap, HashSet, VecDeque},
};

#[derive(Default)]
pub struct Simulation {
    components: HashMap<usize, Component>,
    supergraph: GraphMap<usize, bool, Directed>,
    subgraph: Acyclic<GraphMap<usize, bool, Directed>>,
    subgraph_incoming_count: HashMap<usize, usize>,
    // instead of tracking state of each component, only track the input
    inputs: HashMap<usize, bool>,
    id_gen: usize,
}

impl Simulation {
    pub fn add(&mut self, kind: Component) -> usize {
        let id = self.id_gen;
        self.id_gen += 1;
        self.components.insert(id, kind);

        self.supergraph.add_node(id);
        self.subgraph.add_node(id);

        self.inputs.insert(id, false);
        id
    }

    pub fn add_array<const N: usize>(&mut self, array: [Component; N]) -> [usize; N] {
        array.map(|component| self.add(component))
    }

    pub fn add_array_of<const N: usize>(&mut self, component: Component) -> [usize; N] {
        array::from_fn(|_| self.add(component))
    }

    pub fn add_array_wired<const N: usize>(&mut self, array: [Component; N]) -> [usize; N] {
        let components = self.add_array(array);
        for &[parent, child] in components.array_windows::<2>() {
            self.wire(parent, child);
        }
        components
    }

    pub fn add_array_wired_of<const N: usize>(&mut self, component: Component) -> [usize; N] {
        let components = self.add_array_of(component);
        for &[parent, child] in components.array_windows::<2>() {
            self.wire(parent, child);
        }
        components
    }

    pub fn add_array_wired_loop<const N: usize>(&mut self, array: [Component; N]) -> [usize; N] {
        let components = self.add_array_wired(array);
        if let Some((&first, &last)) = components.first().zip(components.last()) {
            self.wire(last, first); // close the loop
        }
        components
    }

    pub fn add_array_wired_loop_of<const N: usize>(&mut self, component: Component) -> [usize; N] {
        let components = self.add_array_of(component);
        if let Some((&first, &last)) = components.first().zip(components.last()) {
            self.wire(last, first); // close the loop
        }
        components
    }

    pub fn wire(&mut self, parent: usize, child: usize) {
        let parent_kind = self.components.get(&parent).expect("unexpected parent");
        let child_kind = self.components.get(&child).expect("unexpected parent");

        if parent_kind.is_delay() {
            self.supergraph
                .add_edge(parent, child, !child_kind.is_delay());
        } else {
            self.subgraph
                .try_add_edge(parent, child, child_kind.is_delay())
                .expect("found cycle");
            *self.subgraph_incoming_count.entry(child).or_default() += 1;
        }
    }

    pub fn run_step(&mut self) {
        if let previous_state = self.inputs.clone() {
            for (parent, child, _) in self.supergraph.all_edges() {
                self.inputs.insert(child, previous_state[&parent]);
            }
        }

        let mut queue = self.subgraph_roots().collect::<VecDeque<usize>>();
        let mut visited = HashSet::new();

        while let Some(node) = queue.pop_front() {
            for (_, child, crosses_boundaries) in self.subgraph.edges(node) {
                let Not = self.components[&node] else {
                    unreachable!();
                };
                self.inputs.insert(child, !self.inputs[&node]);

                assert!(!visited.contains(&child), "shouldn't visit twice");
                visited.insert(child);

                if !crosses_boundaries {
                    queue.push_back(child);
                }
            }
        }
    }

    pub fn get_input(&self, id: usize) -> bool {
        self.inputs[&id]
    }

    #[track_caller]
    pub fn set_input(&mut self, id: usize, value: bool) {
        let previous = self.inputs.insert(id, value);
        assert!(previous.is_some(), "set_input of unknown {id}");
    }

    fn subgraph_roots(&self) -> impl Iterator<Item = usize> {
        self.subgraph.nodes().filter(|node| {
            assert_ne!(Some(&0), self.subgraph_incoming_count.get(node));
            !self.subgraph_incoming_count.contains_key(node)
        })
    }
}

#[derive(Clone, Copy, strum::EnumIs)]
pub enum Component {
    And,
    Not,
    Delay,
}

#[cfg(test)]
mod tests {
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
    fn test_loop_circuit_with_consecutive_delays_and_nots() {
        let mut sim = Simulation::default();
        let [not_1, not_2, not_3, delay_1, delay_2, delay_3] =
            sim.add_array_wired_loop([Not, Not, Not, Delay, Delay, Delay]);

        for _ in 0..100 {
            sim.run_step();
            assert!(!sim.get_input(not_1));
            assert!(sim.get_input(not_2));
            assert!(!sim.get_input(not_3));
            assert!(sim.get_input(delay_1));
            assert!(!sim.get_input(delay_2));
            assert!(!sim.get_input(delay_3));

            sim.run_step();
            assert!(!sim.get_input(not_1));
            assert!(sim.get_input(not_2));
            assert!(!sim.get_input(not_3));
            assert!(sim.get_input(delay_1));
            assert!(sim.get_input(delay_2));
            assert!(!sim.get_input(delay_3));

            sim.run_step();
            assert!(!sim.get_input(not_1));
            assert!(sim.get_input(not_2));
            assert!(!sim.get_input(not_3));
            assert!(sim.get_input(delay_1));
            assert!(sim.get_input(delay_2));
            assert!(sim.get_input(delay_3));

            sim.run_step();
            assert!(sim.get_input(not_1));
            assert!(!sim.get_input(not_2));
            assert!(sim.get_input(not_3));
            assert!(!sim.get_input(delay_1));
            assert!(sim.get_input(delay_2));
            assert!(sim.get_input(delay_3));

            sim.run_step();
            assert!(sim.get_input(not_1));
            assert!(!sim.get_input(not_2));
            assert!(sim.get_input(not_3));
            assert!(!sim.get_input(delay_1));
            assert!(!sim.get_input(delay_2));
            assert!(sim.get_input(delay_3));

            sim.run_step();
            assert!(sim.get_input(not_1));
            assert!(!sim.get_input(not_2));
            assert!(sim.get_input(not_3));
            assert!(!sim.get_input(delay_1));
            assert!(!sim.get_input(delay_2));
            assert!(!sim.get_input(delay_3));
        }
    }
}
