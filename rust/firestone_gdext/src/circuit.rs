use godot::prelude::*;
use rustc_hash::FxHashMap;
use simulation_engine::{ComponentId, ComponentKind, SimulationEngine};

use crate::cable::Cable;

#[derive(GodotClass)]
#[class(base = Node)]
struct CircuitSimulation {
    engine: SimulationEngine,
    blocks: FxHashMap<Vector3i, ComponentId>,
    cables: FxHashMap<ComponentId, Vec<Gd<Cable>>>,
    base: Base<Node>,
    elapsed: f32,
}

#[godot_api]
impl INode for CircuitSimulation {
    fn init(base: Base<Node>) -> Self {
        Self {
            engine: SimulationEngine::new(),
            blocks: FxHashMap::default(),
            cables: FxHashMap::default(),
            base,
            elapsed: 0.0,
        }
    }

    fn process(&mut self, delta: f32) {
        self.elapsed += delta;
        while self.elapsed > 1.0 {
            godot_print!("Simulation tick {}", self.engine.current_tick());
            self.elapsed -= 1.0;
            self.engine.run_step();
            for (id, component) in self.engine.components() {
                for cable in self.cables.get_mut(&id).into_iter().flatten() {
                    // TODO: remove `0`, consider multi-output gates
                    cable.bind_mut().update_state(component.state.values()[0]);
                }
            }
        }
    }
}

#[godot_api]
impl CircuitSimulation {
    #[func]
    fn connect_blocks(
        &mut self,
        from: Vector3i,
        to: Vector3i,
        is_from_and: bool,
        is_to_and: bool,
    ) -> bool {
        let from_kind = if is_from_and {
            ComponentKind::And(2)
        } else {
            ComponentKind::Not
        };

        let to_kind = if is_to_and {
            ComponentKind::And(2)
        } else {
            ComponentKind::Not
        };

        let from_id = self
            .blocks
            .get(&from)
            .copied()
            .inspect(|id| assert!(self.engine.components().get(id).unwrap().kind == from_kind))
            .unwrap_or_else(|| {
                let id = self.engine.add(from_kind);
                self.blocks.insert(from, id);
                id
            });
        let to_id = self
            .blocks
            .get(&to)
            .copied()
            .inspect(|id| assert!(self.engine.components().get(id).unwrap().kind == to_kind))
            .unwrap_or_else(|| {
                let id = self.engine.add(to_kind);
                self.blocks.insert(to, id);
                id
            });

        self.engine.wire(from_id, to_id, 0, 0)
    }

    /// Registers a cable to have its color be updated every tick.
    #[func]
    fn register_cable(&mut self, pos: Vector3i, cable: Gd<Cable>) {
        let component_id = self.blocks[&pos];
        self.cables.entry(component_id).or_default().push(cable);
    }
}
