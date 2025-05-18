use godot::{
    classes::{Engine, InputEventKey},
    global::Key,
    prelude::*,
};
use rustc_hash::FxHashMap;
use simulation_engine::{ComponentId, ComponentKind, SimulationEngine};

struct MyExtension;

#[derive(GodotClass)]
#[class(init, base = Object)]
struct Utils2 {
    base: Base<Object>,
}

#[godot_api]
impl Utils2 {
    const NAME: &str = "Utils2";

    #[func]
    fn parse_hotbar_number(key: Gd<InputEventKey>) -> Variant {
        match key.get_keycode() {
            Key::KEY_0 => 0.to_variant(),
            Key::KEY_1 => 1.to_variant(),
            Key::KEY_2 => 2.to_variant(),
            Key::KEY_3 => 3.to_variant(),
            Key::KEY_4 => 4.to_variant(),
            Key::KEY_5 => 5.to_variant(),
            Key::KEY_6 => 6.to_variant(),
            Key::KEY_7 => 7.to_variant(),
            Key::KEY_8 => 8.to_variant(),
            Key::KEY_9 => 9.to_variant(),
            _ => Variant::nil(),
        }
    }

    #[func]
    fn refresh_rate_to_fps(refresh_rate: f32) -> u32 {
        godot_print!("refresh rate: {}", refresh_rate);
        refresh_rate as u32 + (refresh_rate.fract() > f32::EPSILON) as u32
    }

    #[func]
    fn repeat(variant: Variant, times: u32) -> Array<Variant> {
        let mut array = Array::new();
        for _ in 0..times {
            array.push(&variant);
        }
        array
    }
}

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {
    fn on_level_init(level: InitLevel) {
        if level == InitLevel::Scene {
            Engine::singleton().register_singleton(Utils2::NAME, &Utils2::new_alloc());
        }
    }

    fn on_level_deinit(level: InitLevel) {
        if level == InitLevel::Scene {
            let mut engine = Engine::singleton();

            if let Some(my_singleton) = engine.get_singleton(Utils2::NAME) {
                engine.unregister_singleton(Utils2::NAME);
                my_singleton.free();
            } else {
                godot_error!("Failed to get singleton");
            }
        }
    }
}

#[derive(GodotClass)]
#[class(base = Node)]
struct CircuitSimulation {
    engine: SimulationEngine,
    blocks: FxHashMap<Vector3i, ComponentId>,
    base: Base<Node>,
    elapsed: f32,
}

#[godot_api]
impl INode for CircuitSimulation {
    fn init(base: Base<Node>) -> Self {
        Self {
            engine: SimulationEngine::new(),
            blocks: FxHashMap::default(),
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
            for (a, b) in self.engine.components() {
                godot_print!("{a:?} = {:?}", b.state.values());
            }
        }
    }
}

#[godot_api]
impl CircuitSimulation {
    #[func]
    fn connect_blocks(&mut self, from: Vector3i, to: Vector3i, is_from_and: bool, is_to_and: bool) {
        godot_print!("connected blocks");
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

        self.engine.wire(from_id, to_id, 0, 0);
    }
}
