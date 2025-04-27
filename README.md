# zig-fib

Zig implementation of [Fibsonisheaf](https://github.com/SheafificationOfG/Fibsonisheaf/)

## build && run

> [!NOTE]
> Default (if not specified) will be the `naive` implementation

```sh
zig build -Doptimize=ReleaseFast -Dimplementation=linear run
```

> using `Debug` mode will not work as it has safety measures against integer overflows, which have yet to be patched

## inspecting assembly

```sh
zig build -Doptimize=ReleaseFast -Dimplementation=linear asm
```

will generate a `[implementation]_[optimize].s` file under `zig-out/asm`

## Flags

some additional flags you may use are:

| Flag                   | Description                       |
| ---------------------- | --------------------------------- |
| -Dprint_numbers=[bool] | print the numbers in the output   |
| -Duse_csv_fmt=[bool]   | print the output using csv format |
