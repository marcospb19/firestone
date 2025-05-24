use godot::{
    builtin::{Color, Vector3},
    classes::{CsgBox3D, ICsgBox3D, StandardMaterial3D},
    prelude::*,
};

#[derive(GodotClass)]
#[class(base = CsgBox3D)]
pub struct Cable {
    start: Vector3,
    end: Vector3,
    is_on: bool,
    material: Option<Gd<StandardMaterial3D>>,

    #[base]
    base: Base<CsgBox3D>,
}

#[godot_api]
impl ICsgBox3D for Cable {
    fn init(base: Base<CsgBox3D>) -> Self {
        Self {
            start: Vector3::ZERO,
            end: Vector3::ZERO,
            is_on: false,
            material: None,
            base,
        }
    }

    fn enter_tree(&mut self) {
        let Self { start, end, .. } = *self;

        // Equivalent to look_at in GDScript
        self.base_mut()
            .look_at_from_position((start + end) / 2.0, start);

        // Set size based on distance
        let distance = (start - end).length();
        self.base_mut().set_size(Vector3::new(
            Self::cable_width(),
            Self::cable_width(),
            distance,
        ));

        // Create and apply material
        let mut material = StandardMaterial3D::new_gd();
        material.set_albedo(Color::GRAY);
        self.base_mut().set_material(&material);
        self.material = Some(material);
    }
}

#[godot_api]
impl Cable {
    #[func(rename = CABLE_WIDTH)]
    fn cable_width() -> f32 {
        0.1
    }

    #[func]
    pub fn create(start: Vector3, end: Vector3) -> Gd<Self> {
        let mut cable = Self::new_alloc();
        if let mut bind = cable.bind_mut() {
            bind.start = start;
            bind.end = end;
        }
        cable
    }

    #[func]
    pub fn update_state(&mut self, value: bool) {
        self.is_on = value;
        if let Some(ref mut material) = self.material {
            let color = if value {
                Color::CYAN
            } else {
                Color::DARK_SLATE_GRAY
            };
            material.set_albedo(color);
        }
    }

    #[func]
    pub fn is_on(&self) -> bool {
        self.is_on
    }
}
