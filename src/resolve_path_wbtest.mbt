///|
test "directory entries remain mutable with the ArrayView filesystem API" {
  let entries = read_dir_raise(".")
  assert_true(entries.contains("moon.mod"))
  sort_strings(entries)
  for i in 1..<entries.length() {
    assert_true(entries[i - 1].compare(entries[i]) <= 0)
  }
}

///|
test "directory errors retain the resolver error contract" {
  ignore(
    read_dir_raise("moon.mod/not-a-directory") catch {
      ParseError::Message(message, offset) => {
        assert_eq(message, "read_dir failed: moon.mod/not-a-directory")
        assert_eq(offset, 0)
        return
      }
    },
  )
  fail("Expected a resolver error")
}
