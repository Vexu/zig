const E = enum(u32) { a, _ };
fn fe(_: E) void {}

export fn entry1() void {
    fe(U.a);
}

const U = union(enum(u32)) { a, _ };
fn fu(_: U) void {}

export fn entry2() void {
    fu(E.a);
}

// error
//
// :5:9: error: expected type 'tmp.E', found '@typeInfo(tmp.U).@"union".tag_type.?'
// :8:11: note: enum declared here
// :1:11: note: enum declared here
// :2:10: note: parameter type declared here
// :12:9: error: expected type 'tmp.U', found 'tmp.E'
// :1:11: note: enum declared here
// :8:11: note: union declared here
// :9:10: note: parameter type declared here
