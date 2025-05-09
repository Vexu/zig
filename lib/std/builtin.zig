//! Types and values provided by the Zig language.

const builtin = @import("builtin");

/// `explicit_subsystem` is missing when the subsystem is automatically detected,
/// so Zig standard library has the subsystem detection logic here. This should generally be
/// used rather than `explicit_subsystem`.
/// On non-Windows targets, this is `null`.
pub const subsystem: ?std.Target.SubSystem = blk: {
    if (@hasDecl(builtin, "explicit_subsystem")) break :blk builtin.explicit_subsystem;
    switch (builtin.os.tag) {
        .windows => {
            if (builtin.is_test) {
                break :blk std.Target.SubSystem.Console;
            }
            if (@hasDecl(root, "main") or
                @hasDecl(root, "WinMain") or
                @hasDecl(root, "wWinMain") or
                @hasDecl(root, "WinMainCRTStartup") or
                @hasDecl(root, "wWinMainCRTStartup"))
            {
                break :blk std.Target.SubSystem.Windows;
            } else {
                break :blk std.Target.SubSystem.Console;
            }
        },
        else => break :blk null,
    }
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const StackTrace = struct {
    index: usize,
    instruction_addresses: []usize,

    pub fn format(
        self: StackTrace,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);

        // TODO: re-evaluate whether to use format() methods at all.
        // Until then, avoid an error when using GeneralPurposeAllocator with WebAssembly
        // where it tries to call detectTTYConfig here.
        if (builtin.os.tag == .freestanding) return;

        _ = options;
        const debug_info = std.debug.getSelfDebugInfo() catch |err| {
            return writer.print("\nUnable to print stack trace: Unable to open debug info: {s}\n", .{@errorName(err)});
        };
        const tty_config = std.io.tty.detectConfig(std.io.getStdErr());
        try writer.writeAll("\n");
        std.debug.writeStackTrace(self, writer, debug_info, tty_config) catch |err| {
            try writer.print("Unable to print stack trace: {s}\n", .{@errorName(err)});
        };
    }
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const GlobalLinkage = enum {
    internal,
    strong,
    weak,
    link_once,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const SymbolVisibility = enum {
    default,
    hidden,
    protected,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AtomicOrder = enum {
    unordered,
    monotonic,
    acquire,
    release,
    acq_rel,
    seq_cst,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ReduceOp = enum {
    And,
    Or,
    Xor,
    Min,
    Max,
    Add,
    Mul,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AtomicRmwOp = enum {
    /// Exchange - store the operand unmodified.
    /// Supports enums, integers, and floats.
    Xchg,
    /// Add operand to existing value.
    /// Supports integers and floats.
    /// For integers, two's complement wraparound applies.
    Add,
    /// Subtract operand from existing value.
    /// Supports integers and floats.
    /// For integers, two's complement wraparound applies.
    Sub,
    /// Perform bitwise AND on existing value with operand.
    /// Supports integers.
    And,
    /// Perform bitwise NAND on existing value with operand.
    /// Supports integers.
    Nand,
    /// Perform bitwise OR on existing value with operand.
    /// Supports integers.
    Or,
    /// Perform bitwise XOR on existing value with operand.
    /// Supports integers.
    Xor,
    /// Store operand if it is larger than the existing value.
    /// Supports integers and floats.
    Max,
    /// Store operand if it is smaller than the existing value.
    /// Supports integers and floats.
    Min,
};

/// The code model puts constraints on the location of symbols and the size of code and data.
/// The selection of a code model is a trade off on speed and restrictions that needs to be selected on a per application basis to meet its requirements.
/// A slightly more detailed explanation can be found in (for example) the [System V Application Binary Interface (x86_64)](https://github.com/hjl-tools/x86-psABI/wiki/x86-64-psABI-1.0.pdf) 3.5.1.
///
/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CodeModel = enum {
    default,
    extreme,
    kernel,
    large,
    medany,
    medium,
    medlow,
    medmid,
    normal,
    small,
    tiny,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const OptimizeMode = enum {
    Debug,
    ReleaseSafe,
    ReleaseFast,
    ReleaseSmall,
};

/// Deprecated; use OptimizeMode.
pub const Mode = OptimizeMode;

/// The calling convention of a function defines how arguments and return values are passed, as well
/// as any other requirements which callers and callees must respect, such as register preservation
/// and stack alignment.
///
/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CallingConvention = union(enum(u8)) {
    pub const Tag = @typeInfo(CallingConvention).@"union".tag_type.?;

    /// This is an alias for the default C calling convention for this target.
    /// Functions marked as `extern` or `export` are given this calling convention by default.
    pub const c = builtin.target.cCallingConvention().?;

    pub const winapi: CallingConvention = switch (builtin.target.cpu.arch) {
        .x86_64 => .{ .x86_64_win = .{} },
        .x86 => .{ .x86_stdcall = .{} },
        .aarch64 => .{ .aarch64_aapcs_win = .{} },
        .thumb => .{ .arm_aapcs_vfp = .{} },
        else => unreachable,
    };

    pub const kernel: CallingConvention = switch (builtin.target.cpu.arch) {
        .amdgcn => .amdgcn_kernel,
        .nvptx, .nvptx64 => .nvptx_kernel,
        .spirv, .spirv32, .spirv64 => .spirv_kernel,
        else => unreachable,
    };

    /// Deprecated; use `.auto`.
    pub const Unspecified: CallingConvention = .auto;
    /// Deprecated; use `.c`.
    pub const C: CallingConvention = .c;
    /// Deprecated; use `.naked`.
    pub const Naked: CallingConvention = .naked;
    /// Deprecated; use `.@"async"`.
    pub const Async: CallingConvention = .@"async";
    /// Deprecated; use `.@"inline"`.
    pub const Inline: CallingConvention = .@"inline";
    /// Deprecated; use `.x86_64_interrupt`, `.x86_interrupt`, or `.avr_interrupt`.
    pub const Interrupt: CallingConvention = switch (builtin.target.cpu.arch) {
        .x86_64 => .{ .x86_64_interrupt = .{} },
        .x86 => .{ .x86_interrupt = .{} },
        .avr => .avr_interrupt,
        else => unreachable,
    };
    /// Deprecated; use `.avr_signal`.
    pub const Signal: CallingConvention = .avr_signal;
    /// Deprecated; use `.x86_stdcall`.
    pub const Stdcall: CallingConvention = .{ .x86_stdcall = .{} };
    /// Deprecated; use `.x86_fastcall`.
    pub const Fastcall: CallingConvention = .{ .x86_fastcall = .{} };
    /// Deprecated; use `.x86_64_vectorcall`, `.x86_vectorcall`, or `aarch64_vfabi`.
    pub const Vectorcall: CallingConvention = switch (builtin.target.cpu.arch) {
        .x86_64 => .{ .x86_64_vectorcall = .{} },
        .x86 => .{ .x86_vectorcall = .{} },
        .aarch64, .aarch64_be => .{ .aarch64_vfabi = .{} },
        else => unreachable,
    };
    /// Deprecated; use `.x86_thiscall`.
    pub const Thiscall: CallingConvention = .{ .x86_thiscall = .{} };
    /// Deprecated; use `.arm_aapcs`.
    pub const AAPCS: CallingConvention = .{ .arm_aapcs = .{} };
    /// Deprecated; use `.arm_aapcs_vfp`.
    pub const AAPCSVFP: CallingConvention = .{ .arm_aapcs_vfp = .{} };
    /// Deprecated; use `.x86_64_sysv`.
    pub const SysV: CallingConvention = .{ .x86_64_sysv = .{} };
    /// Deprecated; use `.x86_64_win`.
    pub const Win64: CallingConvention = .{ .x86_64_win = .{} };
    /// Deprecated; use `.kernel`.
    pub const Kernel: CallingConvention = .kernel;
    /// Deprecated; use `.spirv_fragment`.
    pub const Fragment: CallingConvention = .spirv_fragment;
    /// Deprecated; use `.spirv_vertex`.
    pub const Vertex: CallingConvention = .spirv_vertex;

    /// The default Zig calling convention when neither `export` nor `inline` is specified.
    /// This calling convention makes no guarantees about stack alignment, registers, etc.
    /// It can only be used within this Zig compilation unit.
    auto,

    /// The calling convention of a function that can be called with `async` syntax. An `async` call
    /// of a runtime-known function must target a function with this calling convention.
    /// Comptime-known functions with other calling conventions may be coerced to this one.
    @"async",

    /// Functions with this calling convention have no prologue or epilogue, making the function
    /// uncallable in regular Zig code. This can be useful when integrating with assembly.
    naked,

    /// This calling convention is exactly equivalent to using the `inline` keyword on a function
    /// definition. This function will be semantically inlined by the Zig compiler at call sites.
    /// Pointers to inline functions are comptime-only.
    @"inline",

    // Calling conventions for the `x86_64` architecture.
    x86_64_sysv: CommonOptions,
    x86_64_win: CommonOptions,
    x86_64_regcall_v3_sysv: CommonOptions,
    x86_64_regcall_v4_win: CommonOptions,
    x86_64_vectorcall: CommonOptions,
    x86_64_interrupt: CommonOptions,

    // Calling conventions for the `x86` architecture.
    x86_sysv: X86RegparmOptions,
    x86_win: X86RegparmOptions,
    x86_stdcall: X86RegparmOptions,
    x86_fastcall: CommonOptions,
    x86_thiscall: CommonOptions,
    x86_thiscall_mingw: CommonOptions,
    x86_regcall_v3: CommonOptions,
    x86_regcall_v4_win: CommonOptions,
    x86_vectorcall: CommonOptions,
    x86_interrupt: CommonOptions,

    // Calling conventions for the `aarch64` and `aarch64_be` architectures.
    aarch64_aapcs: CommonOptions,
    aarch64_aapcs_darwin: CommonOptions,
    aarch64_aapcs_win: CommonOptions,
    aarch64_vfabi: CommonOptions,
    aarch64_vfabi_sve: CommonOptions,

    // Calling convetions for the `arm`, `armeb`, `thumb`, and `thumbeb` architectures.
    /// ARM Architecture Procedure Call Standard
    arm_aapcs: CommonOptions,
    /// ARM Architecture Procedure Call Standard Vector Floating-Point
    arm_aapcs_vfp: CommonOptions,
    arm_interrupt: ArmInterruptOptions,

    // Calling conventions for the `mips64` and `mips64el` architectures.
    mips64_n64: CommonOptions,
    mips64_n32: CommonOptions,
    mips64_interrupt: MipsInterruptOptions,

    // Calling conventions for the `mips` and `mipsel` architectures.
    mips_o32: CommonOptions,
    mips_interrupt: MipsInterruptOptions,

    // Calling conventions for the `riscv64` architecture.
    riscv64_lp64: CommonOptions,
    riscv64_lp64_v: CommonOptions,
    riscv64_interrupt: RiscvInterruptOptions,

    // Calling conventions for the `riscv32` architecture.
    riscv32_ilp32: CommonOptions,
    riscv32_ilp32_v: CommonOptions,
    riscv32_interrupt: RiscvInterruptOptions,

    // Calling conventions for the `sparc64` architecture.
    sparc64_sysv: CommonOptions,

    // Calling conventions for the `sparc` architecture.
    sparc_sysv: CommonOptions,

    // Calling conventions for the `powerpc64` and `powerpc64le` architectures.
    powerpc64_elf: CommonOptions,
    powerpc64_elf_altivec: CommonOptions,
    powerpc64_elf_v2: CommonOptions,

    // Calling conventions for the `powerpc` and `powerpcle` architectures.
    powerpc_sysv: CommonOptions,
    powerpc_sysv_altivec: CommonOptions,
    powerpc_aix: CommonOptions,
    powerpc_aix_altivec: CommonOptions,

    /// The standard `wasm32` and `wasm64` calling convention, as specified in the WebAssembly Tool Conventions.
    wasm_mvp: CommonOptions,

    /// The standard `arc` calling convention.
    arc_sysv: CommonOptions,

    // Calling conventions for the `avr` architecture.
    avr_gnu,
    avr_builtin,
    avr_signal,
    avr_interrupt,

    /// The standard `bpfel`/`bpfeb` calling convention.
    bpf_std: CommonOptions,

    // Calling conventions for the `csky` architecture.
    csky_sysv: CommonOptions,
    csky_interrupt: CommonOptions,

    // Calling conventions for the `hexagon` architecture.
    hexagon_sysv: CommonOptions,
    hexagon_sysv_hvx: CommonOptions,

    /// The standard `lanai` calling convention.
    lanai_sysv: CommonOptions,

    /// The standard `loongarch64` calling convention.
    loongarch64_lp64: CommonOptions,

    /// The standard `loongarch32` calling convention.
    loongarch32_ilp32: CommonOptions,

    // Calling conventions for the `m68k` architecture.
    m68k_sysv: CommonOptions,
    m68k_gnu: CommonOptions,
    m68k_rtd: CommonOptions,
    m68k_interrupt: CommonOptions,

    /// The standard `msp430` calling convention.
    msp430_eabi: CommonOptions,

    /// The standard `propeller` calling convention.
    propeller_sysv: CommonOptions,

    // Calling conventions for the `s390x` architecture.
    s390x_sysv: CommonOptions,
    s390x_sysv_vx: CommonOptions,

    /// The standard `ve` calling convention.
    ve_sysv: CommonOptions,

    // Calling conventions for the `xcore` architecture.
    xcore_xs1: CommonOptions,
    xcore_xs2: CommonOptions,

    // Calling conventions for the `xtensa` architecture.
    xtensa_call0: CommonOptions,
    xtensa_windowed: CommonOptions,

    // Calling conventions for the `amdgcn` architecture.
    amdgcn_device: CommonOptions,
    amdgcn_kernel,
    amdgcn_cs: CommonOptions,

    // Calling conventions for the `nvptx` and `nvptx64` architectures.
    nvptx_device,
    nvptx_kernel,

    // Calling conventions for kernels and shaders on the `spirv`, `spirv32`, and `spirv64` architectures.
    spirv_device,
    spirv_kernel,
    spirv_fragment,
    spirv_vertex,

    /// Options shared across most calling conventions.
    pub const CommonOptions = struct {
        /// The boundary the stack is aligned to when the function is called.
        /// `null` means the default for this calling convention.
        incoming_stack_alignment: ?u64 = null,
    };

    /// Options for x86 calling conventions which support the regparm attribute to pass some
    /// arguments in registers.
    pub const X86RegparmOptions = struct {
        /// The boundary the stack is aligned to when the function is called.
        /// `null` means the default for this calling convention.
        incoming_stack_alignment: ?u64 = null,
        /// The number of arguments to pass in registers before passing the remaining arguments
        /// according to the calling convention.
        /// Equivalent to `__attribute__((regparm(x)))` in Clang and GCC.
        register_params: u2 = 0,
    };

    /// Options for the `arm_interrupt` calling convention.
    pub const ArmInterruptOptions = struct {
        /// The boundary the stack is aligned to when the function is called.
        /// `null` means the default for this calling convention.
        incoming_stack_alignment: ?u64 = null,
        /// The kind of interrupt being received.
        type: InterruptType = .generic,

        pub const InterruptType = enum(u3) {
            generic,
            irq,
            fiq,
            swi,
            abort,
            undef,
        };
    };

    /// Options for the `mips_interrupt` and `mips64_interrupt` calling conventions.
    pub const MipsInterruptOptions = struct {
        /// The boundary the stack is aligned to when the function is called.
        /// `null` means the default for this calling convention.
        incoming_stack_alignment: ?u64 = null,
        /// The interrupt mode.
        mode: InterruptMode = .eic,

        pub const InterruptMode = enum(u4) {
            eic,
            sw0,
            sw1,
            hw0,
            hw1,
            hw2,
            hw3,
            hw4,
            hw5,
        };
    };

    /// Options for the `riscv32_interrupt` and `riscv64_interrupt` calling conventions.
    pub const RiscvInterruptOptions = struct {
        /// The boundary the stack is aligned to when the function is called.
        /// `null` means the default for this calling convention.
        incoming_stack_alignment: ?u64 = null,
        /// The privilege mode.
        mode: PrivilegeMode,

        pub const PrivilegeMode = enum(u2) {
            supervisor,
            machine,
        };
    };

    /// Returns the array of `std.Target.Cpu.Arch` to which this `CallingConvention` applies.
    /// Asserts that `cc` is not `.auto`, `.@"async"`, `.naked`, or `.@"inline"`.
    pub fn archs(cc: CallingConvention) []const std.Target.Cpu.Arch {
        return std.Target.Cpu.Arch.fromCallingConvention(cc);
    }

    pub fn eql(a: CallingConvention, b: CallingConvention) bool {
        return std.meta.eql(a, b);
    }

    pub fn withStackAlign(cc: CallingConvention, incoming_stack_alignment: u64) CallingConvention {
        const tag: CallingConvention.Tag = cc;
        var result = cc;
        @field(result, @tagName(tag)).incoming_stack_alignment = incoming_stack_alignment;
        return result;
    }
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AddressSpace = enum(u5) {
    /// The places where a user can specify an address space attribute
    pub const Context = enum {
        /// A function is specified to be placed in a certain address space.
        function,
        /// A (global) variable is specified to be placed in a certain address space.
        /// In contrast to .constant, these values (and thus the address space they will be
        /// placed in) are required to be mutable.
        variable,
        /// A (global) constant value is specified to be placed in a certain address space.
        /// In contrast to .variable, values placed in this address space are not required to be mutable.
        constant,
        /// A pointer is ascripted to point into a certain address space.
        pointer,
    };

    // CPU address spaces.
    generic,
    gs,
    fs,
    ss,

    // GPU address spaces.
    global,
    constant,
    param,
    shared,
    local,
    input,
    output,
    uniform,
    push_constant,
    storage_buffer,

    // AVR address spaces.
    flash,
    flash1,
    flash2,
    flash3,
    flash4,
    flash5,

    // Propeller address spaces.

    /// This address space only addresses the cog-local ram.
    cog,

    /// This address space only addresses shared hub ram.
    hub,

    /// This address space only addresses the "lookup" ram
    lut,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const SourceLocation = struct {
    /// The name chosen when compiling. Not a file path.
    module: [:0]const u8,
    /// Relative to the root directory of its module.
    file: [:0]const u8,
    fn_name: [:0]const u8,
    line: u32,
    column: u32,
};

pub const TypeId = std.meta.Tag(Type);

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Type = union(enum) {
    type: void,
    void: void,
    bool: void,
    noreturn: void,
    int: Int,
    float: Float,
    pointer: Pointer,
    array: Array,
    @"struct": Struct,
    comptime_float: void,
    comptime_int: void,
    undefined: void,
    null: void,
    optional: Optional,
    error_union: ErrorUnion,
    error_set: ErrorSet,
    @"enum": Enum,
    @"union": Union,
    @"fn": Fn,
    @"opaque": Opaque,
    frame: Frame,
    @"anyframe": AnyFrame,
    vector: Vector,
    enum_literal: void,

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Int = struct {
        signedness: Signedness,
        bits: u16,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Float = struct {
        bits: u16,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Pointer = struct {
        size: Size,
        is_const: bool,
        is_volatile: bool,
        /// TODO make this u16 instead of comptime_int
        alignment: comptime_int,
        address_space: AddressSpace,
        child: type,
        is_allowzero: bool,

        /// The type of the sentinel is the element type of the pointer, which is
        /// the value of the `child` field in this struct. However there is no way
        /// to refer to that type here, so we use `*const anyopaque`.
        /// See also: `sentinel`
        sentinel_ptr: ?*const anyopaque,

        /// Loads the pointer type's sentinel value from `sentinel_ptr`.
        /// Returns `null` if the pointer type has no sentinel.
        pub inline fn sentinel(comptime ptr: Pointer) ?ptr.child {
            const sp: *const ptr.child = @ptrCast(@alignCast(ptr.sentinel_ptr orelse return null));
            return sp.*;
        }

        /// This data structure is used by the Zig language code generation and
        /// therefore must be kept in sync with the compiler implementation.
        pub const Size = enum(u2) {
            one,
            many,
            slice,
            c,
        };
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Array = struct {
        len: comptime_int,
        child: type,

        /// The type of the sentinel is the element type of the array, which is
        /// the value of the `child` field in this struct. However there is no way
        /// to refer to that type here, so we use `*const anyopaque`.
        /// See also: `sentinel`.
        sentinel_ptr: ?*const anyopaque,

        /// Loads the array type's sentinel value from `sentinel_ptr`.
        /// Returns `null` if the array type has no sentinel.
        pub inline fn sentinel(comptime arr: Array) ?arr.child {
            const sp: *const arr.child = @ptrCast(@alignCast(arr.sentinel_ptr orelse return null));
            return sp.*;
        }
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ContainerLayout = enum(u2) {
        auto,
        @"extern",
        @"packed",
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const StructField = struct {
        name: [:0]const u8,
        type: type,
        /// The type of the default value is the type of this struct field, which
        /// is the value of the `type` field in this struct. However there is no
        /// way to refer to that type here, so we use `*const anyopaque`.
        /// See also: `defaultValue`.
        default_value_ptr: ?*const anyopaque,
        is_comptime: bool,
        alignment: comptime_int,

        /// Loads the field's default value from `default_value_ptr`.
        /// Returns `null` if the field has no default value.
        pub inline fn defaultValue(comptime sf: StructField) ?sf.type {
            const dp: *const sf.type = @ptrCast(@alignCast(sf.default_value_ptr orelse return null));
            return dp.*;
        }
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Struct = struct {
        layout: ContainerLayout,
        /// Only valid if layout is .@"packed"
        backing_integer: ?type = null,
        fields: []const StructField,
        decls: []const Declaration,
        is_tuple: bool,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Optional = struct {
        child: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ErrorUnion = struct {
        error_set: type,
        payload: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Error = struct {
        name: [:0]const u8,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ErrorSet = ?[]const Error;

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const EnumField = struct {
        name: [:0]const u8,
        value: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Enum = struct {
        tag_type: type,
        fields: []const EnumField,
        decls: []const Declaration,
        is_exhaustive: bool,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const UnionField = struct {
        name: [:0]const u8,
        type: type,
        alignment: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Union = struct {
        layout: ContainerLayout,
        tag_type: ?type,
        fields: []const UnionField,
        decls: []const Declaration,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Fn = struct {
        calling_convention: CallingConvention,
        is_generic: bool,
        is_var_args: bool,
        /// TODO change the language spec to make this not optional.
        return_type: ?type,
        params: []const Param,

        /// This data structure is used by the Zig language code generation and
        /// therefore must be kept in sync with the compiler implementation.
        pub const Param = struct {
            is_generic: bool,
            is_noalias: bool,
            type: ?type,
        };
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Opaque = struct {
        decls: []const Declaration,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Frame = struct {
        function: *const anyopaque,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const AnyFrame = struct {
        child: ?type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Vector = struct {
        len: comptime_int,
        child: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Declaration = struct {
        name: [:0]const u8,
    };
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const FloatMode = enum {
    strict,
    optimized,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Endian = enum {
    big,
    little,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Signedness = enum {
    signed,
    unsigned,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const OutputMode = enum {
    Exe,
    Lib,
    Obj,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const LinkMode = enum {
    static,
    dynamic,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const UnwindTables = enum {
    none,
    sync,
    @"async",
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const WasiExecModel = enum {
    command,
    reactor,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CallModifier = enum {
    /// Equivalent to function call syntax.
    auto,

    /// Equivalent to async keyword used with function call syntax.
    async_kw,

    /// Prevents tail call optimization. This guarantees that the return
    /// address will point to the callsite, as opposed to the callsite's
    /// callsite. If the call is otherwise required to be tail-called
    /// or inlined, a compile error is emitted instead.
    never_tail,

    /// Guarantees that the call will not be inlined. If the call is
    /// otherwise required to be inlined, a compile error is emitted instead.
    never_inline,

    /// Asserts that the function call will not suspend. This allows a
    /// non-async function to call an async function.
    no_async,

    /// Guarantees that the call will be generated with tail call optimization.
    /// If this is not possible, a compile error is emitted instead.
    always_tail,

    /// Guarantees that the call will be inlined at the callsite.
    /// If this is not possible, a compile error is emitted instead.
    always_inline,

    /// Evaluates the call at compile-time. If the call cannot be completed at
    /// compile-time, a compile error is emitted instead.
    compile_time,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListAarch64 = extern struct {
    __stack: *anyopaque,
    __gr_top: *anyopaque,
    __vr_top: *anyopaque,
    __gr_offs: c_int,
    __vr_offs: c_int,

    // // These numbers are not used for variadic arguments, hence it doesn't matter
    // // they don't retain their values across multiple calls to
    // // `classifyArgumentType` here.
    // unsigned NSRN = 0, NPRN = 0;
    // ABIArgInfo AI =
    //     classifyArgumentType(Ty, /*IsVariadicFn=*/true, /* IsNamedArg */ false,
    //                         CGF.CurFnInfo->getCallingConvention(), NSRN, NPRN);
    // // Empty records are ignored for parameter passing purposes.
    // if (AI.isIgnore())
    //     return Slot.asRValue();

    // bool IsIndirect = AI.isIndirect();

    // llvm::Type *BaseTy = CGF.ConvertType(Ty);
    // if (IsIndirect)
    //     BaseTy = llvm::PointerType::getUnqual(BaseTy);
    // else if (AI.getCoerceToType())
    //     BaseTy = AI.getCoerceToType();

    // unsigned NumRegs = 1;
    // if (llvm::ArrayType *ArrTy = dyn_cast<llvm::ArrayType>(BaseTy)) {
    //     BaseTy = ArrTy->getElementType();
    //     NumRegs = ArrTy->getNumElements();
    // }
    // bool IsFPR =
    //     !isSoftFloat() && (BaseTy->isFloatingPointTy() || BaseTy->isVectorTy());

    // // The AArch64 va_list type and handling is specified in the Procedure Call
    // // Standard, section B.4:
    // //
    // // struct {
    // //   void *__stack;
    // //   void *__gr_top;
    // //   void *__vr_top;
    // //   int __gr_offs;
    // //   int __vr_offs;
    // // };

    // llvm::BasicBlock *MaybeRegBlock = CGF.createBasicBlock("vaarg.maybe_reg");
    // llvm::BasicBlock *InRegBlock = CGF.createBasicBlock("vaarg.in_reg");
    // llvm::BasicBlock *OnStackBlock = CGF.createBasicBlock("vaarg.on_stack");
    // llvm::BasicBlock *ContBlock = CGF.createBasicBlock("vaarg.end");

    // CharUnits TySize = getContext().getTypeSizeInChars(Ty);
    // CharUnits TyAlign = getContext().getTypeUnadjustedAlignInChars(Ty);

    // Address reg_offs_p = Address::invalid();
    // llvm::Value *reg_offs = nullptr;
    // int reg_top_index;
    // int RegSize = IsIndirect ? 8 : TySize.getQuantity();
    // if (!IsFPR) {
    //     // 3 is the field number of __gr_offs
    //     reg_offs_p = CGF.Builder.CreateStructGEP(VAListAddr, 3, "gr_offs_p");
    //     reg_offs = CGF.Builder.CreateLoad(reg_offs_p, "gr_offs");
    //     reg_top_index = 1; // field number for __gr_top
    //     RegSize = llvm::alignTo(RegSize, 8);
    // } else {
    //     // 4 is the field number of __vr_offs.
    //     reg_offs_p = CGF.Builder.CreateStructGEP(VAListAddr, 4, "vr_offs_p");
    //     reg_offs = CGF.Builder.CreateLoad(reg_offs_p, "vr_offs");
    //     reg_top_index = 2; // field number for __vr_top
    //     RegSize = 16 * NumRegs;
    // }

    // //=======================================
    // // Find out where argument was passed
    // //=======================================

    // // If reg_offs >= 0 we're already using the stack for this type of
    // // argument. We don't want to keep updating reg_offs (in case it overflows,
    // // though anyone passing 2GB of arguments, each at most 16 bytes, deserves
    // // whatever they get).
    // llvm::Value *UsingStack = nullptr;
    // UsingStack = CGF.Builder.CreateICmpSGE(
    //     reg_offs, llvm::ConstantInt::get(CGF.Int32Ty, 0));

    // CGF.Builder.CreateCondBr(UsingStack, OnStackBlock, MaybeRegBlock);

    // // Otherwise, at least some kind of argument could go in these registers, the
    // // question is whether this particular type is too big.
    // CGF.EmitBlock(MaybeRegBlock);

    // // Integer arguments may need to correct register alignment (for example a
    // // "struct { __int128 a; };" gets passed in x_2N, x_{2N+1}). In this case we
    // // align __gr_offs to calculate the potential address.
    // if (!IsFPR && !IsIndirect && TyAlign.getQuantity() > 8) {
    //     int Align = TyAlign.getQuantity();

    //     reg_offs = CGF.Builder.CreateAdd(
    //         reg_offs, llvm::ConstantInt::get(CGF.Int32Ty, Align - 1),
    //         "align_regoffs");
    //     reg_offs = CGF.Builder.CreateAnd(
    //         reg_offs, llvm::ConstantInt::get(CGF.Int32Ty, -Align),
    //         "aligned_regoffs");
    // }

    // // Update the gr_offs/vr_offs pointer for next call to va_arg on this va_list.
    // // The fact that this is done unconditionally reflects the fact that
    // // allocating an argument to the stack also uses up all the remaining
    // // registers of the appropriate kind.
    // llvm::Value *NewOffset = nullptr;
    // NewOffset = CGF.Builder.CreateAdd(
    //     reg_offs, llvm::ConstantInt::get(CGF.Int32Ty, RegSize), "new_reg_offs");
    // CGF.Builder.CreateStore(NewOffset, reg_offs_p);

    // // Now we're in a position to decide whether this argument really was in
    // // registers or not.
    // llvm::Value *InRegs = nullptr;
    // InRegs = CGF.Builder.CreateICmpSLE(
    //     NewOffset, llvm::ConstantInt::get(CGF.Int32Ty, 0), "inreg");

    // CGF.Builder.CreateCondBr(InRegs, InRegBlock, OnStackBlock);

    // //=======================================
    // // Argument was in registers
    // //=======================================

    // // Now we emit the code for if the argument was originally passed in
    // // registers. First start the appropriate block:
    // CGF.EmitBlock(InRegBlock);

    // llvm::Value *reg_top = nullptr;
    // Address reg_top_p =
    //     CGF.Builder.CreateStructGEP(VAListAddr, reg_top_index, "reg_top_p");
    // reg_top = CGF.Builder.CreateLoad(reg_top_p, "reg_top");
    // Address BaseAddr(CGF.Builder.CreateInBoundsGEP(CGF.Int8Ty, reg_top, reg_offs),
    //                 CGF.Int8Ty, CharUnits::fromQuantity(IsFPR ? 16 : 8));
    // Address RegAddr = Address::invalid();
    // llvm::Type *MemTy = CGF.ConvertTypeForMem(Ty), *ElementTy = MemTy;

    // if (IsIndirect) {
    //     // If it's been passed indirectly (actually a struct), whatever we find from
    //     // stored registers or on the stack will actually be a struct **.
    //     MemTy = llvm::PointerType::getUnqual(MemTy);
    // }

    // const Type *Base = nullptr;
    // uint64_t NumMembers = 0;
    // bool IsHFA = isHomogeneousAggregate(Ty, Base, NumMembers);
    // if (IsHFA && NumMembers > 1) {
    //     // Homogeneous aggregates passed in registers will have their elements split
    //     // and stored 16-bytes apart regardless of size (they're notionally in qN,
    //     // qN+1, ...). We reload and store into a temporary local variable
    //     // contiguously.
    //     assert(!IsIndirect && "Homogeneous aggregates should be passed directly");
    //     auto BaseTyInfo = getContext().getTypeInfoInChars(QualType(Base, 0));
    //     llvm::Type *BaseTy = CGF.ConvertType(QualType(Base, 0));
    //     llvm::Type *HFATy = llvm::ArrayType::get(BaseTy, NumMembers);
    //     Address Tmp = CGF.CreateTempAlloca(HFATy,
    //                                     std::max(TyAlign, BaseTyInfo.Align));

    //     // On big-endian platforms, the value will be right-aligned in its slot.
    //     int Offset = 0;
    //     if (CGF.CGM.getDataLayout().isBigEndian() &&
    //         BaseTyInfo.Width.getQuantity() < 16)
    //     Offset = 16 - BaseTyInfo.Width.getQuantity();

    //     for (unsigned i = 0; i < NumMembers; ++i) {
    //     CharUnits BaseOffset = CharUnits::fromQuantity(16 * i + Offset);
    //     Address LoadAddr =
    //         CGF.Builder.CreateConstInBoundsByteGEP(BaseAddr, BaseOffset);
    //     LoadAddr = LoadAddr.withElementType(BaseTy);

    //     Address StoreAddr = CGF.Builder.CreateConstArrayGEP(Tmp, i);

    //     llvm::Value *Elem = CGF.Builder.CreateLoad(LoadAddr);
    //     CGF.Builder.CreateStore(Elem, StoreAddr);
    //     }

    //     RegAddr = Tmp.withElementType(MemTy);
    // } else {
    //     // Otherwise the object is contiguous in memory.

    //     // It might be right-aligned in its slot.
    //     CharUnits SlotSize = BaseAddr.getAlignment();
    //     if (CGF.CGM.getDataLayout().isBigEndian() && !IsIndirect &&
    //         (IsHFA || !isAggregateTypeForABI(Ty)) &&
    //         TySize < SlotSize) {
    //     CharUnits Offset = SlotSize - TySize;
    //     BaseAddr = CGF.Builder.CreateConstInBoundsByteGEP(BaseAddr, Offset);
    //     }

    //     RegAddr = BaseAddr.withElementType(MemTy);
    // }

    // CGF.EmitBranch(ContBlock);

    // //=======================================
    // // Argument was on the stack
    // //=======================================
    // CGF.EmitBlock(OnStackBlock);

    // Address stack_p = CGF.Builder.CreateStructGEP(VAListAddr, 0, "stack_p");
    // llvm::Value *OnStackPtr = CGF.Builder.CreateLoad(stack_p, "stack");

    // // Again, stack arguments may need realignment. In this case both integer and
    // // floating-point ones might be affected.
    // if (!IsIndirect && TyAlign.getQuantity() > 8) {
    //     OnStackPtr = emitRoundPointerUpToAlignment(CGF, OnStackPtr, TyAlign);
    // }
    // Address OnStackAddr = Address(OnStackPtr, CGF.Int8Ty,
    //                                 std::max(CharUnits::fromQuantity(8), TyAlign));

    // // All stack slots are multiples of 8 bytes.
    // CharUnits StackSlotSize = CharUnits::fromQuantity(8);
    // CharUnits StackSize;
    // if (IsIndirect)
    //     StackSize = StackSlotSize;
    // else
    //     StackSize = TySize.alignTo(StackSlotSize);

    // llvm::Value *StackSizeC = CGF.Builder.getSize(StackSize);
    // llvm::Value *NewStack = CGF.Builder.CreateInBoundsGEP(
    //     CGF.Int8Ty, OnStackPtr, StackSizeC, "new_stack");

    // // Write the new value of __stack for the next call to va_arg
    // CGF.Builder.CreateStore(NewStack, stack_p);

    // if (CGF.CGM.getDataLayout().isBigEndian() && !isAggregateTypeForABI(Ty) &&
    //     TySize < StackSlotSize) {
    //     CharUnits Offset = StackSlotSize - TySize;
    //     OnStackAddr = CGF.Builder.CreateConstInBoundsByteGEP(OnStackAddr, Offset);
    // }

    // OnStackAddr = OnStackAddr.withElementType(MemTy);

    // CGF.EmitBranch(ContBlock);

    // //=======================================
    // // Tidy up
    // //=======================================
    // CGF.EmitBlock(ContBlock);

    // Address ResAddr = emitMergePHI(CGF, RegAddr, InRegBlock, OnStackAddr,
    //                                 OnStackBlock, "vaargs.addr");

    // if (IsIndirect)
    //     return CGF.EmitLoadOfAnyValue(
    //         CGF.MakeAddrLValue(
    //             Address(CGF.Builder.CreateLoad(ResAddr, "vaarg.addr"), ElementTy,
    //                     TyAlign),
    //             Ty),
    //         Slot);

    // return CGF.EmitLoadOfAnyValue(CGF.MakeAddrLValue(ResAddr, Ty), Slot);
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListHexagon = extern struct {
    __gpr: c_long,
    __fpr: c_long,
    __overflow_arg_area: *anyopaque,
    __reg_save_area: *anyopaque,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListPowerPc = extern struct {
    gpr: u8,
    fpr: u8,
    reserved: c_ushort,
    overflow_arg_area: *anyopaque,
    reg_save_area: *anyopaque,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListS390x = extern struct {
    __current_saved_reg_area_pointer: *anyopaque,
    __saved_reg_area_end_pointer: *anyopaque,
    __overflow_area_pointer: *anyopaque,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListX86_64 = extern struct {
    gp_offset: c_uint,
    fp_offset: c_uint,
    overflow_arg_area: *anyopaque,
    reg_save_area: *anyopaque,

    pub fn arg(list: *VaListX86_64, comptime T: type) T {
        // 1. Determine whether arg_ty may be passed in the registers. If not go to step 7.
        // 2. Compute num_gp to hold the number of general purpose registers needed to pass type
        //    and num_fp to hold the number of floating point registers needed.
        const num_gp, const num_fp, const gp_first = (comptime classify(T)) orelse
            return list.argMem(T);

        // 3. Verify whether arguments fit into registers. In the case:
        //        l->gp_offset > 48 - num_gp * 8
        //    or
        //        l->fp_offset > 304 - num_fp * 16
        //    go to step 7.
        //
        // NOTE: 304 is a typo, there are (6 * 8 + 8 * 16) = 176 bytes of
        //    register save space).

        if ((num_gp > 0 and list.gp_offset > 48 - num_gp * 8) or
            (num_fp > 0 and list.fp_offset > 176 - num_fp * 16))
            return list.argMem(T);

        // 4. Fetch type from l->reg_save_area with an offset of l->gp_offset and/or
        //    l->fp_offset. This may require copying to a temporary location in case the
        //    parameter is passed in different register classes or requires an alignment greater
        //    than 8 for general purpose registers and 16 for XMM registers.
        var res: T = undefined;
        if (num_gp > 0 and num_fp > 0) {
            const fp_ptr: *f64 = @ptrFromInt(@intFromPtr(list.reg_save_area) + list.fp_offset);
            const gp_ptr: *u64 = @ptrFromInt(@intFromPtr(list.reg_save_area) + list.gp_offset);
            if (gp_first) {
                const res_ptr: *extern struct { gp: u64, fp: f64 } = @ptrCast(&res);
                res_ptr.gp = gp_ptr.*;
                res_ptr.fp = fp_ptr.*;
            } else {
                const res_ptr: *extern struct { fp: f64, gp: u64 } = @ptrCast(&res);
                res_ptr.gp = gp_ptr.*;
                res_ptr.fp = fp_ptr.*;
            }
        } else {
            const offset = if (num_gp > 0) list.gp_offset else list.fp_offset;
            const ptr: *T = @ptrFromInt(@intFromPtr(list.reg_save_area) + offset);
            res = ptr.*;
        }

        // 5. Set:
        //        l->gp_offset = l->gp_offset + num_gp * 8
        //        l->fp_offset = l->fp_offset + num_fp * 16.
        if (num_gp > 0) {
            list.gp_offset += num_gp * 8;
        }
        if (num_fp > 0) {
            list.gp_offset += num_fp * 16;
        }

        // 6. Return the fetched type.
        return res;
    }

    fn argMem(list: *VaListX86_64, comptime T: type) T {
        // 7. Align l->overflow_arg_area upwards to a 16 byte boundary if alignment needed by
        //    type exceeds 8 byte boundary.
        // 8. Fetch type from l->overflow_arg_area.
        const item_ptr: *T = if (@alignOf(T) > 8)
            @ptrFromInt(std.mem.alignForward(u64, @intFromPtr(list.overflow_arg_area), @alignOf(T)))
        else
            @ptrCast(@alignCast(list.overflow_arg_area));

        // 9. Set l->overflow_arg_area to:
        //        l->overflow_arg_area + sizeof(type)
        // 10. Align l->overflow_arg_area upwards to an 8 byte boundary.
        list.overflow_arg_area = @ptrFromInt(std.mem.alignForward(u64, @intFromPtr(list.overflow_arg_area) + @sizeOf(T), 8));

        // 11. Return the fetched type.
        return item_ptr.*;
    }

    pub fn classify(comptime T: type) ?struct { u8, u8, bool } {
        switch (@typeInfo(T)) {
            .bool, .pointer => return .{ 1, 0, false },
            .int,
            .@"enum",
            .error_set,
            => {
                if (@sizeOf(T) > 16) return null;
                return .{ @divFloor(@sizeOf(T) - 1, 8) + 1, 0, false };
            },
            .float => |info| switch (info.bits) {
                32, 64 => return .{ 0, 1, false },
                128 => return .{ 0, 2, false },
                16, 80 => return null,
                else => unreachable,
            },
            .vector => return null,
            .@"struct" => |info| {
                if (@sizeOf(T) > 16) return null;
                if (info.layout == .@"packed") {
                    return .{ @divFloor(@sizeOf(T) - 1, 8) + 1, 0, false };
                }

                var total_gp: u8 = 0;
                var total_fp: u8 = 0;
                var gp_size = 0;
                var gp_fist = true;
                var last_float = false;
                for (info.fields) |field| {
                    if (field.type == void) continue;
                    const elem_gp, const elem_fp, const elem_in_mem = classify(field.type) orelse return null;
                    if (elem_in_mem) return .{ 0, 0, true, false };
                    if (elem_fp == 2) return .{ 0, 2, false, false };

                    if (total_gp == 0 and gp_size == 0 and elem_fp != 0) gp_fist = false;
                    const is_float = elem_gp == 0 and elem_fp == 1 and @sizeOf(field.type) == 4;

                    if (is_float) {
                        if (last_float) {
                            total_fp += 1;
                            last_float = false;
                        } else if (gp_size == 0) {
                            last_float = true;
                        } else if (gp_size <= 4) {
                            gp_size = 0;
                            total_gp += 1;
                        } else {
                            gp_size = 0;
                            total_gp += 1;
                            last_float = true;
                        }
                        continue;
                    }

                    if (elem_fp == 1) {
                        if (last_float) {
                            total_fp += 1;
                            last_float = false;
                        }
                        if (gp_size != 0) {
                            total_gp += 1;
                            gp_size = 0;
                        }
                        total_fp += 1;
                        continue;
                    }
                    if (last_float) {
                        if (@sizeOf(field.type) > 4) {
                            total_fp += 1;
                        } else {
                            gp_size += 4;
                        }
                        last_float = false;
                    }

                    gp_size += @sizeOf(field.type);
                }
                if (last_float) {
                    if (gp_size != 0) {
                        gp_size += 4;
                    } else {
                        total_fp += 1;
                    }
                }
                total_gp += gp_size / 8;
                return .{ total_gp, total_fp, gp_fist };
            },

            .@"union" => |info| {
                if (@sizeOf(T) > 16) return null;
                if (info.layout == .@"packed") {
                    return .{ @divFloor(@sizeOf(T) - 1, 8) + 1, 0, false };
                }

                @compileError("TODO classify union");
            },
            else => @compileError("can't get non-extern compatible type"),
        }
    }

    const Kind = enum { i8, i16, i32, i64, i128, f32, f64 };

    fn getKind(comptime T: type) ?[]Kind {
        return switch (@typeInfo(T)) {
            .bool => &.{.i8},
            .pointer => &.{.i64},
            .int,
            .@"enum",
            .error_set,
            => {
                if (@sizeOf(T) > 16) return null;
                return .{ @divFloor(@sizeOf(T) - 1, 8) + 1, 0, false };
            },
            .float => |info| switch (info.bits) {
                32, 64 => return .{ 0, 1, false },
                128 => return .{ 0, 2, false },
                16, 80 => return null,
                else => unreachable,
            },
            .vector => return null,
        };
    }
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListXtensa = extern struct {
    __va_stk: *c_int,
    __va_reg: *c_int,
    __va_ndx: c_int,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListWindows = *opaque {};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListDarwin = *opaque {};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListAix = *opaque {};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListCommon = *opaque {
    pub fn arg(list_ptr: *VaListCommon, comptime T: type) T {
        const opts: struct {
            is_indirect: bool,
            slot_bytes: u32,
            allow_higher_align: bool,
            force_right_adjust: bool = false,
        } = switch (builtin.target.cpu.arch) {
            .aarch64, .aarch64_be => {
                // const func = zcu.funcInfo(zcu.navValue(self.ng.nav_index).toIntern());
                // const fn_ty = Type.fromInterned(func.ty);
                // const fn_info = zcu.typeToFunc(fn_ty).?;
                // if (fn_info.cc == .aarch64_aapcs_win) {
                //     const is_indirect = switch (arg_ty.zigTypeTag(zcu)) {
                //         .array => arg_ty.bitSize(zcu) > 128,
                //         .@"struct", .@"union" => arg_ty.bitSize(zcu) > 128 and arg_ty.containerLayout(zcu) != .@"packed",
                //         else => false,
                //     };

                //     return self.voidPtrVaArg(list, arg_ty, .{
                //         .is_indirect = is_indirect,
                //         .slot_bytes = 8,
                //         .allow_higher_align = false,
                //     });
                // } else if (fn_info.cc == .aarch64_aapcs_darwin) {
                //     if (!arg_ty.hasRuntimeBitsIgnoreComptime(zcu)) return .none;

                //     // TODO also check that arg_ty isn't homogenous
                //     const is_indirect = arg_ty.abiSize(zcu) > 16;
                //     return self.voidPtrVaArg(list, arg_ty, .{
                //         .is_indirect = is_indirect,
                //         .slot_bytes = 8,
                //         .allow_higher_align = false,
                //     });
                // }

                // return self.aarch64VaArg(list, arg_ty);
            },
            .amdgcn => .{
                .is_indirect = false,
                .slot_bytes = 4,
                .allow_higher_align = false,
            },
            .arc => .{
                .is_indirect = false,
                .slot_bytes = 4,
                .allow_higher_align = true,
            },
            .csky => blk: {
                if (@sizeOf(T) == 0) return std.mem.zeroes(T);

                break :blk .{
                    .is_indirect = false,
                    .slot_bytes = builtin.target.ptrBitWidth() / 8,
                    .allow_higher_align = true,
                };
            },
            .loongarch32, .loongarch64 => blk: {
                if (@sizeOf(T) == 0) return std.mem.zeroes(T);

                const slot_bytes = builtin.target.ptrBitWidth();
                const is_indirect = @sizeOf(T) > 2 * slot_bytes;
                break :blk .{
                    .is_indirect = is_indirect,
                    .slot_bytes = slot_bytes,
                    .allow_higher_align = true,
                };
            },
            .nvptx, .nvptx64 => .{
                .is_indirect = false,
                .slot_bytes = 1,
                .allow_higher_align = true,
            },
            .powerpc, .powerpcle => if (builtin.target.os.tag == .aix) .{
                // Note add complex type special handling if added.
                .is_indirect = false,
                .slot_bytes = 4,
                .allow_higher_align = true,
                // } else if (builtin.target.os.tag.isDarwin()) .{
                //     .is_indirect = switch (@typeInfo(T)) {
                //         .@"struct" => |info| switch (info.layout) {
                //             .@"packed" => false,
                //             else => @sizeOf(T) > 16,
                //         },
                //         .@"union" => |info| switch (info.layout) {
                //             .@"packed" => false,
                //             else => @sizeOf(T) > 16,
                //         },
                //         .vector => true,
                //         else => false,
                //     },
                //     .slot_bytes = 4,
                //     .allow_higher_align = true,
            } else unreachable,
            .powerpc64, .powerpc64le => if (builtin.target.os.tag == .aix) .{
                // Note add complex type special handling if added.
                .is_indirect = false,
                .slot_bytes = builtin.target.ptrBitWidth() / 8,
                .allow_higher_align = true,
            } else .{
                // Note add complex type special handling if added.
                .is_indirect = false,
                .slot_bytes = 8,
                .allow_higher_align = true,
                .force_right_adjust = true,
            },
            .riscv32, .riscv64 => blk: {
                if (@sizeOf(T) == 0) return std.mem.zeroes(T);

                // TODO GCC compatibility on riscv32 eabi

                const slot_bytes = builtin.target.ptrBitWidth() / 8;
                const is_indirect = @sizeOf(T) > 2 * slot_bytes;
                break :blk .{
                    .is_indirect = is_indirect,
                    .slot_bytes = slot_bytes,
                    .allow_higher_align = true,
                };
            },
            .wasm32, .wasm64 => blk: {
                const is_indirect = switch (@typeInfo(T)) {
                    .@"union" => @sizeOf(T) > 0,
                    .@"struct" => @sizeOf(T) > 0 and
                        false,
                    // wasm_c_abi.classifyType(arg_ty, zcu)[0] == .indirect,
                    else => false,
                };
                break :blk .{
                    .is_indirect = is_indirect,
                    .slot_bytes = 4,
                    .allow_higher_align = true,
                };
            },
            .x86 => blk: {
                if (@sizeOf(T) == 0) return std.mem.zeroes(T);

                // TODO adjust alignment of some types

                break :blk .{
                    .is_indirect = false,
                    .slot_bytes = 4,
                    .allow_higher_align = true,
                };
            },
            .x86_64 => .{
                // Assume x86_64_win calling convention.
                .is_indirect = @bitSizeOf(T) > 64 or !std.math.isPowerOfTwo(@bitSizeOf(T)),
                .slot_bytes = 8,
                .allow_higher_align = false,
            },
            else => @compileError("unimplemented"),
        };

        const ItemPtr = *T;
        const LoadPtr = if (opts.is_indirect) *ItemPtr else ItemPtr;

        // Load the current VaList value.
        const list: [*]u8 = @ptrCast(list_ptr.*);
        const casted_ptr: LoadPtr = @alignCast(@ptrCast(list));

        // Align the pointer for items with alignment bigger than the slot if
        // the calling convention allows it.
        // const byte_alignment = load_alignment.toByteUnits().?;
        const load_alignment = @alignOf(casted_ptr.*);
        const aligned_ptr: LoadPtr = if (opts.allow_higher_align and load_alignment > opts.slot_bytes)
            @ptrFromInt((@intFromPtr(casted_ptr) + load_alignment - 1) & -load_alignment)
        else
            casted_ptr;

        // Increment the item pointer and store it back.
        const load_size = @sizeOf(casted_ptr.*);
        const aligned_size = std.mem.alignForward(u64, load_size, opts.slot_bytes);
        list_ptr.* = @ptrCast(list + aligned_size);

        // On big endian targets arguments smaller than slot_bytes will be on
        // the right side of the slot.
        const align_list = (@sizeOf(T) < opts.slot_bytes and builtin.target.cpu.arch.endian() == .big) and
            (@typeInfo(T) != .@"struct" or opts.force_right_adjust);

        const item_ptr: LoadPtr = if (align_list)
            @ptrCast(@as([*]u8, @ptrCast(aligned_ptr)) + (opts.slot_bytes - @sizeOf(T)))
        else
            aligned_ptr;

        if (opts.is_indirect) {
            const direct_item_ptr = item_ptr.*;
            return direct_item_ptr.*;
        }

        return item_ptr.*;
    }
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaList = switch (builtin.cpu.arch) {
    .aarch64, .aarch64_be => switch (builtin.os.tag) {
        .windows => VaListCommon(.{}),
        .ios, .macos, .tvos, .watchos, .visionos => VaListDarwin,
        else => VaListAarch64,
    },
    .arm, .armeb, .thumb, .thumbeb => switch (builtin.os.tag) {
        .ios, .macos, .tvos, .watchos, .visionos => VaListDarwin,
        else => VaListCommon,
    },
    .amdgcn => VaListCommon,
    .avr => VaListCommon,
    .arc => VaListCommon,
    .bpfel, .bpfeb => VaListCommon,
    .hexagon => if (builtin.target.abi.isMusl()) VaListHexagon else VaListCommon,
    .loongarch32, .loongarch64 => VaListCommon,
    .mips, .mipsel, .mips64, .mips64el => VaListCommon,
    .powerpc, .powerpcle => switch (builtin.os.tag) {
        .aix => VaListAix,
        .ios, .macos, .tvos, .watchos, .visionos => VaListDarwin,
        else => VaListPowerPc,
    },
    .powerpc64, .powerpc64le => switch (builtin.os.tag) {
        .aix => VaListAix,
        else => VaListCommon,
    },
    .riscv32, .riscv64 => VaListCommon,
    .sparc, .sparc64 => VaListCommon,
    .spirv32, .spirv64 => VaListCommon,
    .s390x => VaListS390x,
    .wasm32, .wasm64 => VaListCommon,
    .x86 => VaListCommon,
    .x86_64 => switch (builtin.os.tag) {
        .windows => VaListWindows,
        else => VaListX86_64,
    },
    .xtensa => VaListXtensa,
    else => @compileError("VaList not supported for this target yet"),
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PrefetchOptions = struct {
    /// Whether the prefetch should prepare for a read or a write.
    rw: Rw = .read,
    /// The data's locality in an inclusive range from 0 to 3.
    ///
    /// 0 means no temporal locality. That is, the data can be immediately
    /// dropped from the cache after it is accessed.
    ///
    /// 3 means high temporal locality. That is, the data should be kept in
    /// the cache as it is likely to be accessed again soon.
    locality: u2 = 3,
    /// The cache that the prefetch should be performed on.
    cache: Cache = .data,

    pub const Rw = enum(u1) {
        read,
        write,
    };

    pub const Cache = enum(u1) {
        instruction,
        data,
    };
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ExportOptions = struct {
    name: []const u8,
    linkage: GlobalLinkage = .strong,
    section: ?[]const u8 = null,
    visibility: SymbolVisibility = .default,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ExternOptions = struct {
    name: []const u8,
    library_name: ?[]const u8 = null,
    linkage: GlobalLinkage = .strong,
    is_thread_local: bool = false,
    is_dll_import: bool = false,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const BranchHint = enum(u3) {
    /// Equivalent to no hint given.
    none,
    /// This branch of control flow is more likely to be reached than its peers.
    /// The optimizer should optimize for reaching it.
    likely,
    /// This branch of control flow is less likely to be reached than its peers.
    /// The optimizer should optimize for not reaching it.
    unlikely,
    /// This branch of control flow is unlikely to *ever* be reached.
    /// The optimizer may place it in a different page of memory to optimize other branches.
    cold,
    /// It is difficult to predict whether this branch of control flow will be reached.
    /// The optimizer should avoid branching behavior with expensive mispredictions.
    unpredictable,
};

/// This enum is set by the compiler and communicates which compiler backend is
/// used to produce machine code.
/// Think carefully before deciding to observe this value. Nearly all code should
/// be agnostic to the backend that implements the language. The use case
/// to use this value is to **work around problems with compiler implementations.**
///
/// Avoid failing the compilation if the compiler backend does not match a
/// whitelist of backends; rather one should detect that a known problem would
/// occur in a blacklist of backends.
///
/// The enum is nonexhaustive so that alternate Zig language implementations may
/// choose a number as their tag (please use a random number generator rather
/// than a "cute" number) and codebases can interact with these values even if
/// this upstream enum does not have a name for the number. Of course, upstream
/// is happy to accept pull requests to add Zig implementations to this enum.
///
/// This data structure is part of the Zig language specification.
pub const CompilerBackend = enum(u64) {
    /// It is allowed for a compiler implementation to not reveal its identity,
    /// in which case this value is appropriate. Be cool and make sure your
    /// code supports `other` Zig compilers!
    other = 0,
    /// The original Zig compiler created in 2015 by Andrew Kelley. Implemented
    /// in C++. Used LLVM. Deleted from the ZSF ziglang/zig codebase on
    /// December 6th, 2022.
    stage1 = 1,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// LLVM backend.
    stage2_llvm = 2,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// backend that generates C source code.
    /// Note that one can observe whether the compilation will output C code
    /// directly with `object_format` value rather than the `compiler_backend` value.
    stage2_c = 3,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// WebAssembly backend.
    stage2_wasm = 4,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// arm backend.
    stage2_arm = 5,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// x86_64 backend.
    stage2_x86_64 = 6,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// aarch64 backend.
    stage2_aarch64 = 7,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// x86 backend.
    stage2_x86 = 8,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// riscv64 backend.
    stage2_riscv64 = 9,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// sparc64 backend.
    stage2_sparc64 = 10,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// spirv backend.
    stage2_spirv64 = 11,

    _,
};

/// This function type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const TestFn = struct {
    name: []const u8,
    func: *const fn () anyerror!void,
};

/// Deprecated, use the `Panic` namespace instead.
/// To be deleted after 0.14.0 is released.
pub const PanicFn = fn ([]const u8, ?*StackTrace, ?usize) noreturn;

/// This namespace is used by the Zig compiler to emit various kinds of safety
/// panics. These can be overridden by making a public `panic` namespace in the
/// root source file.
pub const panic: type = p: {
    if (@hasDecl(root, "panic")) {
        if (@TypeOf(root.panic) != type) {
            // Deprecated; make `panic` a namespace instead.
            break :p std.debug.FullPanic(struct {
                fn panic(msg: []const u8, ra: ?usize) noreturn {
                    root.panic(msg, @errorReturnTrace(), ra);
                }
            }.panic);
        }
        break :p root.panic;
    }
    if (@hasDecl(root, "Panic")) {
        break :p root.Panic; // Deprecated; use `panic` instead.
    }
    if (builtin.zig_backend == .stage2_riscv64) {
        break :p std.debug.simple_panic;
    }
    break :p std.debug.FullPanic(std.debug.defaultPanic);
};

pub noinline fn returnError() void {
    @branchHint(.unlikely);
    @setRuntimeSafety(false);
    const st = @errorReturnTrace().?;
    if (st.index < st.instruction_addresses.len)
        st.instruction_addresses[st.index] = @returnAddress();
    st.index += 1;
}

const std = @import("std.zig");
const root = @import("root");
