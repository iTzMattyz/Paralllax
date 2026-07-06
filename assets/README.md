# Art asset list — for the designer

The game now ships with **simple vector placeholders** (the `.svg` files in this
folder) so it looks like a real study instead of colored boxes. They are meant
to be replaced with your final art whenever you like.

Each object is a "hotspot" at a fixed position on a **1280 × 720** screen. The
code loads `assets/<id>.svg` for every object (the ids are in the table below).
To swap in your art, the easiest path is to **overwrite the `.svg` with your own
file** at the same name. If you'd rather deliver PNGs, change the extension in
the `_tex()` helper at the top of `scripts/Game.gd` from `.svg` to `.png`.
Nothing about the puzzle logic changes.

## 1. The room background (most important)

- **`room.png`** — the full room, **1280 × 720**. One flat illustration.
  Leave visual space for the objects below so the clickable zones sit on top of
  the painted versions of them.

## 2. Interactive objects (hotspots)

Each is a clickable region. Provide a PNG sized to the box; transparent areas
are fine. Positions are top-left corner, in pixels.

| File              | What it is        | Position (x, y) | Size (w × h) |
|-------------------|-------------------|-----------------|--------------|
| `bookshelf.png`   | Bookshelf w/ clue | 60, 150         | 170 × 330    |
| `clock.png`       | Stopped clock     | 575, 80         | 130 × 130    |
| `door.png`        | The exit door     | 740, 210        | 150 × 290    |
| `drawer.png`      | Desk drawer       | 470, 520        | 250 × 120    |
| `plant.png`       | Potted plant      | 110, 510        | 130 × 160    |
| `painting.png`    | Wall painting     | 955, 130        | 180 × 160    |
| `safe.png`        | Wall safe         | 975, 150        | 140 × 120    |

> The safe sits *behind* the painting — it only appears after the painting is
> moved aside.

## 3. Inventory item icons (~64 × 64, transparent)

- **`item_small_key.png`** — small rusty key
- **`item_brass_key.png`** — heavy brass key

## 4. Optional polish (nice-to-have)

- **Hover/glow state** for objects (or we fake a highlight in code).
- **Animations** (as sprite sheets or PNG sequences): door swinging open,
  drawer sliding out, painting moving aside, an idle flicker on the clock.
- **Sound**: a UI click, a "wrong code" buzz, a satisfying unlock/clunk, and a
  short ambient room loop.
- **A win screen** illustration for the "YOU ESCAPED" moment.

## Format notes

- PNG with transparency preferred. Aseprite, sprite sheets, or PNG sequences
  all import cleanly into Godot.
- Consistent light direction and palette across objects keeps it cohesive.
- Send everything at 1× the sizes above (or 2× for crispness — we can downscale).
