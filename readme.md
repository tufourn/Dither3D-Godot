# Surface-Stable Fractal Dithering in Godot
This is an implementation of [runevision's Surface-Stable Fractal Dithering](https://github.com/runevision/Dither3D) in Godot.

I wrote [a blog post](https://tufourn.com/posts/surface-stable-fractal-dithering-in-godot/) on how I implemented the technique.

This repo contains a test scene with a few basic meshes to demonstrate the dithering effect.

![Screenshot](screenshots/00_screenshot.png)

The main logic is in `Shaders/Dither3D.gdshaderinc` which is basically the original implementation ported to Godot's GLSL-like shading language.

The 3D dither pattern texture files are available, but I've also included the `CreateDitherTextures.gd` script which you can use to generate them yourself.

