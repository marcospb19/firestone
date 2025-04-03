#[derive(Default)]
pub struct IdGenerator(pub usize);

impl IdGenerator {
    pub fn next_id(&mut self) -> Id {
        let id = Id(self.0);
        self.0 += 1;
        id
    }
}

#[derive(Default, PartialEq, Eq, Hash, PartialOrd, Ord, Debug, Clone, Copy)]
pub struct Id(usize);

unsafe impl petgraph::graph::IndexType for Id {
    fn new(inner: usize) -> Self {
        Id(inner)
    }

    fn index(&self) -> usize {
        self.0
    }

    fn max() -> Self {
        Self(usize::MAX)
    }
}
