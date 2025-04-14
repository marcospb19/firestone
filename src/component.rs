use strum::EnumIs;

use crate::State;

pub struct Component {
    pub state: State,
    pub kind: ComponentKind,
}

impl Component {
    pub fn new(kind: ComponentKind) -> Self {
        Self {
            kind,
            state: State {
                values: vec![false; kind.arity().1],
                version: 0,
            },
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, EnumIs)]
pub enum ComponentKind {
    Not,
    And(usize),
    HalfAdder,
    FullAdder,
    Delay,
}

impl ComponentKind {
    pub fn arity(&self) -> (usize, usize) {
        match *self {
            ComponentKind::Not => (1, 1),
            ComponentKind::And(inputs) => (inputs, 1),
            ComponentKind::HalfAdder => (2, 2),
            ComponentKind::FullAdder => (3, 2),
            ComponentKind::Delay => (1, 1),
        }
    }
}

#[derive(Default)]
pub struct ComponentIdGenerator(pub usize);

impl ComponentIdGenerator {
    pub fn next_id(&mut self) -> ComponentId {
        let id = ComponentId(self.0);
        self.0 += 1;
        id
    }
}

#[derive(Default, PartialEq, Eq, Hash, PartialOrd, Ord, Debug, Clone, Copy)]
pub struct ComponentId(usize);

unsafe impl petgraph::graph::IndexType for ComponentId {
    fn new(inner: usize) -> Self {
        ComponentId(inner)
    }

    fn index(&self) -> usize {
        self.0
    }

    fn max() -> Self {
        Self(usize::MAX)
    }
}
