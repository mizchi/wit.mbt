///|
test "parse benchmark" (b : @bench.T) {
  b.bench(fn() { ignore(parse("package foo:bar;")) })
}

///|
test "tokenize benchmark" (b : @bench.T) {
  b.bench(fn() { ignore(tokenize("package foo:bar;")) })
}
