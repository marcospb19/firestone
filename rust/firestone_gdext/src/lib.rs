#![allow(irrefutable_let_patterns)]

mod cable;
mod circuit;
use godot::{
    classes::{Engine, InputEventKey},
    global::Key,
    prelude::*,
};

struct MyExtension;

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
        refresh_rate as u32 + (refresh_rate.fract() > f32::EPSILON) as u32
    }
}
