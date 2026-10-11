# JavaScript

The sandbox webc ships a Node-compatible JS runtime: `edgejs`
(`pkgs/overlay/packages/edgejs/`), built from the wasmerio/edgejs sources with
the QuickJS N-API provider compiled into the guest. `pkgs/sandbox-webc.py` runs
its `node` entrypoint as a check.

## The guest

- Entrypoints are `node`, `pnpm`, and `npm` (npm is an alias for the bundled
  pnpm). Installing from the registry works, and installed packages resolve.
- QuickJS needs a 4 MiB host stack; the checks pass `--stack-size 4194304`.
- `WebAssembly` works: the guest instantiates wasm modules and calls their
  exports. It is the host Wasmer that provides this, through the
  `wasm_c_api_v0` import module. Upstream's Makefile builds the CLI with
  `build_wasmer_extra_features := wasm-c-api`; the wasmer flake's
  `cliFeatureList` (`scripts/nix/pkg.nix`) omits it, so a flake-built runtime
  must enable the feature for edgejs to instantiate.
- Native Node addons (`canvas`, `gl`, `sharp`) do not load; the guest has no
  way to run them. Pure-JS packages are unaffected.

## Graphics

Verified 2026-10-11 against wasmer 7.4.2 and `wasmer/edgejs-quickjs` from the
wasmer.io registry.

| Path | State |
| ---- | ----- |
| three.js scene/geometry/`toJSON` | works (r186, CJS and ESM) |
| three.js `SVGRenderer` + jsdom | works, writes SVG |
| three.js `WebGLRenderer` | no WebGL in the guest |
| p5.js default (P2D) canvas | no 2D context |
| p5.js `p5.js-svg` + jsdom | works, writes SVG with text; needs `DOMMatrix`, `DOMPoint`, `ImageData`, and `TextMetrics` polyfills, and a no-op `HTMLCanvasElement.prototype.getContext` |
| SVG to PNG | works: `@resvg/resvg-wasm` plus a font buffer |
| Skia raster (`canvaskit-wasm`) | works: init, draw, `encodeToBytes` |

## A 2D context

The guest runs wasm, so no C library has to be ported for a 2D backend. What is
missing is the adapter that makes the canvas API run on one:

1. Rasterise SVG with `@resvg/resvg-wasm` and a bundled font. p5 and three
   already emit SVG, so this is the smallest step to pixel output.
2. Back `require("canvas")` and `HTMLCanvasElement.prototype.getContext("2d")`
   with `canvaskit-wasm`, so libraries that draw through the canvas API run
   unmodified.
3. Ship fonts in the webc and map `font-family` generics to them, since text is
   resolved through the SVG or canvas font stack.

WebGL is out either way: Skia's WebGL backend needs a GPU.
