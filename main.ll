%KValue = type { i64, i64 }
%parsed = type { i64, i64 }
%KBytes = type { i64, ptr }

; Inline twins of the runtime's hot one-liners (tag tests and value
; constructors). LTO declines to inline these across the .ll/.o module
; boundary, leaving a real call on every `if` condition and constructor;
; internal linkage keeps them from colliding with the runtime's own
; definitions, and alwaysinline folds them into every call site.
define internal %KValue @k_force_fast(%KValue %v) alwaysinline {
  %tag = extractvalue %KValue %v, 0
  %is = icmp eq i64 %tag, 14
  br i1 %is, label %slow, label %done
slow:
  %f = call %KValue @k_force(%KValue %v)
  ret %KValue %f
done:
  ret %KValue %v
}
@k_arena = external global ptr
@k_arena_left = external global i64
@k_stats_on = external global i32

define internal %KValue @k_b_append_byte(%KValue %acc, %KValue %x) alwaysinline {
  %atag = extractvalue %KValue %acc, 0
  %isb = icmp eq i64 %atag, 13
  br i1 %isb, label %chkx, label %slow
chkx:
  %xtag = extractvalue %KValue %x, 0
  %isi = icmp eq i64 %xtag, 0
  br i1 %isi, label %chks, label %slow
chks:
  %so = load i32, ptr @k_stats_on
  %counting = icmp ne i32 %so, 0
  br i1 %counting, label %slow, label %fast
fast:
  %bp = extractvalue %KValue %acc, 1
  %b = inttoptr i64 %bp to ptr
  %len = load i64, ptr %b
  %datap = getelementptr i8, ptr %b, i64 8
  %data = load ptr, ptr %datap
  %capp = getelementptr i8, ptr %b, i64 16
  %cap = load i64, ptr %capp
  %capneg = sub i64 0, %cap
  %isneg = icmp slt i64 %cap, 0
  %capa = select i1 %isneg, i64 %capneg, i64 %cap
  %owned = icmp ne i64 %cap, 0
  br i1 %owned, label %fr, label %slow
fr:
  %usedp = getelementptr i8, ptr %data, i64 -8
  %used = load i64, ptr %usedp
  %atfront = icmp eq i64 %used, %len
  %len1 = add i64 %len, 1
  %fits = icmp sle i64 %len1, %capa
  %ok = and i1 %atfront, %fits
  br i1 %ok, label %claim, label %slow
claim:
  %left = load i64, ptr @k_arena_left
  %has = icmp uge i64 %left, 32
  br i1 %has, label %alloc, label %slow
alloc:
  %dst = getelementptr i8, ptr %data, i64 %len
  %xv = extractvalue %KValue %x, 1
  %byte = trunc i64 %xv to i8
  store i8 %byte, ptr %dst
  store i64 %len1, ptr %usedp
  %ar = load ptr, ptr @k_arena
  %ar2 = getelementptr i8, ptr %ar, i64 32
  store ptr %ar2, ptr @k_arena
  %left2 = sub i64 %left, 32
  store i64 %left2, ptr @k_arena_left
  store i64 %len1, ptr %ar
  %hd = getelementptr i8, ptr %ar, i64 8
  store ptr %data, ptr %hd
  %hc = getelementptr i8, ptr %ar, i64 16
  store i64 %cap, ptr %hc
  %pi = ptrtoint ptr %ar to i64
  %r0 = insertvalue %KValue { i64 13, i64 undef }, i64 %pi, 1
  ret %KValue %r0
slow:
  %f = call %KValue @k_b_append(%KValue %acc, %KValue %x)
  ret %KValue %f
}
define internal %KValue @k_b_length_fast(%KValue %v) alwaysinline {
  %tag = extractvalue %KValue %v, 0
  %is_list = icmp eq i64 %tag, 9
  %is_bytes = icmp eq i64 %tag, 13
  %fastable = or i1 %is_list, %is_bytes
  br i1 %fastable, label %list, label %slow
list:
  %p = extractvalue %KValue %v, 1
  %lp = inttoptr i64 %p to ptr
  %len = load i64, ptr %lp
  %r = insertvalue %KValue { i64 0, i64 undef }, i64 %len, 1
  ret %KValue %r
slow:
  %f = call %KValue @k_b_length(%KValue %v)
  ret %KValue %f
}
define internal %KValue @k_int(i64 %n) alwaysinline {
  %v = insertvalue %KValue { i64 0, i64 undef }, i64 %n, 1
  ret %KValue %v
}
define internal %KValue @k_float(double %d) alwaysinline {
  %bits = bitcast double %d to i64
  %v = insertvalue %KValue { i64 1, i64 undef }, i64 %bits, 1
  ret %KValue %v
}
define internal %KValue @k_bool(i64 %b) alwaysinline {
  %c = icmp ne i64 %b, 0
  %tag = select i1 %c, i64 2, i64 3
  %v = insertvalue %KValue { i64 undef, i64 0 }, i64 %tag, 0
  ret %KValue %v
}
define internal %KValue @k_none() alwaysinline {
  ret %KValue { i64 4, i64 0 }
}
define internal i64 @k_not_failure(%KValue %v) alwaysinline {
  %tag = extractvalue %KValue %v, 0
  %ne = icmp ne i64 %tag, 5
  %r = zext i1 %ne to i64
  ret i64 %r
}
define internal i64 @k_truthy(%KValue %v) alwaysinline {
  %tag = extractvalue %KValue %v, 0
  %t = icmp eq i64 %tag, 2
  br i1 %t, label %yes, label %chkf
yes:
  ret i64 1
chkf:
  %f = icmp eq i64 %tag, 3
  br i1 %f, label %no, label %bad
no:
  ret i64 0
bad:
  %r = call i64 @k_truthy_bad(%KValue %v)
  ret i64 %r
}
define internal i64 @k_check_tag(%KValue %v, i64 %t) alwaysinline {
  %tag = extractvalue %KValue %v, 0
  %c = icmp eq i64 %tag, %t
  %r = zext i1 %c to i64
  ret i64 %r
}
define internal i64 @k_check_int(%KValue %v, i64 %n) alwaysinline {
  %tag = extractvalue %KValue %v, 0
  %pay = extractvalue %KValue %v, 1
  %ct = icmp eq i64 %tag, 0
  %cp = icmp eq i64 %pay, %n
  %c = and i1 %ct, %cp
  %r = zext i1 %c to i64
  ret i64 %r
}
define internal i64 @k_check_bool(%KValue %v) alwaysinline {
  %tag = extractvalue %KValue %v, 0
  %t = icmp eq i64 %tag, 2
  %f = icmp eq i64 %tag, 3
  %c = or i1 %t, %f
  %r = zext i1 %c to i64
  ret i64 %r
}
declare i64 @k_truthy_bad(%KValue)

declare %KValue @k_caf_freeze(%KValue)
declare %KValue @k_str_lit(ptr, i64, ptr)
declare %KValue @k_err(%KValue, ptr)
declare %KValue @k_err_hop(%KValue, ptr)
declare %KValue @k_rec(i64, i64, ptr)
declare %KValue @k_rec_reuse(i64, i64, ptr, %KValue)
declare %KValue @k_field(%KValue, i64)
declare %KValue @k_err_inner(%KValue)
declare i64 @k_check_rec(%KValue, i64, i64)
declare i64 @k_check_str(%KValue, ptr, i64)
declare %KValue @k_concat_arr(i64, ptr)
declare %KValue @k_render(%KValue, i64)
declare %KValue @k_add(%KValue, %KValue)
declare %KValue @k_sub(%KValue, %KValue)
declare %KValue @k_mul(%KValue, %KValue)
declare %KValue @k_div(%KValue, %KValue, ptr)
declare %KValue @k_mod(%KValue, %KValue, ptr)
declare %KValue @k_cmp(%KValue, %KValue, i64)
declare %KValue @k_desc_print(%KValue)
declare void @k_die(ptr) noreturn
declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64)
declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64)
declare { i64, i1 } @llvm.smul.with.overflow.i64(i64, i64)
declare %KValue @k_list_lit(i64, ptr)
declare %KValue @k_map_lit(i64, ptr)
declare %KValue @k_closure(ptr, i64, i64, ptr)
declare %KValue @k_env_get(ptr, i64)
declare %KValue @k_b_at(%KValue, %KValue)
declare %KValue @k_index(%KValue, %KValue, ptr)
declare %KValue @k_b_bytes(%KValue)
declare %KValue @k_b_chars(%KValue)
declare %KValue @k_b_split(%KValue, %KValue)
declare %KValue @k_b_concat(%KValue, %KValue)
declare %KValue @k_b_utf8(%KValue, ptr)
declare %KValue @k_desc_args()
declare %KValue @k_desc_stdin()
declare %KValue @k_b_read_file(%KValue)
declare %KValue @k_b_write(%KValue)
declare %KValue @k_b_write_err(%KValue)
declare %KValue @k_b_env(%KValue)
declare %KValue @k_b_exists(%KValue)
declare %KValue @k_b_is_dir(%KValue)
declare %KValue @k_b_list_dir(%KValue)
declare %KValue @k_b_make_dir(%KValue)
declare %KValue @k_b_write_file(%KValue, %KValue)
declare %KValue @k_b_run(%KValue, %KValue)
declare %KValue @k_maybe_bind(%KValue, %KValue)
declare void @k_beat_push()
declare void @k_beat_iter()
declare %KValue @k_beat_pop(%KValue)
declare %KValue @k_cohort_pop(%KValue)
declare %KValue @k_call1(%KValue, %KValue)
declare %KValue @k_call2(%KValue, %KValue, %KValue)
declare %KValue @k_b_char_code(%KValue)
declare %KValue @k_b_entries(%KValue)
declare %KValue @k_b_from_code(%KValue, ptr)
declare %KValue @k_b_join(%KValue, %KValue)
declare %KValue @k_b_length(%KValue)
declare %KValue @k_b_push(%KValue, %KValue)
declare %KValue @k_b_push_mut(%KValue, %KValue)
declare %KValue @k_b_append_mut(%KValue, %KValue)
declare %KValue @k_b_put_mut(%KValue, %KValue, %KValue)
declare %KValue @k_b_slice(%KValue, %KValue, %KValue)
declare %KValue @k_b_find2(%KValue, %KValue, %KValue, %KValue)
declare %KValue @k_b_find2_below(%KValue, %KValue, %KValue, %KValue, %KValue)
declare %KValue @k_b_append(%KValue, %KValue)
declare %KValue @k_b_to_float(%KValue, ptr)
declare %KValue @k_b_to_int(%KValue, ptr)
declare %KValue @k_b_render_value(%KValue)
declare %KValue @k_force(%KValue)

@caf_0 = internal global %KValue zeroinitializer
@caf_0_ready = internal global i8 0
@caf_1 = internal global %KValue zeroinitializer
@caf_1_ready = internal global i8 0
@caf_2 = internal global %KValue zeroinitializer
@caf_2_ready = internal global i8 0
@caf_3 = internal global %KValue zeroinitializer
@caf_3_ready = internal global i8 0
@s0 = private unnamed_addr constant [21 x i8] c"query/io/exit_status\00"
@s0_lit = internal global %KValue zeroinitializer
@s1 = private unnamed_addr constant [17 x i8] c"query/io/process\00"
@s1_lit = internal global %KValue zeroinitializer
@s2 = private unnamed_addr constant [19 x i8] c"query/list/bounded\00"
@s2_lit = internal global %KValue zeroinitializer
@s3 = private unnamed_addr constant [18 x i8] c"query/list/capped\00"
@s3_lit = internal global %KValue zeroinitializer
@s4 = private unnamed_addr constant [20 x i8] c"query/list/counting\00"
@s4_lit = internal global %KValue zeroinitializer
@s5 = private unnamed_addr constant [18 x i8] c"query/list/cursor\00"
@s5_lit = internal global %KValue zeroinitializer
@s6 = private unnamed_addr constant [18 x i8] c"query/list/cycled\00"
@s6_lit = internal global %KValue zeroinitializer
@s7 = private unnamed_addr constant [16 x i8] c"query/list/done\00"
@s7_lit = internal global %KValue zeroinitializer
@s8 = private unnamed_addr constant [17 x i8] c"query/list/grown\00"
@s8_lit = internal global %KValue zeroinitializer
@s9 = private unnamed_addr constant [18 x i8] c"query/list/mapped\00"
@s9_lit = internal global %KValue zeroinitializer
@s10 = private unnamed_addr constant [19 x i8] c"query/list/missing\00"
@s10_lit = internal global %KValue zeroinitializer
@s11 = private unnamed_addr constant [18 x i8] c"query/list/paired\00"
@s11_lit = internal global %KValue zeroinitializer
@s12 = private unnamed_addr constant [20 x i8] c"query/list/repeated\00"
@s12_lit = internal global %KValue zeroinitializer
@s13 = private unnamed_addr constant [18 x i8] c"query/list/sifted\00"
@s13_lit = internal global %KValue zeroinitializer
@s14 = private unnamed_addr constant [19 x i8] c"query/list/skipped\00"
@s14_lit = internal global %KValue zeroinitializer
@s15 = private unnamed_addr constant [18 x i8] c"query/list/sorted\00"
@s15_lit = internal global %KValue zeroinitializer
@s16 = private unnamed_addr constant [16 x i8] c"query/list/step\00"
@s16_lit = internal global %KValue zeroinitializer
@s17 = private unnamed_addr constant [13 x i8] c"query/defect\00"
@s17_lit = internal global %KValue zeroinitializer
@s18 = private unnamed_addr constant [16 x i8] c"query/json_null\00"
@s18_lit = internal global %KValue zeroinitializer
@s19 = private unnamed_addr constant [20 x i8] c"query/parse_failure\00"
@s19_lit = internal global %KValue zeroinitializer
@s20 = private unnamed_addr constant [13 x i8] c"query/parsed\00"
@s20_lit = internal global %KValue zeroinitializer
@s21 = private unnamed_addr constant [15 x i8] c"io/exit_status\00"
@s21_lit = internal global %KValue zeroinitializer
@s22 = private unnamed_addr constant [11 x i8] c"io/process\00"
@s22_lit = internal global %KValue zeroinitializer
@s23 = private unnamed_addr constant [6 x i8] c"entry\00"
@s23_lit = internal global %KValue zeroinitializer
@s24 = private unnamed_addr constant [7 x i8] c"record\00"
@s24_lit = internal global %KValue zeroinitializer
@s25 = private unnamed_addr constant [1 x i8] c"\00"
@s25_lit = internal global %KValue zeroinitializer
@s26 = private unnamed_addr constant [4 x i8] c"key\00"
@s26_lit = internal global %KValue zeroinitializer
@s27 = private unnamed_addr constant [6 x i8] c"value\00"
@s27_lit = internal global %KValue zeroinitializer
@s28 = private unnamed_addr constant [5 x i8] c"code\00"
@s28_lit = internal global %KValue zeroinitializer
@s29 = private unnamed_addr constant [7 x i8] c"status\00"
@s29_lit = internal global %KValue zeroinitializer
@s30 = private unnamed_addr constant [7 x i8] c"stderr\00"
@s30_lit = internal global %KValue zeroinitializer
@s31 = private unnamed_addr constant [7 x i8] c"stdout\00"
@s31_lit = internal global %KValue zeroinitializer
@s32 = private unnamed_addr constant [3 x i8] c"at\00"
@s32_lit = internal global %KValue zeroinitializer
@s33 = private unnamed_addr constant [5 x i8] c"stop\00"
@s33_lit = internal global %KValue zeroinitializer
@s34 = private unnamed_addr constant [7 x i8] c"source\00"
@s34_lit = internal global %KValue zeroinitializer
@s35 = private unnamed_addr constant [5 x i8] c"left\00"
@s35_lit = internal global %KValue zeroinitializer
@s36 = private unnamed_addr constant [8 x i8] c"drained\00"
@s36_lit = internal global %KValue zeroinitializer
@s37 = private unnamed_addr constant [5 x i8] c"seed\00"
@s37_lit = internal global %KValue zeroinitializer
@s38 = private unnamed_addr constant [8 x i8] c"stretch\00"
@s38_lit = internal global %KValue zeroinitializer
@s39 = private unnamed_addr constant [6 x i8] c"shape\00"
@s39_lit = internal global %KValue zeroinitializer
@s40 = private unnamed_addr constant [8 x i8] c"unfound\00"
@s40_lit = internal global %KValue zeroinitializer
@s41 = private unnamed_addr constant [6 x i8] c"right\00"
@s41_lit = internal global %KValue zeroinitializer
@s42 = private unnamed_addr constant [5 x i8] c"keep\00"
@s42_lit = internal global %KValue zeroinitializer
@s43 = private unnamed_addr constant [5 x i8] c"test\00"
@s43_lit = internal global %KValue zeroinitializer
@s44 = private unnamed_addr constant [5 x i8] c"burn\00"
@s44_lit = internal global %KValue zeroinitializer
@s45 = private unnamed_addr constant [6 x i8] c"items\00"
@s45_lit = internal global %KValue zeroinitializer
@s46 = private unnamed_addr constant [5 x i8] c"elem\00"
@s46_lit = internal global %KValue zeroinitializer
@s47 = private unnamed_addr constant [5 x i8] c"rest\00"
@s47_lit = internal global %KValue zeroinitializer
@s48 = private unnamed_addr constant [7 x i8] c"reason\00"
@s48_lit = internal global %KValue zeroinitializer
@s49 = private unnamed_addr constant [9 x i8] c"position\00"
@s49_lit = internal global %KValue zeroinitializer
@s50 = private unnamed_addr constant [4 x i8] c"pos\00"
@s50_lit = internal global %KValue zeroinitializer
@s51 = private unnamed_addr constant [14 x i8] c"query/io/args\00"
@s51_lit = internal global %KValue zeroinitializer
@s52 = private unnamed_addr constant [55 x i8] c"no overload of `query/io/args` matches these arguments\00"
@s52_lit = internal global %KValue zeroinitializer
@s53 = private unnamed_addr constant [13 x i8] c"query/io/env\00"
@s53_lit = internal global %KValue zeroinitializer
@s54 = private unnamed_addr constant [54 x i8] c"no overload of `query/io/env` matches these arguments\00"
@s54_lit = internal global %KValue zeroinitializer
@s55 = private unnamed_addr constant [14 x i8] c"query/io/exit\00"
@s55_lit = internal global %KValue zeroinitializer
@s56 = private unnamed_addr constant [34 x i8] c"query/io/exit at std/io/io.kso:23\00"
@s56_lit = internal global %KValue zeroinitializer
@s57 = private unnamed_addr constant [55 x i8] c"no overload of `query/io/exit` matches these arguments\00"
@s57_lit = internal global %KValue zeroinitializer
@s58 = private unnamed_addr constant [16 x i8] c"query/io/exists\00"
@s58_lit = internal global %KValue zeroinitializer
@s59 = private unnamed_addr constant [57 x i8] c"no overload of `query/io/exists` matches these arguments\00"
@s59_lit = internal global %KValue zeroinitializer
@s60 = private unnamed_addr constant [16 x i8] c"query/io/is_dir\00"
@s60_lit = internal global %KValue zeroinitializer
@s61 = private unnamed_addr constant [57 x i8] c"no overload of `query/io/is_dir` matches these arguments\00"
@s61_lit = internal global %KValue zeroinitializer
@s62 = private unnamed_addr constant [18 x i8] c"query/io/list_dir\00"
@s62_lit = internal global %KValue zeroinitializer
@s63 = private unnamed_addr constant [59 x i8] c"no overload of `query/io/list_dir` matches these arguments\00"
@s63_lit = internal global %KValue zeroinitializer
@s64 = private unnamed_addr constant [19 x i8] c"query/io/read_file\00"
@s64_lit = internal global %KValue zeroinitializer
@s65 = private unnamed_addr constant [60 x i8] c"no overload of `query/io/read_file` matches these arguments\00"
@s65_lit = internal global %KValue zeroinitializer
@s66 = private unnamed_addr constant [13 x i8] c"query/io/run\00"
@s66_lit = internal global %KValue zeroinitializer
@s67 = private unnamed_addr constant [54 x i8] c"no overload of `query/io/run` matches these arguments\00"
@s67_lit = internal global %KValue zeroinitializer
@s68 = private unnamed_addr constant [18 x i8] c"query/io/answered\00"
@s68_lit = internal global %KValue zeroinitializer
@s69 = private unnamed_addr constant [38 x i8] c"query/io/answered at std/io/io.kso:55\00"
@s69_lit = internal global %KValue zeroinitializer
@s70 = private unnamed_addr constant [59 x i8] c"no overload of `query/io/answered` matches these arguments\00"
@s70_lit = internal global %KValue zeroinitializer
@s71 = private unnamed_addr constant [15 x i8] c"query/io/stdin\00"
@s71_lit = internal global %KValue zeroinitializer
@s72 = private unnamed_addr constant [56 x i8] c"no overload of `query/io/stdin` matches these arguments\00"
@s72_lit = internal global %KValue zeroinitializer
@s73 = private unnamed_addr constant [15 x i8] c"query/io/write\00"
@s73_lit = internal global %KValue zeroinitializer
@s74 = private unnamed_addr constant [56 x i8] c"no overload of `query/io/write` matches these arguments\00"
@s74_lit = internal global %KValue zeroinitializer
@s75 = private unnamed_addr constant [19 x i8] c"query/io/write_err\00"
@s75_lit = internal global %KValue zeroinitializer
@s76 = private unnamed_addr constant [60 x i8] c"no overload of `query/io/write_err` matches these arguments\00"
@s76_lit = internal global %KValue zeroinitializer
@s77 = private unnamed_addr constant [18 x i8] c"query/io/make_dir\00"
@s77_lit = internal global %KValue zeroinitializer
@s78 = private unnamed_addr constant [59 x i8] c"no overload of `query/io/make_dir` matches these arguments\00"
@s78_lit = internal global %KValue zeroinitializer
@s79 = private unnamed_addr constant [20 x i8] c"query/io/write_file\00"
@s79_lit = internal global %KValue zeroinitializer
@s80 = private unnamed_addr constant [61 x i8] c"no overload of `query/io/write_file` matches these arguments\00"
@s80_lit = internal global %KValue zeroinitializer
@s81 = private unnamed_addr constant [16 x i8] c"query/list/all?\00"
@s81_lit = internal global %KValue zeroinitializer
@s82 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/all?` matches these arguments\00"
@s82_lit = internal global %KValue zeroinitializer
@s83 = private unnamed_addr constant [22 x i8] c"query/list/holds_all?\00"
@s83_lit = internal global %KValue zeroinitializer
@s84 = private unnamed_addr constant [63 x i8] c"no overload of `query/list/holds_all?` matches these arguments\00"
@s84_lit = internal global %KValue zeroinitializer
@s85 = private unnamed_addr constant [16 x i8] c"query/list/any?\00"
@s85_lit = internal global %KValue zeroinitializer
@s86 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/any?` matches these arguments\00"
@s86_lit = internal global %KValue zeroinitializer
@s87 = private unnamed_addr constant [22 x i8] c"query/list/holds_any?\00"
@s87_lit = internal global %KValue zeroinitializer
@s88 = private unnamed_addr constant [63 x i8] c"no overload of `query/list/holds_any?` matches these arguments\00"
@s88_lit = internal global %KValue zeroinitializer
@s89 = private unnamed_addr constant [18 x i8] c"query/list/argmax\00"
@s89_lit = internal global %KValue zeroinitializer
@s90 = private unnamed_addr constant [59 x i8] c"no overload of `query/list/argmax` matches these arguments\00"
@s90_lit = internal global %KValue zeroinitializer
@s91 = private unnamed_addr constant [18 x i8] c"query/list/argmin\00"
@s91_lit = internal global %KValue zeroinitializer
@s92 = private unnamed_addr constant [59 x i8] c"no overload of `query/list/argmin` matches these arguments\00"
@s92_lit = internal global %KValue zeroinitializer
@s93 = private unnamed_addr constant [18 x i8] c"query/list/bisect\00"
@s93_lit = internal global %KValue zeroinitializer
@s94 = private unnamed_addr constant [71 x i8] c"integer overflow (int64 native build; spec int is arbitrary precision)\00"
@s94_lit = internal global %KValue zeroinitializer
@s95 = private unnamed_addr constant [42 x i8] c"query/list/bisect at std/list/list.kso:86\00"
@s95_lit = internal global %KValue zeroinitializer
@s96 = private unnamed_addr constant [42 x i8] c"query/list/bisect at std/list/list.kso:87\00"
@s96_lit = internal global %KValue zeroinitializer
@s97 = private unnamed_addr constant [59 x i8] c"no overload of `query/list/bisect` matches these arguments\00"
@s97_lit = internal global %KValue zeroinitializer
@s98 = private unnamed_addr constant [16 x i8] c"query/list/bump\00"
@s98_lit = internal global %KValue zeroinitializer
@s99 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/bump` matches these arguments\00"
@s99_lit = internal global %KValue zeroinitializer
@s100 = private unnamed_addr constant [17 x i8] c"query/list/count\00"
@s100_lit = internal global %KValue zeroinitializer
@s101 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/count` matches these arguments\00"
@s101_lit = internal global %KValue zeroinitializer
@s102 = private unnamed_addr constant [17 x i8] c"query/list/cycle\00"
@s102_lit = internal global %KValue zeroinitializer
@s103 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/cycle` matches these arguments\00"
@s103_lit = internal global %KValue zeroinitializer
@s104 = private unnamed_addr constant [16 x i8] c"query/list/drop\00"
@s104_lit = internal global %KValue zeroinitializer
@s105 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/drop` matches these arguments\00"
@s105_lit = internal global %KValue zeroinitializer
@s106 = private unnamed_addr constant [16 x i8] c"query/list/find\00"
@s106_lit = internal global %KValue zeroinitializer
@s107 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/find` matches these arguments\00"
@s107_lit = internal global %KValue zeroinitializer
@s108 = private unnamed_addr constant [20 x i8] c"query/list/found_in\00"
@s108_lit = internal global %KValue zeroinitializer
@s109 = private unnamed_addr constant [61 x i8] c"no overload of `query/list/found_in` matches these arguments\00"
@s109_lit = internal global %KValue zeroinitializer
@s110 = private unnamed_addr constant [17 x i8] c"query/list/first\00"
@s110_lit = internal global %KValue zeroinitializer
@s111 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/first` matches these arguments\00"
@s111_lit = internal global %KValue zeroinitializer
@s112 = private unnamed_addr constant [20 x i8] c"query/list/first_of\00"
@s112_lit = internal global %KValue zeroinitializer
@s113 = private unnamed_addr constant [61 x i8] c"no overload of `query/list/first_of` matches these arguments\00"
@s113_lit = internal global %KValue zeroinitializer
@s114 = private unnamed_addr constant [16 x i8] c"query/list/fold\00"
@s114_lit = internal global %KValue zeroinitializer
@s115 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/fold` matches these arguments\00"
@s115_lit = internal global %KValue zeroinitializer
@s116 = private unnamed_addr constant [24 x i8] c"query/list/bounded_flat\00"
@s116_lit = internal global %KValue zeroinitializer
@s117 = private unnamed_addr constant [65 x i8] c"no overload of `query/list/bounded_flat` matches these arguments\00"
@s117_lit = internal global %KValue zeroinitializer
@s118 = private unnamed_addr constant [24 x i8] c"query/list/bounded_more\00"
@s118_lit = internal global %KValue zeroinitializer
@s119 = private unnamed_addr constant [65 x i8] c"no overload of `query/list/bounded_more` matches these arguments\00"
@s119_lit = internal global %KValue zeroinitializer
@s120 = private unnamed_addr constant [24 x i8] c"query/list/bounded_step\00"
@s120_lit = internal global %KValue zeroinitializer
@s121 = private unnamed_addr constant [49 x i8] c"query/list/bounded_step at std/list/list.kso:146\00"
@s121_lit = internal global %KValue zeroinitializer
@s122 = private unnamed_addr constant [65 x i8] c"no overload of `query/list/bounded_step` matches these arguments\00"
@s122_lit = internal global %KValue zeroinitializer
@s123 = private unnamed_addr constant [21 x i8] c"query/list/fold_flat\00"
@s123_lit = internal global %KValue zeroinitializer
@s124 = private unnamed_addr constant [46 x i8] c"query/list/fold_flat at std/list/list.kso:182\00"
@s124_lit = internal global %KValue zeroinitializer
@s125 = private unnamed_addr constant [62 x i8] c"no overload of `query/list/fold_flat` matches these arguments\00"
@s125_lit = internal global %KValue zeroinitializer
@s126 = private unnamed_addr constant [19 x i8] c"query/list/fold_go\00"
@s126_lit = internal global %KValue zeroinitializer
@s127 = private unnamed_addr constant [60 x i8] c"no overload of `query/list/fold_go` matches these arguments\00"
@s127_lit = internal global %KValue zeroinitializer
@s128 = private unnamed_addr constant [18 x i8] c"query/list/bucket\00"
@s128_lit = internal global %KValue zeroinitializer
@s129 = private unnamed_addr constant [59 x i8] c"no overload of `query/list/bucket` matches these arguments\00"
@s129_lit = internal global %KValue zeroinitializer
@s130 = private unnamed_addr constant [20 x i8] c"query/list/group_by\00"
@s130_lit = internal global %KValue zeroinitializer
@s131 = private unnamed_addr constant [61 x i8] c"no overload of `query/list/group_by` matches these arguments\00"
@s131_lit = internal global %KValue zeroinitializer
@s132 = private unnamed_addr constant [22 x i8] c"query/list/file_under\00"
@s132_lit = internal global %KValue zeroinitializer
@s133 = private unnamed_addr constant [63 x i8] c"no overload of `query/list/file_under` matches these arguments\00"
@s133_lit = internal global %KValue zeroinitializer
@s134 = private unnamed_addr constant [20 x i8] c"query/list/index_by\00"
@s134_lit = internal global %KValue zeroinitializer
@s135 = private unnamed_addr constant [61 x i8] c"no overload of `query/list/index_by` matches these arguments\00"
@s135_lit = internal global %KValue zeroinitializer
@s136 = private unnamed_addr constant [16 x i8] c"query/list/iter\00"
@s136_lit = internal global %KValue zeroinitializer
@s137 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/iter` matches these arguments\00"
@s137_lit = internal global %KValue zeroinitializer
@s138 = private unnamed_addr constant [19 x i8] c"query/list/iterate\00"
@s138_lit = internal global %KValue zeroinitializer
@s139 = private unnamed_addr constant [60 x i8] c"no overload of `query/list/iterate` matches these arguments\00"
@s139_lit = internal global %KValue zeroinitializer
@s140 = private unnamed_addr constant [22 x i8] c"query/list/join_parts\00"
@s140_lit = internal global %KValue zeroinitializer
@s141 = private unnamed_addr constant [63 x i8] c"no overload of `query/list/join_parts` matches these arguments\00"
@s141_lit = internal global %KValue zeroinitializer
@s142 = private unnamed_addr constant [16 x i8] c"query/list/last\00"
@s142_lit = internal global %KValue zeroinitializer
@s143 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/last` matches these arguments\00"
@s143_lit = internal global %KValue zeroinitializer
@s144 = private unnamed_addr constant [15 x i8] c"query/list/map\00"
@s144_lit = internal global %KValue zeroinitializer
@s145 = private unnamed_addr constant [56 x i8] c"no overload of `query/list/map` matches these arguments\00"
@s145_lit = internal global %KValue zeroinitializer
@s146 = private unnamed_addr constant [15 x i8] c"query/list/max\00"
@s146_lit = internal global %KValue zeroinitializer
@s147 = private unnamed_addr constant [56 x i8] c"no overload of `query/list/max` matches these arguments\00"
@s147_lit = internal global %KValue zeroinitializer
@s148 = private unnamed_addr constant [16 x i8] c"query/list/mean\00"
@s148_lit = internal global %KValue zeroinitializer
@s149 = private unnamed_addr constant [41 x i8] c"query/list/mean at std/list/list.kso:259\00"
@s149_lit = internal global %KValue zeroinitializer
@s150 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/mean` matches these arguments\00"
@s150_lit = internal global %KValue zeroinitializer
@s151 = private unnamed_addr constant [15 x i8] c"query/list/min\00"
@s151_lit = internal global %KValue zeroinitializer
@s152 = private unnamed_addr constant [56 x i8] c"no overload of `query/list/min` matches these arguments\00"
@s152_lit = internal global %KValue zeroinitializer
@s153 = private unnamed_addr constant [20 x i8] c"query/list/naturals\00"
@s153_lit = internal global %KValue zeroinitializer
@s154 = private unnamed_addr constant [61 x i8] c"no overload of `query/list/naturals` matches these arguments\00"
@s154_lit = internal global %KValue zeroinitializer
@s155 = private unnamed_addr constant [16 x i8] c"query/list/next\00"
@s155_lit = internal global %KValue zeroinitializer
@s156 = private unnamed_addr constant [41 x i8] c"query/list/next at std/list/list.kso:290\00"
@s156_lit = internal global %KValue zeroinitializer
@s157 = private unnamed_addr constant [41 x i8] c"query/list/next at std/list/list.kso:294\00"
@s157_lit = internal global %KValue zeroinitializer
@s158 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/next` matches these arguments\00"
@s158_lit = internal global %KValue zeroinitializer
@s159 = private unnamed_addr constant [24 x i8] c"query/list/next_bounded\00"
@s159_lit = internal global %KValue zeroinitializer
@s160 = private unnamed_addr constant [49 x i8] c"query/list/next_bounded at std/list/list.kso:280\00"
@s160_lit = internal global %KValue zeroinitializer
@s161 = private unnamed_addr constant [65 x i8] c"no overload of `query/list/next_bounded` matches these arguments\00"
@s161_lit = internal global %KValue zeroinitializer
@s162 = private unnamed_addr constant [23 x i8] c"query/list/next_capped\00"
@s162_lit = internal global %KValue zeroinitializer
@s163 = private unnamed_addr constant [64 x i8] c"no overload of `query/list/next_capped` matches these arguments\00"
@s163_lit = internal global %KValue zeroinitializer
@s164 = private unnamed_addr constant [23 x i8] c"query/list/next_mapped\00"
@s164_lit = internal global %KValue zeroinitializer
@s165 = private unnamed_addr constant [64 x i8] c"no overload of `query/list/next_mapped` matches these arguments\00"
@s165_lit = internal global %KValue zeroinitializer
@s166 = private unnamed_addr constant [23 x i8] c"query/list/next_paired\00"
@s166_lit = internal global %KValue zeroinitializer
@s167 = private unnamed_addr constant [64 x i8] c"no overload of `query/list/next_paired` matches these arguments\00"
@s167_lit = internal global %KValue zeroinitializer
@s168 = private unnamed_addr constant [23 x i8] c"query/list/next_sifted\00"
@s168_lit = internal global %KValue zeroinitializer
@s169 = private unnamed_addr constant [64 x i8] c"no overload of `query/list/next_sifted` matches these arguments\00"
@s169_lit = internal global %KValue zeroinitializer
@s170 = private unnamed_addr constant [24 x i8] c"query/list/next_skipped\00"
@s170_lit = internal global %KValue zeroinitializer
@s171 = private unnamed_addr constant [65 x i8] c"no overload of `query/list/next_skipped` matches these arguments\00"
@s171_lit = internal global %KValue zeroinitializer
@s172 = private unnamed_addr constant [19 x i8] c"query/list/outrank\00"
@s172_lit = internal global %KValue zeroinitializer
@s173 = private unnamed_addr constant [60 x i8] c"no overload of `query/list/outrank` matches these arguments\00"
@s173_lit = internal global %KValue zeroinitializer
@s174 = private unnamed_addr constant [22 x i8] c"query/list/outrank_by\00"
@s174_lit = internal global %KValue zeroinitializer
@s175 = private unnamed_addr constant [63 x i8] c"no overload of `query/list/outrank_by` matches these arguments\00"
@s175_lit = internal global %KValue zeroinitializer
@s176 = private unnamed_addr constant [17 x i8] c"query/list/range\00"
@s176_lit = internal global %KValue zeroinitializer
@s177 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/range` matches these arguments\00"
@s177_lit = internal global %KValue zeroinitializer
@s178 = private unnamed_addr constant [18 x i8] c"query/list/spread\00"
@s178_lit = internal global %KValue zeroinitializer
@s179 = private unnamed_addr constant [59 x i8] c"no overload of `query/list/spread` matches these arguments\00"
@s179_lit = internal global %KValue zeroinitializer
@s180 = private unnamed_addr constant [18 x i8] c"query/list/reject\00"
@s180_lit = internal global %KValue zeroinitializer
@s181 = private unnamed_addr constant [59 x i8] c"no overload of `query/list/reject` matches these arguments\00"
@s181_lit = internal global %KValue zeroinitializer
@s182 = private unnamed_addr constant [18 x i8] c"query/list/repeat\00"
@s182_lit = internal global %KValue zeroinitializer
@s183 = private unnamed_addr constant [59 x i8] c"no overload of `query/list/repeat` matches these arguments\00"
@s183_lit = internal global %KValue zeroinitializer
@s184 = private unnamed_addr constant [18 x i8] c"query/list/select\00"
@s184_lit = internal global %KValue zeroinitializer
@s185 = private unnamed_addr constant [59 x i8] c"no overload of `query/list/select` matches these arguments\00"
@s185_lit = internal global %KValue zeroinitializer
@s186 = private unnamed_addr constant [20 x i8] c"query/list/skip_one\00"
@s186_lit = internal global %KValue zeroinitializer
@s187 = private unnamed_addr constant [61 x i8] c"no overload of `query/list/skip_one` matches these arguments\00"
@s187_lit = internal global %KValue zeroinitializer
@s188 = private unnamed_addr constant [16 x i8] c"query/list/sort\00"
@s188_lit = internal global %KValue zeroinitializer
@s189 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/sort` matches these arguments\00"
@s189_lit = internal global %KValue zeroinitializer
@s190 = private unnamed_addr constant [17 x i8] c"query/list/msort\00"
@s190_lit = internal global %KValue zeroinitializer
@s191 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/msort` matches these arguments\00"
@s191_lit = internal global %KValue zeroinitializer
@s192 = private unnamed_addr constant [17 x i8] c"query/list/whole\00"
@s192_lit = internal global %KValue zeroinitializer
@s193 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/whole` matches these arguments\00"
@s193_lit = internal global %KValue zeroinitializer
@s194 = private unnamed_addr constant [16 x i8] c"query/list/span\00"
@s194_lit = internal global %KValue zeroinitializer
@s195 = private unnamed_addr constant [41 x i8] c"query/list/span at std/list/list.kso:407\00"
@s195_lit = internal global %KValue zeroinitializer
@s196 = private unnamed_addr constant [41 x i8] c"query/list/span at std/list/list.kso:410\00"
@s196_lit = internal global %KValue zeroinitializer
@s197 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/span` matches these arguments\00"
@s197_lit = internal global %KValue zeroinitializer
@s198 = private unnamed_addr constant [17 x i8] c"query/list/merge\00"
@s198_lit = internal global %KValue zeroinitializer
@s199 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/merge` matches these arguments\00"
@s199_lit = internal global %KValue zeroinitializer
@s200 = private unnamed_addr constant [20 x i8] c"query/list/merge_on\00"
@s200_lit = internal global %KValue zeroinitializer
@s201 = private unnamed_addr constant [61 x i8] c"no overload of `query/list/merge_on` matches these arguments\00"
@s201_lit = internal global %KValue zeroinitializer
@s202 = private unnamed_addr constant [16 x i8] c"query/list/pick\00"
@s202_lit = internal global %KValue zeroinitializer
@s203 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/pick` matches these arguments\00"
@s203_lit = internal global %KValue zeroinitializer
@s204 = private unnamed_addr constant [19 x i8] c"query/list/advance\00"
@s204_lit = internal global %KValue zeroinitializer
@s205 = private unnamed_addr constant [60 x i8] c"no overload of `query/list/advance` matches these arguments\00"
@s205_lit = internal global %KValue zeroinitializer
@s206 = private unnamed_addr constant [17 x i8] c"query/list/drain\00"
@s206_lit = internal global %KValue zeroinitializer
@s207 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/drain` matches these arguments\00"
@s207_lit = internal global %KValue zeroinitializer
@s208 = private unnamed_addr constant [15 x i8] c"query/list/sum\00"
@s208_lit = internal global %KValue zeroinitializer
@s209 = private unnamed_addr constant [56 x i8] c"no overload of `query/list/sum` matches these arguments\00"
@s209_lit = internal global %KValue zeroinitializer
@s210 = private unnamed_addr constant [16 x i8] c"query/list/take\00"
@s210_lit = internal global %KValue zeroinitializer
@s211 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/take` matches these arguments\00"
@s211_lit = internal global %KValue zeroinitializer
@s212 = private unnamed_addr constant [17 x i8] c"query/list/tally\00"
@s212_lit = internal global %KValue zeroinitializer
@s213 = private unnamed_addr constant [58 x i8] c"no overload of `query/list/tally` matches these arguments\00"
@s213_lit = internal global %KValue zeroinitializer
@s214 = private unnamed_addr constant [19 x i8] c"query/list/to_list\00"
@s214_lit = internal global %KValue zeroinitializer
@s215 = private unnamed_addr constant [60 x i8] c"no overload of `query/list/to_list` matches these arguments\00"
@s215_lit = internal global %KValue zeroinitializer
@s216 = private unnamed_addr constant [21 x i8] c"query/list/underrank\00"
@s216_lit = internal global %KValue zeroinitializer
@s217 = private unnamed_addr constant [62 x i8] c"no overload of `query/list/underrank` matches these arguments\00"
@s217_lit = internal global %KValue zeroinitializer
@s218 = private unnamed_addr constant [24 x i8] c"query/list/underrank_by\00"
@s218_lit = internal global %KValue zeroinitializer
@s219 = private unnamed_addr constant [65 x i8] c"no overload of `query/list/underrank_by` matches these arguments\00"
@s219_lit = internal global %KValue zeroinitializer
@s220 = private unnamed_addr constant [24 x i8] c"query/list/unwrap_found\00"
@s220_lit = internal global %KValue zeroinitializer
@s221 = private unnamed_addr constant [65 x i8] c"no overload of `query/list/unwrap_found` matches these arguments\00"
@s221_lit = internal global %KValue zeroinitializer
@s222 = private unnamed_addr constant [16 x i8] c"query/list/to_h\00"
@s222_lit = internal global %KValue zeroinitializer
@s223 = private unnamed_addr constant [41 x i8] c"query/list/to_h at std/list/list.kso:468\00"
@s223_lit = internal global %KValue zeroinitializer
@s224 = private unnamed_addr constant [57 x i8] c"no overload of `query/list/to_h` matches these arguments\00"
@s224_lit = internal global %KValue zeroinitializer
@s225 = private unnamed_addr constant [26 x i8] c"query/list/transform_keys\00"
@s225_lit = internal global %KValue zeroinitializer
@s226 = private unnamed_addr constant [67 x i8] c"no overload of `query/list/transform_keys` matches these arguments\00"
@s226_lit = internal global %KValue zeroinitializer
@s227 = private unnamed_addr constant [23 x i8] c"query/list/put_renamed\00"
@s227_lit = internal global %KValue zeroinitializer
@s228 = private unnamed_addr constant [64 x i8] c"no overload of `query/list/put_renamed` matches these arguments\00"
@s228_lit = internal global %KValue zeroinitializer
@s229 = private unnamed_addr constant [28 x i8] c"query/list/transform_values\00"
@s229_lit = internal global %KValue zeroinitializer
@s230 = private unnamed_addr constant [69 x i8] c"no overload of `query/list/transform_values` matches these arguments\00"
@s230_lit = internal global %KValue zeroinitializer
@s231 = private unnamed_addr constant [22 x i8] c"query/list/put_shaped\00"
@s231_lit = internal global %KValue zeroinitializer
@s232 = private unnamed_addr constant [63 x i8] c"no overload of `query/list/put_shaped` matches these arguments\00"
@s232_lit = internal global %KValue zeroinitializer
@s233 = private unnamed_addr constant [15 x i8] c"query/list/zip\00"
@s233_lit = internal global %KValue zeroinitializer
@s234 = private unnamed_addr constant [56 x i8] c"no overload of `query/list/zip` matches these arguments\00"
@s234_lit = internal global %KValue zeroinitializer
@s235 = private unnamed_addr constant [20 x i8] c"query/list/next_zip\00"
@s235_lit = internal global %KValue zeroinitializer
@s236 = private unnamed_addr constant [61 x i8] c"no overload of `query/list/next_zip` matches these arguments\00"
@s236_lit = internal global %KValue zeroinitializer
@s237 = private unnamed_addr constant [18 x i8] c"query/text/append\00"
@s237_lit = internal global %KValue zeroinitializer
@s238 = private unnamed_addr constant [59 x i8] c"no overload of `query/text/append` matches these arguments\00"
@s238_lit = internal global %KValue zeroinitializer
@s239 = private unnamed_addr constant [17 x i8] c"query/text/bytes\00"
@s239_lit = internal global %KValue zeroinitializer
@s240 = private unnamed_addr constant [58 x i8] c"no overload of `query/text/bytes` matches these arguments\00"
@s240_lit = internal global %KValue zeroinitializer
@s241 = private unnamed_addr constant [21 x i8] c"query/text/char_code\00"
@s241_lit = internal global %KValue zeroinitializer
@s242 = private unnamed_addr constant [62 x i8] c"no overload of `query/text/char_code` matches these arguments\00"
@s242_lit = internal global %KValue zeroinitializer
@s243 = private unnamed_addr constant [17 x i8] c"query/text/chars\00"
@s243_lit = internal global %KValue zeroinitializer
@s244 = private unnamed_addr constant [58 x i8] c"no overload of `query/text/chars` matches these arguments\00"
@s244_lit = internal global %KValue zeroinitializer
@s245 = private unnamed_addr constant [18 x i8] c"query/text/concat\00"
@s245_lit = internal global %KValue zeroinitializer
@s246 = private unnamed_addr constant [59 x i8] c"no overload of `query/text/concat` matches these arguments\00"
@s246_lit = internal global %KValue zeroinitializer
@s247 = private unnamed_addr constant [17 x i8] c"query/text/find2\00"
@s247_lit = internal global %KValue zeroinitializer
@s248 = private unnamed_addr constant [58 x i8] c"no overload of `query/text/find2` matches these arguments\00"
@s248_lit = internal global %KValue zeroinitializer
@s249 = private unnamed_addr constant [23 x i8] c"query/text/find2_below\00"
@s249_lit = internal global %KValue zeroinitializer
@s250 = private unnamed_addr constant [64 x i8] c"no overload of `query/text/find2_below` matches these arguments\00"
@s250_lit = internal global %KValue zeroinitializer
@s251 = private unnamed_addr constant [21 x i8] c"query/text/from_code\00"
@s251_lit = internal global %KValue zeroinitializer
@s252 = private unnamed_addr constant [45 x i8] c"query/text/from_code at std/text/text.kso:23\00"
@s252_lit = internal global %KValue zeroinitializer
@s253 = private unnamed_addr constant [62 x i8] c"no overload of `query/text/from_code` matches these arguments\00"
@s253_lit = internal global %KValue zeroinitializer
@s254 = private unnamed_addr constant [16 x i8] c"query/text/join\00"
@s254_lit = internal global %KValue zeroinitializer
@s255 = private unnamed_addr constant [57 x i8] c"no overload of `query/text/join` matches these arguments\00"
@s255_lit = internal global %KValue zeroinitializer
@s256 = private unnamed_addr constant [17 x i8] c"query/text/slice\00"
@s256_lit = internal global %KValue zeroinitializer
@s257 = private unnamed_addr constant [58 x i8] c"no overload of `query/text/slice` matches these arguments\00"
@s257_lit = internal global %KValue zeroinitializer
@s258 = private unnamed_addr constant [17 x i8] c"query/text/split\00"
@s258_lit = internal global %KValue zeroinitializer
@s259 = private unnamed_addr constant [0 x i8] c""
@s259_lit = internal global %KValue zeroinitializer
@s260 = private unnamed_addr constant [58 x i8] c"split needs a separator; text/chars answers the characters"
@s260_lit = internal global %KValue zeroinitializer
@s261 = private unnamed_addr constant [41 x i8] c"query/text/split at std/text/text.kso:35\00"
@s261_lit = internal global %KValue zeroinitializer
@s262 = private unnamed_addr constant [58 x i8] c"no overload of `query/text/split` matches these arguments\00"
@s262_lit = internal global %KValue zeroinitializer
@s263 = private unnamed_addr constant [20 x i8] c"query/text/padding?\00"
@s263_lit = internal global %KValue zeroinitializer
@s264 = private unnamed_addr constant [4 x i8] c" \09\0A\0D"
@s264_lit = internal global %KValue zeroinitializer
@s265 = private unnamed_addr constant [61 x i8] c"no overload of `query/text/padding?` matches these arguments\00"
@s265_lit = internal global %KValue zeroinitializer
@s266 = private unnamed_addr constant [16 x i8] c"query/text/trim\00"
@s266_lit = internal global %KValue zeroinitializer
@s267 = private unnamed_addr constant [57 x i8] c"no overload of `query/text/trim` matches these arguments\00"
@s267_lit = internal global %KValue zeroinitializer
@s268 = private unnamed_addr constant [22 x i8] c"query/text/from_front\00"
@s268_lit = internal global %KValue zeroinitializer
@s269 = private unnamed_addr constant [63 x i8] c"no overload of `query/text/from_front` matches these arguments\00"
@s269_lit = internal global %KValue zeroinitializer
@s270 = private unnamed_addr constant [24 x i8] c"query/text/past_the_end\00"
@s270_lit = internal global %KValue zeroinitializer
@s271 = private unnamed_addr constant [65 x i8] c"no overload of `query/text/past_the_end` matches these arguments\00"
@s271_lit = internal global %KValue zeroinitializer
@s272 = private unnamed_addr constant [19 x i8] c"query/text/step_in\00"
@s272_lit = internal global %KValue zeroinitializer
@s273 = private unnamed_addr constant [60 x i8] c"no overload of `query/text/step_in` matches these arguments\00"
@s273_lit = internal global %KValue zeroinitializer
@s274 = private unnamed_addr constant [21 x i8] c"query/text/from_back\00"
@s274_lit = internal global %KValue zeroinitializer
@s275 = private unnamed_addr constant [62 x i8] c"no overload of `query/text/from_back` matches these arguments\00"
@s275_lit = internal global %KValue zeroinitializer
@s276 = private unnamed_addr constant [21 x i8] c"query/text/step_back\00"
@s276_lit = internal global %KValue zeroinitializer
@s277 = private unnamed_addr constant [62 x i8] c"no overload of `query/text/step_back` matches these arguments\00"
@s277_lit = internal global %KValue zeroinitializer
@s278 = private unnamed_addr constant [20 x i8] c"query/text/to_float\00"
@s278_lit = internal global %KValue zeroinitializer
@s279 = private unnamed_addr constant [44 x i8] c"query/text/to_float at std/text/text.kso:81\00"
@s279_lit = internal global %KValue zeroinitializer
@s280 = private unnamed_addr constant [61 x i8] c"no overload of `query/text/to_float` matches these arguments\00"
@s280_lit = internal global %KValue zeroinitializer
@s281 = private unnamed_addr constant [18 x i8] c"query/text/to_int\00"
@s281_lit = internal global %KValue zeroinitializer
@s282 = private unnamed_addr constant [42 x i8] c"query/text/to_int at std/text/text.kso:84\00"
@s282_lit = internal global %KValue zeroinitializer
@s283 = private unnamed_addr constant [59 x i8] c"no overload of `query/text/to_int` matches these arguments\00"
@s283_lit = internal global %KValue zeroinitializer
@s284 = private unnamed_addr constant [16 x i8] c"query/text/utf8\00"
@s284_lit = internal global %KValue zeroinitializer
@s285 = private unnamed_addr constant [40 x i8] c"query/text/utf8 at std/text/text.kso:87\00"
@s285_lit = internal global %KValue zeroinitializer
@s286 = private unnamed_addr constant [57 x i8] c"no overload of `query/text/utf8` matches these arguments\00"
@s286_lit = internal global %KValue zeroinitializer
@s287 = private unnamed_addr constant [12 x i8] c"query/first\00"
@s287_lit = internal global %KValue zeroinitializer
@s288 = private unnamed_addr constant [53 x i8] c"no overload of `query/first` matches these arguments\00"
@s288_lit = internal global %KValue zeroinitializer
@s289 = private unnamed_addr constant [12 x i8] c"query/apply\00"
@s289_lit = internal global %KValue zeroinitializer
@s290 = private unnamed_addr constant [53 x i8] c"no overload of `query/apply` matches these arguments\00"
@s290_lit = internal global %KValue zeroinitializer
@s291 = private unnamed_addr constant [17 x i8] c"query/elem_chunk\00"
@s291_lit = internal global %KValue zeroinitializer
@s292 = private unnamed_addr constant [2 x i8] c"  "
@s292_lit = internal global %KValue zeroinitializer
@s293 = private unnamed_addr constant [58 x i8] c"no overload of `query/elem_chunk` matches these arguments\00"
@s293_lit = internal global %KValue zeroinitializer
@s294 = private unnamed_addr constant [15 x i8] c"query/dispatch\00"
@s294_lit = internal global %KValue zeroinitializer
@s295 = private unnamed_addr constant [56 x i8] c"no overload of `query/dispatch` matches these arguments\00"
@s295_lit = internal global %KValue zeroinitializer
@s296 = private unnamed_addr constant [20 x i8] c"query/render_result\00"
@s296_lit = internal global %KValue zeroinitializer
@s297 = private unnamed_addr constant [2 x i8] c"[]"
@s297_lit = internal global %KValue zeroinitializer
@s298 = private unnamed_addr constant [42 x i8] c"query/render_result at ./query/cli.kso:14\00"
@s298_lit = internal global %KValue zeroinitializer
@s299 = private unnamed_addr constant [61 x i8] c"no overload of `query/render_result` matches these arguments\00"
@s299_lit = internal global %KValue zeroinitializer
@s300 = private unnamed_addr constant [10 x i8] c"query/sep\00"
@s300_lit = internal global %KValue zeroinitializer
@s301 = private unnamed_addr constant [2 x i8] c",\0A"
@s301_lit = internal global %KValue zeroinitializer
@s302 = private unnamed_addr constant [51 x i8] c"no overload of `query/sep` matches these arguments\00"
@s302_lit = internal global %KValue zeroinitializer
@s303 = private unnamed_addr constant [19 x i8] c"query/stream_elems\00"
@s303_lit = internal global %KValue zeroinitializer
@s304 = private unnamed_addr constant [3 x i8] c"\0A]\0A"
@s304_lit = internal global %KValue zeroinitializer
@s305 = private unnamed_addr constant [60 x i8] c"no overload of `query/stream_elems` matches these arguments\00"
@s305_lit = internal global %KValue zeroinitializer
@s306 = private unnamed_addr constant [18 x i8] c"query/stream_list\00"
@s306_lit = internal global %KValue zeroinitializer
@s307 = private unnamed_addr constant [2 x i8] c"[\0A"
@s307_lit = internal global %KValue zeroinitializer
@s308 = private unnamed_addr constant [59 x i8] c"no overload of `query/stream_list` matches these arguments\00"
@s308_lit = internal global %KValue zeroinitializer
@s309 = private unnamed_addr constant [17 x i8] c"query/stream_one\00"
@s309_lit = internal global %KValue zeroinitializer
@s310 = private unnamed_addr constant [58 x i8] c"no overload of `query/stream_one` matches these arguments\00"
@s310_lit = internal global %KValue zeroinitializer
@s311 = private unnamed_addr constant [12 x i8] c"query/usage\00"
@s311_lit = internal global %KValue zeroinitializer
@s312 = private unnamed_addr constant [63 x i8] c"usage: kq <path> [file.json]   e.g. kq .users[3].name data.json"
@s312_lit = internal global %KValue zeroinitializer
@s313 = private unnamed_addr constant [53 x i8] c"no overload of `query/usage` matches these arguments\00"
@s313_lit = internal global %KValue zeroinitializer
@s314 = private unnamed_addr constant [17 x i8] c"query/with_query\00"
@s314_lit = internal global %KValue zeroinitializer
@s315 = private unnamed_addr constant [58 x i8] c"no overload of `query/with_query` matches these arguments\00"
@s315_lit = internal global %KValue zeroinitializer
@s316 = private unnamed_addr constant [13 x i8] c"query/decode\00"
@s316_lit = internal global %KValue zeroinitializer
@s317 = private unnamed_addr constant [54 x i8] c"no overload of `query/decode` matches these arguments\00"
@s317_lit = internal global %KValue zeroinitializer
@s318 = private unnamed_addr constant [16 x i8] c"query/elem_onto\00"
@s318_lit = internal global %KValue zeroinitializer
@s319 = private unnamed_addr constant [57 x i8] c"no overload of `query/elem_onto` matches these arguments\00"
@s319_lit = internal global %KValue zeroinitializer
@s320 = private unnamed_addr constant [13 x i8] c"query/encode\00"
@s320_lit = internal global %KValue zeroinitializer
@s321 = private unnamed_addr constant [54 x i8] c"no overload of `query/encode` matches these arguments\00"
@s321_lit = internal global %KValue zeroinitializer
@s322 = private unnamed_addr constant [19 x i8] c"query/encode_items\00"
@s322_lit = internal global %KValue zeroinitializer
@s323 = private unnamed_addr constant [60 x i8] c"no overload of `query/encode_items` matches these arguments\00"
@s323_lit = internal global %KValue zeroinitializer
@s324 = private unnamed_addr constant [18 x i8] c"query/encode_list\00"
@s324_lit = internal global %KValue zeroinitializer
@s325 = private unnamed_addr constant [59 x i8] c"no overload of `query/encode_list` matches these arguments\00"
@s325_lit = internal global %KValue zeroinitializer
@s326 = private unnamed_addr constant [17 x i8] c"query/encode_map\00"
@s326_lit = internal global %KValue zeroinitializer
@s327 = private unnamed_addr constant [58 x i8] c"no overload of `query/encode_map` matches these arguments\00"
@s327_lit = internal global %KValue zeroinitializer
@s328 = private unnamed_addr constant [18 x i8] c"query/encode_onto\00"
@s328_lit = internal global %KValue zeroinitializer
@s329 = private unnamed_addr constant [4 x i8] c"true"
@s329_lit = internal global %KValue zeroinitializer
@s330 = private unnamed_addr constant [5 x i8] c"false"
@s330_lit = internal global %KValue zeroinitializer
@s331 = private unnamed_addr constant [4 x i8] c"null"
@s331_lit = internal global %KValue zeroinitializer
@s332 = private unnamed_addr constant [2 x i8] c"{}"
@s332_lit = internal global %KValue zeroinitializer
@s333 = private unnamed_addr constant [59 x i8] c"no overload of `query/encode_onto` matches these arguments\00"
@s333_lit = internal global %KValue zeroinitializer
@s334 = private unnamed_addr constant [19 x i8] c"query/encode_pairs\00"
@s334_lit = internal global %KValue zeroinitializer
@s335 = private unnamed_addr constant [60 x i8] c"no overload of `query/encode_pairs` matches these arguments\00"
@s335_lit = internal global %KValue zeroinitializer
@s336 = private unnamed_addr constant [17 x i8] c"query/entry_onto\00"
@s336_lit = internal global %KValue zeroinitializer
@s337 = private unnamed_addr constant [58 x i8] c"no overload of `query/entry_onto` matches these arguments\00"
@s337_lit = internal global %KValue zeroinitializer
@s338 = private unnamed_addr constant [23 x i8] c"query/failure_position\00"
@s338_lit = internal global %KValue zeroinitializer
@s339 = private unnamed_addr constant [64 x i8] c"no overload of `query/failure_position` matches these arguments\00"
@s339_lit = internal global %KValue zeroinitializer
@s340 = private unnamed_addr constant [21 x i8] c"query/failure_reason\00"
@s340_lit = internal global %KValue zeroinitializer
@s341 = private unnamed_addr constant [62 x i8] c"no overload of `query/failure_reason` matches these arguments\00"
@s341_lit = internal global %KValue zeroinitializer
@s342 = private unnamed_addr constant [13 x i8] c"query/finish\00"
@s342_lit = internal global %KValue zeroinitializer
@s343 = private unnamed_addr constant [23 x i8] c"unexpected end of input"
@s343_lit = internal global %KValue zeroinitializer
@s344 = private unnamed_addr constant [36 x i8] c"query/finish at ./query/json.kso:85\00"
@s344_lit = internal global %KValue zeroinitializer
@s345 = private unnamed_addr constant [30 x i8] c"unexpected trailing characters"
@s345_lit = internal global %KValue zeroinitializer
@s346 = private unnamed_addr constant [54 x i8] c"no overload of `query/finish` matches these arguments\00"
@s346_lit = internal global %KValue zeroinitializer
@s347 = private unnamed_addr constant [11 x i8] c"query/must\00"
@s347_lit = internal global %KValue zeroinitializer
@s348 = private unnamed_addr constant [34 x i8] c"query/must at ./query/json.kso:92\00"
@s348_lit = internal global %KValue zeroinitializer
@s349 = private unnamed_addr constant [52 x i8] c"no overload of `query/must` matches these arguments\00"
@s349_lit = internal global %KValue zeroinitializer
@s350 = private unnamed_addr constant [16 x i8] c"query/pair_onto\00"
@s350_lit = internal global %KValue zeroinitializer
@s351 = private unnamed_addr constant [57 x i8] c"no overload of `query/pair_onto` matches these arguments\00"
@s351_lit = internal global %KValue zeroinitializer
@s352 = private unnamed_addr constant [22 x i8] c"query/test_path_trail\00"
@s352_lit = internal global %KValue zeroinitializer
@s353 = private unnamed_addr constant [14 x i8] c".users[3].name"
@s353_lit = internal global %KValue zeroinitializer
@s354 = private unnamed_addr constant [18 x i8] c"[\22users\22,4,\22name\22]"
@s354_lit = internal global %KValue zeroinitializer
@s355 = private unnamed_addr constant [63 x i8] c"no overload of `query/test_path_trail` matches these arguments\00"
@s355_lit = internal global %KValue zeroinitializer
@s356 = private unnamed_addr constant [23 x i8] c"query/test_pretty_list\00"
@s356_lit = internal global %KValue zeroinitializer
@s357 = private unnamed_addr constant [5 x i8] c"[1,2]"
@s357_lit = internal global %KValue zeroinitializer
@s358 = private unnamed_addr constant [12 x i8] c"[\0A  1,\0A  2\0A]"
@s358_lit = internal global %KValue zeroinitializer
@s359 = private unnamed_addr constant [64 x i8] c"no overload of `query/test_pretty_list` matches these arguments\00"
@s359_lit = internal global %KValue zeroinitializer
@s360 = private unnamed_addr constant [22 x i8] c"query/test_pretty_map\00"
@s360_lit = internal global %KValue zeroinitializer
@s361 = private unnamed_addr constant [13 x i8] c"{\22b\22:2,\22a\22:1}"
@s361_lit = internal global %KValue zeroinitializer
@s362 = private unnamed_addr constant [22 x i8] c"{\0A  \22a\22: 1,\0A  \22b\22: 2\0A}"
@s362_lit = internal global %KValue zeroinitializer
@s363 = private unnamed_addr constant [63 x i8] c"no overload of `query/test_pretty_map` matches these arguments\00"
@s363_lit = internal global %KValue zeroinitializer
@s364 = private unnamed_addr constant [25 x i8] c"query/test_pretty_scalar\00"
@s364_lit = internal global %KValue zeroinitializer
@s365 = private unnamed_addr constant [2 x i8] c"42"
@s365_lit = internal global %KValue zeroinitializer
@s366 = private unnamed_addr constant [66 x i8] c"no overload of `query/test_pretty_scalar` matches these arguments\00"
@s366_lit = internal global %KValue zeroinitializer
@s367 = private unnamed_addr constant [16 x i8] c"query/test_walk\00"
@s367_lit = internal global %KValue zeroinitializer
@s368 = private unnamed_addr constant [15 x i8] c"{\22a\22:[{\22b\22:7}]}"
@s368_lit = internal global %KValue zeroinitializer
@s369 = private unnamed_addr constant [7 x i8] c".a[0].b"
@s369_lit = internal global %KValue zeroinitializer
@s370 = private unnamed_addr constant [57 x i8] c"no overload of `query/test_walk` matches these arguments\00"
@s370_lit = internal global %KValue zeroinitializer
@s371 = private unnamed_addr constant [17 x i8] c"query/mark_from?\00"
@s371_lit = internal global %KValue zeroinitializer
@s372 = private unnamed_addr constant [58 x i8] c"no overload of `query/mark_from?` matches these arguments\00"
@s372_lit = internal global %KValue zeroinitializer
@s373 = private unnamed_addr constant [17 x i8] c"query/mark_step?\00"
@s373_lit = internal global %KValue zeroinitializer
@s374 = private unnamed_addr constant [58 x i8] c"no overload of `query/mark_step?` matches these arguments\00"
@s374_lit = internal global %KValue zeroinitializer
@s375 = private unnamed_addr constant [19 x i8] c"query/number_char?\00"
@s375_lit = internal global %KValue zeroinitializer
@s376 = private unnamed_addr constant [60 x i8] c"no overload of `query/number_char?` matches these arguments\00"
@s376_lit = internal global %KValue zeroinitializer
@s377 = private unnamed_addr constant [17 x i8] c"query/number_end\00"
@s377_lit = internal global %KValue zeroinitializer
@s378 = private unnamed_addr constant [58 x i8] c"no overload of `query/number_end` matches these arguments\00"
@s378_lit = internal global %KValue zeroinitializer
@s379 = private unnamed_addr constant [16 x i8] c"query/number_ok\00"
@s379_lit = internal global %KValue zeroinitializer
@s380 = private unnamed_addr constant [14 x i8] c"invalid number"
@s380_lit = internal global %KValue zeroinitializer
@s381 = private unnamed_addr constant [57 x i8] c"no overload of `query/number_ok` matches these arguments\00"
@s381_lit = internal global %KValue zeroinitializer
@s382 = private unnamed_addr constant [20 x i8] c"query/number_start?\00"
@s382_lit = internal global %KValue zeroinitializer
@s383 = private unnamed_addr constant [61 x i8] c"no overload of `query/number_start?` matches these arguments\00"
@s383_lit = internal global %KValue zeroinitializer
@s384 = private unnamed_addr constant [19 x i8] c"query/number_value\00"
@s384_lit = internal global %KValue zeroinitializer
@s385 = private unnamed_addr constant [60 x i8] c"no overload of `query/number_value` matches these arguments\00"
@s385_lit = internal global %KValue zeroinitializer
@s386 = private unnamed_addr constant [16 x i8] c"query/index_end\00"
@s386_lit = internal global %KValue zeroinitializer
@s387 = private unnamed_addr constant [57 x i8] c"no overload of `query/index_end` matches these arguments\00"
@s387_lit = internal global %KValue zeroinitializer
@s388 = private unnamed_addr constant [14 x i8] c"query/key_end\00"
@s388_lit = internal global %KValue zeroinitializer
@s389 = private unnamed_addr constant [55 x i8] c"no overload of `query/key_end` matches these arguments\00"
@s389_lit = internal global %KValue zeroinitializer
@s390 = private unnamed_addr constant [17 x i8] c"query/key_end_at\00"
@s390_lit = internal global %KValue zeroinitializer
@s391 = private unnamed_addr constant [58 x i8] c"no overload of `query/key_end_at` matches these arguments\00"
@s391_lit = internal global %KValue zeroinitializer
@s392 = private unnamed_addr constant [17 x i8] c"query/parse_path\00"
@s392_lit = internal global %KValue zeroinitializer
@s393 = private unnamed_addr constant [58 x i8] c"no overload of `query/parse_path` matches these arguments\00"
@s393_lit = internal global %KValue zeroinitializer
@s394 = private unnamed_addr constant [17 x i8] c"query/scan_steps\00"
@s394_lit = internal global %KValue zeroinitializer
@s395 = private unnamed_addr constant [58 x i8] c"no overload of `query/scan_steps` matches these arguments\00"
@s395_lit = internal global %KValue zeroinitializer
@s396 = private unnamed_addr constant [14 x i8] c"query/step_at\00"
@s396_lit = internal global %KValue zeroinitializer
@s397 = private unnamed_addr constant [55 x i8] c"no overload of `query/step_at` matches these arguments\00"
@s397_lit = internal global %KValue zeroinitializer
@s398 = private unnamed_addr constant [22 x i8] c"bad path: unexpected `"
@s398_lit = internal global %KValue zeroinitializer
@s399 = private unnamed_addr constant [1 x i8] c"`"
@s399_lit = internal global %KValue zeroinitializer
@s400 = private unnamed_addr constant [37 x i8] c"query/step_at at ./query/path.kso:40\00"
@s400_lit = internal global %KValue zeroinitializer
@s401 = private unnamed_addr constant [18 x i8] c"query/steps_index\00"
@s401_lit = internal global %KValue zeroinitializer
@s402 = private unnamed_addr constant [59 x i8] c"no overload of `query/steps_index` matches these arguments\00"
@s402_lit = internal global %KValue zeroinitializer
@s403 = private unnamed_addr constant [24 x i8] c"query/steps_index_close\00"
@s403_lit = internal global %KValue zeroinitializer
@s404 = private unnamed_addr constant [22 x i8] c"bad path: expected `]`"
@s404_lit = internal global %KValue zeroinitializer
@s405 = private unnamed_addr constant [47 x i8] c"query/steps_index_close at ./query/path.kso:51\00"
@s405_lit = internal global %KValue zeroinitializer
@s406 = private unnamed_addr constant [65 x i8] c"no overload of `query/steps_index_close` matches these arguments\00"
@s406_lit = internal global %KValue zeroinitializer
@s407 = private unnamed_addr constant [16 x i8] c"query/steps_key\00"
@s407_lit = internal global %KValue zeroinitializer
@s408 = private unnamed_addr constant [57 x i8] c"no overload of `query/steps_key` matches these arguments\00"
@s408_lit = internal global %KValue zeroinitializer
@s409 = private unnamed_addr constant [24 x i8] c"query/steps_key_checked\00"
@s409_lit = internal global %KValue zeroinitializer
@s410 = private unnamed_addr constant [65 x i8] c"no overload of `query/steps_key_checked` matches these arguments\00"
@s410_lit = internal global %KValue zeroinitializer
@s411 = private unnamed_addr constant [11 x i8] c"query/walk\00"
@s411_lit = internal global %KValue zeroinitializer
@s412 = private unnamed_addr constant [52 x i8] c"no overload of `query/walk` matches these arguments\00"
@s412_lit = internal global %KValue zeroinitializer
@s413 = private unnamed_addr constant [14 x i8] c"query/walk_at\00"
@s413_lit = internal global %KValue zeroinitializer
@s414 = private unnamed_addr constant [55 x i8] c"no overload of `query/walk_at` matches these arguments\00"
@s414_lit = internal global %KValue zeroinitializer
@s415 = private unnamed_addr constant [16 x i8] c"query/walk_step\00"
@s415_lit = internal global %KValue zeroinitializer
@s416 = private unnamed_addr constant [57 x i8] c"no overload of `query/walk_step` matches these arguments\00"
@s416_lit = internal global %KValue zeroinitializer
@s417 = private unnamed_addr constant [15 x i8] c"query/elem_row\00"
@s417_lit = internal global %KValue zeroinitializer
@s418 = private unnamed_addr constant [56 x i8] c"no overload of `query/elem_row` matches these arguments\00"
@s418_lit = internal global %KValue zeroinitializer
@s419 = private unnamed_addr constant [18 x i8] c"query/indent_onto\00"
@s419_lit = internal global %KValue zeroinitializer
@s420 = private unnamed_addr constant [59 x i8] c"no overload of `query/indent_onto` matches these arguments\00"
@s420_lit = internal global %KValue zeroinitializer
@s421 = private unnamed_addr constant [15 x i8] c"query/pair_row\00"
@s421_lit = internal global %KValue zeroinitializer
@s422 = private unnamed_addr constant [56 x i8] c"no overload of `query/pair_row` matches these arguments\00"
@s422_lit = internal global %KValue zeroinitializer
@s423 = private unnamed_addr constant [13 x i8] c"query/pretty\00"
@s423_lit = internal global %KValue zeroinitializer
@s424 = private unnamed_addr constant [54 x i8] c"no overload of `query/pretty` matches these arguments\00"
@s424_lit = internal global %KValue zeroinitializer
@s425 = private unnamed_addr constant [19 x i8] c"query/pretty_elems\00"
@s425_lit = internal global %KValue zeroinitializer
@s426 = private unnamed_addr constant [60 x i8] c"no overload of `query/pretty_elems` matches these arguments\00"
@s426_lit = internal global %KValue zeroinitializer
@s427 = private unnamed_addr constant [19 x i8] c"query/pretty_entry\00"
@s427_lit = internal global %KValue zeroinitializer
@s428 = private unnamed_addr constant [3 x i8] c"\22: "
@s428_lit = internal global %KValue zeroinitializer
@s429 = private unnamed_addr constant [60 x i8] c"no overload of `query/pretty_entry` matches these arguments\00"
@s429_lit = internal global %KValue zeroinitializer
@s430 = private unnamed_addr constant [18 x i8] c"query/pretty_list\00"
@s430_lit = internal global %KValue zeroinitializer
@s431 = private unnamed_addr constant [1 x i8] c"\0A"
@s431_lit = internal global %KValue zeroinitializer
@s432 = private unnamed_addr constant [59 x i8] c"no overload of `query/pretty_list` matches these arguments\00"
@s432_lit = internal global %KValue zeroinitializer
@s433 = private unnamed_addr constant [17 x i8] c"query/pretty_map\00"
@s433_lit = internal global %KValue zeroinitializer
@s434 = private unnamed_addr constant [2 x i8] c"{\0A"
@s434_lit = internal global %KValue zeroinitializer
@s435 = private unnamed_addr constant [58 x i8] c"no overload of `query/pretty_map` matches these arguments\00"
@s435_lit = internal global %KValue zeroinitializer
@s436 = private unnamed_addr constant [18 x i8] c"query/pretty_onto\00"
@s436_lit = internal global %KValue zeroinitializer
@s437 = private unnamed_addr constant [59 x i8] c"no overload of `query/pretty_onto` matches these arguments\00"
@s437_lit = internal global %KValue zeroinitializer
@s438 = private unnamed_addr constant [19 x i8] c"query/pretty_pairs\00"
@s438_lit = internal global %KValue zeroinitializer
@s439 = private unnamed_addr constant [60 x i8] c"no overload of `query/pretty_pairs` matches these arguments\00"
@s439_lit = internal global %KValue zeroinitializer
@s440 = private unnamed_addr constant [18 x i8] c"query/expect_char\00"
@s440_lit = internal global %KValue zeroinitializer
@s441 = private unnamed_addr constant [59 x i8] c"no overload of `query/expect_char` matches these arguments\00"
@s441_lit = internal global %KValue zeroinitializer
@s442 = private unnamed_addr constant [19 x i8] c"query/expect_check\00"
@s442_lit = internal global %KValue zeroinitializer
@s443 = private unnamed_addr constant [10 x i8] c"expected `"
@s443_lit = internal global %KValue zeroinitializer
@s444 = private unnamed_addr constant [60 x i8] c"no overload of `query/expect_check` matches these arguments\00"
@s444_lit = internal global %KValue zeroinitializer
@s445 = private unnamed_addr constant [11 x i8] c"query/fail\00"
@s445_lit = internal global %KValue zeroinitializer
@s446 = private unnamed_addr constant [34 x i8] c"query/fail at ./query/scan.kso:10\00"
@s446_lit = internal global %KValue zeroinitializer
@s447 = private unnamed_addr constant [52 x i8] c"no overload of `query/fail` matches these arguments\00"
@s447_lit = internal global %KValue zeroinitializer
@s448 = private unnamed_addr constant [14 x i8] c"query/skip_ws\00"
@s448_lit = internal global %KValue zeroinitializer
@s449 = private unnamed_addr constant [55 x i8] c"no overload of `query/skip_ws` matches these arguments\00"
@s449_lit = internal global %KValue zeroinitializer
@s450 = private unnamed_addr constant [10 x i8] c"query/ws?\00"
@s450_lit = internal global %KValue zeroinitializer
@s451 = private unnamed_addr constant [51 x i8] c"no overload of `query/ws?` matches these arguments\00"
@s451_lit = internal global %KValue zeroinitializer
@s452 = private unnamed_addr constant [15 x i8] c"query/esc_byte\00"
@s452_lit = internal global %KValue zeroinitializer
@s453 = private unnamed_addr constant [56 x i8] c"no overload of `query/esc_byte` matches these arguments\00"
@s453_lit = internal global %KValue zeroinitializer
@s454 = private unnamed_addr constant [18 x i8] c"query/escape_able\00"
@s454_lit = internal global %KValue zeroinitializer
@s455 = private unnamed_addr constant [59 x i8] c"no overload of `query/escape_able` matches these arguments\00"
@s455_lit = internal global %KValue zeroinitializer
@s456 = private unnamed_addr constant [19 x i8] c"query/escape_clean\00"
@s456_lit = internal global %KValue zeroinitializer
@s457 = private unnamed_addr constant [60 x i8] c"no overload of `query/escape_clean` matches these arguments\00"
@s457_lit = internal global %KValue zeroinitializer
@s458 = private unnamed_addr constant [18 x i8] c"query/escape_onto\00"
@s458_lit = internal global %KValue zeroinitializer
@s459 = private unnamed_addr constant [59 x i8] c"no overload of `query/escape_onto` matches these arguments\00"
@s459_lit = internal global %KValue zeroinitializer
@s460 = private unnamed_addr constant [17 x i8] c"query/escape_str\00"
@s460_lit = internal global %KValue zeroinitializer
@s461 = private unnamed_addr constant [58 x i8] c"no overload of `query/escape_str` matches these arguments\00"
@s461_lit = internal global %KValue zeroinitializer
@s462 = private unnamed_addr constant [11 x i8] c"query/hex4\00"
@s462_lit = internal global %KValue zeroinitializer
@s463 = private unnamed_addr constant [34 x i8] c"query/hex4 at ./query/text.kso:40\00"
@s463_lit = internal global %KValue zeroinitializer
@s464 = private unnamed_addr constant [34 x i8] c"query/hex4 at ./query/text.kso:42\00"
@s464_lit = internal global %KValue zeroinitializer
@s465 = private unnamed_addr constant [34 x i8] c"query/hex4 at ./query/text.kso:44\00"
@s465_lit = internal global %KValue zeroinitializer
@s466 = private unnamed_addr constant [52 x i8] c"no overload of `query/hex4` matches these arguments\00"
@s466_lit = internal global %KValue zeroinitializer
@s467 = private unnamed_addr constant [16 x i8] c"query/hex_alpha\00"
@s467_lit = internal global %KValue zeroinitializer
@s468 = private unnamed_addr constant [57 x i8] c"no overload of `query/hex_alpha` matches these arguments\00"
@s468_lit = internal global %KValue zeroinitializer
@s469 = private unnamed_addr constant [21 x i8] c"query/hex_byte_table\00"
@s469_lit = internal global %KValue zeroinitializer
@s470 = private unnamed_addr constant [16 x i8] c"0123456789abcdef"
@s470_lit = internal global %KValue zeroinitializer
@s471 = private unnamed_addr constant [62 x i8] c"no overload of `query/hex_byte_table` matches these arguments\00"
@s471_lit = internal global %KValue zeroinitializer
@s472 = private unnamed_addr constant [15 x i8] c"query/hex_char\00"
@s472_lit = internal global %KValue zeroinitializer
@s473 = private unnamed_addr constant [56 x i8] c"no overload of `query/hex_char` matches these arguments\00"
@s473_lit = internal global %KValue zeroinitializer
@s474 = private unnamed_addr constant [15 x i8] c"query/hex_code\00"
@s474_lit = internal global %KValue zeroinitializer
@s475 = private unnamed_addr constant [56 x i8] c"no overload of `query/hex_code` matches these arguments\00"
@s475_lit = internal global %KValue zeroinitializer
@s476 = private unnamed_addr constant [16 x i8] c"query/hex_digit\00"
@s476_lit = internal global %KValue zeroinitializer
@s477 = private unnamed_addr constant [57 x i8] c"no overload of `query/hex_digit` matches these arguments\00"
@s477_lit = internal global %KValue zeroinitializer
@s478 = private unnamed_addr constant [17 x i8] c"query/hex_digits\00"
@s478_lit = internal global %KValue zeroinitializer
@s479 = private unnamed_addr constant [58 x i8] c"no overload of `query/hex_digits` matches these arguments\00"
@s479_lit = internal global %KValue zeroinitializer
@s480 = private unnamed_addr constant [16 x i8] c"query/hex_upper\00"
@s480_lit = internal global %KValue zeroinitializer
@s481 = private unnamed_addr constant [17 x i8] c"invalid hex digit"
@s481_lit = internal global %KValue zeroinitializer
@s482 = private unnamed_addr constant [39 x i8] c"query/hex_upper at ./query/text.kso:65\00"
@s482_lit = internal global %KValue zeroinitializer
@s483 = private unnamed_addr constant [57 x i8] c"no overload of `query/hex_upper` matches these arguments\00"
@s483_lit = internal global %KValue zeroinitializer
@s484 = private unnamed_addr constant [19 x i8] c"query/parse_string\00"
@s484_lit = internal global %KValue zeroinitializer
@s485 = private unnamed_addr constant [60 x i8] c"no overload of `query/parse_string` matches these arguments\00"
@s485_lit = internal global %KValue zeroinitializer
@s486 = private unnamed_addr constant [15 x i8] c"query/str_char\00"
@s486_lit = internal global %KValue zeroinitializer
@s487 = private unnamed_addr constant [56 x i8] c"no overload of `query/str_char` matches these arguments\00"
@s487_lit = internal global %KValue zeroinitializer
@s488 = private unnamed_addr constant [19 x i8] c"unterminated string"
@s488_lit = internal global %KValue zeroinitializer
@s489 = private unnamed_addr constant [16 x i8] c"query/str_chars\00"
@s489_lit = internal global %KValue zeroinitializer
@s490 = private unnamed_addr constant [57 x i8] c"no overload of `query/str_chars` matches these arguments\00"
@s490_lit = internal global %KValue zeroinitializer
@s491 = private unnamed_addr constant [17 x i8] c"query/str_escape\00"
@s491_lit = internal global %KValue zeroinitializer
@s492 = private unnamed_addr constant [58 x i8] c"no overload of `query/str_escape` matches these arguments\00"
@s492_lit = internal global %KValue zeroinitializer
@s493 = private unnamed_addr constant [17 x i8] c"invalid escape `\5C"
@s493_lit = internal global %KValue zeroinitializer
@s494 = private unnamed_addr constant [18 x i8] c"query/str_unicode\00"
@s494_lit = internal global %KValue zeroinitializer
@s495 = private unnamed_addr constant [59 x i8] c"no overload of `query/str_unicode` matches these arguments\00"
@s495_lit = internal global %KValue zeroinitializer
@s496 = private unnamed_addr constant [16 x i8] c"query/string_at\00"
@s496_lit = internal global %KValue zeroinitializer
@s497 = private unnamed_addr constant [57 x i8] c"no overload of `query/string_at` matches these arguments\00"
@s497_lit = internal global %KValue zeroinitializer
@s498 = private unnamed_addr constant [16 x i8] c"query/string_ok\00"
@s498_lit = internal global %KValue zeroinitializer
@s499 = private unnamed_addr constant [23 x i8] c"invalid utf-8 in string"
@s499_lit = internal global %KValue zeroinitializer
@s500 = private unnamed_addr constant [40 x i8] c"query/string_ok at ./query/text.kso:140\00"
@s500_lit = internal global %KValue zeroinitializer
@s501 = private unnamed_addr constant [57 x i8] c"no overload of `query/string_ok` matches these arguments\00"
@s501_lit = internal global %KValue zeroinitializer
@s502 = private unnamed_addr constant [18 x i8] c"query/string_scan\00"
@s502_lit = internal global %KValue zeroinitializer
@s503 = private unnamed_addr constant [59 x i8] c"no overload of `query/string_scan` matches these arguments\00"
@s503_lit = internal global %KValue zeroinitializer
@s504 = private unnamed_addr constant [14 x i8] c"query/u_bytes\00"
@s504_lit = internal global %KValue zeroinitializer
@s505 = private unnamed_addr constant [38 x i8] c"query/u_bytes at ./query/text.kso:150\00"
@s505_lit = internal global %KValue zeroinitializer
@s506 = private unnamed_addr constant [38 x i8] c"query/u_bytes at ./query/text.kso:151\00"
@s506_lit = internal global %KValue zeroinitializer
@s507 = private unnamed_addr constant [4 x i8] c"\5Cu00"
@s507_lit = internal global %KValue zeroinitializer
@s508 = private unnamed_addr constant [55 x i8] c"no overload of `query/u_bytes` matches these arguments\00"
@s508_lit = internal global %KValue zeroinitializer
@s509 = private unnamed_addr constant [18 x i8] c"query/array_delim\00"
@s509_lit = internal global %KValue zeroinitializer
@s510 = private unnamed_addr constant [59 x i8] c"no overload of `query/array_delim` matches these arguments\00"
@s510_lit = internal global %KValue zeroinitializer
@s511 = private unnamed_addr constant [28 x i8] c"expected `,` or `]`, found `"
@s511_lit = internal global %KValue zeroinitializer
@s512 = private unnamed_addr constant [18 x i8] c"query/array_items\00"
@s512_lit = internal global %KValue zeroinitializer
@s513 = private unnamed_addr constant [59 x i8] c"no overload of `query/array_items` matches these arguments\00"
@s513_lit = internal global %KValue zeroinitializer
@s514 = private unnamed_addr constant [17 x i8] c"query/array_open\00"
@s514_lit = internal global %KValue zeroinitializer
@s515 = private unnamed_addr constant [58 x i8] c"no overload of `query/array_open` matches these arguments\00"
@s515_lit = internal global %KValue zeroinitializer
@s516 = private unnamed_addr constant [17 x i8] c"query/array_step\00"
@s516_lit = internal global %KValue zeroinitializer
@s517 = private unnamed_addr constant [58 x i8] c"no overload of `query/array_step` matches these arguments\00"
@s517_lit = internal global %KValue zeroinitializer
@s518 = private unnamed_addr constant [21 x i8] c"query/bad_value_char\00"
@s518_lit = internal global %KValue zeroinitializer
@s519 = private unnamed_addr constant [22 x i8] c"unexpected character `"
@s519_lit = internal global %KValue zeroinitializer
@s520 = private unnamed_addr constant [62 x i8] c"no overload of `query/bad_value_char` matches these arguments\00"
@s520_lit = internal global %KValue zeroinitializer
@s521 = private unnamed_addr constant [18 x i8] c"query/bytes_false\00"
@s521_lit = internal global %KValue zeroinitializer
@s522 = private unnamed_addr constant [59 x i8] c"no overload of `query/bytes_false` matches these arguments\00"
@s522_lit = internal global %KValue zeroinitializer
@s523 = private unnamed_addr constant [17 x i8] c"query/bytes_null\00"
@s523_lit = internal global %KValue zeroinitializer
@s524 = private unnamed_addr constant [58 x i8] c"no overload of `query/bytes_null` matches these arguments\00"
@s524_lit = internal global %KValue zeroinitializer
@s525 = private unnamed_addr constant [17 x i8] c"query/bytes_true\00"
@s525_lit = internal global %KValue zeroinitializer
@s526 = private unnamed_addr constant [58 x i8] c"no overload of `query/bytes_true` matches these arguments\00"
@s526_lit = internal global %KValue zeroinitializer
@s527 = private unnamed_addr constant [16 x i8] c"query/obj_colon\00"
@s527_lit = internal global %KValue zeroinitializer
@s528 = private unnamed_addr constant [57 x i8] c"no overload of `query/obj_colon` matches these arguments\00"
@s528_lit = internal global %KValue zeroinitializer
@s529 = private unnamed_addr constant [16 x i8] c"query/obj_delim\00"
@s529_lit = internal global %KValue zeroinitializer
@s530 = private unnamed_addr constant [57 x i8] c"no overload of `query/obj_delim` matches these arguments\00"
@s530_lit = internal global %KValue zeroinitializer
@s531 = private unnamed_addr constant [28 x i8] c"expected `,` or `}`, found `"
@s531_lit = internal global %KValue zeroinitializer
@s532 = private unnamed_addr constant [16 x i8] c"query/obj_items\00"
@s532_lit = internal global %KValue zeroinitializer
@s533 = private unnamed_addr constant [57 x i8] c"no overload of `query/obj_items` matches these arguments\00"
@s533_lit = internal global %KValue zeroinitializer
@s534 = private unnamed_addr constant [14 x i8] c"query/obj_key\00"
@s534_lit = internal global %KValue zeroinitializer
@s535 = private unnamed_addr constant [55 x i8] c"no overload of `query/obj_key` matches these arguments\00"
@s535_lit = internal global %KValue zeroinitializer
@s536 = private unnamed_addr constant [20 x i8] c"query/obj_key_start\00"
@s536_lit = internal global %KValue zeroinitializer
@s537 = private unnamed_addr constant [21 x i8] c"expected a string key"
@s537_lit = internal global %KValue zeroinitializer
@s538 = private unnamed_addr constant [61 x i8] c"no overload of `query/obj_key_start` matches these arguments\00"
@s538_lit = internal global %KValue zeroinitializer
@s539 = private unnamed_addr constant [15 x i8] c"query/obj_open\00"
@s539_lit = internal global %KValue zeroinitializer
@s540 = private unnamed_addr constant [56 x i8] c"no overload of `query/obj_open` matches these arguments\00"
@s540_lit = internal global %KValue zeroinitializer
@s541 = private unnamed_addr constant [16 x i8] c"query/obj_value\00"
@s541_lit = internal global %KValue zeroinitializer
@s542 = private unnamed_addr constant [57 x i8] c"no overload of `query/obj_value` matches these arguments\00"
@s542_lit = internal global %KValue zeroinitializer
@s543 = private unnamed_addr constant [18 x i8] c"query/parse_array\00"
@s543_lit = internal global %KValue zeroinitializer
@s544 = private unnamed_addr constant [59 x i8] c"no overload of `query/parse_array` matches these arguments\00"
@s544_lit = internal global %KValue zeroinitializer
@s545 = private unnamed_addr constant [19 x i8] c"query/parse_number\00"
@s545_lit = internal global %KValue zeroinitializer
@s546 = private unnamed_addr constant [60 x i8] c"no overload of `query/parse_number` matches these arguments\00"
@s546_lit = internal global %KValue zeroinitializer
@s547 = private unnamed_addr constant [19 x i8] c"query/parse_object\00"
@s547_lit = internal global %KValue zeroinitializer
@s548 = private unnamed_addr constant [60 x i8] c"no overload of `query/parse_object` matches these arguments\00"
@s548_lit = internal global %KValue zeroinitializer
@s549 = private unnamed_addr constant [18 x i8] c"query/parse_value\00"
@s549_lit = internal global %KValue zeroinitializer
@s550 = private unnamed_addr constant [59 x i8] c"no overload of `query/parse_value` matches these arguments\00"
@s550_lit = internal global %KValue zeroinitializer
@s551 = private unnamed_addr constant [16 x i8] c"query/value_for\00"
@s551_lit = internal global %KValue zeroinitializer
@s552 = private unnamed_addr constant [57 x i8] c"no overload of `query/value_for` matches these arguments\00"
@s552_lit = internal global %KValue zeroinitializer
@s553 = private unnamed_addr constant [11 x i8] c"query/word\00"
@s553_lit = internal global %KValue zeroinitializer
@s554 = private unnamed_addr constant [15 x i8] c"invalid literal"
@s554_lit = internal global %KValue zeroinitializer
@s555 = private unnamed_addr constant [52 x i8] c"no overload of `query/word` matches these arguments\00"
@s555_lit = internal global %KValue zeroinitializer
@s556 = private unnamed_addr constant [8 x i8] c"io/args\00"
@s556_lit = internal global %KValue zeroinitializer
@s557 = private unnamed_addr constant [49 x i8] c"no overload of `io/args` matches these arguments\00"
@s557_lit = internal global %KValue zeroinitializer
@s558 = private unnamed_addr constant [7 x i8] c"io/env\00"
@s558_lit = internal global %KValue zeroinitializer
@s559 = private unnamed_addr constant [48 x i8] c"no overload of `io/env` matches these arguments\00"
@s559_lit = internal global %KValue zeroinitializer
@s560 = private unnamed_addr constant [8 x i8] c"io/exit\00"
@s560_lit = internal global %KValue zeroinitializer
@s561 = private unnamed_addr constant [28 x i8] c"io/exit at std/io/io.kso:23\00"
@s561_lit = internal global %KValue zeroinitializer
@s562 = private unnamed_addr constant [49 x i8] c"no overload of `io/exit` matches these arguments\00"
@s562_lit = internal global %KValue zeroinitializer
@s563 = private unnamed_addr constant [10 x i8] c"io/exists\00"
@s563_lit = internal global %KValue zeroinitializer
@s564 = private unnamed_addr constant [51 x i8] c"no overload of `io/exists` matches these arguments\00"
@s564_lit = internal global %KValue zeroinitializer
@s565 = private unnamed_addr constant [10 x i8] c"io/is_dir\00"
@s565_lit = internal global %KValue zeroinitializer
@s566 = private unnamed_addr constant [51 x i8] c"no overload of `io/is_dir` matches these arguments\00"
@s566_lit = internal global %KValue zeroinitializer
@s567 = private unnamed_addr constant [12 x i8] c"io/list_dir\00"
@s567_lit = internal global %KValue zeroinitializer
@s568 = private unnamed_addr constant [53 x i8] c"no overload of `io/list_dir` matches these arguments\00"
@s568_lit = internal global %KValue zeroinitializer
@s569 = private unnamed_addr constant [13 x i8] c"io/read_file\00"
@s569_lit = internal global %KValue zeroinitializer
@s570 = private unnamed_addr constant [54 x i8] c"no overload of `io/read_file` matches these arguments\00"
@s570_lit = internal global %KValue zeroinitializer
@s571 = private unnamed_addr constant [7 x i8] c"io/run\00"
@s571_lit = internal global %KValue zeroinitializer
@s572 = private unnamed_addr constant [48 x i8] c"no overload of `io/run` matches these arguments\00"
@s572_lit = internal global %KValue zeroinitializer
@s573 = private unnamed_addr constant [12 x i8] c"io/answered\00"
@s573_lit = internal global %KValue zeroinitializer
@s574 = private unnamed_addr constant [32 x i8] c"io/answered at std/io/io.kso:55\00"
@s574_lit = internal global %KValue zeroinitializer
@s575 = private unnamed_addr constant [53 x i8] c"no overload of `io/answered` matches these arguments\00"
@s575_lit = internal global %KValue zeroinitializer
@s576 = private unnamed_addr constant [9 x i8] c"io/stdin\00"
@s576_lit = internal global %KValue zeroinitializer
@s577 = private unnamed_addr constant [50 x i8] c"no overload of `io/stdin` matches these arguments\00"
@s577_lit = internal global %KValue zeroinitializer
@s578 = private unnamed_addr constant [9 x i8] c"io/write\00"
@s578_lit = internal global %KValue zeroinitializer
@s579 = private unnamed_addr constant [50 x i8] c"no overload of `io/write` matches these arguments\00"
@s579_lit = internal global %KValue zeroinitializer
@s580 = private unnamed_addr constant [13 x i8] c"io/write_err\00"
@s580_lit = internal global %KValue zeroinitializer
@s581 = private unnamed_addr constant [54 x i8] c"no overload of `io/write_err` matches these arguments\00"
@s581_lit = internal global %KValue zeroinitializer
@s582 = private unnamed_addr constant [12 x i8] c"io/make_dir\00"
@s582_lit = internal global %KValue zeroinitializer
@s583 = private unnamed_addr constant [53 x i8] c"no overload of `io/make_dir` matches these arguments\00"
@s583_lit = internal global %KValue zeroinitializer
@s584 = private unnamed_addr constant [14 x i8] c"io/write_file\00"
@s584_lit = internal global %KValue zeroinitializer
@s585 = private unnamed_addr constant [55 x i8] c"no overload of `io/write_file` matches these arguments\00"
@s585_lit = internal global %KValue zeroinitializer
@s586 = private unnamed_addr constant [17 x i8] c"render/to_string\00"
@s586_lit = internal global %KValue zeroinitializer
@s587 = private unnamed_addr constant [6 x i8] c"<none>"
@s587_lit = internal global %KValue zeroinitializer
@s588 = private unnamed_addr constant [58 x i8] c"no overload of `render/to_string` matches these arguments\00"
@s588_lit = internal global %KValue zeroinitializer
@s589 = private unnamed_addr constant [5 x i8] c"args\00"
@s589_lit = internal global %KValue zeroinitializer
@s590 = private unnamed_addr constant [46 x i8] c"no overload of `args` matches these arguments\00"
@s590_lit = internal global %KValue zeroinitializer
@s591 = private unnamed_addr constant [4 x i8] c"env\00"
@s591_lit = internal global %KValue zeroinitializer
@s592 = private unnamed_addr constant [45 x i8] c"no overload of `env` matches these arguments\00"
@s592_lit = internal global %KValue zeroinitializer
@s593 = private unnamed_addr constant [5 x i8] c"exit\00"
@s593_lit = internal global %KValue zeroinitializer
@s594 = private unnamed_addr constant [25 x i8] c"exit at std/io/io.kso:23\00"
@s594_lit = internal global %KValue zeroinitializer
@s595 = private unnamed_addr constant [46 x i8] c"no overload of `exit` matches these arguments\00"
@s595_lit = internal global %KValue zeroinitializer
@s596 = private unnamed_addr constant [7 x i8] c"exists\00"
@s596_lit = internal global %KValue zeroinitializer
@s597 = private unnamed_addr constant [48 x i8] c"no overload of `exists` matches these arguments\00"
@s597_lit = internal global %KValue zeroinitializer
@s598 = private unnamed_addr constant [7 x i8] c"is_dir\00"
@s598_lit = internal global %KValue zeroinitializer
@s599 = private unnamed_addr constant [48 x i8] c"no overload of `is_dir` matches these arguments\00"
@s599_lit = internal global %KValue zeroinitializer
@s600 = private unnamed_addr constant [9 x i8] c"list_dir\00"
@s600_lit = internal global %KValue zeroinitializer
@s601 = private unnamed_addr constant [50 x i8] c"no overload of `list_dir` matches these arguments\00"
@s601_lit = internal global %KValue zeroinitializer
@s602 = private unnamed_addr constant [10 x i8] c"read_file\00"
@s602_lit = internal global %KValue zeroinitializer
@s603 = private unnamed_addr constant [51 x i8] c"no overload of `read_file` matches these arguments\00"
@s603_lit = internal global %KValue zeroinitializer
@s604 = private unnamed_addr constant [4 x i8] c"run\00"
@s604_lit = internal global %KValue zeroinitializer
@s605 = private unnamed_addr constant [45 x i8] c"no overload of `run` matches these arguments\00"
@s605_lit = internal global %KValue zeroinitializer
@s606 = private unnamed_addr constant [6 x i8] c"stdin\00"
@s606_lit = internal global %KValue zeroinitializer
@s607 = private unnamed_addr constant [47 x i8] c"no overload of `stdin` matches these arguments\00"
@s607_lit = internal global %KValue zeroinitializer
@s608 = private unnamed_addr constant [6 x i8] c"write\00"
@s608_lit = internal global %KValue zeroinitializer
@s609 = private unnamed_addr constant [47 x i8] c"no overload of `write` matches these arguments\00"
@s609_lit = internal global %KValue zeroinitializer
@s610 = private unnamed_addr constant [10 x i8] c"write_err\00"
@s610_lit = internal global %KValue zeroinitializer
@s611 = private unnamed_addr constant [51 x i8] c"no overload of `write_err` matches these arguments\00"
@s611_lit = internal global %KValue zeroinitializer
@s612 = private unnamed_addr constant [9 x i8] c"make_dir\00"
@s612_lit = internal global %KValue zeroinitializer
@s613 = private unnamed_addr constant [50 x i8] c"no overload of `make_dir` matches these arguments\00"
@s613_lit = internal global %KValue zeroinitializer
@s614 = private unnamed_addr constant [11 x i8] c"write_file\00"
@s614_lit = internal global %KValue zeroinitializer
@s615 = private unnamed_addr constant [52 x i8] c"no overload of `write_file` matches these arguments\00"
@s615_lit = internal global %KValue zeroinitializer
@s616 = private unnamed_addr constant [6 x i8] c"Entry\00"
@s616_lit = internal global %KValue zeroinitializer
@s617 = private unnamed_addr constant [47 x i8] c"no overload of `Entry` matches these arguments\00"
@s617_lit = internal global %KValue zeroinitializer

define ptr @k_type_name(i64 %id) {
entry:
  switch i64 %id, label %TD [
    i64 1, label %T1
    i64 2, label %T2
    i64 3, label %T3
    i64 4, label %T4
    i64 5, label %T5
    i64 6, label %T6
    i64 7, label %T7
    i64 8, label %T8
    i64 9, label %T9
    i64 10, label %T10
    i64 11, label %T11
    i64 12, label %T12
    i64 13, label %T13
    i64 14, label %T14
    i64 15, label %T15
    i64 16, label %T16
    i64 17, label %T17
    i64 34, label %T34
    i64 35, label %T35
    i64 36, label %T36
    i64 37, label %T37
    i64 38, label %T38
    i64 39, label %T39
    i64 0, label %T0
  ]
T1:
  ret ptr @s0
T2:
  ret ptr @s1
T3:
  ret ptr @s2
T4:
  ret ptr @s3
T5:
  ret ptr @s4
T6:
  ret ptr @s5
T7:
  ret ptr @s6
T8:
  ret ptr @s7
T9:
  ret ptr @s8
T10:
  ret ptr @s9
T11:
  ret ptr @s10
T12:
  ret ptr @s11
T13:
  ret ptr @s12
T14:
  ret ptr @s13
T15:
  ret ptr @s14
T16:
  ret ptr @s15
T17:
  ret ptr @s16
T34:
  ret ptr @s17
T35:
  ret ptr @s18
T36:
  ret ptr @s19
T37:
  ret ptr @s20
T38:
  ret ptr @s21
T39:
  ret ptr @s22
T0:
  ret ptr @s23
TD:
  ret ptr @s24
}

define i64 @k_type_field_count(i64 %id) {
entry:
  switch i64 %id, label %CD [
    i64 0, label %C0
    i64 1, label %C1
    i64 2, label %C2
    i64 3, label %C3
    i64 4, label %C4
    i64 5, label %C5
    i64 6, label %C6
    i64 7, label %C7
    i64 8, label %C8
    i64 9, label %C9
    i64 10, label %C10
    i64 11, label %C11
    i64 12, label %C12
    i64 13, label %C13
    i64 14, label %C14
    i64 15, label %C15
    i64 16, label %C16
    i64 17, label %C17
    i64 34, label %C34
    i64 35, label %C35
    i64 36, label %C36
    i64 37, label %C37
    i64 38, label %C38
    i64 39, label %C39
  ]
C0:
  ret i64 2
C1:
  ret i64 1
C2:
  ret i64 3
C3:
  ret i64 3
C4:
  ret i64 2
C5:
  ret i64 1
C6:
  ret i64 2
C7:
  ret i64 2
C8:
  ret i64 1
C9:
  ret i64 2
C10:
  ret i64 2
C11:
  ret i64 1
C12:
  ret i64 2
C13:
  ret i64 1
C14:
  ret i64 3
C15:
  ret i64 2
C16:
  ret i64 1
C17:
  ret i64 2
C34:
  ret i64 1
C35:
  ret i64 0
C36:
  ret i64 2
C37:
  ret i64 2
C38:
  ret i64 1
C39:
  ret i64 3
CD:
  ret i64 0
}

define ptr @k_type_field_name(i64 %id, i64 %i) {
entry:
  switch i64 %id, label %TD [
    i64 0, label %T0
    i64 1, label %T1
    i64 2, label %T2
    i64 3, label %T3
    i64 4, label %T4
    i64 5, label %T5
    i64 6, label %T6
    i64 7, label %T7
    i64 8, label %T8
    i64 9, label %T9
    i64 10, label %T10
    i64 11, label %T11
    i64 12, label %T12
    i64 13, label %T13
    i64 14, label %T14
    i64 15, label %T15
    i64 16, label %T16
    i64 17, label %T17
    i64 34, label %T34
    i64 35, label %T35
    i64 36, label %T36
    i64 37, label %T37
    i64 38, label %T38
    i64 39, label %T39
  ]
T0F0:
  ret ptr @s26
T0F1:
  ret ptr @s27
T0:
  switch i64 %i, label %TD [
    i64 0, label %T0F0
    i64 1, label %T0F1
  ]
T1F0:
  ret ptr @s28
T1:
  switch i64 %i, label %TD [
    i64 0, label %T1F0
  ]
T2F0:
  ret ptr @s29
T2F1:
  ret ptr @s30
T2F2:
  ret ptr @s31
T2:
  switch i64 %i, label %TD [
    i64 0, label %T2F0
    i64 1, label %T2F1
    i64 2, label %T2F2
  ]
T3F0:
  ret ptr @s32
T3F1:
  ret ptr @s33
T3F2:
  ret ptr @s34
T3:
  switch i64 %i, label %TD [
    i64 0, label %T3F0
    i64 1, label %T3F1
    i64 2, label %T3F2
  ]
T4F0:
  ret ptr @s35
T4F1:
  ret ptr @s34
T4:
  switch i64 %i, label %TD [
    i64 0, label %T4F0
    i64 1, label %T4F1
  ]
T5F0:
  ret ptr @s32
T5:
  switch i64 %i, label %TD [
    i64 0, label %T5F0
  ]
T6F0:
  ret ptr @s32
T6F1:
  ret ptr @s34
T6:
  switch i64 %i, label %TD [
    i64 0, label %T6F0
    i64 1, label %T6F1
  ]
T7F0:
  ret ptr @s32
T7F1:
  ret ptr @s34
T7:
  switch i64 %i, label %TD [
    i64 0, label %T7F0
    i64 1, label %T7F1
  ]
T8F0:
  ret ptr @s36
T8:
  switch i64 %i, label %TD [
    i64 0, label %T8F0
  ]
T9F0:
  ret ptr @s37
T9F1:
  ret ptr @s38
T9:
  switch i64 %i, label %TD [
    i64 0, label %T9F0
    i64 1, label %T9F1
  ]
T10F0:
  ret ptr @s39
T10F1:
  ret ptr @s34
T10:
  switch i64 %i, label %TD [
    i64 0, label %T10F0
    i64 1, label %T10F1
  ]
T11F0:
  ret ptr @s40
T11:
  switch i64 %i, label %TD [
    i64 0, label %T11F0
  ]
T12F0:
  ret ptr @s35
T12F1:
  ret ptr @s41
T12:
  switch i64 %i, label %TD [
    i64 0, label %T12F0
    i64 1, label %T12F1
  ]
T13F0:
  ret ptr @s27
T13:
  switch i64 %i, label %TD [
    i64 0, label %T13F0
  ]
T14F0:
  ret ptr @s42
T14F1:
  ret ptr @s34
T14F2:
  ret ptr @s43
T14:
  switch i64 %i, label %TD [
    i64 0, label %T14F0
    i64 1, label %T14F1
    i64 2, label %T14F2
  ]
T15F0:
  ret ptr @s44
T15F1:
  ret ptr @s34
T15:
  switch i64 %i, label %TD [
    i64 0, label %T15F0
    i64 1, label %T15F1
  ]
T16F0:
  ret ptr @s45
T16:
  switch i64 %i, label %TD [
    i64 0, label %T16F0
  ]
T17F0:
  ret ptr @s46
T17F1:
  ret ptr @s47
T17:
  switch i64 %i, label %TD [
    i64 0, label %T17F0
    i64 1, label %T17F1
  ]
T34F0:
  ret ptr @s48
T34:
  switch i64 %i, label %TD [
    i64 0, label %T34F0
  ]
T35:
  switch i64 %i, label %TD [
  ]
T36F0:
  ret ptr @s49
T36F1:
  ret ptr @s48
T36:
  switch i64 %i, label %TD [
    i64 0, label %T36F0
    i64 1, label %T36F1
  ]
T37F0:
  ret ptr @s50
T37F1:
  ret ptr @s27
T37:
  switch i64 %i, label %TD [
    i64 0, label %T37F0
    i64 1, label %T37F1
  ]
T38F0:
  ret ptr @s28
T38:
  switch i64 %i, label %TD [
    i64 0, label %T38F0
  ]
T39F0:
  ret ptr @s29
T39F1:
  ret ptr @s30
T39F2:
  ret ptr @s31
T39:
  switch i64 %i, label %TD [
    i64 0, label %T39F0
    i64 1, label %T39F1
    i64 2, label %T39F2
  ]
TD:
  ret ptr @s25
}

define %KValue @"d_query/io/args_0"() {
entry:
  %t1 = call %KValue @k_desc_args()
  ret %KValue %t1
fail0:
  call void @k_die(ptr @s52)
  unreachable
}

define %KValue @"d_query/io/env_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_env(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s53)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s54)
  unreachable
}

define %KValue @"d_query/io/exit_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue %x0, ptr %t2
  %t3 = call %KValue @k_rec_reuse(i64 1, i64 1, ptr %t1, %KValue %x0)
  %t4 = call %KValue @k_err(%KValue %t3, ptr @s56)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s55)
  ret %KValue %t7
L2:
  call void @k_die(ptr @s57)
  unreachable
}

define %KValue @"d_query/io/exists_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_exists(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s58)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s59)
  unreachable
}

define %KValue @"d_query/io/is_dir_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_is_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s60)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s61)
  unreachable
}

define %KValue @"d_query/io/list_dir_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_list_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s62)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s63)
  unreachable
}

define %KValue @"d_query/io/read_file_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_read_file(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s64)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s65)
  unreachable
}

define tailcc %KValue @klam0(ptr %env, %KValue %a0) {
entry:
  %t1 = musttail call tailcc %KValue @"d_query/io/answered_1"(%KValue %a0)
  ret %KValue %t1
}

define %KValue @w_klam0(ptr %env, %KValue %a0) {
entry:
  %r = call tailcc %KValue @klam0(ptr %env, %KValue %a0)
  ret %KValue %r
}

define %KValue @"d_query/io/run_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_run(%KValue %x0, %KValue %x1)
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_closure(ptr @w_klam0, i64 1, i64 0, ptr %t2)
  %t4 = call %KValue @k_maybe_bind(%KValue %t1, %KValue %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s66)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s66)
  ret %KValue %t10
L4:
  call void @k_die(ptr @s67)
  unreachable
}

define tailcc %KValue @"d_query/io/answered_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 13
  %t3 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %x0, 1
  %t7 = inttoptr i64 %t6 to ptr
  %t8 = getelementptr %KBytes, ptr %t7, i64 0, i32 0
  %t9 = load i64, ptr %t8
  %t10 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t11 = icmp sge i64 %t10, 1
  %t12 = icmp sle i64 %t10, %t9
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L2
L4:
  %t14 = getelementptr %KBytes, ptr %t7, i64 0, i32 1
  %t15 = load ptr, ptr %t14
  %t16 = add i64 %t10, -1
  %t17 = getelementptr i8, ptr %t15, i64 %t16
  %t18 = load i8, ptr %t17
  %t19 = zext i8 %t18 to i64
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  br label %L3
L2:
  %t21 = call %KValue @k_index(%KValue %x0, %KValue { i64 0, i64 1 }, ptr @s69)
  br label %L3
L3:
  %t22 = phi %KValue [ %t20, %L4 ], [ %t21, %L2 ]
  %t23 = extractvalue %KValue %x0, 0
  %t24 = icmp eq i64 %t23, 13
  %t25 = extractvalue %KValue { i64 0, i64 3 }, 0
  %t26 = icmp eq i64 %t25, 0
  %t27 = and i1 %t24, %t26
  br i1 %t27, label %L5, label %L6
L5:
  %t28 = extractvalue %KValue %x0, 1
  %t29 = inttoptr i64 %t28 to ptr
  %t30 = getelementptr %KBytes, ptr %t29, i64 0, i32 0
  %t31 = load i64, ptr %t30
  %t32 = extractvalue %KValue { i64 0, i64 3 }, 1
  %t33 = icmp sge i64 %t32, 1
  %t34 = icmp sle i64 %t32, %t31
  %t35 = and i1 %t33, %t34
  br i1 %t35, label %L8, label %L6
L8:
  %t36 = getelementptr %KBytes, ptr %t29, i64 0, i32 1
  %t37 = load ptr, ptr %t36
  %t38 = add i64 %t32, -1
  %t39 = getelementptr i8, ptr %t37, i64 %t38
  %t40 = load i8, ptr %t39
  %t41 = zext i8 %t40 to i64
  %t42 = insertvalue %KValue { i64 0, i64 undef }, i64 %t41, 1
  br label %L7
L6:
  %t43 = call %KValue @k_index(%KValue %x0, %KValue { i64 0, i64 3 }, ptr @s69)
  br label %L7
L7:
  %t44 = phi %KValue [ %t42, %L8 ], [ %t43, %L6 ]
  %t45 = extractvalue %KValue %x0, 0
  %t46 = icmp eq i64 %t45, 13
  %t47 = extractvalue %KValue { i64 0, i64 2 }, 0
  %t48 = icmp eq i64 %t47, 0
  %t49 = and i1 %t46, %t48
  br i1 %t49, label %L9, label %L10
L9:
  %t50 = extractvalue %KValue %x0, 1
  %t51 = inttoptr i64 %t50 to ptr
  %t52 = getelementptr %KBytes, ptr %t51, i64 0, i32 0
  %t53 = load i64, ptr %t52
  %t54 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t55 = icmp sge i64 %t54, 1
  %t56 = icmp sle i64 %t54, %t53
  %t57 = and i1 %t55, %t56
  br i1 %t57, label %L12, label %L10
L12:
  %t58 = getelementptr %KBytes, ptr %t51, i64 0, i32 1
  %t59 = load ptr, ptr %t58
  %t60 = add i64 %t54, -1
  %t61 = getelementptr i8, ptr %t59, i64 %t60
  %t62 = load i8, ptr %t61
  %t63 = zext i8 %t62 to i64
  %t64 = insertvalue %KValue { i64 0, i64 undef }, i64 %t63, 1
  br label %L11
L10:
  %t65 = call %KValue @k_index(%KValue %x0, %KValue { i64 0, i64 2 }, ptr @s69)
  br label %L11
L11:
  %t66 = phi %KValue [ %t64, %L12 ], [ %t65, %L10 ]
  %t67 = alloca [3 x %KValue]
  %t68 = getelementptr [3 x %KValue], ptr %t67, i64 0, i64 0
  store %KValue %t22, ptr %t68
  %t69 = getelementptr [3 x %KValue], ptr %t67, i64 0, i64 1
  store %KValue %t44, ptr %t69
  %t70 = getelementptr [3 x %KValue], ptr %t67, i64 0, i64 2
  store %KValue %t66, ptr %t70
  %t71 = call %KValue @k_rec(i64 2, i64 3, ptr %t67)
  ret %KValue %t71
fail0:
  %t72 = call i64 @k_not_failure(%KValue %x0)
  %t73 = icmp ne i64 %t72, 0
  br i1 %t73, label %L14, label %L13
L13:
  %t74 = call %KValue @k_err_hop(%KValue %x0, ptr @s68)
  ret %KValue %t74
L14:
  call void @k_die(ptr @s70)
  unreachable
}

define %KValue @"d_query/io/stdin_0"() {
entry:
  %t1 = call %KValue @k_desc_stdin()
  ret %KValue %t1
fail0:
  call void @k_die(ptr @s72)
  unreachable
}

define %KValue @"d_query/io/write_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_write(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s73)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s74)
  unreachable
}

define %KValue @"d_query/io/write_err_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_write_err(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s75)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s76)
  unreachable
}

define %KValue @"d_query/io/make_dir_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_make_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s77)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s78)
  unreachable
}

define %KValue @"d_query/io/write_file_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_write_file(%KValue %x0, %KValue %x1)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s79)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s79)
  ret %KValue %t7
L4:
  call void @k_die(ptr @s80)
  unreachable
}

define tailcc %KValue @"d_query/list/all?_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t1)
  %t3 = musttail call tailcc %KValue @"d_query/list/holds_all?_2"(%KValue %t2, %KValue %x1)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s81)
  ret %KValue %t6
L2:
  %t7 = call i64 @k_not_failure(%KValue %x1)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L4, label %L3
L3:
  %t9 = call %KValue @k_err_hop(%KValue %x1, ptr @s81)
  ret %KValue %t9
L4:
  call void @k_die(ptr @s82)
  unreachable
}

define tailcc %KValue @"d_query/list/holds_all?_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  ret %KValue { i64 2, i64 0 }
fail0:
  %t6 = call i64 @k_check_rec(%KValue %x0, i64 17, i64 2)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %fail1
L3:
  %t8 = call %KValue @k_field(%KValue %x0, i64 0)
  %t9 = call i64 @k_not_failure(%KValue %t8)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %fail1
L4:
  %t11 = call %KValue @k_field(%KValue %x0, i64 1)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L5, label %fail1
L5:
  %t14 = call %KValue @k_call1(%KValue %x1, %KValue %t8)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L6, label %L7
L7:
  ret %KValue %t14
L6:
  %t17 = call i64 @k_truthy(%KValue %t14)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L8, label %L9
L8:
  %t19 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t11)
  %t20 = musttail call tailcc %KValue @"d_query/list/holds_all?_2"(%KValue %t19, %KValue %x1)
  ret %KValue %t20
L9:
  ret %KValue { i64 3, i64 0 }
fail1:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L11, label %L10
L10:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s83)
  ret %KValue %t23
L11:
  %t24 = call i64 @k_not_failure(%KValue %x1)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L13, label %L12
L12:
  %t26 = call %KValue @k_err_hop(%KValue %x1, ptr @s83)
  ret %KValue %t26
L13:
  call void @k_die(ptr @s84)
  unreachable
}

define tailcc %KValue @"d_query/list/any?_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t1)
  %t3 = musttail call tailcc %KValue @"d_query/list/holds_any?_2"(%KValue %t2, %KValue %x1)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s85)
  ret %KValue %t6
L2:
  %t7 = call i64 @k_not_failure(%KValue %x1)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L4, label %L3
L3:
  %t9 = call %KValue @k_err_hop(%KValue %x1, ptr @s85)
  ret %KValue %t9
L4:
  call void @k_die(ptr @s86)
  unreachable
}

define tailcc %KValue @"d_query/list/holds_any?_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  ret %KValue { i64 3, i64 0 }
fail0:
  %t6 = call i64 @k_check_rec(%KValue %x0, i64 17, i64 2)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %fail1
L3:
  %t8 = call %KValue @k_field(%KValue %x0, i64 0)
  %t9 = call i64 @k_not_failure(%KValue %t8)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %fail1
L4:
  %t11 = call %KValue @k_field(%KValue %x0, i64 1)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L5, label %fail1
L5:
  %t14 = call %KValue @k_call1(%KValue %x1, %KValue %t8)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L6, label %L7
L7:
  ret %KValue %t14
L6:
  %t17 = call i64 @k_truthy(%KValue %t14)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L8, label %L9
L8:
  ret %KValue { i64 2, i64 0 }
L9:
  %t19 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t11)
  %t20 = musttail call tailcc %KValue @"d_query/list/holds_any?_2"(%KValue %t19, %KValue %x1)
  ret %KValue %t20
fail1:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L11, label %L10
L10:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s87)
  ret %KValue %t23
L11:
  %t24 = call i64 @k_not_failure(%KValue %x1)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L13, label %L12
L12:
  %t26 = call %KValue @k_err_hop(%KValue %x1, ptr @s87)
  ret %KValue %t26
L13:
  call void @k_die(ptr @s88)
  unreachable
}

define tailcc %KValue @klam1(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = musttail call tailcc %KValue @"d_query/list/outrank_by_3"(%KValue %a0, %KValue %a1, %KValue %t1)
  ret %KValue %t2
}

define %KValue @w_klam1(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call tailcc %KValue @klam1(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/argmax_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t2
  %t3 = call %KValue @k_rec(i64 11, i64 1, ptr %t1)
  %t4 = alloca [1 x %KValue]
  %t5 = getelementptr [1 x %KValue], ptr %t4, i64 0, i64 0
  store %KValue %x1, ptr %t5
  %t6 = call %KValue @k_closure(ptr @w_klam1, i64 2, i64 1, ptr %t4)
  %t7 = call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t3, %KValue %t6)
  %t8 = musttail call tailcc %KValue @"d_query/list/unwrap_found_1"(%KValue %t7)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_not_failure(%KValue %x0)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L2, label %L1
L1:
  %t11 = call %KValue @k_err_hop(%KValue %x0, ptr @s89)
  ret %KValue %t11
L2:
  %t12 = call i64 @k_not_failure(%KValue %x1)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L3
L3:
  %t14 = call %KValue @k_err_hop(%KValue %x1, ptr @s89)
  ret %KValue %t14
L4:
  call void @k_die(ptr @s90)
  unreachable
}

define tailcc %KValue @klam2(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = musttail call tailcc %KValue @"d_query/list/underrank_by_3"(%KValue %a0, %KValue %a1, %KValue %t1)
  ret %KValue %t2
}

define %KValue @w_klam2(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call tailcc %KValue @klam2(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/argmin_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t2
  %t3 = call %KValue @k_rec(i64 11, i64 1, ptr %t1)
  %t4 = alloca [1 x %KValue]
  %t5 = getelementptr [1 x %KValue], ptr %t4, i64 0, i64 0
  store %KValue %x1, ptr %t5
  %t6 = call %KValue @k_closure(ptr @w_klam2, i64 2, i64 1, ptr %t4)
  %t7 = call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t3, %KValue %t6)
  %t8 = musttail call tailcc %KValue @"d_query/list/unwrap_found_1"(%KValue %t7)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_not_failure(%KValue %x0)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L2, label %L1
L1:
  %t11 = call %KValue @k_err_hop(%KValue %x0, ptr @s91)
  ret %KValue %t11
L2:
  %t12 = call i64 @k_not_failure(%KValue %x1)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L3
L3:
  %t14 = call %KValue @k_err_hop(%KValue %x1, ptr @s91)
  ret %KValue %t14
L4:
  call void @k_die(ptr @s92)
  unreachable
}

define tailcc %KValue @"d_query/list/bisect_5"(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %x3, %KValue %x4) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call i64 @k_not_failure(%KValue %x3)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %fail0
L2:
  %t5 = call i64 @k_not_failure(%KValue %x4)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L3, label %fail0
L3:
  %t7 = extractvalue %KValue %x3, 1
  %t8 = extractvalue %KValue %x2, 1
  %t9 = icmp slt i64 %t7, %t8
  %t10 = select i1 %t9, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t11 = call i64 @k_not_failure(%KValue %t10)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L4, label %L5
L5:
  ret %KValue %t10
L4:
  %t13 = call i64 @k_truthy(%KValue %t10)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L6, label %L7
L6:
  ret %KValue %x4
L7:
  %t15 = extractvalue %KValue %x3, 1
  %t16 = extractvalue %KValue %x2, 1
  %t17 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t15, i64 %t16)
  %t18 = extractvalue { i64, i1 } %t17, 0
  %t19 = extractvalue { i64, i1 } %t17, 1
  br i1 %t19, label %L9, label %L8
L9:
  call void @k_die(ptr @s94)
  unreachable
L8:
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t18, 1
  %t21 = call %KValue @k_div(%KValue %t20, %KValue { i64 0, i64 2 }, ptr @s95)
  %t22 = extractvalue %KValue %x2, 0
  %t23 = extractvalue %KValue %t21, 0
  %t24 = icmp eq i64 %t22, 0
  %t25 = icmp eq i64 %t23, 0
  %t26 = and i1 %t24, %t25
  br i1 %t26, label %L10, label %L11
L10:
  %t27 = extractvalue %KValue %x2, 1
  %t28 = extractvalue %KValue %t21, 1
  %t29 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t27, i64 %t28)
  %t30 = extractvalue { i64, i1 } %t29, 0
  %t31 = extractvalue { i64, i1 } %t29, 1
  br i1 %t31, label %L11, label %L13
L13:
  %t32 = insertvalue %KValue { i64 0, i64 undef }, i64 %t30, 1
  br label %L12
L11:
  %t33 = call %KValue @k_add(%KValue %x2, %KValue %t21)
  br label %L12
L12:
  %t34 = phi %KValue [ %t32, %L13 ], [ %t33, %L11 ]
  %t35 = extractvalue %KValue %x0, 0
  %t36 = icmp eq i64 %t35, 13
  %t37 = extractvalue %KValue %t34, 0
  %t38 = icmp eq i64 %t37, 0
  %t39 = and i1 %t36, %t38
  br i1 %t39, label %L14, label %L15
L14:
  %t40 = extractvalue %KValue %x0, 1
  %t41 = inttoptr i64 %t40 to ptr
  %t42 = getelementptr %KBytes, ptr %t41, i64 0, i32 0
  %t43 = load i64, ptr %t42
  %t44 = extractvalue %KValue %t34, 1
  %t45 = icmp sge i64 %t44, 1
  %t46 = icmp sle i64 %t44, %t43
  %t47 = and i1 %t45, %t46
  br i1 %t47, label %L17, label %L15
L17:
  %t48 = getelementptr %KBytes, ptr %t41, i64 0, i32 1
  %t49 = load ptr, ptr %t48
  %t50 = add i64 %t44, -1
  %t51 = getelementptr i8, ptr %t49, i64 %t50
  %t52 = load i8, ptr %t51
  %t53 = zext i8 %t52 to i64
  %t54 = insertvalue %KValue { i64 0, i64 undef }, i64 %t53, 1
  br label %L16
L15:
  %t55 = call %KValue @k_index(%KValue %x0, %KValue %t34, ptr @s96)
  br label %L16
L16:
  %t56 = phi %KValue [ %t54, %L17 ], [ %t55, %L15 ]
  %t57 = call %KValue @k_call1(%KValue %x1, %KValue %t56)
  %t58 = call i64 @k_not_failure(%KValue %t57)
  %t59 = icmp ne i64 %t58, 0
  br i1 %t59, label %L18, label %L19
L19:
  ret %KValue %t57
L18:
  %t60 = call i64 @k_truthy(%KValue %t57)
  %t61 = icmp ne i64 %t60, 0
  br i1 %t61, label %L20, label %L21
L20:
  %t62 = extractvalue %KValue %t34, 0
  %t63 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t64 = icmp eq i64 %t62, 0
  %t65 = icmp eq i64 %t63, 0
  %t66 = and i1 %t64, %t65
  br i1 %t66, label %L22, label %L23
L22:
  %t67 = extractvalue %KValue %t34, 1
  %t68 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t69 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t67, i64 %t68)
  %t70 = extractvalue { i64, i1 } %t69, 0
  %t71 = extractvalue { i64, i1 } %t69, 1
  br i1 %t71, label %L23, label %L25
L25:
  %t72 = insertvalue %KValue { i64 0, i64 undef }, i64 %t70, 1
  br label %L24
L23:
  %t73 = call %KValue @k_sub(%KValue %t34, %KValue { i64 0, i64 1 })
  br label %L24
L24:
  %t74 = phi %KValue [ %t72, %L25 ], [ %t73, %L23 ]
  %t75 = musttail call tailcc %KValue @"d_query/list/bisect_5"(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %t74, %KValue %t56)
  ret %KValue %t75
L21:
  %t76 = extractvalue %KValue %t34, 0
  %t77 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t78 = icmp eq i64 %t76, 0
  %t79 = icmp eq i64 %t77, 0
  %t80 = and i1 %t78, %t79
  br i1 %t80, label %L26, label %L27
L26:
  %t81 = extractvalue %KValue %t34, 1
  %t82 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t83 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t81, i64 %t82)
  %t84 = extractvalue { i64, i1 } %t83, 0
  %t85 = extractvalue { i64, i1 } %t83, 1
  br i1 %t85, label %L27, label %L29
L29:
  %t86 = insertvalue %KValue { i64 0, i64 undef }, i64 %t84, 1
  br label %L28
L27:
  %t87 = call %KValue @k_add(%KValue %t34, %KValue { i64 0, i64 1 })
  br label %L28
L28:
  %t88 = phi %KValue [ %t86, %L29 ], [ %t87, %L27 ]
  %t89 = musttail call tailcc %KValue @"d_query/list/bisect_5"(%KValue %x0, %KValue %x1, %KValue %t88, %KValue %x3, %KValue %x4)
  ret %KValue %t89
fail0:
  %t90 = call i64 @k_not_failure(%KValue %x0)
  %t91 = icmp ne i64 %t90, 0
  br i1 %t91, label %L31, label %L30
L30:
  %t92 = call %KValue @k_err_hop(%KValue %x0, ptr @s93)
  ret %KValue %t92
L31:
  %t93 = call i64 @k_not_failure(%KValue %x1)
  %t94 = icmp ne i64 %t93, 0
  br i1 %t94, label %L33, label %L32
L32:
  %t95 = call %KValue @k_err_hop(%KValue %x1, ptr @s93)
  ret %KValue %t95
L33:
  %t96 = call i64 @k_not_failure(%KValue %x2)
  %t97 = icmp ne i64 %t96, 0
  br i1 %t97, label %L35, label %L34
L34:
  %t98 = call %KValue @k_err_hop(%KValue %x2, ptr @s93)
  ret %KValue %t98
L35:
  %t99 = call i64 @k_not_failure(%KValue %x3)
  %t100 = icmp ne i64 %t99, 0
  br i1 %t100, label %L37, label %L36
L36:
  %t101 = call %KValue @k_err_hop(%KValue %x3, ptr @s93)
  ret %KValue %t101
L37:
  %t102 = call i64 @k_not_failure(%KValue %x4)
  %t103 = icmp ne i64 %t102, 0
  br i1 %t103, label %L39, label %L38
L38:
  %t104 = call %KValue @k_err_hop(%KValue %x4, ptr @s93)
  ret %KValue %t104
L39:
  call void @k_die(ptr @s97)
  unreachable
}

define %KValue @"d_query/list/bump_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 4
  br i1 %t2, label %L1, label %fail0
L1:
  ret %KValue { i64 0, i64 1 }
fail0:
  %t3 = extractvalue %KValue %x0, 0
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t5 = icmp eq i64 %t3, 0
  %t6 = icmp eq i64 %t4, 0
  %t7 = and i1 %t5, %t6
  br i1 %t7, label %L2, label %L3
L2:
  %t8 = extractvalue %KValue %x0, 1
  %t9 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t10 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t8, i64 %t9)
  %t11 = extractvalue { i64, i1 } %t10, 0
  %t12 = extractvalue { i64, i1 } %t10, 1
  br i1 %t12, label %L3, label %L5
L5:
  %t13 = insertvalue %KValue { i64 0, i64 undef }, i64 %t11, 1
  br label %L4
L3:
  %t14 = call %KValue @k_add(%KValue %x0, %KValue { i64 0, i64 1 })
  br label %L4
L4:
  %t15 = phi %KValue [ %t13, %L5 ], [ %t14, %L3 ]
  ret %KValue %t15
fail1:
  %t16 = call i64 @k_not_failure(%KValue %x0)
  %t17 = icmp ne i64 %t16, 0
  br i1 %t17, label %L7, label %L6
L6:
  %t18 = call %KValue @k_err_hop(%KValue %x0, ptr @s98)
  ret %KValue %t18
L7:
  call void @k_die(ptr @s99)
  unreachable
}

define %KValue @klam3(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = call %KValue @k_call1(%KValue %t1, %KValue %a1)
  %t3 = call i64 @k_not_failure(%KValue %t2)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L1, label %L2
L2:
  ret %KValue %t2
L1:
  %t5 = call i64 @k_truthy(%KValue %t2)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L3, label %L4
L3:
  %t7 = extractvalue %KValue %a0, 0
  %t8 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t9 = icmp eq i64 %t7, 0
  %t10 = icmp eq i64 %t8, 0
  %t11 = and i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = extractvalue %KValue %a0, 1
  %t13 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t14 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t12, i64 %t13)
  %t15 = extractvalue { i64, i1 } %t14, 0
  %t16 = extractvalue { i64, i1 } %t14, 1
  br i1 %t16, label %L6, label %L8
L8:
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t15, 1
  br label %L7
L6:
  %t18 = call %KValue @k_add(%KValue %a0, %KValue { i64 0, i64 1 })
  br label %L7
L7:
  %t19 = phi %KValue [ %t17, %L8 ], [ %t18, %L6 ]
  ret %KValue %t19
L4:
  ret %KValue %a0
}

define %KValue @w_klam3(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam3(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/count_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue %x1, ptr %t2
  %t3 = call %KValue @k_closure(ptr @w_klam3, i64 2, i64 1, ptr %t1)
  %t4 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue { i64 0, i64 0 }, %KValue %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s100)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s100)
  ret %KValue %t10
L4:
  call void @k_die(ptr @s101)
  unreachable
}

define %KValue @"d_query/list/cycle_1"(%KValue %x0) {
entry:
  %t1 = call tailcc %KValue @"d_query/list/to_list_1"(%KValue %x0)
  %t2 = alloca [2 x %KValue]
  %t3 = getelementptr [2 x %KValue], ptr %t2, i64 0, i64 0
  store %KValue { i64 0, i64 1 }, ptr %t3
  %t4 = getelementptr [2 x %KValue], ptr %t2, i64 0, i64 1
  store %KValue %t1, ptr %t4
  %t5 = call %KValue @k_rec_reuse(i64 7, i64 2, ptr %t2, %KValue %x0)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s102)
  ret %KValue %t8
L2:
  call void @k_die(ptr @s103)
  unreachable
}

define %KValue @"d_query/list/drop_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = alloca [2 x %KValue]
  %t3 = getelementptr [2 x %KValue], ptr %t2, i64 0, i64 0
  store %KValue %x1, ptr %t3
  %t4 = getelementptr [2 x %KValue], ptr %t2, i64 0, i64 1
  store %KValue %t1, ptr %t4
  %t5 = call %KValue @k_rec(i64 15, i64 2, ptr %t2)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s104)
  ret %KValue %t8
L2:
  %t9 = call i64 @k_not_failure(%KValue %x1)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %L3
L3:
  %t11 = call %KValue @k_err_hop(%KValue %x1, ptr @s104)
  ret %KValue %t11
L4:
  call void @k_die(ptr @s105)
  unreachable
}

define tailcc %KValue @"d_query/list/find_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 16, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_b_length_fast(%KValue %t3)
  %t7 = musttail call tailcc %KValue @"d_query/list/bisect_5"(%KValue %t3, %KValue %x1, %KValue { i64 0, i64 1 }, %KValue %t6, %KValue { i64 4, i64 0 })
  ret %KValue %t7
fail0:
  %t8 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t9 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t8)
  %t10 = musttail call tailcc %KValue @"d_query/list/found_in_2"(%KValue %t9, %KValue %x1)
  ret %KValue %t10
fail1:
  %t11 = call i64 @k_not_failure(%KValue %x0)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L4, label %L3
L3:
  %t13 = call %KValue @k_err_hop(%KValue %x0, ptr @s106)
  ret %KValue %t13
L4:
  %t14 = call i64 @k_not_failure(%KValue %x1)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %L5
L5:
  %t16 = call %KValue @k_err_hop(%KValue %x1, ptr @s106)
  ret %KValue %t16
L6:
  call void @k_die(ptr @s107)
  unreachable
}

define tailcc %KValue @"d_query/list/found_in_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  ret %KValue { i64 4, i64 0 }
fail0:
  %t6 = call i64 @k_check_rec(%KValue %x0, i64 17, i64 2)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %fail1
L3:
  %t8 = call %KValue @k_field(%KValue %x0, i64 0)
  %t9 = call i64 @k_not_failure(%KValue %t8)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %fail1
L4:
  %t11 = call %KValue @k_field(%KValue %x0, i64 1)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L5, label %fail1
L5:
  %t14 = call %KValue @k_call1(%KValue %x1, %KValue %t8)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L6, label %L7
L7:
  ret %KValue %t14
L6:
  %t17 = call i64 @k_truthy(%KValue %t14)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L8, label %L9
L8:
  ret %KValue %t8
L9:
  %t19 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t11)
  %t20 = musttail call tailcc %KValue @"d_query/list/found_in_2"(%KValue %t19, %KValue %x1)
  ret %KValue %t20
fail1:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L11, label %L10
L10:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s108)
  ret %KValue %t23
L11:
  %t24 = call i64 @k_not_failure(%KValue %x1)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L13, label %L12
L12:
  %t26 = call %KValue @k_err_hop(%KValue %x1, ptr @s108)
  ret %KValue %t26
L13:
  call void @k_die(ptr @s109)
  unreachable
}

define tailcc %KValue @"d_query/list/first_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t1)
  %t3 = musttail call tailcc %KValue @"d_query/list/first_of_1"(%KValue %t2)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s110)
  ret %KValue %t6
L2:
  call void @k_die(ptr @s111)
  unreachable
}

define tailcc %KValue @"d_query/list/first_of_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  ret %KValue { i64 4, i64 0 }
fail0:
  %t6 = call i64 @k_check_rec(%KValue %x0, i64 17, i64 2)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %fail1
L3:
  %t8 = call %KValue @k_field(%KValue %x0, i64 0)
  %t9 = call i64 @k_not_failure(%KValue %t8)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %fail1
L4:
  %t11 = call %KValue @k_field(%KValue %x0, i64 1)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L5, label %fail1
L5:
  ret %KValue %t8
fail1:
  %t14 = call i64 @k_not_failure(%KValue %x0)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L7, label %L6
L6:
  %t16 = call %KValue @k_err_hop(%KValue %x0, ptr @s112)
  ret %KValue %t16
L7:
  call void @k_die(ptr @s113)
  unreachable
}

define tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 4, i64 2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %x0, i64 1)
  %t7 = call i64 @k_check_rec(%KValue %t6, i64 6, i64 2)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = call %KValue @k_field(%KValue %t6, i64 0)
  %t10 = call i64 @k_not_failure(%KValue %t9)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %fail0
L4:
  %t12 = call %KValue @k_field(%KValue %t6, i64 1)
  %t13 = call i64 @k_not_failure(%KValue %t12)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L5, label %fail0
L5:
  %t15 = extractvalue %KValue %t9, 0
  %t16 = extractvalue %KValue %t3, 0
  %t17 = icmp eq i64 %t15, 0
  %t18 = icmp eq i64 %t16, 0
  %t19 = and i1 %t17, %t18
  br i1 %t19, label %L6, label %L7
L6:
  %t20 = extractvalue %KValue %t9, 1
  %t21 = extractvalue %KValue %t3, 1
  %t22 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t20, i64 %t21)
  %t23 = extractvalue { i64, i1 } %t22, 0
  %t24 = extractvalue { i64, i1 } %t22, 1
  br i1 %t24, label %L7, label %L9
L9:
  %t25 = insertvalue %KValue { i64 0, i64 undef }, i64 %t23, 1
  br label %L8
L7:
  %t26 = call %KValue @k_add(%KValue %t9, %KValue %t3)
  br label %L8
L8:
  %t27 = phi %KValue [ %t25, %L9 ], [ %t26, %L7 ]
  %t28 = extractvalue %KValue %t27, 0
  %t29 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t30 = icmp eq i64 %t28, 0
  %t31 = icmp eq i64 %t29, 0
  %t32 = and i1 %t30, %t31
  br i1 %t32, label %L10, label %L11
L10:
  %t33 = extractvalue %KValue %t27, 1
  %t34 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t35 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t33, i64 %t34)
  %t36 = extractvalue { i64, i1 } %t35, 0
  %t37 = extractvalue { i64, i1 } %t35, 1
  br i1 %t37, label %L11, label %L13
L13:
  %t38 = insertvalue %KValue { i64 0, i64 undef }, i64 %t36, 1
  br label %L12
L11:
  %t39 = call %KValue @k_sub(%KValue %t27, %KValue { i64 0, i64 1 })
  br label %L12
L12:
  %t40 = phi %KValue [ %t38, %L13 ], [ %t39, %L11 ]
  %t41 = extractvalue %KValue %t9, 1
  %t42 = musttail call tailcc %KValue @"d_query/list/bounded_flat_5"(%KValue %t12, %KValue %x1, %KValue %x2, i64 %t41, %KValue %t40)
  ret %KValue %t42
fail0:
  %t43 = call i64 @k_check_rec(%KValue %x0, i64 3, i64 3)
  %t44 = icmp ne i64 %t43, 0
  br i1 %t44, label %L14, label %fail1
L14:
  %t45 = call %KValue @k_field(%KValue %x0, i64 0)
  %t46 = call i64 @k_not_failure(%KValue %t45)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L15, label %fail1
L15:
  %t48 = call %KValue @k_field(%KValue %x0, i64 1)
  %t49 = call i64 @k_not_failure(%KValue %t48)
  %t50 = icmp ne i64 %t49, 0
  br i1 %t50, label %L16, label %fail1
L16:
  %t51 = call %KValue @k_field(%KValue %x0, i64 2)
  %t52 = call i64 @k_not_failure(%KValue %t51)
  %t53 = icmp ne i64 %t52, 0
  br i1 %t53, label %L17, label %fail1
L17:
  %t54 = extractvalue %KValue %t45, 1
  %t55 = musttail call tailcc %KValue @"d_query/list/bounded_flat_5"(%KValue %t51, %KValue %x1, %KValue %x2, i64 %t54, %KValue %t48)
  ret %KValue %t55
fail1:
  %t56 = call i64 @k_check_rec(%KValue %x0, i64 4, i64 2)
  %t57 = icmp ne i64 %t56, 0
  br i1 %t57, label %L18, label %fail2
L18:
  %t58 = call %KValue @k_field(%KValue %x0, i64 0)
  %t59 = call i64 @k_not_failure(%KValue %t58)
  %t60 = icmp ne i64 %t59, 0
  br i1 %t60, label %L19, label %fail2
L19:
  %t61 = call %KValue @k_field(%KValue %x0, i64 1)
  %t62 = call i64 @k_not_failure(%KValue %t61)
  %t63 = icmp ne i64 %t62, 0
  br i1 %t63, label %L20, label %fail2
L20:
  %t64 = alloca [2 x %KValue]
  %t65 = getelementptr [2 x %KValue], ptr %t64, i64 0, i64 0
  store %KValue %t58, ptr %t65
  %t66 = getelementptr [2 x %KValue], ptr %t64, i64 0, i64 1
  store %KValue %t61, ptr %t66
  %t67 = call %KValue @k_rec(i64 4, i64 2, ptr %t64)
  %t68 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t67)
  %t69 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t68, %KValue %x1, %KValue %x2)
  ret %KValue %t69
fail2:
  %t70 = call i64 @k_check_rec(%KValue %x0, i64 5, i64 1)
  %t71 = icmp ne i64 %t70, 0
  br i1 %t71, label %L21, label %fail3
L21:
  %t72 = call %KValue @k_field(%KValue %x0, i64 0)
  %t73 = call i64 @k_not_failure(%KValue %t72)
  %t74 = icmp ne i64 %t73, 0
  br i1 %t74, label %L22, label %fail3
L22:
  %t75 = alloca [1 x %KValue]
  %t76 = getelementptr [1 x %KValue], ptr %t75, i64 0, i64 0
  store %KValue %t72, ptr %t76
  %t77 = call %KValue @k_rec(i64 5, i64 1, ptr %t75)
  %t78 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t77)
  %t79 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t78, %KValue %x1, %KValue %x2)
  ret %KValue %t79
fail3:
  %t80 = call i64 @k_check_rec(%KValue %x0, i64 6, i64 2)
  %t81 = icmp ne i64 %t80, 0
  br i1 %t81, label %L23, label %fail4
L23:
  %t82 = call %KValue @k_field(%KValue %x0, i64 0)
  %t83 = call i64 @k_not_failure(%KValue %t82)
  %t84 = icmp ne i64 %t83, 0
  br i1 %t84, label %L24, label %fail4
L24:
  %t85 = call %KValue @k_field(%KValue %x0, i64 1)
  %t86 = call i64 @k_not_failure(%KValue %t85)
  %t87 = icmp ne i64 %t86, 0
  br i1 %t87, label %L25, label %fail4
L25:
  %t88 = alloca [2 x %KValue]
  %t89 = getelementptr [2 x %KValue], ptr %t88, i64 0, i64 0
  store %KValue %t82, ptr %t89
  %t90 = getelementptr [2 x %KValue], ptr %t88, i64 0, i64 1
  store %KValue %t85, ptr %t90
  %t91 = call %KValue @k_rec(i64 6, i64 2, ptr %t88)
  %t92 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t91)
  %t93 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t92, %KValue %x1, %KValue %x2)
  ret %KValue %t93
fail4:
  %t94 = call i64 @k_check_rec(%KValue %x0, i64 7, i64 2)
  %t95 = icmp ne i64 %t94, 0
  br i1 %t95, label %L26, label %fail5
L26:
  %t96 = call %KValue @k_field(%KValue %x0, i64 0)
  %t97 = call i64 @k_not_failure(%KValue %t96)
  %t98 = icmp ne i64 %t97, 0
  br i1 %t98, label %L27, label %fail5
L27:
  %t99 = call %KValue @k_field(%KValue %x0, i64 1)
  %t100 = call i64 @k_not_failure(%KValue %t99)
  %t101 = icmp ne i64 %t100, 0
  br i1 %t101, label %L28, label %fail5
L28:
  %t102 = alloca [2 x %KValue]
  %t103 = getelementptr [2 x %KValue], ptr %t102, i64 0, i64 0
  store %KValue %t96, ptr %t103
  %t104 = getelementptr [2 x %KValue], ptr %t102, i64 0, i64 1
  store %KValue %t99, ptr %t104
  %t105 = call %KValue @k_rec(i64 7, i64 2, ptr %t102)
  %t106 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t105)
  %t107 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t106, %KValue %x1, %KValue %x2)
  ret %KValue %t107
fail5:
  %t108 = call i64 @k_check_rec(%KValue %x0, i64 9, i64 2)
  %t109 = icmp ne i64 %t108, 0
  br i1 %t109, label %L29, label %fail6
L29:
  %t110 = call %KValue @k_field(%KValue %x0, i64 0)
  %t111 = call i64 @k_not_failure(%KValue %t110)
  %t112 = icmp ne i64 %t111, 0
  br i1 %t112, label %L30, label %fail6
L30:
  %t113 = call %KValue @k_field(%KValue %x0, i64 1)
  %t114 = call i64 @k_not_failure(%KValue %t113)
  %t115 = icmp ne i64 %t114, 0
  br i1 %t115, label %L31, label %fail6
L31:
  %t116 = alloca [2 x %KValue]
  %t117 = getelementptr [2 x %KValue], ptr %t116, i64 0, i64 0
  store %KValue %t110, ptr %t117
  %t118 = getelementptr [2 x %KValue], ptr %t116, i64 0, i64 1
  store %KValue %t113, ptr %t118
  %t119 = call %KValue @k_rec(i64 9, i64 2, ptr %t116)
  %t120 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t119)
  %t121 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t120, %KValue %x1, %KValue %x2)
  ret %KValue %t121
fail6:
  %t122 = call i64 @k_check_rec(%KValue %x0, i64 10, i64 2)
  %t123 = icmp ne i64 %t122, 0
  br i1 %t123, label %L32, label %fail7
L32:
  %t124 = call %KValue @k_field(%KValue %x0, i64 0)
  %t125 = call i64 @k_not_failure(%KValue %t124)
  %t126 = icmp ne i64 %t125, 0
  br i1 %t126, label %L33, label %fail7
L33:
  %t127 = call %KValue @k_field(%KValue %x0, i64 1)
  %t128 = call i64 @k_not_failure(%KValue %t127)
  %t129 = icmp ne i64 %t128, 0
  br i1 %t129, label %L34, label %fail7
L34:
  %t130 = alloca [2 x %KValue]
  %t131 = getelementptr [2 x %KValue], ptr %t130, i64 0, i64 0
  store %KValue %t124, ptr %t131
  %t132 = getelementptr [2 x %KValue], ptr %t130, i64 0, i64 1
  store %KValue %t127, ptr %t132
  %t133 = call %KValue @k_rec(i64 10, i64 2, ptr %t130)
  %t134 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t133)
  %t135 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t134, %KValue %x1, %KValue %x2)
  ret %KValue %t135
fail7:
  %t136 = call i64 @k_check_rec(%KValue %x0, i64 12, i64 2)
  %t137 = icmp ne i64 %t136, 0
  br i1 %t137, label %L35, label %fail8
L35:
  %t138 = call %KValue @k_field(%KValue %x0, i64 0)
  %t139 = call i64 @k_not_failure(%KValue %t138)
  %t140 = icmp ne i64 %t139, 0
  br i1 %t140, label %L36, label %fail8
L36:
  %t141 = call %KValue @k_field(%KValue %x0, i64 1)
  %t142 = call i64 @k_not_failure(%KValue %t141)
  %t143 = icmp ne i64 %t142, 0
  br i1 %t143, label %L37, label %fail8
L37:
  %t144 = alloca [2 x %KValue]
  %t145 = getelementptr [2 x %KValue], ptr %t144, i64 0, i64 0
  store %KValue %t138, ptr %t145
  %t146 = getelementptr [2 x %KValue], ptr %t144, i64 0, i64 1
  store %KValue %t141, ptr %t146
  %t147 = call %KValue @k_rec(i64 12, i64 2, ptr %t144)
  %t148 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t147)
  %t149 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t148, %KValue %x1, %KValue %x2)
  ret %KValue %t149
fail8:
  %t150 = call i64 @k_check_rec(%KValue %x0, i64 13, i64 1)
  %t151 = icmp ne i64 %t150, 0
  br i1 %t151, label %L38, label %fail9
L38:
  %t152 = call %KValue @k_field(%KValue %x0, i64 0)
  %t153 = call i64 @k_not_failure(%KValue %t152)
  %t154 = icmp ne i64 %t153, 0
  br i1 %t154, label %L39, label %fail9
L39:
  %t155 = alloca [1 x %KValue]
  %t156 = getelementptr [1 x %KValue], ptr %t155, i64 0, i64 0
  store %KValue %t152, ptr %t156
  %t157 = call %KValue @k_rec(i64 13, i64 1, ptr %t155)
  %t158 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t157)
  %t159 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t158, %KValue %x1, %KValue %x2)
  ret %KValue %t159
fail9:
  %t160 = call i64 @k_check_rec(%KValue %x0, i64 14, i64 3)
  %t161 = icmp ne i64 %t160, 0
  br i1 %t161, label %L40, label %fail10
L40:
  %t162 = call %KValue @k_field(%KValue %x0, i64 0)
  %t163 = call i64 @k_not_failure(%KValue %t162)
  %t164 = icmp ne i64 %t163, 0
  br i1 %t164, label %L41, label %fail10
L41:
  %t165 = call %KValue @k_field(%KValue %x0, i64 1)
  %t166 = call i64 @k_not_failure(%KValue %t165)
  %t167 = icmp ne i64 %t166, 0
  br i1 %t167, label %L42, label %fail10
L42:
  %t168 = call %KValue @k_field(%KValue %x0, i64 2)
  %t169 = call i64 @k_not_failure(%KValue %t168)
  %t170 = icmp ne i64 %t169, 0
  br i1 %t170, label %L43, label %fail10
L43:
  %t171 = alloca [3 x %KValue]
  %t172 = getelementptr [3 x %KValue], ptr %t171, i64 0, i64 0
  store %KValue %t162, ptr %t172
  %t173 = getelementptr [3 x %KValue], ptr %t171, i64 0, i64 1
  store %KValue %t165, ptr %t173
  %t174 = getelementptr [3 x %KValue], ptr %t171, i64 0, i64 2
  store %KValue %t168, ptr %t174
  %t175 = call %KValue @k_rec(i64 14, i64 3, ptr %t171)
  %t176 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t175)
  %t177 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t176, %KValue %x1, %KValue %x2)
  ret %KValue %t177
fail10:
  %t178 = call i64 @k_check_rec(%KValue %x0, i64 15, i64 2)
  %t179 = icmp ne i64 %t178, 0
  br i1 %t179, label %L44, label %fail11
L44:
  %t180 = call %KValue @k_field(%KValue %x0, i64 0)
  %t181 = call i64 @k_not_failure(%KValue %t180)
  %t182 = icmp ne i64 %t181, 0
  br i1 %t182, label %L45, label %fail11
L45:
  %t183 = call %KValue @k_field(%KValue %x0, i64 1)
  %t184 = call i64 @k_not_failure(%KValue %t183)
  %t185 = icmp ne i64 %t184, 0
  br i1 %t185, label %L46, label %fail11
L46:
  %t186 = alloca [2 x %KValue]
  %t187 = getelementptr [2 x %KValue], ptr %t186, i64 0, i64 0
  store %KValue %t180, ptr %t187
  %t188 = getelementptr [2 x %KValue], ptr %t186, i64 0, i64 1
  store %KValue %t183, ptr %t188
  %t189 = call %KValue @k_rec(i64 15, i64 2, ptr %t186)
  %t190 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t189)
  %t191 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t190, %KValue %x1, %KValue %x2)
  ret %KValue %t191
fail11:
  %t192 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t193 = musttail call tailcc %KValue @"d_query/list/fold_flat_4"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %t192)
  ret %KValue %t193
fail12:
  %t194 = call i64 @k_not_failure(%KValue %x0)
  %t195 = icmp ne i64 %t194, 0
  br i1 %t195, label %L48, label %L47
L47:
  %t196 = call %KValue @k_err_hop(%KValue %x0, ptr @s114)
  ret %KValue %t196
L48:
  %t197 = call i64 @k_not_failure(%KValue %x1)
  %t198 = icmp ne i64 %t197, 0
  br i1 %t198, label %L50, label %L49
L49:
  %t199 = call %KValue @k_err_hop(%KValue %x1, ptr @s114)
  ret %KValue %t199
L50:
  %t200 = call i64 @k_not_failure(%KValue %x2)
  %t201 = icmp ne i64 %t200, 0
  br i1 %t201, label %L52, label %L51
L51:
  %t202 = call %KValue @k_err_hop(%KValue %x2, ptr @s114)
  ret %KValue %t202
L52:
  call void @k_die(ptr @s115)
  unreachable
}

define tailcc %KValue @"d_query/list/bounded_flat_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %x3r, %KValue %x4) {
entry:
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %t1 = call i64 @k_not_failure(%KValue %x1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x4, 0
  %t4 = extractvalue %KValue %x3, 0
  %t5 = icmp eq i64 %t3, 0
  %t6 = icmp eq i64 %t4, 0
  %t7 = and i1 %t5, %t6
  br i1 %t7, label %L2, label %L3
L2:
  %t8 = extractvalue %KValue %x4, 1
  %t9 = extractvalue %KValue %x3, 1
  %t10 = icmp slt i64 %t8, %t9
  %t11 = select i1 %t10, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L4
L3:
  %t12 = call %KValue @k_cmp(%KValue %x4, %KValue %x3, i64 2)
  br label %L4
L4:
  %t13 = phi %KValue [ %t11, %L2 ], [ %t12, %L3 ]
  %t14 = call i64 @k_not_failure(%KValue %t13)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L5, label %L6
L6:
  ret %KValue %t13
L5:
  %t16 = call i64 @k_truthy(%KValue %t13)
  %t17 = icmp ne i64 %t16, 0
  br i1 %t17, label %L7, label %L8
L7:
  ret %KValue %x1
L8:
  %t18 = extractvalue %KValue %x3, 1
  %t19 = musttail call tailcc %KValue @"d_query/list/bounded_more_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %t18, %KValue %x4)
  ret %KValue %t19
fail0:
  %t20 = call i64 @k_not_failure(%KValue %x0)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L10, label %L9
L9:
  %t22 = call %KValue @k_err_hop(%KValue %x0, ptr @s116)
  ret %KValue %t22
L10:
  %t23 = call i64 @k_not_failure(%KValue %x1)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L12, label %L11
L11:
  %t25 = call %KValue @k_err_hop(%KValue %x1, ptr @s116)
  ret %KValue %t25
L12:
  %t26 = call i64 @k_not_failure(%KValue %x2)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L14, label %L13
L13:
  %t28 = call %KValue @k_err_hop(%KValue %x2, ptr @s116)
  ret %KValue %t28
L14:
  %t29 = call i64 @k_not_failure(%KValue %x3)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L16, label %L15
L15:
  %t31 = call %KValue @k_err_hop(%KValue %x3, ptr @s116)
  ret %KValue %t31
L16:
  %t32 = call i64 @k_not_failure(%KValue %x4)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L18, label %L17
L17:
  %t34 = call %KValue @k_err_hop(%KValue %x4, ptr @s116)
  ret %KValue %t34
L18:
  call void @k_die(ptr @s117)
  unreachable
}

define tailcc %KValue @"d_query/list/bounded_more_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %x3r, %KValue %x4) {
entry:
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %t1 = call %KValue @k_b_length_fast(%KValue %x0)
  %t2 = extractvalue %KValue %t1, 1
  %t3 = extractvalue %KValue %x3, 1
  %t4 = icmp slt i64 %t2, %t3
  %t5 = select i1 %t4, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L1, label %L2
L2:
  ret %KValue %t5
L1:
  %t8 = call i64 @k_truthy(%KValue %t5)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L4
L3:
  ret %KValue %x1
L4:
  %t10 = extractvalue %KValue %x3, 1
  %t11 = musttail call tailcc %KValue @"d_query/list/bounded_step_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %t10, %KValue %x4)
  ret %KValue %t11
fail0:
  %t12 = call i64 @k_not_failure(%KValue %x0)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L6, label %L5
L5:
  %t14 = call %KValue @k_err_hop(%KValue %x0, ptr @s118)
  ret %KValue %t14
L6:
  %t15 = call i64 @k_not_failure(%KValue %x1)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L8, label %L7
L7:
  %t17 = call %KValue @k_err_hop(%KValue %x1, ptr @s118)
  ret %KValue %t17
L8:
  %t18 = call i64 @k_not_failure(%KValue %x2)
  %t19 = icmp ne i64 %t18, 0
  br i1 %t19, label %L10, label %L9
L9:
  %t20 = call %KValue @k_err_hop(%KValue %x2, ptr @s118)
  ret %KValue %t20
L10:
  %t21 = call i64 @k_not_failure(%KValue %x3)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L12, label %L11
L11:
  %t23 = call %KValue @k_err_hop(%KValue %x3, ptr @s118)
  ret %KValue %t23
L12:
  %t24 = call i64 @k_not_failure(%KValue %x4)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L14, label %L13
L13:
  %t26 = call %KValue @k_err_hop(%KValue %x4, ptr @s118)
  ret %KValue %t26
L14:
  call void @k_die(ptr @s119)
  unreachable
}

define tailcc %KValue @"d_query/list/bounded_step_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %x3r, %KValue %x4) {
entry:
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 13
  %t3 = extractvalue %KValue %x3, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %x0, 1
  %t7 = inttoptr i64 %t6 to ptr
  %t8 = getelementptr %KBytes, ptr %t7, i64 0, i32 0
  %t9 = load i64, ptr %t8
  %t10 = extractvalue %KValue %x3, 1
  %t11 = icmp sge i64 %t10, 1
  %t12 = icmp sle i64 %t10, %t9
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L2
L4:
  %t14 = getelementptr %KBytes, ptr %t7, i64 0, i32 1
  %t15 = load ptr, ptr %t14
  %t16 = add i64 %t10, -1
  %t17 = getelementptr i8, ptr %t15, i64 %t16
  %t18 = load i8, ptr %t17
  %t19 = zext i8 %t18 to i64
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  br label %L3
L2:
  %t21 = call %KValue @k_index(%KValue %x0, %KValue %x3, ptr @s121)
  br label %L3
L3:
  %t22 = phi %KValue [ %t20, %L4 ], [ %t21, %L2 ]
  %t23 = call %KValue @k_call2(%KValue %x2, %KValue %x1, %KValue %t22)
  %t24 = extractvalue %KValue %x3, 1
  %t25 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t26 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t24, i64 %t25)
  %t27 = extractvalue { i64, i1 } %t26, 0
  %t28 = extractvalue { i64, i1 } %t26, 1
  br i1 %t28, label %L6, label %L5
L6:
  call void @k_die(ptr @s94)
  unreachable
L5:
  %t29 = insertvalue %KValue { i64 0, i64 undef }, i64 %t27, 1
  %t30 = extractvalue %KValue %t29, 1
  %t31 = musttail call tailcc %KValue @"d_query/list/bounded_flat_5"(%KValue %x0, %KValue %t23, %KValue %x2, i64 %t30, %KValue %x4)
  ret %KValue %t31
fail0:
  %t32 = call i64 @k_not_failure(%KValue %x0)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L8, label %L7
L7:
  %t34 = call %KValue @k_err_hop(%KValue %x0, ptr @s120)
  ret %KValue %t34
L8:
  %t35 = call i64 @k_not_failure(%KValue %x1)
  %t36 = icmp ne i64 %t35, 0
  br i1 %t36, label %L10, label %L9
L9:
  %t37 = call %KValue @k_err_hop(%KValue %x1, ptr @s120)
  ret %KValue %t37
L10:
  %t38 = call i64 @k_not_failure(%KValue %x2)
  %t39 = icmp ne i64 %t38, 0
  br i1 %t39, label %L12, label %L11
L11:
  %t40 = call %KValue @k_err_hop(%KValue %x2, ptr @s120)
  ret %KValue %t40
L12:
  %t41 = call i64 @k_not_failure(%KValue %x3)
  %t42 = icmp ne i64 %t41, 0
  br i1 %t42, label %L14, label %L13
L13:
  %t43 = call %KValue @k_err_hop(%KValue %x3, ptr @s120)
  ret %KValue %t43
L14:
  %t44 = call i64 @k_not_failure(%KValue %x4)
  %t45 = icmp ne i64 %t44, 0
  br i1 %t45, label %L16, label %L15
L15:
  %t46 = call %KValue @k_err_hop(%KValue %x4, ptr @s120)
  ret %KValue %t46
L16:
  call void @k_die(ptr @s122)
  unreachable
}

define tailcc %KValue @"d_query/list/fold_flat_4"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %x3r) {
entry:
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %t1 = call i64 @k_not_failure(%KValue %x1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_length_fast(%KValue %x0)
  %t4 = extractvalue %KValue %t3, 1
  %t5 = extractvalue %KValue %x3, 1
  %t6 = icmp slt i64 %t4, %t5
  %t7 = select i1 %t6, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t8 = call i64 @k_not_failure(%KValue %t7)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L3
L3:
  ret %KValue %t7
L2:
  %t10 = call i64 @k_truthy(%KValue %t7)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L5
L4:
  ret %KValue %x1
L5:
  %t12 = extractvalue %KValue %x0, 0
  %t13 = icmp eq i64 %t12, 13
  %t14 = extractvalue %KValue %x3, 0
  %t15 = icmp eq i64 %t14, 0
  %t16 = and i1 %t13, %t15
  br i1 %t16, label %L6, label %L7
L6:
  %t17 = extractvalue %KValue %x0, 1
  %t18 = inttoptr i64 %t17 to ptr
  %t19 = getelementptr %KBytes, ptr %t18, i64 0, i32 0
  %t20 = load i64, ptr %t19
  %t21 = extractvalue %KValue %x3, 1
  %t22 = icmp sge i64 %t21, 1
  %t23 = icmp sle i64 %t21, %t20
  %t24 = and i1 %t22, %t23
  br i1 %t24, label %L9, label %L7
L9:
  %t25 = getelementptr %KBytes, ptr %t18, i64 0, i32 1
  %t26 = load ptr, ptr %t25
  %t27 = add i64 %t21, -1
  %t28 = getelementptr i8, ptr %t26, i64 %t27
  %t29 = load i8, ptr %t28
  %t30 = zext i8 %t29 to i64
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t30, 1
  br label %L8
L7:
  %t32 = call %KValue @k_index(%KValue %x0, %KValue %x3, ptr @s124)
  br label %L8
L8:
  %t33 = phi %KValue [ %t31, %L9 ], [ %t32, %L7 ]
  %t34 = call %KValue @k_call2(%KValue %x2, %KValue %x1, %KValue %t33)
  %t35 = extractvalue %KValue %x3, 1
  %t36 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t37 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t35, i64 %t36)
  %t38 = extractvalue { i64, i1 } %t37, 0
  %t39 = extractvalue { i64, i1 } %t37, 1
  br i1 %t39, label %L11, label %L10
L11:
  call void @k_die(ptr @s94)
  unreachable
L10:
  %t40 = insertvalue %KValue { i64 0, i64 undef }, i64 %t38, 1
  %t41 = extractvalue %KValue %t40, 1
  %t42 = musttail call tailcc %KValue @"d_query/list/fold_flat_4"(%KValue %x0, %KValue %t34, %KValue %x2, i64 %t41)
  ret %KValue %t42
fail0:
  %t43 = call i64 @k_not_failure(%KValue %x0)
  %t44 = icmp ne i64 %t43, 0
  br i1 %t44, label %L13, label %L12
L12:
  %t45 = call %KValue @k_err_hop(%KValue %x0, ptr @s123)
  ret %KValue %t45
L13:
  %t46 = call i64 @k_not_failure(%KValue %x1)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L15, label %L14
L14:
  %t48 = call %KValue @k_err_hop(%KValue %x1, ptr @s123)
  ret %KValue %t48
L15:
  %t49 = call i64 @k_not_failure(%KValue %x2)
  %t50 = icmp ne i64 %t49, 0
  br i1 %t50, label %L17, label %L16
L16:
  %t51 = call %KValue @k_err_hop(%KValue %x2, ptr @s123)
  ret %KValue %t51
L17:
  %t52 = call i64 @k_not_failure(%KValue %x3)
  %t53 = icmp ne i64 %t52, 0
  br i1 %t53, label %L19, label %L18
L18:
  %t54 = call %KValue @k_err_hop(%KValue %x3, ptr @s123)
  ret %KValue %t54
L19:
  call void @k_die(ptr @s125)
  unreachable
}

define tailcc %KValue @"d_query/list/fold_go_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %fail0
L3:
  ret %KValue %x1
fail0:
  %t8 = call i64 @k_check_rec(%KValue %x0, i64 17, i64 2)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %fail1
L4:
  %t10 = call %KValue @k_field(%KValue %x0, i64 0)
  %t11 = call i64 @k_not_failure(%KValue %t10)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L5, label %fail1
L5:
  %t13 = call %KValue @k_field(%KValue %x0, i64 1)
  %t14 = call i64 @k_not_failure(%KValue %t13)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %fail1
L6:
  %t16 = call i64 @k_not_failure(%KValue %x1)
  %t17 = icmp ne i64 %t16, 0
  br i1 %t17, label %L7, label %fail1
L7:
  %t18 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t13)
  %t19 = call %KValue @k_call2(%KValue %x2, %KValue %x1, %KValue %t10)
  %t20 = musttail call tailcc %KValue @"d_query/list/fold_go_3"(%KValue %t18, %KValue %t19, %KValue %x2)
  ret %KValue %t20
fail1:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L9, label %L8
L8:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s126)
  ret %KValue %t23
L9:
  %t24 = call i64 @k_not_failure(%KValue %x1)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L11, label %L10
L10:
  %t26 = call %KValue @k_err_hop(%KValue %x1, ptr @s126)
  ret %KValue %t26
L11:
  %t27 = call i64 @k_not_failure(%KValue %x2)
  %t28 = icmp ne i64 %t27, 0
  br i1 %t28, label %L13, label %L12
L12:
  %t29 = call %KValue @k_err_hop(%KValue %x2, ptr @s126)
  ret %KValue %t29
L13:
  call void @k_die(ptr @s127)
  unreachable
}

define %KValue @"d_query/list/bucket_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 4
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = alloca [1 x %KValue]
  %t4 = call %KValue @k_list_lit(i64 0, ptr %t3)
  ret %KValue %t4
fail0:
  ret %KValue %x0
fail1:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L3, label %L2
L2:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s128)
  ret %KValue %t7
L3:
  call void @k_die(ptr @s129)
  unreachable
}

define tailcc %KValue @klam4(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = call %KValue @k_call1(%KValue %t1, %KValue %a1)
  %t3 = musttail call tailcc %KValue @"d_query/list/file_under_3"(%KValue %a0, %KValue %t2, %KValue %a1)
  ret %KValue %t3
}

define %KValue @w_klam4(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call tailcc %KValue @klam4(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/group_by_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = call %KValue @k_map_lit(i64 0, ptr %t1)
  %t3 = alloca [1 x %KValue]
  %t4 = getelementptr [1 x %KValue], ptr %t3, i64 0, i64 0
  store %KValue %x1, ptr %t4
  %t5 = call %KValue @k_closure(ptr @w_klam4, i64 2, i64 1, ptr %t3)
  %t6 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t2, %KValue %t5)
  ret %KValue %t6
fail0:
  %t7 = call i64 @k_not_failure(%KValue %x0)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L2, label %L1
L1:
  %t9 = call %KValue @k_err_hop(%KValue %x0, ptr @s130)
  ret %KValue %t9
L2:
  %t10 = call i64 @k_not_failure(%KValue %x1)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L3
L3:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s130)
  ret %KValue %t12
L4:
  call void @k_die(ptr @s131)
  unreachable
}

define tailcc %KValue @"d_query/list/file_under_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x0, 0
  %t4 = icmp eq i64 %t3, 13
  %t5 = extractvalue %KValue %x1, 0
  %t6 = icmp eq i64 %t5, 0
  %t7 = and i1 %t4, %t6
  br i1 %t7, label %L2, label %L3
L2:
  %t8 = extractvalue %KValue %x0, 1
  %t9 = inttoptr i64 %t8 to ptr
  %t10 = getelementptr %KBytes, ptr %t9, i64 0, i32 0
  %t11 = load i64, ptr %t10
  %t12 = extractvalue %KValue %x1, 1
  %t13 = icmp sge i64 %t12, 1
  %t14 = icmp sle i64 %t12, %t11
  %t15 = and i1 %t13, %t14
  br i1 %t15, label %L5, label %L3
L5:
  %t16 = getelementptr %KBytes, ptr %t9, i64 0, i32 1
  %t17 = load ptr, ptr %t16
  %t18 = add i64 %t12, -1
  %t19 = getelementptr i8, ptr %t17, i64 %t18
  %t20 = load i8, ptr %t19
  %t21 = zext i8 %t20 to i64
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t21, 1
  br label %L4
L3:
  %t23 = call %KValue @k_b_at(%KValue %x0, %KValue %x1)
  br label %L4
L4:
  %t24 = phi %KValue [ %t22, %L5 ], [ %t23, %L3 ]
  %t25 = call %KValue @"d_query/list/bucket_1"(%KValue %t24)
  %t26 = call %KValue @k_b_push(%KValue %t25, %KValue %x2)
  %t27 = call %KValue @k_b_put_mut(%KValue %x0, %KValue %x1, %KValue %t26)
  ret %KValue %t27
fail0:
  %t28 = call i64 @k_not_failure(%KValue %x0)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L7, label %L6
L6:
  %t30 = call %KValue @k_err_hop(%KValue %x0, ptr @s132)
  ret %KValue %t30
L7:
  %t31 = call i64 @k_not_failure(%KValue %x1)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L9, label %L8
L8:
  %t33 = call %KValue @k_err_hop(%KValue %x1, ptr @s132)
  ret %KValue %t33
L9:
  %t34 = call i64 @k_not_failure(%KValue %x2)
  %t35 = icmp ne i64 %t34, 0
  br i1 %t35, label %L11, label %L10
L10:
  %t36 = call %KValue @k_err_hop(%KValue %x2, ptr @s132)
  ret %KValue %t36
L11:
  call void @k_die(ptr @s133)
  unreachable
}

define %KValue @klam5(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = call %KValue @k_call1(%KValue %t1, %KValue %a1)
  %t3 = call %KValue @k_b_put_mut(%KValue %a0, %KValue %t2, %KValue %a1)
  ret %KValue %t3
}

define %KValue @w_klam5(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam5(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/index_by_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = call %KValue @k_map_lit(i64 0, ptr %t1)
  %t3 = alloca [1 x %KValue]
  %t4 = getelementptr [1 x %KValue], ptr %t3, i64 0, i64 0
  store %KValue %x1, ptr %t4
  %t5 = call %KValue @k_closure(ptr @w_klam5, i64 2, i64 1, ptr %t3)
  %t6 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t2, %KValue %t5)
  ret %KValue %t6
fail0:
  %t7 = call i64 @k_not_failure(%KValue %x0)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L2, label %L1
L1:
  %t9 = call %KValue @k_err_hop(%KValue %x0, ptr @s134)
  ret %KValue %t9
L2:
  %t10 = call i64 @k_not_failure(%KValue %x1)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L3
L3:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s134)
  ret %KValue %t12
L4:
  call void @k_die(ptr @s135)
  unreachable
}

define %KValue @"d_query/list/iter_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 3, i64 3)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %x0, i64 1)
  %t7 = call i64 @k_not_failure(%KValue %t6)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = call %KValue @k_field(%KValue %x0, i64 2)
  %t10 = call i64 @k_not_failure(%KValue %t9)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %fail0
L4:
  %t12 = alloca [3 x %KValue]
  %t13 = getelementptr [3 x %KValue], ptr %t12, i64 0, i64 0
  store %KValue %t3, ptr %t13
  %t14 = getelementptr [3 x %KValue], ptr %t12, i64 0, i64 1
  store %KValue %t6, ptr %t14
  %t15 = getelementptr [3 x %KValue], ptr %t12, i64 0, i64 2
  store %KValue %t9, ptr %t15
  %t16 = call %KValue @k_rec(i64 3, i64 3, ptr %t12)
  ret %KValue %t16
fail0:
  %t17 = call i64 @k_check_rec(%KValue %x0, i64 4, i64 2)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L5, label %fail1
L5:
  %t19 = call %KValue @k_field(%KValue %x0, i64 0)
  %t20 = call i64 @k_not_failure(%KValue %t19)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L6, label %fail1
L6:
  %t22 = call %KValue @k_field(%KValue %x0, i64 1)
  %t23 = call i64 @k_not_failure(%KValue %t22)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L7, label %fail1
L7:
  %t25 = alloca [2 x %KValue]
  %t26 = getelementptr [2 x %KValue], ptr %t25, i64 0, i64 0
  store %KValue %t19, ptr %t26
  %t27 = getelementptr [2 x %KValue], ptr %t25, i64 0, i64 1
  store %KValue %t22, ptr %t27
  %t28 = call %KValue @k_rec(i64 4, i64 2, ptr %t25)
  ret %KValue %t28
fail1:
  %t29 = call i64 @k_check_rec(%KValue %x0, i64 5, i64 1)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L8, label %fail2
L8:
  %t31 = call %KValue @k_field(%KValue %x0, i64 0)
  %t32 = call i64 @k_not_failure(%KValue %t31)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L9, label %fail2
L9:
  %t34 = alloca [1 x %KValue]
  %t35 = getelementptr [1 x %KValue], ptr %t34, i64 0, i64 0
  store %KValue %t31, ptr %t35
  %t36 = call %KValue @k_rec(i64 5, i64 1, ptr %t34)
  ret %KValue %t36
fail2:
  %t37 = call i64 @k_check_rec(%KValue %x0, i64 7, i64 2)
  %t38 = icmp ne i64 %t37, 0
  br i1 %t38, label %L10, label %fail3
L10:
  %t39 = call %KValue @k_field(%KValue %x0, i64 0)
  %t40 = call i64 @k_not_failure(%KValue %t39)
  %t41 = icmp ne i64 %t40, 0
  br i1 %t41, label %L11, label %fail3
L11:
  %t42 = call %KValue @k_field(%KValue %x0, i64 1)
  %t43 = call i64 @k_not_failure(%KValue %t42)
  %t44 = icmp ne i64 %t43, 0
  br i1 %t44, label %L12, label %fail3
L12:
  %t45 = alloca [2 x %KValue]
  %t46 = getelementptr [2 x %KValue], ptr %t45, i64 0, i64 0
  store %KValue %t39, ptr %t46
  %t47 = getelementptr [2 x %KValue], ptr %t45, i64 0, i64 1
  store %KValue %t42, ptr %t47
  %t48 = call %KValue @k_rec(i64 7, i64 2, ptr %t45)
  ret %KValue %t48
fail3:
  %t49 = call i64 @k_check_rec(%KValue %x0, i64 9, i64 2)
  %t50 = icmp ne i64 %t49, 0
  br i1 %t50, label %L13, label %fail4
L13:
  %t51 = call %KValue @k_field(%KValue %x0, i64 0)
  %t52 = call i64 @k_not_failure(%KValue %t51)
  %t53 = icmp ne i64 %t52, 0
  br i1 %t53, label %L14, label %fail4
L14:
  %t54 = call %KValue @k_field(%KValue %x0, i64 1)
  %t55 = call i64 @k_not_failure(%KValue %t54)
  %t56 = icmp ne i64 %t55, 0
  br i1 %t56, label %L15, label %fail4
L15:
  %t57 = alloca [2 x %KValue]
  %t58 = getelementptr [2 x %KValue], ptr %t57, i64 0, i64 0
  store %KValue %t51, ptr %t58
  %t59 = getelementptr [2 x %KValue], ptr %t57, i64 0, i64 1
  store %KValue %t54, ptr %t59
  %t60 = call %KValue @k_rec(i64 9, i64 2, ptr %t57)
  ret %KValue %t60
fail4:
  %t61 = call i64 @k_check_rec(%KValue %x0, i64 12, i64 2)
  %t62 = icmp ne i64 %t61, 0
  br i1 %t62, label %L16, label %fail5
L16:
  %t63 = call %KValue @k_field(%KValue %x0, i64 0)
  %t64 = call i64 @k_not_failure(%KValue %t63)
  %t65 = icmp ne i64 %t64, 0
  br i1 %t65, label %L17, label %fail5
L17:
  %t66 = call %KValue @k_field(%KValue %x0, i64 1)
  %t67 = call i64 @k_not_failure(%KValue %t66)
  %t68 = icmp ne i64 %t67, 0
  br i1 %t68, label %L18, label %fail5
L18:
  %t69 = alloca [2 x %KValue]
  %t70 = getelementptr [2 x %KValue], ptr %t69, i64 0, i64 0
  store %KValue %t63, ptr %t70
  %t71 = getelementptr [2 x %KValue], ptr %t69, i64 0, i64 1
  store %KValue %t66, ptr %t71
  %t72 = call %KValue @k_rec(i64 12, i64 2, ptr %t69)
  ret %KValue %t72
fail5:
  %t73 = call i64 @k_check_rec(%KValue %x0, i64 13, i64 1)
  %t74 = icmp ne i64 %t73, 0
  br i1 %t74, label %L19, label %fail6
L19:
  %t75 = call %KValue @k_field(%KValue %x0, i64 0)
  %t76 = call i64 @k_not_failure(%KValue %t75)
  %t77 = icmp ne i64 %t76, 0
  br i1 %t77, label %L20, label %fail6
L20:
  %t78 = alloca [1 x %KValue]
  %t79 = getelementptr [1 x %KValue], ptr %t78, i64 0, i64 0
  store %KValue %t75, ptr %t79
  %t80 = call %KValue @k_rec(i64 13, i64 1, ptr %t78)
  ret %KValue %t80
fail6:
  %t81 = call i64 @k_check_rec(%KValue %x0, i64 6, i64 2)
  %t82 = icmp ne i64 %t81, 0
  br i1 %t82, label %L21, label %fail7
L21:
  %t83 = call %KValue @k_field(%KValue %x0, i64 0)
  %t84 = call i64 @k_not_failure(%KValue %t83)
  %t85 = icmp ne i64 %t84, 0
  br i1 %t85, label %L22, label %fail7
L22:
  %t86 = call %KValue @k_field(%KValue %x0, i64 1)
  %t87 = call i64 @k_not_failure(%KValue %t86)
  %t88 = icmp ne i64 %t87, 0
  br i1 %t88, label %L23, label %fail7
L23:
  %t89 = alloca [2 x %KValue]
  %t90 = getelementptr [2 x %KValue], ptr %t89, i64 0, i64 0
  store %KValue %t83, ptr %t90
  %t91 = getelementptr [2 x %KValue], ptr %t89, i64 0, i64 1
  store %KValue %t86, ptr %t91
  %t92 = call %KValue @k_rec(i64 6, i64 2, ptr %t89)
  ret %KValue %t92
fail7:
  %t93 = call i64 @k_check_rec(%KValue %x0, i64 10, i64 2)
  %t94 = icmp ne i64 %t93, 0
  br i1 %t94, label %L24, label %fail8
L24:
  %t95 = call %KValue @k_field(%KValue %x0, i64 0)
  %t96 = call i64 @k_not_failure(%KValue %t95)
  %t97 = icmp ne i64 %t96, 0
  br i1 %t97, label %L25, label %fail8
L25:
  %t98 = call %KValue @k_field(%KValue %x0, i64 1)
  %t99 = call i64 @k_not_failure(%KValue %t98)
  %t100 = icmp ne i64 %t99, 0
  br i1 %t100, label %L26, label %fail8
L26:
  %t101 = alloca [2 x %KValue]
  %t102 = getelementptr [2 x %KValue], ptr %t101, i64 0, i64 0
  store %KValue %t95, ptr %t102
  %t103 = getelementptr [2 x %KValue], ptr %t101, i64 0, i64 1
  store %KValue %t98, ptr %t103
  %t104 = call %KValue @k_rec(i64 10, i64 2, ptr %t101)
  ret %KValue %t104
fail8:
  %t105 = call i64 @k_check_rec(%KValue %x0, i64 14, i64 3)
  %t106 = icmp ne i64 %t105, 0
  br i1 %t106, label %L27, label %fail9
L27:
  %t107 = call %KValue @k_field(%KValue %x0, i64 0)
  %t108 = call i64 @k_not_failure(%KValue %t107)
  %t109 = icmp ne i64 %t108, 0
  br i1 %t109, label %L28, label %fail9
L28:
  %t110 = call %KValue @k_field(%KValue %x0, i64 1)
  %t111 = call i64 @k_not_failure(%KValue %t110)
  %t112 = icmp ne i64 %t111, 0
  br i1 %t112, label %L29, label %fail9
L29:
  %t113 = call %KValue @k_field(%KValue %x0, i64 2)
  %t114 = call i64 @k_not_failure(%KValue %t113)
  %t115 = icmp ne i64 %t114, 0
  br i1 %t115, label %L30, label %fail9
L30:
  %t116 = alloca [3 x %KValue]
  %t117 = getelementptr [3 x %KValue], ptr %t116, i64 0, i64 0
  store %KValue %t107, ptr %t117
  %t118 = getelementptr [3 x %KValue], ptr %t116, i64 0, i64 1
  store %KValue %t110, ptr %t118
  %t119 = getelementptr [3 x %KValue], ptr %t116, i64 0, i64 2
  store %KValue %t113, ptr %t119
  %t120 = call %KValue @k_rec(i64 14, i64 3, ptr %t116)
  ret %KValue %t120
fail9:
  %t121 = call i64 @k_check_rec(%KValue %x0, i64 15, i64 2)
  %t122 = icmp ne i64 %t121, 0
  br i1 %t122, label %L31, label %fail10
L31:
  %t123 = call %KValue @k_field(%KValue %x0, i64 0)
  %t124 = call i64 @k_not_failure(%KValue %t123)
  %t125 = icmp ne i64 %t124, 0
  br i1 %t125, label %L32, label %fail10
L32:
  %t126 = call %KValue @k_field(%KValue %x0, i64 1)
  %t127 = call i64 @k_not_failure(%KValue %t126)
  %t128 = icmp ne i64 %t127, 0
  br i1 %t128, label %L33, label %fail10
L33:
  %t129 = alloca [2 x %KValue]
  %t130 = getelementptr [2 x %KValue], ptr %t129, i64 0, i64 0
  store %KValue %t123, ptr %t130
  %t131 = getelementptr [2 x %KValue], ptr %t129, i64 0, i64 1
  store %KValue %t126, ptr %t131
  %t132 = call %KValue @k_rec(i64 15, i64 2, ptr %t129)
  ret %KValue %t132
fail10:
  %t133 = alloca [2 x %KValue]
  %t134 = getelementptr [2 x %KValue], ptr %t133, i64 0, i64 0
  store %KValue { i64 0, i64 1 }, ptr %t134
  %t135 = getelementptr [2 x %KValue], ptr %t133, i64 0, i64 1
  store %KValue %x0, ptr %t135
  %t136 = call %KValue @k_rec(i64 6, i64 2, ptr %t133)
  ret %KValue %t136
fail11:
  %t137 = call i64 @k_not_failure(%KValue %x0)
  %t138 = icmp ne i64 %t137, 0
  br i1 %t138, label %L35, label %L34
L34:
  %t139 = call %KValue @k_err_hop(%KValue %x0, ptr @s136)
  ret %KValue %t139
L35:
  call void @k_die(ptr @s137)
  unreachable
}

define %KValue @"d_query/list/iterate_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = alloca [2 x %KValue]
  %t2 = getelementptr [2 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue %x0, ptr %t2
  %t3 = getelementptr [2 x %KValue], ptr %t1, i64 0, i64 1
  store %KValue %x1, ptr %t3
  %t4 = call %KValue @k_rec(i64 9, i64 2, ptr %t1)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s138)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s138)
  ret %KValue %t10
L4:
  call void @k_die(ptr @s139)
  unreachable
}

define %KValue @klam6(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_b_push_mut(%KValue %a0, %KValue %a1)
  ret %KValue %t1
}

define %KValue @w_klam6(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam6(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/join_parts_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call %KValue @k_b_push_mut(%KValue %x0, %KValue %x1)
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_closure(ptr @w_klam6, i64 2, i64 0, ptr %t2)
  %t4 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x2, %KValue %t1, %KValue %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s140)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s140)
  ret %KValue %t10
L4:
  %t11 = call i64 @k_not_failure(%KValue %x2)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L6, label %L5
L5:
  %t13 = call %KValue @k_err_hop(%KValue %x2, ptr @s140)
  ret %KValue %t13
L6:
  call void @k_die(ptr @s141)
  unreachable
}

define %KValue @klam7(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  ret %KValue %a1
}

define %KValue @w_klam7(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam7(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/last_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t2
  %t3 = call %KValue @k_rec(i64 11, i64 1, ptr %t1)
  %t4 = alloca [1 x %KValue]
  %t5 = call %KValue @k_closure(ptr @w_klam7, i64 2, i64 0, ptr %t4)
  %t6 = call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t3, %KValue %t5)
  %t7 = musttail call tailcc %KValue @"d_query/list/unwrap_found_1"(%KValue %t6)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L1
L1:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s142)
  ret %KValue %t10
L2:
  call void @k_die(ptr @s143)
  unreachable
}

define %KValue @"d_query/list/map_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = alloca [2 x %KValue]
  %t3 = getelementptr [2 x %KValue], ptr %t2, i64 0, i64 0
  store %KValue %x1, ptr %t3
  %t4 = getelementptr [2 x %KValue], ptr %t2, i64 0, i64 1
  store %KValue %t1, ptr %t4
  %t5 = call %KValue @k_rec(i64 10, i64 2, ptr %t2)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s144)
  ret %KValue %t8
L2:
  %t9 = call i64 @k_not_failure(%KValue %x1)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %L3
L3:
  %t11 = call %KValue @k_err_hop(%KValue %x1, ptr @s144)
  ret %KValue %t11
L4:
  call void @k_die(ptr @s145)
  unreachable
}

define tailcc %KValue @klam8(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = musttail call tailcc %KValue @"d_query/list/outrank_2"(%KValue %a0, %KValue %a1)
  ret %KValue %t1
}

define %KValue @w_klam8(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call tailcc %KValue @klam8(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/max_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t2
  %t3 = call %KValue @k_rec(i64 11, i64 1, ptr %t1)
  %t4 = alloca [1 x %KValue]
  %t5 = call %KValue @k_closure(ptr @w_klam8, i64 2, i64 0, ptr %t4)
  %t6 = call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t3, %KValue %t5)
  %t7 = musttail call tailcc %KValue @"d_query/list/unwrap_found_1"(%KValue %t6)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L1
L1:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s146)
  ret %KValue %t10
L2:
  call void @k_die(ptr @s147)
  unreachable
}

define %KValue @klam9(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = extractvalue %KValue %a0, 0
  %t2 = extractvalue %KValue %a1, 0
  %t3 = icmp eq i64 %t1, 0
  %t4 = icmp eq i64 %t2, 0
  %t5 = and i1 %t3, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %a0, 1
  %t7 = extractvalue %KValue %a1, 1
  %t8 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t6, i64 %t7)
  %t9 = extractvalue { i64, i1 } %t8, 0
  %t10 = extractvalue { i64, i1 } %t8, 1
  br i1 %t10, label %L2, label %L4
L4:
  %t11 = insertvalue %KValue { i64 0, i64 undef }, i64 %t9, 1
  br label %L3
L2:
  %t12 = call %KValue @k_add(%KValue %a0, %KValue %a1)
  br label %L3
L3:
  %t13 = phi %KValue [ %t11, %L4 ], [ %t12, %L2 ]
  ret %KValue %t13
}

define %KValue @w_klam9(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam9(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define %KValue @klam10(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = extractvalue %KValue %a0, 0
  %t2 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t3 = icmp eq i64 %t1, 0
  %t4 = icmp eq i64 %t2, 0
  %t5 = and i1 %t3, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %a0, 1
  %t7 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t8 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t6, i64 %t7)
  %t9 = extractvalue { i64, i1 } %t8, 0
  %t10 = extractvalue { i64, i1 } %t8, 1
  br i1 %t10, label %L2, label %L4
L4:
  %t11 = insertvalue %KValue { i64 0, i64 undef }, i64 %t9, 1
  br label %L3
L2:
  %t12 = call %KValue @k_add(%KValue %a0, %KValue { i64 0, i64 1 })
  br label %L3
L3:
  %t13 = phi %KValue [ %t11, %L4 ], [ %t12, %L2 ]
  ret %KValue %t13
}

define %KValue @w_klam10(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam10(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define %KValue @"d_query/list/mean_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_float(double 0x0000000000000000)
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_closure(ptr @w_klam9, i64 2, i64 0, ptr %t2)
  %t4 = call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t1, %KValue %t3)
  %t5 = alloca [1 x %KValue]
  %t6 = call %KValue @k_closure(ptr @w_klam10, i64 2, i64 0, ptr %t5)
  %t7 = call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue { i64 0, i64 0 }, %KValue %t6)
  %t8 = call %KValue @k_div(%KValue %t4, %KValue %t7, ptr @s149)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_not_failure(%KValue %x0)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L2, label %L1
L1:
  %t11 = call %KValue @k_err_hop(%KValue %x0, ptr @s148)
  ret %KValue %t11
L2:
  call void @k_die(ptr @s150)
  unreachable
}

define tailcc %KValue @klam11(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = musttail call tailcc %KValue @"d_query/list/underrank_2"(%KValue %a0, %KValue %a1)
  ret %KValue %t1
}

define %KValue @w_klam11(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call tailcc %KValue @klam11(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/min_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t2
  %t3 = call %KValue @k_rec(i64 11, i64 1, ptr %t1)
  %t4 = alloca [1 x %KValue]
  %t5 = call %KValue @k_closure(ptr @w_klam11, i64 2, i64 0, ptr %t4)
  %t6 = call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t3, %KValue %t5)
  %t7 = musttail call tailcc %KValue @"d_query/list/unwrap_found_1"(%KValue %t6)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L1
L1:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s151)
  ret %KValue %t10
L2:
  call void @k_die(ptr @s152)
  unreachable
}

define %KValue @"d_query/list/naturals_0"() {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 0, i64 1 }, ptr %t2
  %t3 = call %KValue @k_rec(i64 5, i64 1, ptr %t1)
  ret %KValue %t3
fail0:
  call void @k_die(ptr @s154)
  unreachable
}

define tailcc %KValue @"d_query/list/next_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 4, i64 2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %x0, i64 1)
  %t7 = call i64 @k_check_rec(%KValue %t6, i64 6, i64 2)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = call %KValue @k_field(%KValue %t6, i64 0)
  %t10 = call i64 @k_not_failure(%KValue %t9)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %fail0
L4:
  %t12 = call %KValue @k_field(%KValue %t6, i64 1)
  %t13 = call i64 @k_not_failure(%KValue %t12)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L5, label %fail0
L5:
  %t15 = extractvalue %KValue %t9, 0
  %t16 = extractvalue %KValue %t3, 0
  %t17 = icmp eq i64 %t15, 0
  %t18 = icmp eq i64 %t16, 0
  %t19 = and i1 %t17, %t18
  br i1 %t19, label %L6, label %L7
L6:
  %t20 = extractvalue %KValue %t9, 1
  %t21 = extractvalue %KValue %t3, 1
  %t22 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t20, i64 %t21)
  %t23 = extractvalue { i64, i1 } %t22, 0
  %t24 = extractvalue { i64, i1 } %t22, 1
  br i1 %t24, label %L7, label %L9
L9:
  %t25 = insertvalue %KValue { i64 0, i64 undef }, i64 %t23, 1
  br label %L8
L7:
  %t26 = call %KValue @k_add(%KValue %t9, %KValue %t3)
  br label %L8
L8:
  %t27 = phi %KValue [ %t25, %L9 ], [ %t26, %L7 ]
  %t28 = extractvalue %KValue %t27, 0
  %t29 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t30 = icmp eq i64 %t28, 0
  %t31 = icmp eq i64 %t29, 0
  %t32 = and i1 %t30, %t31
  br i1 %t32, label %L10, label %L11
L10:
  %t33 = extractvalue %KValue %t27, 1
  %t34 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t35 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t33, i64 %t34)
  %t36 = extractvalue { i64, i1 } %t35, 0
  %t37 = extractvalue { i64, i1 } %t35, 1
  br i1 %t37, label %L11, label %L13
L13:
  %t38 = insertvalue %KValue { i64 0, i64 undef }, i64 %t36, 1
  br label %L12
L11:
  %t39 = call %KValue @k_sub(%KValue %t27, %KValue { i64 0, i64 1 })
  br label %L12
L12:
  %t40 = phi %KValue [ %t38, %L13 ], [ %t39, %L11 ]
  %t41 = alloca [3 x %KValue]
  %t42 = getelementptr [3 x %KValue], ptr %t41, i64 0, i64 0
  store %KValue %t9, ptr %t42
  %t43 = getelementptr [3 x %KValue], ptr %t41, i64 0, i64 1
  store %KValue %t40, ptr %t43
  %t44 = getelementptr [3 x %KValue], ptr %t41, i64 0, i64 2
  store %KValue %t12, ptr %t44
  %t45 = call %KValue @k_rec(i64 3, i64 3, ptr %t41)
  %t46 = musttail call tailcc %KValue @"d_query/list/next_1"(%KValue %t45)
  ret %KValue %t46
fail0:
  %t47 = call i64 @k_check_rec(%KValue %x0, i64 3, i64 3)
  %t48 = icmp ne i64 %t47, 0
  br i1 %t48, label %L14, label %fail1
L14:
  %t49 = call %KValue @k_field(%KValue %x0, i64 0)
  %t50 = call i64 @k_not_failure(%KValue %t49)
  %t51 = icmp ne i64 %t50, 0
  br i1 %t51, label %L15, label %fail1
L15:
  %t52 = call %KValue @k_field(%KValue %x0, i64 1)
  %t53 = call i64 @k_not_failure(%KValue %t52)
  %t54 = icmp ne i64 %t53, 0
  br i1 %t54, label %L16, label %fail1
L16:
  %t55 = call %KValue @k_field(%KValue %x0, i64 2)
  %t56 = call i64 @k_not_failure(%KValue %t55)
  %t57 = icmp ne i64 %t56, 0
  br i1 %t57, label %L17, label %fail1
L17:
  %t58 = extractvalue %KValue %t52, 0
  %t59 = extractvalue %KValue %t49, 0
  %t60 = icmp eq i64 %t58, 0
  %t61 = icmp eq i64 %t59, 0
  %t62 = and i1 %t60, %t61
  br i1 %t62, label %L18, label %L19
L18:
  %t63 = extractvalue %KValue %t52, 1
  %t64 = extractvalue %KValue %t49, 1
  %t65 = icmp slt i64 %t63, %t64
  %t66 = select i1 %t65, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L20
L19:
  %t67 = call %KValue @k_cmp(%KValue %t52, %KValue %t49, i64 2)
  br label %L20
L20:
  %t68 = phi %KValue [ %t66, %L18 ], [ %t67, %L19 ]
  %t69 = call i64 @k_not_failure(%KValue %t68)
  %t70 = icmp ne i64 %t69, 0
  br i1 %t70, label %L21, label %L22
L22:
  ret %KValue %t68
L21:
  %t71 = call i64 @k_truthy(%KValue %t68)
  %t72 = icmp ne i64 %t71, 0
  br i1 %t72, label %L23, label %L24
L23:
  %t73 = alloca [1 x %KValue]
  %t74 = getelementptr [1 x %KValue], ptr %t73, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t74
  %t75 = call %KValue @k_rec(i64 8, i64 1, ptr %t73)
  ret %KValue %t75
L24:
  %t76 = extractvalue %KValue %t49, 1
  %t77 = musttail call tailcc %KValue @"d_query/list/next_bounded_3"(i64 %t76, %KValue %t52, %KValue %t55)
  ret %KValue %t77
fail1:
  %t78 = call i64 @k_check_rec(%KValue %x0, i64 4, i64 2)
  %t79 = icmp ne i64 %t78, 0
  br i1 %t79, label %L25, label %fail2
L25:
  %t80 = call %KValue @k_field(%KValue %x0, i64 0)
  %t81 = call i64 @k_not_failure(%KValue %t80)
  %t82 = icmp ne i64 %t81, 0
  br i1 %t82, label %L26, label %fail2
L26:
  %t83 = call %KValue @k_field(%KValue %x0, i64 1)
  %t84 = call i64 @k_not_failure(%KValue %t83)
  %t85 = icmp ne i64 %t84, 0
  br i1 %t85, label %L27, label %fail2
L27:
  %t86 = extractvalue %KValue %t80, 0
  %t87 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t88 = icmp eq i64 %t86, 0
  %t89 = icmp eq i64 %t87, 0
  %t90 = and i1 %t88, %t89
  br i1 %t90, label %L28, label %L29
L28:
  %t91 = extractvalue %KValue %t80, 1
  %t92 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t93 = icmp slt i64 %t91, %t92
  %t94 = select i1 %t93, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L30
L29:
  %t95 = call %KValue @k_cmp(%KValue %t80, %KValue { i64 0, i64 1 }, i64 2)
  br label %L30
L30:
  %t96 = phi %KValue [ %t94, %L28 ], [ %t95, %L29 ]
  %t97 = call i64 @k_not_failure(%KValue %t96)
  %t98 = icmp ne i64 %t97, 0
  br i1 %t98, label %L31, label %L32
L32:
  ret %KValue %t96
L31:
  %t99 = call i64 @k_truthy(%KValue %t96)
  %t100 = icmp ne i64 %t99, 0
  br i1 %t100, label %L33, label %L34
L33:
  %t101 = alloca [1 x %KValue]
  %t102 = getelementptr [1 x %KValue], ptr %t101, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t102
  %t103 = call %KValue @k_rec(i64 8, i64 1, ptr %t101)
  ret %KValue %t103
L34:
  %t104 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t83)
  %t105 = musttail call tailcc %KValue @"d_query/list/next_capped_2"(%KValue %t80, %KValue %t104)
  ret %KValue %t105
fail2:
  %t106 = call i64 @k_check_rec(%KValue %x0, i64 5, i64 1)
  %t107 = icmp ne i64 %t106, 0
  br i1 %t107, label %L35, label %fail3
L35:
  %t108 = call %KValue @k_field(%KValue %x0, i64 0)
  %t109 = call i64 @k_not_failure(%KValue %t108)
  %t110 = icmp ne i64 %t109, 0
  br i1 %t110, label %L36, label %fail3
L36:
  %t111 = extractvalue %KValue %t108, 0
  %t112 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t113 = icmp eq i64 %t111, 0
  %t114 = icmp eq i64 %t112, 0
  %t115 = and i1 %t113, %t114
  br i1 %t115, label %L37, label %L38
L37:
  %t116 = extractvalue %KValue %t108, 1
  %t117 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t118 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t116, i64 %t117)
  %t119 = extractvalue { i64, i1 } %t118, 0
  %t120 = extractvalue { i64, i1 } %t118, 1
  br i1 %t120, label %L38, label %L40
L40:
  %t121 = insertvalue %KValue { i64 0, i64 undef }, i64 %t119, 1
  br label %L39
L38:
  %t122 = call %KValue @k_add(%KValue %t108, %KValue { i64 0, i64 1 })
  br label %L39
L39:
  %t123 = phi %KValue [ %t121, %L40 ], [ %t122, %L38 ]
  %t124 = alloca [1 x %KValue]
  %t125 = getelementptr [1 x %KValue], ptr %t124, i64 0, i64 0
  store %KValue %t123, ptr %t125
  %t126 = call %KValue @k_rec(i64 5, i64 1, ptr %t124)
  %t127 = alloca [2 x %KValue]
  %t128 = getelementptr [2 x %KValue], ptr %t127, i64 0, i64 0
  store %KValue %t108, ptr %t128
  %t129 = getelementptr [2 x %KValue], ptr %t127, i64 0, i64 1
  store %KValue %t126, ptr %t129
  %t130 = call %KValue @k_rec(i64 17, i64 2, ptr %t127)
  ret %KValue %t130
fail3:
  %t131 = call i64 @k_check_rec(%KValue %x0, i64 6, i64 2)
  %t132 = icmp ne i64 %t131, 0
  br i1 %t132, label %L41, label %fail4
L41:
  %t133 = call %KValue @k_field(%KValue %x0, i64 0)
  %t134 = call i64 @k_not_failure(%KValue %t133)
  %t135 = icmp ne i64 %t134, 0
  br i1 %t135, label %L42, label %fail4
L42:
  %t136 = call %KValue @k_field(%KValue %x0, i64 1)
  %t137 = call i64 @k_not_failure(%KValue %t136)
  %t138 = icmp ne i64 %t137, 0
  br i1 %t138, label %L43, label %fail4
L43:
  %t139 = extractvalue %KValue %t133, 0
  %t140 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t141 = icmp eq i64 %t139, 0
  %t142 = icmp eq i64 %t140, 0
  %t143 = and i1 %t141, %t142
  br i1 %t143, label %L44, label %L45
L44:
  %t144 = extractvalue %KValue %t133, 1
  %t145 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t146 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t144, i64 %t145)
  %t147 = extractvalue { i64, i1 } %t146, 0
  %t148 = extractvalue { i64, i1 } %t146, 1
  br i1 %t148, label %L45, label %L47
L47:
  %t149 = insertvalue %KValue { i64 0, i64 undef }, i64 %t147, 1
  br label %L46
L45:
  %t150 = call %KValue @k_add(%KValue %t133, %KValue { i64 0, i64 1 })
  br label %L46
L46:
  %t151 = phi %KValue [ %t149, %L47 ], [ %t150, %L45 ]
  %t152 = alloca [2 x %KValue]
  %t153 = getelementptr [2 x %KValue], ptr %t152, i64 0, i64 0
  store %KValue %t151, ptr %t153
  %t154 = getelementptr [2 x %KValue], ptr %t152, i64 0, i64 1
  store %KValue %t136, ptr %t154
  %t155 = call %KValue @k_rec(i64 6, i64 2, ptr %t152)
  %t156 = call %KValue @k_b_length_fast(%KValue %t136)
  %t157 = extractvalue %KValue %t156, 0
  %t158 = extractvalue %KValue %t133, 0
  %t159 = icmp eq i64 %t157, 0
  %t160 = icmp eq i64 %t158, 0
  %t161 = and i1 %t159, %t160
  br i1 %t161, label %L48, label %L49
L48:
  %t162 = extractvalue %KValue %t156, 1
  %t163 = extractvalue %KValue %t133, 1
  %t164 = icmp slt i64 %t162, %t163
  %t165 = select i1 %t164, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L50
L49:
  %t166 = call %KValue @k_cmp(%KValue %t156, %KValue %t133, i64 2)
  br label %L50
L50:
  %t167 = phi %KValue [ %t165, %L48 ], [ %t166, %L49 ]
  %t168 = call i64 @k_not_failure(%KValue %t167)
  %t169 = icmp ne i64 %t168, 0
  br i1 %t169, label %L51, label %L52
L52:
  ret %KValue %t167
L51:
  %t170 = call i64 @k_truthy(%KValue %t167)
  %t171 = icmp ne i64 %t170, 0
  br i1 %t171, label %L53, label %L54
L53:
  %t172 = alloca [1 x %KValue]
  %t173 = getelementptr [1 x %KValue], ptr %t172, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t173
  %t174 = call %KValue @k_rec(i64 8, i64 1, ptr %t172)
  ret %KValue %t174
L54:
  %t175 = extractvalue %KValue %t136, 0
  %t176 = icmp eq i64 %t175, 13
  %t177 = extractvalue %KValue %t133, 0
  %t178 = icmp eq i64 %t177, 0
  %t179 = and i1 %t176, %t178
  br i1 %t179, label %L55, label %L56
L55:
  %t180 = extractvalue %KValue %t136, 1
  %t181 = inttoptr i64 %t180 to ptr
  %t182 = getelementptr %KBytes, ptr %t181, i64 0, i32 0
  %t183 = load i64, ptr %t182
  %t184 = extractvalue %KValue %t133, 1
  %t185 = icmp sge i64 %t184, 1
  %t186 = icmp sle i64 %t184, %t183
  %t187 = and i1 %t185, %t186
  br i1 %t187, label %L58, label %L56
L58:
  %t188 = getelementptr %KBytes, ptr %t181, i64 0, i32 1
  %t189 = load ptr, ptr %t188
  %t190 = add i64 %t184, -1
  %t191 = getelementptr i8, ptr %t189, i64 %t190
  %t192 = load i8, ptr %t191
  %t193 = zext i8 %t192 to i64
  %t194 = insertvalue %KValue { i64 0, i64 undef }, i64 %t193, 1
  br label %L57
L56:
  %t195 = call %KValue @k_index(%KValue %t136, %KValue %t133, ptr @s156)
  br label %L57
L57:
  %t196 = phi %KValue [ %t194, %L58 ], [ %t195, %L56 ]
  %t197 = alloca [2 x %KValue]
  %t198 = getelementptr [2 x %KValue], ptr %t197, i64 0, i64 0
  store %KValue %t196, ptr %t198
  %t199 = getelementptr [2 x %KValue], ptr %t197, i64 0, i64 1
  store %KValue %t155, ptr %t199
  %t200 = call %KValue @k_rec(i64 17, i64 2, ptr %t197)
  ret %KValue %t200
fail4:
  %t201 = call i64 @k_check_rec(%KValue %x0, i64 7, i64 2)
  %t202 = icmp ne i64 %t201, 0
  br i1 %t202, label %L59, label %fail5
L59:
  %t203 = call %KValue @k_field(%KValue %x0, i64 0)
  %t204 = call i64 @k_not_failure(%KValue %t203)
  %t205 = icmp ne i64 %t204, 0
  br i1 %t205, label %L60, label %fail5
L60:
  %t206 = call %KValue @k_field(%KValue %x0, i64 1)
  %t207 = call i64 @k_not_failure(%KValue %t206)
  %t208 = icmp ne i64 %t207, 0
  br i1 %t208, label %L61, label %fail5
L61:
  %t209 = extractvalue %KValue %t203, 0
  %t210 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t211 = icmp eq i64 %t209, 0
  %t212 = icmp eq i64 %t210, 0
  %t213 = and i1 %t211, %t212
  br i1 %t213, label %L62, label %L63
L62:
  %t214 = extractvalue %KValue %t203, 1
  %t215 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t216 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t214, i64 %t215)
  %t217 = extractvalue { i64, i1 } %t216, 0
  %t218 = extractvalue { i64, i1 } %t216, 1
  br i1 %t218, label %L63, label %L65
L65:
  %t219 = insertvalue %KValue { i64 0, i64 undef }, i64 %t217, 1
  br label %L64
L63:
  %t220 = call %KValue @k_add(%KValue %t203, %KValue { i64 0, i64 1 })
  br label %L64
L64:
  %t221 = phi %KValue [ %t219, %L65 ], [ %t220, %L63 ]
  %t222 = alloca [2 x %KValue]
  %t223 = getelementptr [2 x %KValue], ptr %t222, i64 0, i64 0
  store %KValue %t221, ptr %t223
  %t224 = getelementptr [2 x %KValue], ptr %t222, i64 0, i64 1
  store %KValue %t206, ptr %t224
  %t225 = call %KValue @k_rec(i64 7, i64 2, ptr %t222)
  %t226 = call %KValue @k_b_length_fast(%KValue %t206)
  %t227 = extractvalue %KValue %t226, 0
  %t228 = extractvalue %KValue %t203, 0
  %t229 = icmp eq i64 %t227, 0
  %t230 = icmp eq i64 %t228, 0
  %t231 = and i1 %t229, %t230
  br i1 %t231, label %L66, label %L67
L66:
  %t232 = extractvalue %KValue %t226, 1
  %t233 = extractvalue %KValue %t203, 1
  %t234 = icmp slt i64 %t232, %t233
  %t235 = select i1 %t234, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L68
L67:
  %t236 = call %KValue @k_cmp(%KValue %t226, %KValue %t203, i64 2)
  br label %L68
L68:
  %t237 = phi %KValue [ %t235, %L66 ], [ %t236, %L67 ]
  %t238 = call i64 @k_not_failure(%KValue %t237)
  %t239 = icmp ne i64 %t238, 0
  br i1 %t239, label %L69, label %L70
L70:
  ret %KValue %t237
L69:
  %t240 = call i64 @k_truthy(%KValue %t237)
  %t241 = icmp ne i64 %t240, 0
  br i1 %t241, label %L71, label %L72
L71:
  %t242 = alloca [2 x %KValue]
  %t243 = getelementptr [2 x %KValue], ptr %t242, i64 0, i64 0
  store %KValue { i64 0, i64 1 }, ptr %t243
  %t244 = getelementptr [2 x %KValue], ptr %t242, i64 0, i64 1
  store %KValue %t206, ptr %t244
  %t245 = call %KValue @k_rec(i64 7, i64 2, ptr %t242)
  %t246 = musttail call tailcc %KValue @"d_query/list/next_1"(%KValue %t245)
  ret %KValue %t246
L72:
  %t247 = extractvalue %KValue %t206, 0
  %t248 = icmp eq i64 %t247, 13
  %t249 = extractvalue %KValue %t203, 0
  %t250 = icmp eq i64 %t249, 0
  %t251 = and i1 %t248, %t250
  br i1 %t251, label %L73, label %L74
L73:
  %t252 = extractvalue %KValue %t206, 1
  %t253 = inttoptr i64 %t252 to ptr
  %t254 = getelementptr %KBytes, ptr %t253, i64 0, i32 0
  %t255 = load i64, ptr %t254
  %t256 = extractvalue %KValue %t203, 1
  %t257 = icmp sge i64 %t256, 1
  %t258 = icmp sle i64 %t256, %t255
  %t259 = and i1 %t257, %t258
  br i1 %t259, label %L76, label %L74
L76:
  %t260 = getelementptr %KBytes, ptr %t253, i64 0, i32 1
  %t261 = load ptr, ptr %t260
  %t262 = add i64 %t256, -1
  %t263 = getelementptr i8, ptr %t261, i64 %t262
  %t264 = load i8, ptr %t263
  %t265 = zext i8 %t264 to i64
  %t266 = insertvalue %KValue { i64 0, i64 undef }, i64 %t265, 1
  br label %L75
L74:
  %t267 = call %KValue @k_index(%KValue %t206, %KValue %t203, ptr @s157)
  br label %L75
L75:
  %t268 = phi %KValue [ %t266, %L76 ], [ %t267, %L74 ]
  %t269 = alloca [2 x %KValue]
  %t270 = getelementptr [2 x %KValue], ptr %t269, i64 0, i64 0
  store %KValue %t268, ptr %t270
  %t271 = getelementptr [2 x %KValue], ptr %t269, i64 0, i64 1
  store %KValue %t225, ptr %t271
  %t272 = call %KValue @k_rec(i64 17, i64 2, ptr %t269)
  ret %KValue %t272
fail5:
  %t273 = call i64 @k_check_rec(%KValue %x0, i64 9, i64 2)
  %t274 = icmp ne i64 %t273, 0
  br i1 %t274, label %L77, label %fail6
L77:
  %t275 = call %KValue @k_field(%KValue %x0, i64 0)
  %t276 = call i64 @k_not_failure(%KValue %t275)
  %t277 = icmp ne i64 %t276, 0
  br i1 %t277, label %L78, label %fail6
L78:
  %t278 = call %KValue @k_field(%KValue %x0, i64 1)
  %t279 = call i64 @k_not_failure(%KValue %t278)
  %t280 = icmp ne i64 %t279, 0
  br i1 %t280, label %L79, label %fail6
L79:
  %t281 = call %KValue @k_call1(%KValue %t278, %KValue %t275)
  %t282 = alloca [2 x %KValue]
  %t283 = getelementptr [2 x %KValue], ptr %t282, i64 0, i64 0
  store %KValue %t281, ptr %t283
  %t284 = getelementptr [2 x %KValue], ptr %t282, i64 0, i64 1
  store %KValue %t278, ptr %t284
  %t285 = call %KValue @k_rec(i64 9, i64 2, ptr %t282)
  %t286 = alloca [2 x %KValue]
  %t287 = getelementptr [2 x %KValue], ptr %t286, i64 0, i64 0
  store %KValue %t275, ptr %t287
  %t288 = getelementptr [2 x %KValue], ptr %t286, i64 0, i64 1
  store %KValue %t285, ptr %t288
  %t289 = call %KValue @k_rec(i64 17, i64 2, ptr %t286)
  ret %KValue %t289
fail6:
  %t290 = call i64 @k_check_rec(%KValue %x0, i64 10, i64 2)
  %t291 = icmp ne i64 %t290, 0
  br i1 %t291, label %L80, label %fail7
L80:
  %t292 = call %KValue @k_field(%KValue %x0, i64 0)
  %t293 = call i64 @k_not_failure(%KValue %t292)
  %t294 = icmp ne i64 %t293, 0
  br i1 %t294, label %L81, label %fail7
L81:
  %t295 = call %KValue @k_field(%KValue %x0, i64 1)
  %t296 = call i64 @k_not_failure(%KValue %t295)
  %t297 = icmp ne i64 %t296, 0
  br i1 %t297, label %L82, label %fail7
L82:
  %t298 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t295)
  %t299 = musttail call tailcc %KValue @"d_query/list/next_mapped_2"(%KValue %t292, %KValue %t298)
  ret %KValue %t299
fail7:
  %t300 = call i64 @k_check_rec(%KValue %x0, i64 12, i64 2)
  %t301 = icmp ne i64 %t300, 0
  br i1 %t301, label %L83, label %fail8
L83:
  %t302 = call %KValue @k_field(%KValue %x0, i64 0)
  %t303 = call i64 @k_not_failure(%KValue %t302)
  %t304 = icmp ne i64 %t303, 0
  br i1 %t304, label %L84, label %fail8
L84:
  %t305 = call %KValue @k_field(%KValue %x0, i64 1)
  %t306 = call i64 @k_not_failure(%KValue %t305)
  %t307 = icmp ne i64 %t306, 0
  br i1 %t307, label %L85, label %fail8
L85:
  %t308 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t302)
  %t309 = musttail call tailcc %KValue @"d_query/list/next_paired_2"(%KValue %t308, %KValue %t305)
  ret %KValue %t309
fail8:
  %t310 = call i64 @k_check_rec(%KValue %x0, i64 13, i64 1)
  %t311 = icmp ne i64 %t310, 0
  br i1 %t311, label %L86, label %fail9
L86:
  %t312 = call %KValue @k_field(%KValue %x0, i64 0)
  %t313 = call i64 @k_not_failure(%KValue %t312)
  %t314 = icmp ne i64 %t313, 0
  br i1 %t314, label %L87, label %fail9
L87:
  %t315 = alloca [1 x %KValue]
  %t316 = getelementptr [1 x %KValue], ptr %t315, i64 0, i64 0
  store %KValue %t312, ptr %t316
  %t317 = call %KValue @k_rec(i64 13, i64 1, ptr %t315)
  %t318 = alloca [2 x %KValue]
  %t319 = getelementptr [2 x %KValue], ptr %t318, i64 0, i64 0
  store %KValue %t312, ptr %t319
  %t320 = getelementptr [2 x %KValue], ptr %t318, i64 0, i64 1
  store %KValue %t317, ptr %t320
  %t321 = call %KValue @k_rec(i64 17, i64 2, ptr %t318)
  ret %KValue %t321
fail9:
  %t322 = call i64 @k_check_rec(%KValue %x0, i64 14, i64 3)
  %t323 = icmp ne i64 %t322, 0
  br i1 %t323, label %L88, label %fail10
L88:
  %t324 = call %KValue @k_field(%KValue %x0, i64 0)
  %t325 = call i64 @k_not_failure(%KValue %t324)
  %t326 = icmp ne i64 %t325, 0
  br i1 %t326, label %L89, label %fail10
L89:
  %t327 = call %KValue @k_field(%KValue %x0, i64 1)
  %t328 = call i64 @k_not_failure(%KValue %t327)
  %t329 = icmp ne i64 %t328, 0
  br i1 %t329, label %L90, label %fail10
L90:
  %t330 = call %KValue @k_field(%KValue %x0, i64 2)
  %t331 = call i64 @k_not_failure(%KValue %t330)
  %t332 = icmp ne i64 %t331, 0
  br i1 %t332, label %L91, label %fail10
L91:
  %t333 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t327)
  %t334 = musttail call tailcc %KValue @"d_query/list/next_sifted_3"(%KValue %t324, %KValue %t330, %KValue %t333)
  ret %KValue %t334
fail10:
  %t335 = call i64 @k_check_rec(%KValue %x0, i64 15, i64 2)
  %t336 = icmp ne i64 %t335, 0
  br i1 %t336, label %L92, label %fail11
L92:
  %t337 = call %KValue @k_field(%KValue %x0, i64 0)
  %t338 = call i64 @k_not_failure(%KValue %t337)
  %t339 = icmp ne i64 %t338, 0
  br i1 %t339, label %L93, label %fail11
L93:
  %t340 = call %KValue @k_field(%KValue %x0, i64 1)
  %t341 = call i64 @k_not_failure(%KValue %t340)
  %t342 = icmp ne i64 %t341, 0
  br i1 %t342, label %L94, label %fail11
L94:
  %t343 = musttail call tailcc %KValue @"d_query/list/next_skipped_2"(%KValue %t337, %KValue %t340)
  ret %KValue %t343
fail11:
  %t344 = call i64 @k_not_failure(%KValue %x0)
  %t345 = icmp ne i64 %t344, 0
  br i1 %t345, label %L96, label %L95
L95:
  %t346 = call %KValue @k_err_hop(%KValue %x0, ptr @s155)
  ret %KValue %t346
L96:
  call void @k_die(ptr @s158)
  unreachable
}

define tailcc %KValue @"d_query/list/next_bounded_3"(i64 %x0r, %KValue %x1, %KValue %x2) {
entry:
  %x0 = insertvalue %KValue { i64 0, i64 undef }, i64 %x0r, 1
  %t1 = extractvalue %KValue %x0, 1
  %t2 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t3 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t1, i64 %t2)
  %t4 = extractvalue { i64, i1 } %t3, 0
  %t5 = extractvalue { i64, i1 } %t3, 1
  br i1 %t5, label %L2, label %L1
L2:
  call void @k_die(ptr @s94)
  unreachable
L1:
  %t6 = insertvalue %KValue { i64 0, i64 undef }, i64 %t4, 1
  %t7 = alloca [3 x %KValue]
  %t8 = getelementptr [3 x %KValue], ptr %t7, i64 0, i64 0
  store %KValue %t6, ptr %t8
  %t9 = getelementptr [3 x %KValue], ptr %t7, i64 0, i64 1
  store %KValue %x1, ptr %t9
  %t10 = getelementptr [3 x %KValue], ptr %t7, i64 0, i64 2
  store %KValue %x2, ptr %t10
  %t11 = call %KValue @k_rec(i64 3, i64 3, ptr %t7)
  %t12 = call %KValue @k_b_length_fast(%KValue %x2)
  %t13 = extractvalue %KValue %t12, 1
  %t14 = extractvalue %KValue %x0, 1
  %t15 = icmp slt i64 %t13, %t14
  %t16 = select i1 %t15, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t17 = call i64 @k_not_failure(%KValue %t16)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L3, label %L4
L4:
  ret %KValue %t16
L3:
  %t19 = call i64 @k_truthy(%KValue %t16)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L5, label %L6
L5:
  %t21 = alloca [1 x %KValue]
  %t22 = getelementptr [1 x %KValue], ptr %t21, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t22
  %t23 = call %KValue @k_rec(i64 8, i64 1, ptr %t21)
  ret %KValue %t23
L6:
  %t24 = extractvalue %KValue %x2, 0
  %t25 = icmp eq i64 %t24, 13
  %t26 = extractvalue %KValue %x0, 0
  %t27 = icmp eq i64 %t26, 0
  %t28 = and i1 %t25, %t27
  br i1 %t28, label %L7, label %L8
L7:
  %t29 = extractvalue %KValue %x2, 1
  %t30 = inttoptr i64 %t29 to ptr
  %t31 = getelementptr %KBytes, ptr %t30, i64 0, i32 0
  %t32 = load i64, ptr %t31
  %t33 = extractvalue %KValue %x0, 1
  %t34 = icmp sge i64 %t33, 1
  %t35 = icmp sle i64 %t33, %t32
  %t36 = and i1 %t34, %t35
  br i1 %t36, label %L10, label %L8
L10:
  %t37 = getelementptr %KBytes, ptr %t30, i64 0, i32 1
  %t38 = load ptr, ptr %t37
  %t39 = add i64 %t33, -1
  %t40 = getelementptr i8, ptr %t38, i64 %t39
  %t41 = load i8, ptr %t40
  %t42 = zext i8 %t41 to i64
  %t43 = insertvalue %KValue { i64 0, i64 undef }, i64 %t42, 1
  br label %L9
L8:
  %t44 = call %KValue @k_index(%KValue %x2, %KValue %x0, ptr @s160)
  br label %L9
L9:
  %t45 = phi %KValue [ %t43, %L10 ], [ %t44, %L8 ]
  %t46 = alloca [2 x %KValue]
  %t47 = getelementptr [2 x %KValue], ptr %t46, i64 0, i64 0
  store %KValue %t45, ptr %t47
  %t48 = getelementptr [2 x %KValue], ptr %t46, i64 0, i64 1
  store %KValue %t11, ptr %t48
  %t49 = call %KValue @k_rec(i64 17, i64 2, ptr %t46)
  ret %KValue %t49
fail0:
  %t50 = call i64 @k_not_failure(%KValue %x0)
  %t51 = icmp ne i64 %t50, 0
  br i1 %t51, label %L12, label %L11
L11:
  %t52 = call %KValue @k_err_hop(%KValue %x0, ptr @s159)
  ret %KValue %t52
L12:
  %t53 = call i64 @k_not_failure(%KValue %x1)
  %t54 = icmp ne i64 %t53, 0
  br i1 %t54, label %L14, label %L13
L13:
  %t55 = call %KValue @k_err_hop(%KValue %x1, ptr @s159)
  ret %KValue %t55
L14:
  %t56 = call i64 @k_not_failure(%KValue %x2)
  %t57 = icmp ne i64 %t56, 0
  br i1 %t57, label %L16, label %L15
L15:
  %t58 = call %KValue @k_err_hop(%KValue %x2, ptr @s159)
  ret %KValue %t58
L16:
  call void @k_die(ptr @s161)
  unreachable
}

define tailcc %KValue @"d_query/list/next_capped_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x1, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x1, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = alloca [1 x %KValue]
  %t7 = getelementptr [1 x %KValue], ptr %t6, i64 0, i64 0
  store %KValue %t3, ptr %t7
  %t8 = call %KValue @k_rec(i64 8, i64 1, ptr %t6)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_check_rec(%KValue %x1, i64 17, i64 2)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L3, label %fail1
L3:
  %t11 = call %KValue @k_field(%KValue %x1, i64 0)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %fail1
L4:
  %t14 = call %KValue @k_field(%KValue %x1, i64 1)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L5, label %fail1
L5:
  %t17 = extractvalue %KValue %x0, 0
  %t18 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t19 = icmp eq i64 %t17, 0
  %t20 = icmp eq i64 %t18, 0
  %t21 = and i1 %t19, %t20
  br i1 %t21, label %L6, label %L7
L6:
  %t22 = extractvalue %KValue %x0, 1
  %t23 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t24 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t22, i64 %t23)
  %t25 = extractvalue { i64, i1 } %t24, 0
  %t26 = extractvalue { i64, i1 } %t24, 1
  br i1 %t26, label %L7, label %L9
L9:
  %t27 = insertvalue %KValue { i64 0, i64 undef }, i64 %t25, 1
  br label %L8
L7:
  %t28 = call %KValue @k_sub(%KValue %x0, %KValue { i64 0, i64 1 })
  br label %L8
L8:
  %t29 = phi %KValue [ %t27, %L9 ], [ %t28, %L7 ]
  %t30 = alloca [2 x %KValue]
  %t31 = getelementptr [2 x %KValue], ptr %t30, i64 0, i64 0
  store %KValue %t29, ptr %t31
  %t32 = getelementptr [2 x %KValue], ptr %t30, i64 0, i64 1
  store %KValue %t14, ptr %t32
  %t33 = call %KValue @k_rec(i64 4, i64 2, ptr %t30)
  %t34 = alloca [2 x %KValue]
  %t35 = getelementptr [2 x %KValue], ptr %t34, i64 0, i64 0
  store %KValue %t11, ptr %t35
  %t36 = getelementptr [2 x %KValue], ptr %t34, i64 0, i64 1
  store %KValue %t33, ptr %t36
  %t37 = call %KValue @k_rec(i64 17, i64 2, ptr %t34)
  ret %KValue %t37
fail1:
  %t38 = call i64 @k_not_failure(%KValue %x0)
  %t39 = icmp ne i64 %t38, 0
  br i1 %t39, label %L11, label %L10
L10:
  %t40 = call %KValue @k_err_hop(%KValue %x0, ptr @s162)
  ret %KValue %t40
L11:
  %t41 = call i64 @k_not_failure(%KValue %x1)
  %t42 = icmp ne i64 %t41, 0
  br i1 %t42, label %L13, label %L12
L12:
  %t43 = call %KValue @k_err_hop(%KValue %x1, ptr @s162)
  ret %KValue %t43
L13:
  call void @k_die(ptr @s163)
  unreachable
}

define tailcc %KValue @"d_query/list/next_mapped_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x1, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x1, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = alloca [1 x %KValue]
  %t7 = getelementptr [1 x %KValue], ptr %t6, i64 0, i64 0
  store %KValue %t3, ptr %t7
  %t8 = call %KValue @k_rec(i64 8, i64 1, ptr %t6)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_check_rec(%KValue %x1, i64 17, i64 2)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L3, label %fail1
L3:
  %t11 = call %KValue @k_field(%KValue %x1, i64 0)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %fail1
L4:
  %t14 = call %KValue @k_field(%KValue %x1, i64 1)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L5, label %fail1
L5:
  %t17 = call %KValue @k_call1(%KValue %x0, %KValue %t11)
  %t18 = alloca [2 x %KValue]
  %t19 = getelementptr [2 x %KValue], ptr %t18, i64 0, i64 0
  store %KValue %x0, ptr %t19
  %t20 = getelementptr [2 x %KValue], ptr %t18, i64 0, i64 1
  store %KValue %t14, ptr %t20
  %t21 = call %KValue @k_rec(i64 10, i64 2, ptr %t18)
  %t22 = alloca [2 x %KValue]
  %t23 = getelementptr [2 x %KValue], ptr %t22, i64 0, i64 0
  store %KValue %t17, ptr %t23
  %t24 = getelementptr [2 x %KValue], ptr %t22, i64 0, i64 1
  store %KValue %t21, ptr %t24
  %t25 = call %KValue @k_rec(i64 17, i64 2, ptr %t22)
  ret %KValue %t25
fail1:
  %t26 = call i64 @k_not_failure(%KValue %x0)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L7, label %L6
L6:
  %t28 = call %KValue @k_err_hop(%KValue %x0, ptr @s164)
  ret %KValue %t28
L7:
  %t29 = call i64 @k_not_failure(%KValue %x1)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L9, label %L8
L8:
  %t31 = call %KValue @k_err_hop(%KValue %x1, ptr @s164)
  ret %KValue %t31
L9:
  call void @k_die(ptr @s165)
  unreachable
}

define tailcc %KValue @"d_query/list/next_paired_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = alloca [1 x %KValue]
  %t7 = getelementptr [1 x %KValue], ptr %t6, i64 0, i64 0
  store %KValue %t3, ptr %t7
  %t8 = call %KValue @k_rec(i64 8, i64 1, ptr %t6)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_check_rec(%KValue %x0, i64 17, i64 2)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L3, label %fail1
L3:
  %t11 = call %KValue @k_field(%KValue %x0, i64 0)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %fail1
L4:
  %t14 = call %KValue @k_field(%KValue %x0, i64 1)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L5, label %fail1
L5:
  %t17 = call tailcc %KValue @"d_query/list/next_1"(%KValue %x1)
  %t18 = musttail call tailcc %KValue @"d_query/list/next_zip_3"(%KValue %t11, %KValue %t14, %KValue %t17)
  ret %KValue %t18
fail1:
  %t19 = call i64 @k_not_failure(%KValue %x0)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L7, label %L6
L6:
  %t21 = call %KValue @k_err_hop(%KValue %x0, ptr @s166)
  ret %KValue %t21
L7:
  %t22 = call i64 @k_not_failure(%KValue %x1)
  %t23 = icmp ne i64 %t22, 0
  br i1 %t23, label %L9, label %L8
L8:
  %t24 = call %KValue @k_err_hop(%KValue %x1, ptr @s166)
  ret %KValue %t24
L9:
  call void @k_die(ptr @s167)
  unreachable
}

define tailcc %KValue @"d_query/list/next_sifted_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x2, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x2, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = alloca [1 x %KValue]
  %t7 = getelementptr [1 x %KValue], ptr %t6, i64 0, i64 0
  store %KValue %t3, ptr %t7
  %t8 = call %KValue @k_rec(i64 8, i64 1, ptr %t6)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_check_rec(%KValue %x2, i64 17, i64 2)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L3, label %fail1
L3:
  %t11 = call %KValue @k_field(%KValue %x2, i64 0)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %fail1
L4:
  %t14 = call %KValue @k_field(%KValue %x2, i64 1)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L5, label %fail1
L5:
  %t17 = alloca [3 x %KValue]
  %t18 = getelementptr [3 x %KValue], ptr %t17, i64 0, i64 0
  store %KValue %x0, ptr %t18
  %t19 = getelementptr [3 x %KValue], ptr %t17, i64 0, i64 1
  store %KValue %t14, ptr %t19
  %t20 = getelementptr [3 x %KValue], ptr %t17, i64 0, i64 2
  store %KValue %x1, ptr %t20
  %t21 = call %KValue @k_rec(i64 14, i64 3, ptr %t17)
  %t22 = call %KValue @k_call1(%KValue %x1, %KValue %t11)
  %t23 = extractvalue %KValue %t22, 0
  %t24 = extractvalue %KValue %x0, 0
  %t25 = icmp eq i64 %t23, 0
  %t26 = icmp eq i64 %t24, 0
  %t27 = and i1 %t25, %t26
  br i1 %t27, label %L6, label %L7
L6:
  %t28 = extractvalue %KValue %t22, 1
  %t29 = extractvalue %KValue %x0, 1
  %t30 = icmp eq i64 %t28, %t29
  %t31 = select i1 %t30, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L8
L7:
  %t32 = call %KValue @k_cmp(%KValue %t22, %KValue %x0, i64 0)
  br label %L8
L8:
  %t33 = phi %KValue [ %t31, %L6 ], [ %t32, %L7 ]
  %t34 = call i64 @k_not_failure(%KValue %t33)
  %t35 = icmp ne i64 %t34, 0
  br i1 %t35, label %L9, label %L10
L10:
  ret %KValue %t33
L9:
  %t36 = call i64 @k_truthy(%KValue %t33)
  %t37 = icmp ne i64 %t36, 0
  br i1 %t37, label %L11, label %L12
L11:
  %t38 = alloca [2 x %KValue]
  %t39 = getelementptr [2 x %KValue], ptr %t38, i64 0, i64 0
  store %KValue %t11, ptr %t39
  %t40 = getelementptr [2 x %KValue], ptr %t38, i64 0, i64 1
  store %KValue %t21, ptr %t40
  %t41 = call %KValue @k_rec(i64 17, i64 2, ptr %t38)
  ret %KValue %t41
L12:
  %t42 = musttail call tailcc %KValue @"d_query/list/next_1"(%KValue %t21)
  ret %KValue %t42
fail1:
  %t43 = call i64 @k_not_failure(%KValue %x0)
  %t44 = icmp ne i64 %t43, 0
  br i1 %t44, label %L14, label %L13
L13:
  %t45 = call %KValue @k_err_hop(%KValue %x0, ptr @s168)
  ret %KValue %t45
L14:
  %t46 = call i64 @k_not_failure(%KValue %x1)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L16, label %L15
L15:
  %t48 = call %KValue @k_err_hop(%KValue %x1, ptr @s168)
  ret %KValue %t48
L16:
  %t49 = call i64 @k_not_failure(%KValue %x2)
  %t50 = icmp ne i64 %t49, 0
  br i1 %t50, label %L18, label %L17
L17:
  %t51 = call %KValue @k_err_hop(%KValue %x2, ptr @s168)
  ret %KValue %t51
L18:
  call void @k_die(ptr @s169)
  unreachable
}

define tailcc %KValue @"d_query/list/next_skipped_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x1, i64 6, i64 2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x1, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %x1, i64 1)
  %t7 = call i64 @k_not_failure(%KValue %t6)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = extractvalue %KValue %t3, 0
  %t10 = extractvalue %KValue %x0, 0
  %t11 = icmp eq i64 %t9, 0
  %t12 = icmp eq i64 %t10, 0
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L5
L4:
  %t14 = extractvalue %KValue %t3, 1
  %t15 = extractvalue %KValue %x0, 1
  %t16 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t14, i64 %t15)
  %t17 = extractvalue { i64, i1 } %t16, 0
  %t18 = extractvalue { i64, i1 } %t16, 1
  br i1 %t18, label %L5, label %L7
L7:
  %t19 = insertvalue %KValue { i64 0, i64 undef }, i64 %t17, 1
  br label %L6
L5:
  %t20 = call %KValue @k_add(%KValue %t3, %KValue %x0)
  br label %L6
L6:
  %t21 = phi %KValue [ %t19, %L7 ], [ %t20, %L5 ]
  %t22 = alloca [2 x %KValue]
  %t23 = getelementptr [2 x %KValue], ptr %t22, i64 0, i64 0
  store %KValue %t21, ptr %t23
  %t24 = getelementptr [2 x %KValue], ptr %t22, i64 0, i64 1
  store %KValue %t6, ptr %t24
  %t25 = call %KValue @k_rec(i64 6, i64 2, ptr %t22)
  %t26 = musttail call tailcc %KValue @"d_query/list/next_1"(%KValue %t25)
  ret %KValue %t26
fail0:
  %t27 = call i64 @k_not_failure(%KValue %x1)
  %t28 = icmp ne i64 %t27, 0
  br i1 %t28, label %L8, label %fail1
L8:
  %t29 = extractvalue %KValue %x0, 0
  %t30 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t31 = icmp eq i64 %t29, 0
  %t32 = icmp eq i64 %t30, 0
  %t33 = and i1 %t31, %t32
  br i1 %t33, label %L9, label %L10
L9:
  %t34 = extractvalue %KValue %x0, 1
  %t35 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t36 = icmp slt i64 %t34, %t35
  %t37 = select i1 %t36, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L11
L10:
  %t38 = call %KValue @k_cmp(%KValue %x0, %KValue { i64 0, i64 1 }, i64 2)
  br label %L11
L11:
  %t39 = phi %KValue [ %t37, %L9 ], [ %t38, %L10 ]
  %t40 = call i64 @k_not_failure(%KValue %t39)
  %t41 = icmp ne i64 %t40, 0
  br i1 %t41, label %L12, label %L13
L13:
  ret %KValue %t39
L12:
  %t42 = call i64 @k_truthy(%KValue %t39)
  %t43 = icmp ne i64 %t42, 0
  br i1 %t43, label %L14, label %L15
L14:
  %t44 = musttail call tailcc %KValue @"d_query/list/next_1"(%KValue %x1)
  ret %KValue %t44
L15:
  %t45 = extractvalue %KValue %x0, 0
  %t46 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t47 = icmp eq i64 %t45, 0
  %t48 = icmp eq i64 %t46, 0
  %t49 = and i1 %t47, %t48
  br i1 %t49, label %L16, label %L17
L16:
  %t50 = extractvalue %KValue %x0, 1
  %t51 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t52 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t50, i64 %t51)
  %t53 = extractvalue { i64, i1 } %t52, 0
  %t54 = extractvalue { i64, i1 } %t52, 1
  br i1 %t54, label %L17, label %L19
L19:
  %t55 = insertvalue %KValue { i64 0, i64 undef }, i64 %t53, 1
  br label %L18
L17:
  %t56 = call %KValue @k_sub(%KValue %x0, %KValue { i64 0, i64 1 })
  br label %L18
L18:
  %t57 = phi %KValue [ %t55, %L19 ], [ %t56, %L17 ]
  %t58 = call tailcc %KValue @"d_query/list/next_1"(%KValue %x1)
  %t59 = call %KValue @"d_query/list/skip_one_1"(%KValue %t58)
  %t60 = musttail call tailcc %KValue @"d_query/list/next_skipped_2"(%KValue %t57, %KValue %t59)
  ret %KValue %t60
fail1:
  %t61 = call i64 @k_not_failure(%KValue %x0)
  %t62 = icmp ne i64 %t61, 0
  br i1 %t62, label %L21, label %L20
L20:
  %t63 = call %KValue @k_err_hop(%KValue %x0, ptr @s170)
  ret %KValue %t63
L21:
  %t64 = call i64 @k_not_failure(%KValue %x1)
  %t65 = icmp ne i64 %t64, 0
  br i1 %t65, label %L23, label %L22
L22:
  %t66 = call %KValue @k_err_hop(%KValue %x1, ptr @s170)
  ret %KValue %t66
L23:
  call void @k_die(ptr @s171)
  unreachable
}

define tailcc %KValue @"d_query/list/outrank_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 11, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  ret %KValue %x1
fail0:
  %t6 = extractvalue %KValue %x0, 0
  %t7 = extractvalue %KValue %x1, 0
  %t8 = icmp eq i64 %t6, 0
  %t9 = icmp eq i64 %t7, 0
  %t10 = and i1 %t8, %t9
  br i1 %t10, label %L3, label %L4
L3:
  %t11 = extractvalue %KValue %x0, 1
  %t12 = extractvalue %KValue %x1, 1
  %t13 = icmp slt i64 %t11, %t12
  %t14 = select i1 %t13, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L5
L4:
  %t15 = call %KValue @k_cmp(%KValue %x0, %KValue %x1, i64 2)
  br label %L5
L5:
  %t16 = phi %KValue [ %t14, %L3 ], [ %t15, %L4 ]
  %t17 = call i64 @k_not_failure(%KValue %t16)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L6, label %L7
L7:
  ret %KValue %t16
L6:
  %t19 = call i64 @k_truthy(%KValue %t16)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L8, label %L9
L8:
  ret %KValue %x1
L9:
  ret %KValue %x0
fail1:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L11, label %L10
L10:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s172)
  ret %KValue %t23
L11:
  %t24 = call i64 @k_not_failure(%KValue %x1)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L13, label %L12
L12:
  %t26 = call %KValue @k_err_hop(%KValue %x1, ptr @s172)
  ret %KValue %t26
L13:
  call void @k_die(ptr @s173)
  unreachable
}

define tailcc %KValue @"d_query/list/outrank_by_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 11, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  ret %KValue %x1
fail0:
  %t6 = call %KValue @k_call1(%KValue %x2, %KValue %x0)
  %t7 = call %KValue @k_call1(%KValue %x2, %KValue %x1)
  %t8 = extractvalue %KValue %t6, 0
  %t9 = extractvalue %KValue %t7, 0
  %t10 = icmp eq i64 %t8, 0
  %t11 = icmp eq i64 %t9, 0
  %t12 = and i1 %t10, %t11
  br i1 %t12, label %L3, label %L4
L3:
  %t13 = extractvalue %KValue %t6, 1
  %t14 = extractvalue %KValue %t7, 1
  %t15 = icmp slt i64 %t13, %t14
  %t16 = select i1 %t15, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L5
L4:
  %t17 = call %KValue @k_cmp(%KValue %t6, %KValue %t7, i64 2)
  br label %L5
L5:
  %t18 = phi %KValue [ %t16, %L3 ], [ %t17, %L4 ]
  %t19 = call i64 @k_not_failure(%KValue %t18)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L6, label %L7
L7:
  ret %KValue %t18
L6:
  %t21 = call i64 @k_truthy(%KValue %t18)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L8, label %L9
L8:
  ret %KValue %x1
L9:
  ret %KValue %x0
fail1:
  %t23 = call i64 @k_not_failure(%KValue %x0)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L11, label %L10
L10:
  %t25 = call %KValue @k_err_hop(%KValue %x0, ptr @s174)
  ret %KValue %t25
L11:
  %t26 = call i64 @k_not_failure(%KValue %x1)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L13, label %L12
L12:
  %t28 = call %KValue @k_err_hop(%KValue %x1, ptr @s174)
  ret %KValue %t28
L13:
  %t29 = call i64 @k_not_failure(%KValue %x2)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L15, label %L14
L14:
  %t31 = call %KValue @k_err_hop(%KValue %x2, ptr @s174)
  ret %KValue %t31
L15:
  call void @k_die(ptr @s175)
  unreachable
}

define tailcc %KValue @"d_query/list/range_1"(%KValue %x0) {
entry:
  %t1 = call tailcc %KValue @"d_query/list/min_1"(%KValue %x0)
  %t2 = call tailcc %KValue @"d_query/list/max_1"(%KValue %x0)
  %t3 = musttail call tailcc %KValue @"d_query/list/spread_2"(%KValue %t1, %KValue %t2)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s176)
  ret %KValue %t6
L2:
  call void @k_die(ptr @s177)
  unreachable
}

define tailcc %KValue @"d_query/list/spread_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 4
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call i64 @k_not_failure(%KValue %x1)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %fail0
L2:
  ret %KValue { i64 4, i64 0 }
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L3, label %fail1
L3:
  %t7 = call i64 @k_not_failure(%KValue %x1)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L4, label %fail1
L4:
  %t9 = extractvalue %KValue %x1, 0
  %t10 = extractvalue %KValue %x0, 0
  %t11 = icmp eq i64 %t9, 0
  %t12 = icmp eq i64 %t10, 0
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L5, label %L6
L5:
  %t14 = extractvalue %KValue %x1, 1
  %t15 = extractvalue %KValue %x0, 1
  %t16 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t14, i64 %t15)
  %t17 = extractvalue { i64, i1 } %t16, 0
  %t18 = extractvalue { i64, i1 } %t16, 1
  br i1 %t18, label %L6, label %L8
L8:
  %t19 = insertvalue %KValue { i64 0, i64 undef }, i64 %t17, 1
  br label %L7
L6:
  %t20 = call %KValue @k_sub(%KValue %x1, %KValue %x0)
  br label %L7
L7:
  %t21 = phi %KValue [ %t19, %L8 ], [ %t20, %L6 ]
  ret %KValue %t21
fail1:
  %t22 = call i64 @k_not_failure(%KValue %x0)
  %t23 = icmp ne i64 %t22, 0
  br i1 %t23, label %L10, label %L9
L9:
  %t24 = call %KValue @k_err_hop(%KValue %x0, ptr @s178)
  ret %KValue %t24
L10:
  %t25 = call i64 @k_not_failure(%KValue %x1)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L12, label %L11
L11:
  %t27 = call %KValue @k_err_hop(%KValue %x1, ptr @s178)
  ret %KValue %t27
L12:
  call void @k_die(ptr @s179)
  unreachable
}

define %KValue @"d_query/list/reject_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = alloca [3 x %KValue]
  %t3 = getelementptr [3 x %KValue], ptr %t2, i64 0, i64 0
  store %KValue { i64 3, i64 0 }, ptr %t3
  %t4 = getelementptr [3 x %KValue], ptr %t2, i64 0, i64 1
  store %KValue %t1, ptr %t4
  %t5 = getelementptr [3 x %KValue], ptr %t2, i64 0, i64 2
  store %KValue %x1, ptr %t5
  %t6 = call %KValue @k_rec(i64 14, i64 3, ptr %t2)
  ret %KValue %t6
fail0:
  %t7 = call i64 @k_not_failure(%KValue %x0)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L2, label %L1
L1:
  %t9 = call %KValue @k_err_hop(%KValue %x0, ptr @s180)
  ret %KValue %t9
L2:
  %t10 = call i64 @k_not_failure(%KValue %x1)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L3
L3:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s180)
  ret %KValue %t12
L4:
  call void @k_die(ptr @s181)
  unreachable
}

define %KValue @"d_query/list/repeat_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue %x0, ptr %t2
  %t3 = call %KValue @k_rec_reuse(i64 13, i64 1, ptr %t1, %KValue %x0)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s182)
  ret %KValue %t6
L2:
  call void @k_die(ptr @s183)
  unreachable
}

define %KValue @"d_query/list/select_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = alloca [3 x %KValue]
  %t3 = getelementptr [3 x %KValue], ptr %t2, i64 0, i64 0
  store %KValue { i64 2, i64 0 }, ptr %t3
  %t4 = getelementptr [3 x %KValue], ptr %t2, i64 0, i64 1
  store %KValue %t1, ptr %t4
  %t5 = getelementptr [3 x %KValue], ptr %t2, i64 0, i64 2
  store %KValue %x1, ptr %t5
  %t6 = call %KValue @k_rec(i64 14, i64 3, ptr %t2)
  ret %KValue %t6
fail0:
  %t7 = call i64 @k_not_failure(%KValue %x0)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L2, label %L1
L1:
  %t9 = call %KValue @k_err_hop(%KValue %x0, ptr @s184)
  ret %KValue %t9
L2:
  %t10 = call i64 @k_not_failure(%KValue %x1)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L3
L3:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s184)
  ret %KValue %t12
L4:
  call void @k_die(ptr @s185)
  unreachable
}

define %KValue @"d_query/list/skip_one_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = alloca [1 x %KValue]
  %t7 = getelementptr [1 x %KValue], ptr %t6, i64 0, i64 0
  store %KValue %t3, ptr %t7
  %t8 = call %KValue @k_rec(i64 8, i64 1, ptr %t6)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_check_rec(%KValue %x0, i64 17, i64 2)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L3, label %fail1
L3:
  %t11 = call %KValue @k_field(%KValue %x0, i64 0)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %fail1
L4:
  %t14 = call %KValue @k_field(%KValue %x0, i64 1)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L5, label %fail1
L5:
  ret %KValue %t14
fail1:
  %t17 = call i64 @k_not_failure(%KValue %x0)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L7, label %L6
L6:
  %t19 = call %KValue @k_err_hop(%KValue %x0, ptr @s186)
  ret %KValue %t19
L7:
  call void @k_die(ptr @s187)
  unreachable
}

define tailcc %KValue @"d_query/list/sort_1"(%KValue %x0) {
entry:
  %t1 = call tailcc %KValue @"d_query/list/to_list_1"(%KValue %x0)
  %t2 = musttail call tailcc %KValue @"d_query/list/msort_1"(%KValue %t1)
  ret %KValue %t2
fail0:
  %t3 = call i64 @k_not_failure(%KValue %x0)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %L1
L1:
  %t5 = call %KValue @k_err_hop(%KValue %x0, ptr @s188)
  ret %KValue %t5
L2:
  call void @k_die(ptr @s189)
  unreachable
}

define tailcc %KValue @"d_query/list/msort_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_length_fast(%KValue %x0)
  %t4 = extractvalue %KValue %t3, 1
  %t5 = musttail call tailcc %KValue @"d_query/list/whole_2"(%KValue %x0, i64 %t4)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %L2
L2:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s190)
  ret %KValue %t8
L3:
  call void @k_die(ptr @s191)
  unreachable
}

define tailcc %KValue @"d_query/list/whole_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 0
  %t2 = icmp eq i64 %t1, 0
  %t3 = extractvalue %KValue %x1, 1
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %fail0
L1:
  ret %KValue %x0
fail0:
  %t6 = extractvalue %KValue %x1, 1
  %t7 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t8 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t6, i64 %t7)
  %t9 = extractvalue { i64, i1 } %t8, 0
  %t10 = extractvalue { i64, i1 } %t8, 1
  br i1 %t10, label %L3, label %L2
L3:
  call void @k_die(ptr @s94)
  unreachable
L2:
  %t11 = insertvalue %KValue { i64 0, i64 undef }, i64 %t9, 1
  %t12 = musttail call tailcc %KValue @"d_query/list/span_4"(%KValue %x0, %KValue { i64 0, i64 1 }, %KValue %x1, %KValue %t11)
  ret %KValue %t12
fail1:
  %t13 = call i64 @k_not_failure(%KValue %x0)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L5, label %L4
L4:
  %t15 = call %KValue @k_err_hop(%KValue %x0, ptr @s192)
  ret %KValue %t15
L5:
  %t16 = call i64 @k_not_failure(%KValue %x1)
  %t17 = icmp ne i64 %t16, 0
  br i1 %t17, label %L7, label %L6
L6:
  %t18 = call %KValue @k_err_hop(%KValue %x1, ptr @s192)
  ret %KValue %t18
L7:
  call void @k_die(ptr @s193)
  unreachable
}

define tailcc %KValue @"d_query/list/span_4"(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %x3) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call i64 @k_not_failure(%KValue %x2)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %fail0
L2:
  %t5 = extractvalue %KValue %x3, 0
  %t6 = icmp eq i64 %t5, 0
  %t7 = extractvalue %KValue %x3, 1
  %t8 = icmp eq i64 %t7, 0
  %t9 = and i1 %t6, %t8
  br i1 %t9, label %L3, label %fail0
L3:
  %t10 = extractvalue %KValue %x0, 0
  %t11 = icmp eq i64 %t10, 13
  %t12 = extractvalue %KValue %x1, 0
  %t13 = icmp eq i64 %t12, 0
  %t14 = and i1 %t11, %t13
  br i1 %t14, label %L4, label %L5
L4:
  %t15 = extractvalue %KValue %x0, 1
  %t16 = inttoptr i64 %t15 to ptr
  %t17 = getelementptr %KBytes, ptr %t16, i64 0, i32 0
  %t18 = load i64, ptr %t17
  %t19 = extractvalue %KValue %x1, 1
  %t20 = icmp sge i64 %t19, 1
  %t21 = icmp sle i64 %t19, %t18
  %t22 = and i1 %t20, %t21
  br i1 %t22, label %L7, label %L5
L7:
  %t23 = getelementptr %KBytes, ptr %t16, i64 0, i32 1
  %t24 = load ptr, ptr %t23
  %t25 = add i64 %t19, -1
  %t26 = getelementptr i8, ptr %t24, i64 %t25
  %t27 = load i8, ptr %t26
  %t28 = zext i8 %t27 to i64
  %t29 = insertvalue %KValue { i64 0, i64 undef }, i64 %t28, 1
  br label %L6
L5:
  %t30 = call %KValue @k_index(%KValue %x0, %KValue %x1, ptr @s195)
  br label %L6
L6:
  %t31 = phi %KValue [ %t29, %L7 ], [ %t30, %L5 ]
  %t32 = alloca [1 x %KValue]
  %t33 = getelementptr [1 x %KValue], ptr %t32, i64 0, i64 0
  store %KValue %t31, ptr %t33
  %t34 = call %KValue @k_list_lit(i64 1, ptr %t32)
  ret %KValue %t34
fail0:
  %t35 = call i64 @k_not_failure(%KValue %x1)
  %t36 = icmp ne i64 %t35, 0
  br i1 %t36, label %L8, label %fail1
L8:
  %t37 = call i64 @k_not_failure(%KValue %x2)
  %t38 = icmp ne i64 %t37, 0
  br i1 %t38, label %L9, label %fail1
L9:
  %t39 = call i64 @k_not_failure(%KValue %x3)
  %t40 = icmp ne i64 %t39, 0
  br i1 %t40, label %L10, label %fail1
L10:
  %t41 = call %KValue @k_div(%KValue %x3, %KValue { i64 0, i64 2 }, ptr @s196)
  %t42 = extractvalue %KValue %x1, 0
  %t43 = extractvalue %KValue %t41, 0
  %t44 = icmp eq i64 %t42, 0
  %t45 = icmp eq i64 %t43, 0
  %t46 = and i1 %t44, %t45
  br i1 %t46, label %L11, label %L12
L11:
  %t47 = extractvalue %KValue %x1, 1
  %t48 = extractvalue %KValue %t41, 1
  %t49 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t47, i64 %t48)
  %t50 = extractvalue { i64, i1 } %t49, 0
  %t51 = extractvalue { i64, i1 } %t49, 1
  br i1 %t51, label %L12, label %L14
L14:
  %t52 = insertvalue %KValue { i64 0, i64 undef }, i64 %t50, 1
  br label %L13
L12:
  %t53 = call %KValue @k_add(%KValue %x1, %KValue %t41)
  br label %L13
L13:
  %t54 = phi %KValue [ %t52, %L14 ], [ %t53, %L12 ]
  %t55 = extractvalue %KValue %t54, 0
  %t56 = extractvalue %KValue %x1, 0
  %t57 = icmp eq i64 %t55, 0
  %t58 = icmp eq i64 %t56, 0
  %t59 = and i1 %t57, %t58
  br i1 %t59, label %L15, label %L16
L15:
  %t60 = extractvalue %KValue %t54, 1
  %t61 = extractvalue %KValue %x1, 1
  %t62 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t60, i64 %t61)
  %t63 = extractvalue { i64, i1 } %t62, 0
  %t64 = extractvalue { i64, i1 } %t62, 1
  br i1 %t64, label %L16, label %L18
L18:
  %t65 = insertvalue %KValue { i64 0, i64 undef }, i64 %t63, 1
  br label %L17
L16:
  %t66 = call %KValue @k_sub(%KValue %t54, %KValue %x1)
  br label %L17
L17:
  %t67 = phi %KValue [ %t65, %L18 ], [ %t66, %L16 ]
  %t68 = call tailcc %KValue @"d_query/list/span_4"(%KValue %x0, %KValue %x1, %KValue %t54, %KValue %t67)
  %t69 = extractvalue %KValue %t54, 0
  %t70 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t71 = icmp eq i64 %t69, 0
  %t72 = icmp eq i64 %t70, 0
  %t73 = and i1 %t71, %t72
  br i1 %t73, label %L19, label %L20
L19:
  %t74 = extractvalue %KValue %t54, 1
  %t75 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t76 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t74, i64 %t75)
  %t77 = extractvalue { i64, i1 } %t76, 0
  %t78 = extractvalue { i64, i1 } %t76, 1
  br i1 %t78, label %L20, label %L22
L22:
  %t79 = insertvalue %KValue { i64 0, i64 undef }, i64 %t77, 1
  br label %L21
L20:
  %t80 = call %KValue @k_add(%KValue %t54, %KValue { i64 0, i64 1 })
  br label %L21
L21:
  %t81 = phi %KValue [ %t79, %L22 ], [ %t80, %L20 ]
  %t82 = extractvalue %KValue %x2, 0
  %t83 = extractvalue %KValue %t54, 0
  %t84 = icmp eq i64 %t82, 0
  %t85 = icmp eq i64 %t83, 0
  %t86 = and i1 %t84, %t85
  br i1 %t86, label %L23, label %L24
L23:
  %t87 = extractvalue %KValue %x2, 1
  %t88 = extractvalue %KValue %t54, 1
  %t89 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t87, i64 %t88)
  %t90 = extractvalue { i64, i1 } %t89, 0
  %t91 = extractvalue { i64, i1 } %t89, 1
  br i1 %t91, label %L24, label %L26
L26:
  %t92 = insertvalue %KValue { i64 0, i64 undef }, i64 %t90, 1
  br label %L25
L24:
  %t93 = call %KValue @k_sub(%KValue %x2, %KValue %t54)
  br label %L25
L25:
  %t94 = phi %KValue [ %t92, %L26 ], [ %t93, %L24 ]
  %t95 = extractvalue %KValue %t94, 0
  %t96 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t97 = icmp eq i64 %t95, 0
  %t98 = icmp eq i64 %t96, 0
  %t99 = and i1 %t97, %t98
  br i1 %t99, label %L27, label %L28
L27:
  %t100 = extractvalue %KValue %t94, 1
  %t101 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t102 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t100, i64 %t101)
  %t103 = extractvalue { i64, i1 } %t102, 0
  %t104 = extractvalue { i64, i1 } %t102, 1
  br i1 %t104, label %L28, label %L30
L30:
  %t105 = insertvalue %KValue { i64 0, i64 undef }, i64 %t103, 1
  br label %L29
L28:
  %t106 = call %KValue @k_sub(%KValue %t94, %KValue { i64 0, i64 1 })
  br label %L29
L29:
  %t107 = phi %KValue [ %t105, %L30 ], [ %t106, %L28 ]
  %t108 = call tailcc %KValue @"d_query/list/span_4"(%KValue %x0, %KValue %t81, %KValue %x2, %KValue %t107)
  %t109 = alloca [1 x %KValue]
  %t110 = call %KValue @k_list_lit(i64 0, ptr %t109)
  %t111 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t112 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t113 = musttail call tailcc %KValue @"d_query/list/merge_5"(%KValue %t110, %KValue %t68, %KValue %t108, i64 %t111, i64 %t112)
  ret %KValue %t113
fail1:
  %t114 = call i64 @k_not_failure(%KValue %x0)
  %t115 = icmp ne i64 %t114, 0
  br i1 %t115, label %L32, label %L31
L31:
  %t116 = call %KValue @k_err_hop(%KValue %x0, ptr @s194)
  ret %KValue %t116
L32:
  %t117 = call i64 @k_not_failure(%KValue %x1)
  %t118 = icmp ne i64 %t117, 0
  br i1 %t118, label %L34, label %L33
L33:
  %t119 = call %KValue @k_err_hop(%KValue %x1, ptr @s194)
  ret %KValue %t119
L34:
  %t120 = call i64 @k_not_failure(%KValue %x2)
  %t121 = icmp ne i64 %t120, 0
  br i1 %t121, label %L36, label %L35
L35:
  %t122 = call %KValue @k_err_hop(%KValue %x2, ptr @s194)
  ret %KValue %t122
L36:
  %t123 = call i64 @k_not_failure(%KValue %x3)
  %t124 = icmp ne i64 %t123, 0
  br i1 %t124, label %L38, label %L37
L37:
  %t125 = call %KValue @k_err_hop(%KValue %x3, ptr @s194)
  ret %KValue %t125
L38:
  call void @k_die(ptr @s197)
  unreachable
}

define tailcc %KValue @"d_query/list/merge_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %x3r, i64 %x4r) {
entry:
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %x4 = insertvalue %KValue { i64 0, i64 undef }, i64 %x4r, 1
  %t1 = call i64 @k_not_failure(%KValue %x1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call i64 @k_not_failure(%KValue %x2)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %fail0
L2:
  %t5 = call %KValue @k_b_length_fast(%KValue %x1)
  %t6 = extractvalue %KValue %x3, 1
  %t7 = extractvalue %KValue %t5, 1
  %t8 = icmp sgt i64 %t6, %t7
  %t9 = select i1 %t8, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t10 = call i64 @k_not_failure(%KValue %t9)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L3, label %L4
L4:
  ret %KValue %t9
L3:
  %t12 = call i64 @k_truthy(%KValue %t9)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L5, label %L6
L5:
  %t14 = extractvalue %KValue %x4, 1
  %t15 = musttail call tailcc %KValue @"d_query/list/drain_3"(%KValue %x0, %KValue %x2, i64 %t14)
  ret %KValue %t15
L6:
  %t16 = extractvalue %KValue %x3, 1
  %t17 = extractvalue %KValue %x4, 1
  %t18 = musttail call tailcc %KValue @"d_query/list/merge_on_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %t16, i64 %t17)
  ret %KValue %t18
fail0:
  %t19 = call i64 @k_not_failure(%KValue %x0)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L8, label %L7
L7:
  %t21 = call %KValue @k_err_hop(%KValue %x0, ptr @s198)
  ret %KValue %t21
L8:
  %t22 = call i64 @k_not_failure(%KValue %x1)
  %t23 = icmp ne i64 %t22, 0
  br i1 %t23, label %L10, label %L9
L9:
  %t24 = call %KValue @k_err_hop(%KValue %x1, ptr @s198)
  ret %KValue %t24
L10:
  %t25 = call i64 @k_not_failure(%KValue %x2)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L12, label %L11
L11:
  %t27 = call %KValue @k_err_hop(%KValue %x2, ptr @s198)
  ret %KValue %t27
L12:
  %t28 = call i64 @k_not_failure(%KValue %x3)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L14, label %L13
L13:
  %t30 = call %KValue @k_err_hop(%KValue %x3, ptr @s198)
  ret %KValue %t30
L14:
  %t31 = call i64 @k_not_failure(%KValue %x4)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L16, label %L15
L15:
  %t33 = call %KValue @k_err_hop(%KValue %x4, ptr @s198)
  ret %KValue %t33
L16:
  call void @k_die(ptr @s199)
  unreachable
}

define tailcc %KValue @"d_query/list/merge_on_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %x3r, i64 %x4r) {
entry:
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %x4 = insertvalue %KValue { i64 0, i64 undef }, i64 %x4r, 1
  %t1 = call %KValue @k_b_length_fast(%KValue %x2)
  %t2 = extractvalue %KValue %x4, 1
  %t3 = extractvalue %KValue %t1, 1
  %t4 = icmp sgt i64 %t2, %t3
  %t5 = select i1 %t4, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L1, label %L2
L2:
  ret %KValue %t5
L1:
  %t8 = call i64 @k_truthy(%KValue %t5)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L4
L3:
  %t10 = extractvalue %KValue %x3, 1
  %t11 = musttail call tailcc %KValue @"d_query/list/drain_3"(%KValue %x0, %KValue %x1, i64 %t10)
  ret %KValue %t11
L4:
  %t12 = extractvalue %KValue %x3, 1
  %t13 = extractvalue %KValue %x4, 1
  %t14 = musttail call tailcc %KValue @"d_query/list/pick_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %t12, i64 %t13)
  ret %KValue %t14
fail0:
  %t15 = call i64 @k_not_failure(%KValue %x0)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L6, label %L5
L5:
  %t17 = call %KValue @k_err_hop(%KValue %x0, ptr @s200)
  ret %KValue %t17
L6:
  %t18 = call i64 @k_not_failure(%KValue %x1)
  %t19 = icmp ne i64 %t18, 0
  br i1 %t19, label %L8, label %L7
L7:
  %t20 = call %KValue @k_err_hop(%KValue %x1, ptr @s200)
  ret %KValue %t20
L8:
  %t21 = call i64 @k_not_failure(%KValue %x2)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L10, label %L9
L9:
  %t23 = call %KValue @k_err_hop(%KValue %x2, ptr @s200)
  ret %KValue %t23
L10:
  %t24 = call i64 @k_not_failure(%KValue %x3)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L12, label %L11
L11:
  %t26 = call %KValue @k_err_hop(%KValue %x3, ptr @s200)
  ret %KValue %t26
L12:
  %t27 = call i64 @k_not_failure(%KValue %x4)
  %t28 = icmp ne i64 %t27, 0
  br i1 %t28, label %L14, label %L13
L13:
  %t29 = call %KValue @k_err_hop(%KValue %x4, ptr @s200)
  ret %KValue %t29
L14:
  call void @k_die(ptr @s201)
  unreachable
}

define tailcc %KValue @"d_query/list/pick_5"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %x3r, i64 %x4r) {
entry:
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %x4 = insertvalue %KValue { i64 0, i64 undef }, i64 %x4r, 1
  %t1 = extractvalue %KValue %x1, 0
  %t2 = icmp eq i64 %t1, 13
  %t3 = extractvalue %KValue %x3, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %x1, 1
  %t7 = inttoptr i64 %t6 to ptr
  %t8 = getelementptr %KBytes, ptr %t7, i64 0, i32 0
  %t9 = load i64, ptr %t8
  %t10 = extractvalue %KValue %x3, 1
  %t11 = icmp sge i64 %t10, 1
  %t12 = icmp sle i64 %t10, %t9
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L2
L4:
  %t14 = getelementptr %KBytes, ptr %t7, i64 0, i32 1
  %t15 = load ptr, ptr %t14
  %t16 = add i64 %t10, -1
  %t17 = getelementptr i8, ptr %t15, i64 %t16
  %t18 = load i8, ptr %t17
  %t19 = zext i8 %t18 to i64
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  br label %L3
L2:
  %t21 = call %KValue @k_b_at(%KValue %x1, %KValue %x3)
  br label %L3
L3:
  %t22 = phi %KValue [ %t20, %L4 ], [ %t21, %L2 ]
  %t23 = extractvalue %KValue %x2, 0
  %t24 = icmp eq i64 %t23, 13
  %t25 = extractvalue %KValue %x4, 0
  %t26 = icmp eq i64 %t25, 0
  %t27 = and i1 %t24, %t26
  br i1 %t27, label %L5, label %L6
L5:
  %t28 = extractvalue %KValue %x2, 1
  %t29 = inttoptr i64 %t28 to ptr
  %t30 = getelementptr %KBytes, ptr %t29, i64 0, i32 0
  %t31 = load i64, ptr %t30
  %t32 = extractvalue %KValue %x4, 1
  %t33 = icmp sge i64 %t32, 1
  %t34 = icmp sle i64 %t32, %t31
  %t35 = and i1 %t33, %t34
  br i1 %t35, label %L8, label %L6
L8:
  %t36 = getelementptr %KBytes, ptr %t29, i64 0, i32 1
  %t37 = load ptr, ptr %t36
  %t38 = add i64 %t32, -1
  %t39 = getelementptr i8, ptr %t37, i64 %t38
  %t40 = load i8, ptr %t39
  %t41 = zext i8 %t40 to i64
  %t42 = insertvalue %KValue { i64 0, i64 undef }, i64 %t41, 1
  br label %L7
L6:
  %t43 = call %KValue @k_b_at(%KValue %x2, %KValue %x4)
  br label %L7
L7:
  %t44 = phi %KValue [ %t42, %L8 ], [ %t43, %L6 ]
  %t45 = extractvalue %KValue %t22, 0
  %t46 = extractvalue %KValue %t44, 0
  %t47 = icmp eq i64 %t45, 0
  %t48 = icmp eq i64 %t46, 0
  %t49 = and i1 %t47, %t48
  br i1 %t49, label %L9, label %L10
L9:
  %t50 = extractvalue %KValue %t22, 1
  %t51 = extractvalue %KValue %t44, 1
  %t52 = icmp slt i64 %t50, %t51
  %t53 = select i1 %t52, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L11
L10:
  %t54 = call %KValue @k_cmp(%KValue %t22, %KValue %t44, i64 2)
  br label %L11
L11:
  %t55 = phi %KValue [ %t53, %L9 ], [ %t54, %L10 ]
  %t56 = extractvalue %KValue %x3, 1
  %t57 = extractvalue %KValue %x4, 1
  %t58 = musttail call tailcc %KValue @"d_query/list/advance_6"(%KValue %t55, %KValue %x0, %KValue %x1, %KValue %x2, i64 %t56, i64 %t57)
  ret %KValue %t58
fail0:
  %t59 = call i64 @k_not_failure(%KValue %x0)
  %t60 = icmp ne i64 %t59, 0
  br i1 %t60, label %L13, label %L12
L12:
  %t61 = call %KValue @k_err_hop(%KValue %x0, ptr @s202)
  ret %KValue %t61
L13:
  %t62 = call i64 @k_not_failure(%KValue %x1)
  %t63 = icmp ne i64 %t62, 0
  br i1 %t63, label %L15, label %L14
L14:
  %t64 = call %KValue @k_err_hop(%KValue %x1, ptr @s202)
  ret %KValue %t64
L15:
  %t65 = call i64 @k_not_failure(%KValue %x2)
  %t66 = icmp ne i64 %t65, 0
  br i1 %t66, label %L17, label %L16
L16:
  %t67 = call %KValue @k_err_hop(%KValue %x2, ptr @s202)
  ret %KValue %t67
L17:
  %t68 = call i64 @k_not_failure(%KValue %x3)
  %t69 = icmp ne i64 %t68, 0
  br i1 %t69, label %L19, label %L18
L18:
  %t70 = call %KValue @k_err_hop(%KValue %x3, ptr @s202)
  ret %KValue %t70
L19:
  %t71 = call i64 @k_not_failure(%KValue %x4)
  %t72 = icmp ne i64 %t71, 0
  br i1 %t72, label %L21, label %L20
L20:
  %t73 = call %KValue @k_err_hop(%KValue %x4, ptr @s202)
  ret %KValue %t73
L21:
  call void @k_die(ptr @s203)
  unreachable
}

define tailcc %KValue @"d_query/list/advance_6"(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %x3, i64 %x4r, i64 %x5r) {
entry:
  %x4 = insertvalue %KValue { i64 0, i64 undef }, i64 %x4r, 1
  %x5 = insertvalue %KValue { i64 0, i64 undef }, i64 %x5r, 1
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 2
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x2, 0
  %t4 = icmp eq i64 %t3, 13
  %t5 = extractvalue %KValue %x4, 0
  %t6 = icmp eq i64 %t5, 0
  %t7 = and i1 %t4, %t6
  br i1 %t7, label %L2, label %L3
L2:
  %t8 = extractvalue %KValue %x2, 1
  %t9 = inttoptr i64 %t8 to ptr
  %t10 = getelementptr %KBytes, ptr %t9, i64 0, i32 0
  %t11 = load i64, ptr %t10
  %t12 = extractvalue %KValue %x4, 1
  %t13 = icmp sge i64 %t12, 1
  %t14 = icmp sle i64 %t12, %t11
  %t15 = and i1 %t13, %t14
  br i1 %t15, label %L5, label %L3
L5:
  %t16 = getelementptr %KBytes, ptr %t9, i64 0, i32 1
  %t17 = load ptr, ptr %t16
  %t18 = add i64 %t12, -1
  %t19 = getelementptr i8, ptr %t17, i64 %t18
  %t20 = load i8, ptr %t19
  %t21 = zext i8 %t20 to i64
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t21, 1
  br label %L4
L3:
  %t23 = call %KValue @k_b_at(%KValue %x2, %KValue %x4)
  br label %L4
L4:
  %t24 = phi %KValue [ %t22, %L5 ], [ %t23, %L3 ]
  %t25 = call %KValue @k_b_push_mut(%KValue %x1, %KValue %t24)
  %t26 = extractvalue %KValue %x4, 1
  %t27 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t28 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t26, i64 %t27)
  %t29 = extractvalue { i64, i1 } %t28, 0
  %t30 = extractvalue { i64, i1 } %t28, 1
  br i1 %t30, label %L7, label %L6
L7:
  call void @k_die(ptr @s94)
  unreachable
L6:
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t29, 1
  %t32 = extractvalue %KValue %t31, 1
  %t33 = extractvalue %KValue %x5, 1
  %t34 = musttail call tailcc %KValue @"d_query/list/merge_5"(%KValue %t25, %KValue %x2, %KValue %x3, i64 %t32, i64 %t33)
  ret %KValue %t34
fail0:
  %t35 = extractvalue %KValue %x0, 0
  %t36 = icmp eq i64 %t35, 3
  br i1 %t36, label %L8, label %fail1
L8:
  %t37 = extractvalue %KValue %x3, 0
  %t38 = icmp eq i64 %t37, 13
  %t39 = extractvalue %KValue %x5, 0
  %t40 = icmp eq i64 %t39, 0
  %t41 = and i1 %t38, %t40
  br i1 %t41, label %L9, label %L10
L9:
  %t42 = extractvalue %KValue %x3, 1
  %t43 = inttoptr i64 %t42 to ptr
  %t44 = getelementptr %KBytes, ptr %t43, i64 0, i32 0
  %t45 = load i64, ptr %t44
  %t46 = extractvalue %KValue %x5, 1
  %t47 = icmp sge i64 %t46, 1
  %t48 = icmp sle i64 %t46, %t45
  %t49 = and i1 %t47, %t48
  br i1 %t49, label %L12, label %L10
L12:
  %t50 = getelementptr %KBytes, ptr %t43, i64 0, i32 1
  %t51 = load ptr, ptr %t50
  %t52 = add i64 %t46, -1
  %t53 = getelementptr i8, ptr %t51, i64 %t52
  %t54 = load i8, ptr %t53
  %t55 = zext i8 %t54 to i64
  %t56 = insertvalue %KValue { i64 0, i64 undef }, i64 %t55, 1
  br label %L11
L10:
  %t57 = call %KValue @k_b_at(%KValue %x3, %KValue %x5)
  br label %L11
L11:
  %t58 = phi %KValue [ %t56, %L12 ], [ %t57, %L10 ]
  %t59 = call %KValue @k_b_push_mut(%KValue %x1, %KValue %t58)
  %t60 = extractvalue %KValue %x5, 1
  %t61 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t62 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t60, i64 %t61)
  %t63 = extractvalue { i64, i1 } %t62, 0
  %t64 = extractvalue { i64, i1 } %t62, 1
  br i1 %t64, label %L14, label %L13
L14:
  call void @k_die(ptr @s94)
  unreachable
L13:
  %t65 = insertvalue %KValue { i64 0, i64 undef }, i64 %t63, 1
  %t66 = extractvalue %KValue %x4, 1
  %t67 = extractvalue %KValue %t65, 1
  %t68 = musttail call tailcc %KValue @"d_query/list/merge_5"(%KValue %t59, %KValue %x2, %KValue %x3, i64 %t66, i64 %t67)
  ret %KValue %t68
fail1:
  %t69 = call i64 @k_not_failure(%KValue %x0)
  %t70 = icmp ne i64 %t69, 0
  br i1 %t70, label %L16, label %L15
L15:
  %t71 = call %KValue @k_err_hop(%KValue %x0, ptr @s204)
  ret %KValue %t71
L16:
  %t72 = call i64 @k_not_failure(%KValue %x1)
  %t73 = icmp ne i64 %t72, 0
  br i1 %t73, label %L18, label %L17
L17:
  %t74 = call %KValue @k_err_hop(%KValue %x1, ptr @s204)
  ret %KValue %t74
L18:
  %t75 = call i64 @k_not_failure(%KValue %x2)
  %t76 = icmp ne i64 %t75, 0
  br i1 %t76, label %L20, label %L19
L19:
  %t77 = call %KValue @k_err_hop(%KValue %x2, ptr @s204)
  ret %KValue %t77
L20:
  %t78 = call i64 @k_not_failure(%KValue %x3)
  %t79 = icmp ne i64 %t78, 0
  br i1 %t79, label %L22, label %L21
L21:
  %t80 = call %KValue @k_err_hop(%KValue %x3, ptr @s204)
  ret %KValue %t80
L22:
  %t81 = call i64 @k_not_failure(%KValue %x4)
  %t82 = icmp ne i64 %t81, 0
  br i1 %t82, label %L24, label %L23
L23:
  %t83 = call %KValue @k_err_hop(%KValue %x4, ptr @s204)
  ret %KValue %t83
L24:
  %t84 = call i64 @k_not_failure(%KValue %x5)
  %t85 = icmp ne i64 %t84, 0
  br i1 %t85, label %L26, label %L25
L25:
  %t86 = call %KValue @k_err_hop(%KValue %x5, ptr @s204)
  ret %KValue %t86
L26:
  call void @k_die(ptr @s205)
  unreachable
}

define tailcc %KValue @"d_query/list/drain_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_b_length_fast(%KValue %x1)
  %t2 = extractvalue %KValue %x2, 1
  %t3 = extractvalue %KValue %t1, 1
  %t4 = icmp sgt i64 %t2, %t3
  %t5 = select i1 %t4, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L1, label %L2
L2:
  ret %KValue %t5
L1:
  %t8 = call i64 @k_truthy(%KValue %t5)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L4
L3:
  ret %KValue %x0
L4:
  %t10 = extractvalue %KValue %x1, 0
  %t11 = icmp eq i64 %t10, 13
  %t12 = extractvalue %KValue %x2, 0
  %t13 = icmp eq i64 %t12, 0
  %t14 = and i1 %t11, %t13
  br i1 %t14, label %L5, label %L6
L5:
  %t15 = extractvalue %KValue %x1, 1
  %t16 = inttoptr i64 %t15 to ptr
  %t17 = getelementptr %KBytes, ptr %t16, i64 0, i32 0
  %t18 = load i64, ptr %t17
  %t19 = extractvalue %KValue %x2, 1
  %t20 = icmp sge i64 %t19, 1
  %t21 = icmp sle i64 %t19, %t18
  %t22 = and i1 %t20, %t21
  br i1 %t22, label %L8, label %L6
L8:
  %t23 = getelementptr %KBytes, ptr %t16, i64 0, i32 1
  %t24 = load ptr, ptr %t23
  %t25 = add i64 %t19, -1
  %t26 = getelementptr i8, ptr %t24, i64 %t25
  %t27 = load i8, ptr %t26
  %t28 = zext i8 %t27 to i64
  %t29 = insertvalue %KValue { i64 0, i64 undef }, i64 %t28, 1
  br label %L7
L6:
  %t30 = call %KValue @k_b_at(%KValue %x1, %KValue %x2)
  br label %L7
L7:
  %t31 = phi %KValue [ %t29, %L8 ], [ %t30, %L6 ]
  %t32 = call %KValue @k_b_push_mut(%KValue %x0, %KValue %t31)
  %t33 = extractvalue %KValue %x2, 1
  %t34 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t35 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t33, i64 %t34)
  %t36 = extractvalue { i64, i1 } %t35, 0
  %t37 = extractvalue { i64, i1 } %t35, 1
  br i1 %t37, label %L10, label %L9
L10:
  call void @k_die(ptr @s94)
  unreachable
L9:
  %t38 = insertvalue %KValue { i64 0, i64 undef }, i64 %t36, 1
  %t39 = extractvalue %KValue %t38, 1
  %t40 = musttail call tailcc %KValue @"d_query/list/drain_3"(%KValue %t32, %KValue %x1, i64 %t39)
  ret %KValue %t40
fail0:
  %t41 = call i64 @k_not_failure(%KValue %x0)
  %t42 = icmp ne i64 %t41, 0
  br i1 %t42, label %L12, label %L11
L11:
  %t43 = call %KValue @k_err_hop(%KValue %x0, ptr @s206)
  ret %KValue %t43
L12:
  %t44 = call i64 @k_not_failure(%KValue %x1)
  %t45 = icmp ne i64 %t44, 0
  br i1 %t45, label %L14, label %L13
L13:
  %t46 = call %KValue @k_err_hop(%KValue %x1, ptr @s206)
  ret %KValue %t46
L14:
  %t47 = call i64 @k_not_failure(%KValue %x2)
  %t48 = icmp ne i64 %t47, 0
  br i1 %t48, label %L16, label %L15
L15:
  %t49 = call %KValue @k_err_hop(%KValue %x2, ptr @s206)
  ret %KValue %t49
L16:
  call void @k_die(ptr @s207)
  unreachable
}

define %KValue @klam12(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = extractvalue %KValue %a0, 0
  %t2 = extractvalue %KValue %a1, 0
  %t3 = icmp eq i64 %t1, 0
  %t4 = icmp eq i64 %t2, 0
  %t5 = and i1 %t3, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %a0, 1
  %t7 = extractvalue %KValue %a1, 1
  %t8 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t6, i64 %t7)
  %t9 = extractvalue { i64, i1 } %t8, 0
  %t10 = extractvalue { i64, i1 } %t8, 1
  br i1 %t10, label %L2, label %L4
L4:
  %t11 = insertvalue %KValue { i64 0, i64 undef }, i64 %t9, 1
  br label %L3
L2:
  %t12 = call %KValue @k_add(%KValue %a0, %KValue %a1)
  br label %L3
L3:
  %t13 = phi %KValue [ %t11, %L4 ], [ %t12, %L2 ]
  ret %KValue %t13
}

define %KValue @w_klam12(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam12(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/sum_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = call %KValue @k_closure(ptr @w_klam12, i64 2, i64 0, ptr %t1)
  %t3 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue { i64 0, i64 0 }, %KValue %t2)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s208)
  ret %KValue %t6
L2:
  call void @k_die(ptr @s209)
  unreachable
}

define %KValue @"d_query/list/take_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = alloca [2 x %KValue]
  %t3 = getelementptr [2 x %KValue], ptr %t2, i64 0, i64 0
  store %KValue %x1, ptr %t3
  %t4 = getelementptr [2 x %KValue], ptr %t2, i64 0, i64 1
  store %KValue %t1, ptr %t4
  %t5 = call %KValue @k_rec(i64 4, i64 2, ptr %t2)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s210)
  ret %KValue %t8
L2:
  %t9 = call i64 @k_not_failure(%KValue %x1)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %L3
L3:
  %t11 = call %KValue @k_err_hop(%KValue %x1, ptr @s210)
  ret %KValue %t11
L4:
  call void @k_die(ptr @s211)
  unreachable
}

define %KValue @klam13(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = extractvalue %KValue %a0, 0
  %t2 = icmp eq i64 %t1, 13
  %t3 = extractvalue %KValue %a1, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %a0, 1
  %t7 = inttoptr i64 %t6 to ptr
  %t8 = getelementptr %KBytes, ptr %t7, i64 0, i32 0
  %t9 = load i64, ptr %t8
  %t10 = extractvalue %KValue %a1, 1
  %t11 = icmp sge i64 %t10, 1
  %t12 = icmp sle i64 %t10, %t9
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L2
L4:
  %t14 = getelementptr %KBytes, ptr %t7, i64 0, i32 1
  %t15 = load ptr, ptr %t14
  %t16 = add i64 %t10, -1
  %t17 = getelementptr i8, ptr %t15, i64 %t16
  %t18 = load i8, ptr %t17
  %t19 = zext i8 %t18 to i64
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  br label %L3
L2:
  %t21 = call %KValue @k_b_at(%KValue %a0, %KValue %a1)
  br label %L3
L3:
  %t22 = phi %KValue [ %t20, %L4 ], [ %t21, %L2 ]
  %t23 = call %KValue @"d_query/list/bump_1"(%KValue %t22)
  %t24 = call %KValue @k_b_put_mut(%KValue %a0, %KValue %a1, %KValue %t23)
  ret %KValue %t24
}

define %KValue @w_klam13(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam13(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/tally_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = call %KValue @k_map_lit(i64 0, ptr %t1)
  %t3 = alloca [1 x %KValue]
  %t4 = call %KValue @k_closure(ptr @w_klam13, i64 2, i64 0, ptr %t3)
  %t5 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t2, %KValue %t4)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s212)
  ret %KValue %t8
L2:
  call void @k_die(ptr @s213)
  unreachable
}

define %KValue @klam14(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_b_push_mut(%KValue %a0, %KValue %a1)
  ret %KValue %t1
}

define %KValue @w_klam14(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam14(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/to_list_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = call %KValue @k_list_lit(i64 0, ptr %t1)
  %t3 = alloca [1 x %KValue]
  %t4 = call %KValue @k_closure(ptr @w_klam14, i64 2, i64 0, ptr %t3)
  %t5 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t2, %KValue %t4)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s214)
  ret %KValue %t8
L2:
  call void @k_die(ptr @s215)
  unreachable
}

define tailcc %KValue @"d_query/list/underrank_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 11, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  ret %KValue %x1
fail0:
  %t6 = extractvalue %KValue %x1, 0
  %t7 = extractvalue %KValue %x0, 0
  %t8 = icmp eq i64 %t6, 0
  %t9 = icmp eq i64 %t7, 0
  %t10 = and i1 %t8, %t9
  br i1 %t10, label %L3, label %L4
L3:
  %t11 = extractvalue %KValue %x1, 1
  %t12 = extractvalue %KValue %x0, 1
  %t13 = icmp slt i64 %t11, %t12
  %t14 = select i1 %t13, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L5
L4:
  %t15 = call %KValue @k_cmp(%KValue %x1, %KValue %x0, i64 2)
  br label %L5
L5:
  %t16 = phi %KValue [ %t14, %L3 ], [ %t15, %L4 ]
  %t17 = call i64 @k_not_failure(%KValue %t16)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L6, label %L7
L7:
  ret %KValue %t16
L6:
  %t19 = call i64 @k_truthy(%KValue %t16)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L8, label %L9
L8:
  ret %KValue %x1
L9:
  ret %KValue %x0
fail1:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L11, label %L10
L10:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s216)
  ret %KValue %t23
L11:
  %t24 = call i64 @k_not_failure(%KValue %x1)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L13, label %L12
L12:
  %t26 = call %KValue @k_err_hop(%KValue %x1, ptr @s216)
  ret %KValue %t26
L13:
  call void @k_die(ptr @s217)
  unreachable
}

define tailcc %KValue @"d_query/list/underrank_by_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x0, i64 11, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x0, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  ret %KValue %x1
fail0:
  %t6 = call %KValue @k_call1(%KValue %x2, %KValue %x1)
  %t7 = call %KValue @k_call1(%KValue %x2, %KValue %x0)
  %t8 = extractvalue %KValue %t6, 0
  %t9 = extractvalue %KValue %t7, 0
  %t10 = icmp eq i64 %t8, 0
  %t11 = icmp eq i64 %t9, 0
  %t12 = and i1 %t10, %t11
  br i1 %t12, label %L3, label %L4
L3:
  %t13 = extractvalue %KValue %t6, 1
  %t14 = extractvalue %KValue %t7, 1
  %t15 = icmp slt i64 %t13, %t14
  %t16 = select i1 %t15, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L5
L4:
  %t17 = call %KValue @k_cmp(%KValue %t6, %KValue %t7, i64 2)
  br label %L5
L5:
  %t18 = phi %KValue [ %t16, %L3 ], [ %t17, %L4 ]
  %t19 = call i64 @k_not_failure(%KValue %t18)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L6, label %L7
L7:
  ret %KValue %t18
L6:
  %t21 = call i64 @k_truthy(%KValue %t18)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L8, label %L9
L8:
  ret %KValue %x1
L9:
  ret %KValue %x0
fail1:
  %t23 = call i64 @k_not_failure(%KValue %x0)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L11, label %L10
L10:
  %t25 = call %KValue @k_err_hop(%KValue %x0, ptr @s218)
  ret %KValue %t25
L11:
  %t26 = call i64 @k_not_failure(%KValue %x1)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L13, label %L12
L12:
  %t28 = call %KValue @k_err_hop(%KValue %x1, ptr @s218)
  ret %KValue %t28
L13:
  %t29 = call i64 @k_not_failure(%KValue %x2)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L15, label %L14
L14:
  %t31 = call %KValue @k_err_hop(%KValue %x2, ptr @s218)
  ret %KValue %t31
L15:
  call void @k_die(ptr @s219)
  unreachable
}

define tailcc %KValue @"d_query/list/unwrap_found_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 4
  br i1 %t2, label %L1, label %fail0
L1:
  ret %KValue { i64 4, i64 0 }
fail0:
  %t3 = call i64 @k_check_rec(%KValue %x0, i64 11, i64 1)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %fail1
L2:
  %t5 = call %KValue @k_field(%KValue %x0, i64 0)
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %fail1
L3:
  ret %KValue { i64 4, i64 0 }
fail1:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %fail2
L4:
  ret %KValue %x0
fail2:
  %t10 = call i64 @k_not_failure(%KValue %x0)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L6, label %L5
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x0, ptr @s220)
  ret %KValue %t12
L6:
  call void @k_die(ptr @s221)
  unreachable
}

define %KValue @klam15(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = extractvalue %KValue %a1, 0
  %t2 = icmp eq i64 %t1, 13
  %t3 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %a1, 1
  %t7 = inttoptr i64 %t6 to ptr
  %t8 = getelementptr %KBytes, ptr %t7, i64 0, i32 0
  %t9 = load i64, ptr %t8
  %t10 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t11 = icmp sge i64 %t10, 1
  %t12 = icmp sle i64 %t10, %t9
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L2
L4:
  %t14 = getelementptr %KBytes, ptr %t7, i64 0, i32 1
  %t15 = load ptr, ptr %t14
  %t16 = add i64 %t10, -1
  %t17 = getelementptr i8, ptr %t15, i64 %t16
  %t18 = load i8, ptr %t17
  %t19 = zext i8 %t18 to i64
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  br label %L3
L2:
  %t21 = call %KValue @k_index(%KValue %a1, %KValue { i64 0, i64 1 }, ptr @s223)
  br label %L3
L3:
  %t22 = phi %KValue [ %t20, %L4 ], [ %t21, %L2 ]
  %t23 = extractvalue %KValue %a1, 0
  %t24 = icmp eq i64 %t23, 13
  %t25 = extractvalue %KValue { i64 0, i64 2 }, 0
  %t26 = icmp eq i64 %t25, 0
  %t27 = and i1 %t24, %t26
  br i1 %t27, label %L5, label %L6
L5:
  %t28 = extractvalue %KValue %a1, 1
  %t29 = inttoptr i64 %t28 to ptr
  %t30 = getelementptr %KBytes, ptr %t29, i64 0, i32 0
  %t31 = load i64, ptr %t30
  %t32 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t33 = icmp sge i64 %t32, 1
  %t34 = icmp sle i64 %t32, %t31
  %t35 = and i1 %t33, %t34
  br i1 %t35, label %L8, label %L6
L8:
  %t36 = getelementptr %KBytes, ptr %t29, i64 0, i32 1
  %t37 = load ptr, ptr %t36
  %t38 = add i64 %t32, -1
  %t39 = getelementptr i8, ptr %t37, i64 %t38
  %t40 = load i8, ptr %t39
  %t41 = zext i8 %t40 to i64
  %t42 = insertvalue %KValue { i64 0, i64 undef }, i64 %t41, 1
  br label %L7
L6:
  %t43 = call %KValue @k_index(%KValue %a1, %KValue { i64 0, i64 2 }, ptr @s223)
  br label %L7
L7:
  %t44 = phi %KValue [ %t42, %L8 ], [ %t43, %L6 ]
  %t45 = call %KValue @k_b_put_mut(%KValue %a0, %KValue %t22, %KValue %t44)
  ret %KValue %t45
}

define %KValue @w_klam15(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call %KValue @klam15(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/to_h_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = call %KValue @k_map_lit(i64 0, ptr %t1)
  %t3 = alloca [1 x %KValue]
  %t4 = call %KValue @k_closure(ptr @w_klam15, i64 2, i64 0, ptr %t3)
  %t5 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x0, %KValue %t2, %KValue %t4)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s222)
  ret %KValue %t8
L2:
  call void @k_die(ptr @s224)
  unreachable
}

define tailcc %KValue @klam16(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = musttail call tailcc %KValue @"d_query/list/put_renamed_3"(%KValue %a0, %KValue %a1, %KValue %t1)
  ret %KValue %t2
}

define %KValue @w_klam16(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call tailcc %KValue @klam16(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/transform_keys_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_entries(%KValue %x0)
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_map_lit(i64 0, ptr %t2)
  %t4 = alloca [1 x %KValue]
  %t5 = getelementptr [1 x %KValue], ptr %t4, i64 0, i64 0
  store %KValue %x1, ptr %t5
  %t6 = call %KValue @k_closure(ptr @w_klam16, i64 2, i64 1, ptr %t4)
  %t7 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %t1, %KValue %t3, %KValue %t6)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L1
L1:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s225)
  ret %KValue %t10
L2:
  %t11 = call i64 @k_not_failure(%KValue %x1)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L4, label %L3
L3:
  %t13 = call %KValue @k_err_hop(%KValue %x1, ptr @s225)
  ret %KValue %t13
L4:
  call void @k_die(ptr @s226)
  unreachable
}

define tailcc %KValue @"d_query/list/put_renamed_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x1, i64 0, i64 2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x1, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %x1, i64 1)
  %t7 = call i64 @k_not_failure(%KValue %t6)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = call %KValue @k_call1(%KValue %x2, %KValue %t3)
  %t10 = call %KValue @k_b_put_mut(%KValue %x0, %KValue %t9, %KValue %t6)
  ret %KValue %t10
fail0:
  %t11 = call i64 @k_not_failure(%KValue %x0)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L5, label %L4
L4:
  %t13 = call %KValue @k_err_hop(%KValue %x0, ptr @s227)
  ret %KValue %t13
L5:
  %t14 = call i64 @k_not_failure(%KValue %x1)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L7, label %L6
L6:
  %t16 = call %KValue @k_err_hop(%KValue %x1, ptr @s227)
  ret %KValue %t16
L7:
  %t17 = call i64 @k_not_failure(%KValue %x2)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L9, label %L8
L8:
  %t19 = call %KValue @k_err_hop(%KValue %x2, ptr @s227)
  ret %KValue %t19
L9:
  call void @k_die(ptr @s228)
  unreachable
}

define tailcc %KValue @klam17(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = musttail call tailcc %KValue @"d_query/list/put_shaped_3"(%KValue %a0, %KValue %a1, %KValue %t1)
  ret %KValue %t2
}

define %KValue @w_klam17(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call tailcc %KValue @klam17(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/list/transform_values_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_entries(%KValue %x0)
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_map_lit(i64 0, ptr %t2)
  %t4 = alloca [1 x %KValue]
  %t5 = getelementptr [1 x %KValue], ptr %t4, i64 0, i64 0
  store %KValue %x1, ptr %t5
  %t6 = call %KValue @k_closure(ptr @w_klam17, i64 2, i64 1, ptr %t4)
  %t7 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %t1, %KValue %t3, %KValue %t6)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L1
L1:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s229)
  ret %KValue %t10
L2:
  %t11 = call i64 @k_not_failure(%KValue %x1)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L4, label %L3
L3:
  %t13 = call %KValue @k_err_hop(%KValue %x1, ptr @s229)
  ret %KValue %t13
L4:
  call void @k_die(ptr @s230)
  unreachable
}

define tailcc %KValue @"d_query/list/put_shaped_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x1, i64 0, i64 2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x1, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %x1, i64 1)
  %t7 = call i64 @k_not_failure(%KValue %t6)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = call %KValue @k_call1(%KValue %x2, %KValue %t6)
  %t10 = call %KValue @k_b_put_mut(%KValue %x0, %KValue %t3, %KValue %t9)
  ret %KValue %t10
fail0:
  %t11 = call i64 @k_not_failure(%KValue %x0)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L5, label %L4
L4:
  %t13 = call %KValue @k_err_hop(%KValue %x0, ptr @s231)
  ret %KValue %t13
L5:
  %t14 = call i64 @k_not_failure(%KValue %x1)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L7, label %L6
L6:
  %t16 = call %KValue @k_err_hop(%KValue %x1, ptr @s231)
  ret %KValue %t16
L7:
  %t17 = call i64 @k_not_failure(%KValue %x2)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L9, label %L8
L8:
  %t19 = call %KValue @k_err_hop(%KValue %x2, ptr @s231)
  ret %KValue %t19
L9:
  call void @k_die(ptr @s232)
  unreachable
}

define %KValue @"d_query/list/zip_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = call %KValue @"d_query/list/iter_1"(%KValue %x1)
  %t3 = alloca [2 x %KValue]
  %t4 = getelementptr [2 x %KValue], ptr %t3, i64 0, i64 0
  store %KValue %t1, ptr %t4
  %t5 = getelementptr [2 x %KValue], ptr %t3, i64 0, i64 1
  store %KValue %t2, ptr %t5
  %t6 = call %KValue @k_rec(i64 12, i64 2, ptr %t3)
  ret %KValue %t6
fail0:
  %t7 = call i64 @k_not_failure(%KValue %x0)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L2, label %L1
L1:
  %t9 = call %KValue @k_err_hop(%KValue %x0, ptr @s233)
  ret %KValue %t9
L2:
  %t10 = call i64 @k_not_failure(%KValue %x1)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L3
L3:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s233)
  ret %KValue %t12
L4:
  call void @k_die(ptr @s234)
  unreachable
}

define tailcc %KValue @"d_query/list/next_zip_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x2, i64 8, i64 1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x2, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = alloca [1 x %KValue]
  %t7 = getelementptr [1 x %KValue], ptr %t6, i64 0, i64 0
  store %KValue %t3, ptr %t7
  %t8 = call %KValue @k_rec(i64 8, i64 1, ptr %t6)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_check_rec(%KValue %x2, i64 17, i64 2)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L3, label %fail1
L3:
  %t11 = call %KValue @k_field(%KValue %x2, i64 0)
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %fail1
L4:
  %t14 = call %KValue @k_field(%KValue %x2, i64 1)
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L5, label %fail1
L5:
  %t17 = alloca [2 x %KValue]
  %t18 = getelementptr [2 x %KValue], ptr %t17, i64 0, i64 0
  store %KValue %x0, ptr %t18
  %t19 = getelementptr [2 x %KValue], ptr %t17, i64 0, i64 1
  store %KValue %t11, ptr %t19
  %t20 = call %KValue @k_list_lit(i64 2, ptr %t17)
  %t21 = alloca [2 x %KValue]
  %t22 = getelementptr [2 x %KValue], ptr %t21, i64 0, i64 0
  store %KValue %x1, ptr %t22
  %t23 = getelementptr [2 x %KValue], ptr %t21, i64 0, i64 1
  store %KValue %t14, ptr %t23
  %t24 = call %KValue @k_rec(i64 12, i64 2, ptr %t21)
  %t25 = alloca [2 x %KValue]
  %t26 = getelementptr [2 x %KValue], ptr %t25, i64 0, i64 0
  store %KValue %t20, ptr %t26
  %t27 = getelementptr [2 x %KValue], ptr %t25, i64 0, i64 1
  store %KValue %t24, ptr %t27
  %t28 = call %KValue @k_rec(i64 17, i64 2, ptr %t25)
  ret %KValue %t28
fail1:
  %t29 = call i64 @k_not_failure(%KValue %x0)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L7, label %L6
L6:
  %t31 = call %KValue @k_err_hop(%KValue %x0, ptr @s235)
  ret %KValue %t31
L7:
  %t32 = call i64 @k_not_failure(%KValue %x1)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L9, label %L8
L8:
  %t34 = call %KValue @k_err_hop(%KValue %x1, ptr @s235)
  ret %KValue %t34
L9:
  %t35 = call i64 @k_not_failure(%KValue %x2)
  %t36 = icmp ne i64 %t35, 0
  br i1 %t36, label %L11, label %L10
L10:
  %t37 = call %KValue @k_err_hop(%KValue %x2, ptr @s235)
  ret %KValue %t37
L11:
  call void @k_die(ptr @s236)
  unreachable
}

define %KValue @"d_query/text/append_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %x1)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s237)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s237)
  ret %KValue %t7
L4:
  call void @k_die(ptr @s238)
  unreachable
}

define %KValue @"d_query/text/bytes_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_bytes(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s239)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s240)
  unreachable
}

define %KValue @"d_query/text/char_code_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_char_code(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s241)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s242)
  unreachable
}

define %KValue @"d_query/text/chars_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_chars(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s243)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s244)
  unreachable
}

define %KValue @"d_query/text/concat_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_concat(%KValue %x0, %KValue %x1)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s245)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s245)
  ret %KValue %t7
L4:
  call void @k_die(ptr @s246)
  unreachable
}

define %KValue @"d_query/text/find2_4"(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %x3) {
entry:
  %t1 = call %KValue @k_b_find2(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %x3)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s247)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s247)
  ret %KValue %t7
L4:
  %t8 = call i64 @k_not_failure(%KValue %x2)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L6, label %L5
L5:
  %t10 = call %KValue @k_err_hop(%KValue %x2, ptr @s247)
  ret %KValue %t10
L6:
  %t11 = call i64 @k_not_failure(%KValue %x3)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L8, label %L7
L7:
  %t13 = call %KValue @k_err_hop(%KValue %x3, ptr @s247)
  ret %KValue %t13
L8:
  call void @k_die(ptr @s248)
  unreachable
}

define %KValue @"d_query/text/find2_below_5"(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %x3, %KValue %x4) {
entry:
  %t1 = call %KValue @k_b_find2_below(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %x3, %KValue %x4)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s249)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s249)
  ret %KValue %t7
L4:
  %t8 = call i64 @k_not_failure(%KValue %x2)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L6, label %L5
L5:
  %t10 = call %KValue @k_err_hop(%KValue %x2, ptr @s249)
  ret %KValue %t10
L6:
  %t11 = call i64 @k_not_failure(%KValue %x3)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L8, label %L7
L7:
  %t13 = call %KValue @k_err_hop(%KValue %x3, ptr @s249)
  ret %KValue %t13
L8:
  %t14 = call i64 @k_not_failure(%KValue %x4)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L10, label %L9
L9:
  %t16 = call %KValue @k_err_hop(%KValue %x4, ptr @s249)
  ret %KValue %t16
L10:
  call void @k_die(ptr @s250)
  unreachable
}

define %KValue @"d_query/text/from_code_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_from_code(%KValue %x0, ptr @s252)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L3, label %L2
L2:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s251)
  ret %KValue %t6
L3:
  call void @k_die(ptr @s253)
  unreachable
}

define %KValue @"d_query/text/join_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_join(%KValue %x0, %KValue %x1)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s254)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s254)
  ret %KValue %t7
L4:
  call void @k_die(ptr @s255)
  unreachable
}

define %KValue @"d_query/text/slice_3"(%KValue %x0, %KValue %x1, %KValue %x2) {
entry:
  %t1 = call %KValue @k_b_slice(%KValue %x0, %KValue %x1, %KValue %x2)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s256)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s256)
  ret %KValue %t7
L4:
  %t8 = call i64 @k_not_failure(%KValue %x2)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L6, label %L5
L5:
  %t10 = call %KValue @k_err_hop(%KValue %x2, ptr @s256)
  ret %KValue %t10
L6:
  call void @k_die(ptr @s257)
  unreachable
}

define %KValue @"d_query/text/split_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_str(%KValue %x1, ptr @s259, i64 0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_str_lit(ptr @s260, i64 58, ptr @s260_lit)
  %t4 = call %KValue @k_err(%KValue %t3, ptr @s261)
  ret %KValue %t4
fail0:
  %t5 = call %KValue @k_b_split(%KValue %x0, %KValue %x1)
  ret %KValue %t5
fail1:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %L2
L2:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s258)
  ret %KValue %t8
L3:
  %t9 = call i64 @k_not_failure(%KValue %x1)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L5, label %L4
L4:
  %t11 = call %KValue @k_err_hop(%KValue %x1, ptr @s258)
  ret %KValue %t11
L5:
  call void @k_die(ptr @s262)
  unreachable
}

define %KValue @"d_query/text/padding?_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s264, i64 4, ptr @s264_lit)
  %t2 = call %KValue @"d_query/text/split_2"(%KValue %t1, %KValue %x0)
  %t3 = call %KValue @k_b_length_fast(%KValue %t2)
  %t4 = extractvalue %KValue %t3, 0
  %t5 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t6 = icmp eq i64 %t4, 0
  %t7 = icmp eq i64 %t5, 0
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = extractvalue %KValue %t3, 1
  %t10 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t11 = icmp sgt i64 %t9, %t10
  %t12 = select i1 %t11, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t13 = call %KValue @k_cmp(%KValue %t3, %KValue { i64 0, i64 1 }, i64 4)
  br label %L3
L3:
  %t14 = phi %KValue [ %t12, %L1 ], [ %t13, %L2 ]
  ret %KValue %t14
fail0:
  %t15 = call i64 @k_not_failure(%KValue %x0)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L5, label %L4
L4:
  %t17 = call %KValue @k_err_hop(%KValue %x0, ptr @s263)
  ret %KValue %t17
L5:
  call void @k_die(ptr @s265)
  unreachable
}

define tailcc %KValue @"d_query/text/trim_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_length_fast(%KValue %x0)
  %t2 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t3 = extractvalue %KValue %t1, 1
  %t4 = musttail call tailcc %KValue @"d_query/text/from_front_3"(%KValue %x0, i64 %t2, i64 %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s266)
  ret %KValue %t7
L2:
  call void @k_die(ptr @s267)
  unreachable
}

define tailcc %KValue @"d_query/text/from_front_3"(%KValue %x0, i64 %x1r, i64 %x2r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = extractvalue %KValue %x2, 1
  %t3 = icmp sgt i64 %t1, %t2
  %t4 = select i1 %t3, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t5 = extractvalue %KValue %x1, 1
  %t6 = extractvalue %KValue %x2, 1
  %t7 = musttail call tailcc %KValue @"d_query/text/past_the_end_4"(%KValue %x0, i64 %t5, i64 %t6, %KValue %t4)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L1
L1:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s268)
  ret %KValue %t10
L2:
  %t11 = call i64 @k_not_failure(%KValue %x1)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L4, label %L3
L3:
  %t13 = call %KValue @k_err_hop(%KValue %x1, ptr @s268)
  ret %KValue %t13
L4:
  %t14 = call i64 @k_not_failure(%KValue %x2)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %L5
L5:
  %t16 = call %KValue @k_err_hop(%KValue %x2, ptr @s268)
  ret %KValue %t16
L6:
  call void @k_die(ptr @s269)
  unreachable
}

define tailcc %KValue @"d_query/text/past_the_end_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x3, 0
  %t2 = icmp eq i64 %t1, 2
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_str_lit(ptr @s259, i64 0, ptr @s259_lit)
  ret %KValue %t3
fail0:
  %t4 = extractvalue %KValue %x3, 0
  %t5 = icmp eq i64 %t4, 3
  br i1 %t5, label %L2, label %fail1
L2:
  %t6 = call %KValue @k_b_slice(%KValue %x0, %KValue %x1, %KValue %x1)
  %t7 = call %KValue @"d_query/text/padding?_1"(%KValue %t6)
  %t8 = extractvalue %KValue %x1, 1
  %t9 = extractvalue %KValue %x2, 1
  %t10 = musttail call tailcc %KValue @"d_query/text/step_in_4"(%KValue %x0, i64 %t8, i64 %t9, %KValue %t7)
  ret %KValue %t10
fail1:
  %t11 = call i64 @k_not_failure(%KValue %x0)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L4, label %L3
L3:
  %t13 = call %KValue @k_err_hop(%KValue %x0, ptr @s270)
  ret %KValue %t13
L4:
  %t14 = call i64 @k_not_failure(%KValue %x1)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %L5
L5:
  %t16 = call %KValue @k_err_hop(%KValue %x1, ptr @s270)
  ret %KValue %t16
L6:
  %t17 = call i64 @k_not_failure(%KValue %x2)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L8, label %L7
L7:
  %t19 = call %KValue @k_err_hop(%KValue %x2, ptr @s270)
  ret %KValue %t19
L8:
  %t20 = call i64 @k_not_failure(%KValue %x3)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L10, label %L9
L9:
  %t22 = call %KValue @k_err_hop(%KValue %x3, ptr @s270)
  ret %KValue %t22
L10:
  call void @k_die(ptr @s271)
  unreachable
}

define tailcc %KValue @"d_query/text/step_in_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x3, 0
  %t2 = icmp eq i64 %t1, 2
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1, 1
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t5 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t3, i64 %t4)
  %t6 = extractvalue { i64, i1 } %t5, 0
  %t7 = extractvalue { i64, i1 } %t5, 1
  br i1 %t7, label %L3, label %L2
L3:
  call void @k_die(ptr @s94)
  unreachable
L2:
  %t8 = insertvalue %KValue { i64 0, i64 undef }, i64 %t6, 1
  %t9 = extractvalue %KValue %t8, 1
  %t10 = extractvalue %KValue %x2, 1
  %t11 = musttail call tailcc %KValue @"d_query/text/from_front_3"(%KValue %x0, i64 %t9, i64 %t10)
  ret %KValue %t11
fail0:
  %t12 = extractvalue %KValue %x3, 0
  %t13 = icmp eq i64 %t12, 3
  br i1 %t13, label %L4, label %fail1
L4:
  %t14 = extractvalue %KValue %x1, 1
  %t15 = extractvalue %KValue %x2, 1
  %t16 = musttail call tailcc %KValue @"d_query/text/from_back_3"(%KValue %x0, i64 %t14, i64 %t15)
  ret %KValue %t16
fail1:
  %t17 = call i64 @k_not_failure(%KValue %x0)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L6, label %L5
L5:
  %t19 = call %KValue @k_err_hop(%KValue %x0, ptr @s272)
  ret %KValue %t19
L6:
  %t20 = call i64 @k_not_failure(%KValue %x1)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L8, label %L7
L7:
  %t22 = call %KValue @k_err_hop(%KValue %x1, ptr @s272)
  ret %KValue %t22
L8:
  %t23 = call i64 @k_not_failure(%KValue %x2)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L10, label %L9
L9:
  %t25 = call %KValue @k_err_hop(%KValue %x2, ptr @s272)
  ret %KValue %t25
L10:
  %t26 = call i64 @k_not_failure(%KValue %x3)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L12, label %L11
L11:
  %t28 = call %KValue @k_err_hop(%KValue %x3, ptr @s272)
  ret %KValue %t28
L12:
  call void @k_die(ptr @s273)
  unreachable
}

define tailcc %KValue @"d_query/text/from_back_3"(%KValue %x0, i64 %x1r, i64 %x2r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_b_slice(%KValue %x0, %KValue %x2, %KValue %x2)
  %t2 = call %KValue @"d_query/text/padding?_1"(%KValue %t1)
  %t3 = extractvalue %KValue %x1, 1
  %t4 = extractvalue %KValue %x2, 1
  %t5 = musttail call tailcc %KValue @"d_query/text/step_back_4"(%KValue %x0, i64 %t3, i64 %t4, %KValue %t2)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s274)
  ret %KValue %t8
L2:
  %t9 = call i64 @k_not_failure(%KValue %x1)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %L3
L3:
  %t11 = call %KValue @k_err_hop(%KValue %x1, ptr @s274)
  ret %KValue %t11
L4:
  %t12 = call i64 @k_not_failure(%KValue %x2)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L6, label %L5
L5:
  %t14 = call %KValue @k_err_hop(%KValue %x2, ptr @s274)
  ret %KValue %t14
L6:
  call void @k_die(ptr @s275)
  unreachable
}

define tailcc %KValue @"d_query/text/step_back_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x3, 0
  %t2 = icmp eq i64 %t1, 2
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x2, 1
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t5 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t3, i64 %t4)
  %t6 = extractvalue { i64, i1 } %t5, 0
  %t7 = extractvalue { i64, i1 } %t5, 1
  br i1 %t7, label %L3, label %L2
L3:
  call void @k_die(ptr @s94)
  unreachable
L2:
  %t8 = insertvalue %KValue { i64 0, i64 undef }, i64 %t6, 1
  %t9 = extractvalue %KValue %x1, 1
  %t10 = extractvalue %KValue %t8, 1
  %t11 = musttail call tailcc %KValue @"d_query/text/from_back_3"(%KValue %x0, i64 %t9, i64 %t10)
  ret %KValue %t11
fail0:
  %t12 = extractvalue %KValue %x3, 0
  %t13 = icmp eq i64 %t12, 3
  br i1 %t13, label %L4, label %fail1
L4:
  %t14 = call %KValue @k_b_slice(%KValue %x0, %KValue %x1, %KValue %x2)
  ret %KValue %t14
fail1:
  %t15 = call i64 @k_not_failure(%KValue %x0)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L6, label %L5
L5:
  %t17 = call %KValue @k_err_hop(%KValue %x0, ptr @s276)
  ret %KValue %t17
L6:
  %t18 = call i64 @k_not_failure(%KValue %x1)
  %t19 = icmp ne i64 %t18, 0
  br i1 %t19, label %L8, label %L7
L7:
  %t20 = call %KValue @k_err_hop(%KValue %x1, ptr @s276)
  ret %KValue %t20
L8:
  %t21 = call i64 @k_not_failure(%KValue %x2)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L10, label %L9
L9:
  %t23 = call %KValue @k_err_hop(%KValue %x2, ptr @s276)
  ret %KValue %t23
L10:
  %t24 = call i64 @k_not_failure(%KValue %x3)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L12, label %L11
L11:
  %t26 = call %KValue @k_err_hop(%KValue %x3, ptr @s276)
  ret %KValue %t26
L12:
  call void @k_die(ptr @s277)
  unreachable
}

define %KValue @"d_query/text/to_float_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_to_float(%KValue %x0, ptr @s279)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s278)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s280)
  unreachable
}

define %KValue @"d_query/text/to_int_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_to_int(%KValue %x0, ptr @s282)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L3, label %L2
L2:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s281)
  ret %KValue %t6
L3:
  call void @k_die(ptr @s283)
  unreachable
}

define %KValue @"d_query/text/utf8_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_utf8(%KValue %x0, ptr @s285)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L3, label %L2
L2:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s284)
  ret %KValue %t6
L3:
  call void @k_die(ptr @s286)
  unreachable
}

define tailcc %KValue @"d_query/first_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @"d_query/list/iter_1"(%KValue %x0)
  %t2 = call tailcc %KValue @"d_query/list/next_1"(%KValue %t1)
  %t3 = musttail call tailcc %KValue @"d_query/list/first_of_1"(%KValue %t2)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s287)
  ret %KValue %t6
L2:
  call void @k_die(ptr @s288)
  unreachable
}

define tailcc %KValue @"d_query/apply_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call tailcc %KValue @"d_query/decode_1"(%KValue %x0)
  %t2 = call tailcc %KValue @"d_query/parse_path_1"(%KValue %x1)
  %t3 = call tailcc %KValue @"d_query/walk_2"(%KValue %t1, %KValue %t2)
  %t4 = musttail call tailcc %KValue @"d_query/render_result_1"(%KValue %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s289)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s289)
  ret %KValue %t10
L4:
  call void @k_die(ptr @s290)
  unreachable
}

define %KValue @"d_query/elem_chunk_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_bytes(%KValue %x1)
  %t2 = call %KValue @k_str_lit(ptr @s292, i64 2, ptr @s292_lit)
  %t3 = call %KValue @k_b_append_mut(%KValue %t1, %KValue %t2)
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t5 = call tailcc %KValue @"d_query/pretty_onto_3"(%KValue %t3, %KValue %x0, i64 %t4)
  call void @k_beat_push()
  %t6 = call %KValue @"d_query/text/utf8_1"(%KValue %t5)
  %t7 = call %KValue @k_cohort_pop(%KValue %t6)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L1
L1:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s291)
  ret %KValue %t10
L2:
  %t11 = call i64 @k_not_failure(%KValue %x1)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L4, label %L3
L3:
  %t13 = call %KValue @k_err_hop(%KValue %x1, ptr @s291)
  ret %KValue %t13
L4:
  call void @k_die(ptr @s293)
  unreachable
}

define tailcc %KValue @"d_query/dispatch_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_length_fast(%KValue %x0)
  %t2 = extractvalue %KValue %t1, 1
  %t3 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t4 = icmp eq i64 %t2, %t3
  %t5 = select i1 %t4, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L1, label %L2
L2:
  ret %KValue %t5
L1:
  %t8 = call i64 @k_truthy(%KValue %t5)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L4
L3:
  %t10 = call %KValue @"d_query/usage_0"()
  ret %KValue %t10
L4:
  %t11 = musttail call tailcc %KValue @"d_query/with_query_1"(%KValue %x0)
  ret %KValue %t11
fail0:
  %t12 = call i64 @k_not_failure(%KValue %x0)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L6, label %L5
L5:
  %t14 = call %KValue @k_err_hop(%KValue %x0, ptr @s294)
  ret %KValue %t14
L6:
  call void @k_die(ptr @s295)
  unreachable
}

define tailcc %KValue @"d_query/render_result_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_check_tag(%KValue %x0, i64 9)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_length_fast(%KValue %x0)
  %t4 = extractvalue %KValue %t3, 0
  %t5 = extractvalue %KValue { i64 0, i64 0 }, 0
  %t6 = icmp eq i64 %t4, 0
  %t7 = icmp eq i64 %t5, 0
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L2, label %L3
L2:
  %t9 = extractvalue %KValue %t3, 1
  %t10 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t11 = icmp eq i64 %t9, %t10
  %t12 = select i1 %t11, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L4
L3:
  %t13 = call %KValue @k_cmp(%KValue %t3, %KValue { i64 0, i64 0 }, i64 0)
  br label %L4
L4:
  %t14 = phi %KValue [ %t12, %L2 ], [ %t13, %L3 ]
  %t15 = call i64 @k_not_failure(%KValue %t14)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L5, label %L6
L6:
  ret %KValue %t14
L5:
  %t17 = call i64 @k_truthy(%KValue %t14)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L7, label %L8
L7:
  %t19 = call %KValue @k_str_lit(ptr @s297, i64 2, ptr @s297_lit)
  %t20 = call %KValue @k_desc_print(%KValue %t19)
  ret %KValue %t20
L8:
  %t21 = musttail call tailcc %KValue @"d_query/stream_list_1"(%KValue %x0)
  ret %KValue %t21
fail0:
  %t22 = call i64 @k_check_tag(%KValue %x0, i64 5)
  %t23 = icmp ne i64 %t22, 0
  br i1 %t23, label %L9, label %fail1
L9:
  %t24 = call %KValue @k_err_inner(%KValue %x0)
  %t25 = call i64 @k_not_failure(%KValue %t24)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L10, label %fail1
L10:
  %t27 = call %KValue @k_err(%KValue %t24, ptr @s298)
  ret %KValue %t27
fail1:
  %t28 = call i64 @k_not_failure(%KValue %x0)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L11, label %fail2
L11:
  %t30 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t31 = call %KValue @"d_query/pretty_2"(%KValue %x0, i64 %t30)
  %t32 = call %KValue @k_desc_print(%KValue %t31)
  ret %KValue %t32
fail2:
  %t33 = call i64 @k_not_failure(%KValue %x0)
  %t34 = icmp ne i64 %t33, 0
  br i1 %t34, label %L13, label %L12
L12:
  %t35 = call %KValue @k_err_hop(%KValue %x0, ptr @s296)
  ret %KValue %t35
L13:
  call void @k_die(ptr @s299)
  unreachable
}

define %KValue @"d_query/sep_1"(i64 %x0r) {
entry:
  %x0 = insertvalue %KValue { i64 0, i64 undef }, i64 %x0r, 1
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 0
  %t3 = extractvalue %KValue %x0, 1
  %t4 = icmp eq i64 %t3, 1
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %fail0
L1:
  %t6 = call %KValue @k_str_lit(ptr @s259, i64 0, ptr @s259_lit)
  ret %KValue %t6
fail0:
  %t7 = call %KValue @k_str_lit(ptr @s301, i64 2, ptr @s301_lit)
  ret %KValue %t7
fail1:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L2
L2:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s300)
  ret %KValue %t10
L3:
  call void @k_die(ptr @s302)
  unreachable
}

define tailcc %KValue @"d_query/stream_elems_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = call %KValue @k_b_length_fast(%KValue %x0)
  %t2 = extractvalue %KValue %t1, 1
  %t3 = extractvalue %KValue %x1, 1
  %t4 = icmp slt i64 %t2, %t3
  %t5 = select i1 %t4, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L1, label %L2
L2:
  ret %KValue %t5
L1:
  %t8 = call i64 @k_truthy(%KValue %t5)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L4
L3:
  %t10 = call %KValue @k_str_lit(ptr @s304, i64 3, ptr @s304_lit)
  %t11 = call %KValue @k_b_write(%KValue %t10)
  ret %KValue %t11
L4:
  %t12 = extractvalue %KValue %x1, 1
  %t13 = musttail call tailcc %KValue @"d_query/stream_one_2"(%KValue %x0, i64 %t12)
  ret %KValue %t13
fail0:
  %t14 = call i64 @k_not_failure(%KValue %x0)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %L5
L5:
  %t16 = call %KValue @k_err_hop(%KValue %x0, ptr @s303)
  ret %KValue %t16
L6:
  %t17 = call i64 @k_not_failure(%KValue %x1)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L8, label %L7
L7:
  %t19 = call %KValue @k_err_hop(%KValue %x1, ptr @s303)
  ret %KValue %t19
L8:
  call void @k_die(ptr @s305)
  unreachable
}

define tailcc %KValue @klam18(ptr %env, %KValue %a0) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t3 = musttail call tailcc %KValue @"d_query/stream_elems_2"(%KValue %t1, i64 %t2)
  ret %KValue %t3
}

define %KValue @w_klam18(ptr %env, %KValue %a0) {
entry:
  %r = call tailcc %KValue @klam18(ptr %env, %KValue %a0)
  ret %KValue %r
}

define tailcc %KValue @"d_query/stream_list_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s307, i64 2, ptr @s307_lit)
  %t2 = call %KValue @k_b_write(%KValue %t1)
  %t3 = extractvalue %KValue %t2, 0
  %t4 = icmp eq i64 %t3, 8
  br i1 %t4, label %L1, label %L2
L1:
  %t6 = alloca [1 x %KValue]
  %t7 = getelementptr [1 x %KValue], ptr %t6, i64 0, i64 0
  store %KValue %x0, ptr %t7
  %t8 = call %KValue @k_closure(ptr @w_klam18, i64 1, i64 1, ptr %t6)
  %t5 = call %KValue @k_maybe_bind(%KValue %t2, %KValue %t8)
  ret %KValue %t5
L2:
  %t9 = call i64 @k_not_failure(%KValue %t2)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L4, label %L3
L3:
  ret %KValue %t2
L4:
  %t11 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t12 = musttail call tailcc %KValue @"d_query/stream_elems_2"(%KValue %x0, i64 %t11)
  ret %KValue %t12
fail0:
  %t13 = call i64 @k_not_failure(%KValue %x0)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L6, label %L5
L5:
  %t15 = call %KValue @k_err_hop(%KValue %x0, ptr @s306)
  ret %KValue %t15
L6:
  call void @k_die(ptr @s308)
  unreachable
}

define tailcc %KValue @klam19(ptr %env, %KValue %a0) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = call %KValue @k_env_get(ptr %env, i64 1)
  %t3 = extractvalue %KValue %t2, 0
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t5 = icmp eq i64 %t3, 0
  %t6 = icmp eq i64 %t4, 0
  %t7 = and i1 %t5, %t6
  br i1 %t7, label %L1, label %L2
L1:
  %t8 = extractvalue %KValue %t2, 1
  %t9 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t10 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t8, i64 %t9)
  %t11 = extractvalue { i64, i1 } %t10, 0
  %t12 = extractvalue { i64, i1 } %t10, 1
  br i1 %t12, label %L2, label %L4
L4:
  %t13 = insertvalue %KValue { i64 0, i64 undef }, i64 %t11, 1
  br label %L3
L2:
  %t14 = call %KValue @k_add(%KValue %t2, %KValue { i64 0, i64 1 })
  br label %L3
L3:
  %t15 = phi %KValue [ %t13, %L4 ], [ %t14, %L2 ]
  %t16 = extractvalue %KValue %t15, 1
  %t17 = musttail call tailcc %KValue @"d_query/stream_elems_2"(%KValue %t1, i64 %t16)
  ret %KValue %t17
}

define %KValue @w_klam19(ptr %env, %KValue %a0) {
entry:
  %r = call tailcc %KValue @klam19(ptr %env, %KValue %a0)
  ret %KValue %r
}

define tailcc %KValue @"d_query/stream_one_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 13
  %t3 = extractvalue %KValue %x1, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %x0, 1
  %t7 = inttoptr i64 %t6 to ptr
  %t8 = getelementptr %KBytes, ptr %t7, i64 0, i32 0
  %t9 = load i64, ptr %t8
  %t10 = extractvalue %KValue %x1, 1
  %t11 = icmp sge i64 %t10, 1
  %t12 = icmp sle i64 %t10, %t9
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L2
L4:
  %t14 = getelementptr %KBytes, ptr %t7, i64 0, i32 1
  %t15 = load ptr, ptr %t14
  %t16 = add i64 %t10, -1
  %t17 = getelementptr i8, ptr %t15, i64 %t16
  %t18 = load i8, ptr %t17
  %t19 = zext i8 %t18 to i64
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  br label %L3
L2:
  %t21 = call %KValue @k_b_at(%KValue %x0, %KValue %x1)
  br label %L3
L3:
  %t22 = phi %KValue [ %t20, %L4 ], [ %t21, %L2 ]
  %t23 = extractvalue %KValue %x1, 1
  %t24 = call %KValue @"d_query/sep_1"(i64 %t23)
  %t25 = call %KValue @"d_query/elem_chunk_2"(%KValue %t22, %KValue %t24)
  %t26 = call %KValue @k_b_write(%KValue %t25)
  %t27 = extractvalue %KValue %t26, 0
  %t28 = icmp eq i64 %t27, 8
  br i1 %t28, label %L5, label %L6
L5:
  %t30 = alloca [2 x %KValue]
  %t31 = getelementptr [2 x %KValue], ptr %t30, i64 0, i64 0
  store %KValue %x0, ptr %t31
  %t32 = getelementptr [2 x %KValue], ptr %t30, i64 0, i64 1
  store %KValue %x1, ptr %t32
  %t33 = call %KValue @k_closure(ptr @w_klam19, i64 1, i64 2, ptr %t30)
  %t29 = call %KValue @k_maybe_bind(%KValue %t26, %KValue %t33)
  ret %KValue %t29
L6:
  %t34 = call i64 @k_not_failure(%KValue %t26)
  %t35 = icmp ne i64 %t34, 0
  br i1 %t35, label %L8, label %L7
L7:
  ret %KValue %t26
L8:
  %t36 = extractvalue %KValue %x1, 1
  %t37 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t38 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t36, i64 %t37)
  %t39 = extractvalue { i64, i1 } %t38, 0
  %t40 = extractvalue { i64, i1 } %t38, 1
  br i1 %t40, label %L10, label %L9
L10:
  call void @k_die(ptr @s94)
  unreachable
L9:
  %t41 = insertvalue %KValue { i64 0, i64 undef }, i64 %t39, 1
  %t42 = extractvalue %KValue %t41, 1
  %t43 = musttail call tailcc %KValue @"d_query/stream_elems_2"(%KValue %x0, i64 %t42)
  ret %KValue %t43
fail0:
  %t44 = call i64 @k_not_failure(%KValue %x0)
  %t45 = icmp ne i64 %t44, 0
  br i1 %t45, label %L12, label %L11
L11:
  %t46 = call %KValue @k_err_hop(%KValue %x0, ptr @s309)
  ret %KValue %t46
L12:
  %t47 = call i64 @k_not_failure(%KValue %x1)
  %t48 = icmp ne i64 %t47, 0
  br i1 %t48, label %L14, label %L13
L13:
  %t49 = call %KValue @k_err_hop(%KValue %x1, ptr @s309)
  ret %KValue %t49
L14:
  call void @k_die(ptr @s310)
  unreachable
}

define %KValue @"d_query/usage_0"() {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s312, i64 63, ptr @s312_lit)
  %t2 = call %KValue @k_desc_print(%KValue %t1)
  ret %KValue %t2
fail0:
  call void @k_die(ptr @s313)
  unreachable
}

define tailcc %KValue @klam20(ptr %env, %KValue %a0) {
entry:
  %t1 = call %KValue @k_env_get(ptr %env, i64 0)
  %t2 = extractvalue %KValue %t1, 0
  %t3 = icmp eq i64 %t2, 13
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t5 = icmp eq i64 %t4, 0
  %t6 = and i1 %t3, %t5
  br i1 %t6, label %L1, label %L2
L1:
  %t7 = extractvalue %KValue %t1, 1
  %t8 = inttoptr i64 %t7 to ptr
  %t9 = getelementptr %KBytes, ptr %t8, i64 0, i32 0
  %t10 = load i64, ptr %t9
  %t11 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t12 = icmp sge i64 %t11, 1
  %t13 = icmp sle i64 %t11, %t10
  %t14 = and i1 %t12, %t13
  br i1 %t14, label %L4, label %L2
L4:
  %t15 = getelementptr %KBytes, ptr %t8, i64 0, i32 1
  %t16 = load ptr, ptr %t15
  %t17 = add i64 %t11, -1
  %t18 = getelementptr i8, ptr %t16, i64 %t17
  %t19 = load i8, ptr %t18
  %t20 = zext i8 %t19 to i64
  %t21 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  br label %L3
L2:
  %t22 = call %KValue @k_b_at(%KValue %t1, %KValue { i64 0, i64 1 })
  br label %L3
L3:
  %t23 = phi %KValue [ %t21, %L4 ], [ %t22, %L2 ]
  %t24 = musttail call tailcc %KValue @"d_query/apply_2"(%KValue %a0, %KValue %t23)
  ret %KValue %t24
}

define %KValue @w_klam20(ptr %env, %KValue %a0) {
entry:
  %r = call tailcc %KValue @klam20(ptr %env, %KValue %a0)
  ret %KValue %r
}

define tailcc %KValue @"d_query/with_query_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_length_fast(%KValue %x0)
  %t2 = extractvalue %KValue %t1, 1
  %t3 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t4 = icmp sgt i64 %t2, %t3
  %t5 = select i1 %t4, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L1, label %L2
L1:
  %t8 = call i64 @k_truthy(%KValue %t5)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L4
L3:
  %t10 = extractvalue %KValue %x0, 0
  %t11 = icmp eq i64 %t10, 13
  %t12 = extractvalue %KValue { i64 0, i64 2 }, 0
  %t13 = icmp eq i64 %t12, 0
  %t14 = and i1 %t11, %t13
  br i1 %t14, label %L5, label %L6
L5:
  %t15 = extractvalue %KValue %x0, 1
  %t16 = inttoptr i64 %t15 to ptr
  %t17 = getelementptr %KBytes, ptr %t16, i64 0, i32 0
  %t18 = load i64, ptr %t17
  %t19 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t20 = icmp sge i64 %t19, 1
  %t21 = icmp sle i64 %t19, %t18
  %t22 = and i1 %t20, %t21
  br i1 %t22, label %L8, label %L6
L8:
  %t23 = getelementptr %KBytes, ptr %t16, i64 0, i32 1
  %t24 = load ptr, ptr %t23
  %t25 = add i64 %t19, -1
  %t26 = getelementptr i8, ptr %t24, i64 %t25
  %t27 = load i8, ptr %t26
  %t28 = zext i8 %t27 to i64
  %t29 = insertvalue %KValue { i64 0, i64 undef }, i64 %t28, 1
  br label %L7
L6:
  %t30 = call %KValue @k_b_at(%KValue %x0, %KValue { i64 0, i64 2 })
  br label %L7
L7:
  %t31 = phi %KValue [ %t29, %L8 ], [ %t30, %L6 ]
  %t32 = call %KValue @k_b_read_file(%KValue %t31)
  br label %L2
L4:
  %t33 = call %KValue @"d_query/io/stdin_0"()
  br label %L2
L2:
  %t34 = phi %KValue [ %t5, %entry ], [ %t32, %L7 ], [ %t33, %L4 ]
  %t35 = alloca [1 x %KValue]
  %t36 = getelementptr [1 x %KValue], ptr %t35, i64 0, i64 0
  store %KValue %x0, ptr %t36
  %t37 = call %KValue @k_closure(ptr @w_klam20, i64 1, i64 1, ptr %t35)
  %t38 = call %KValue @k_maybe_bind(%KValue %t34, %KValue %t37)
  ret %KValue %t38
fail0:
  %t39 = call i64 @k_not_failure(%KValue %x0)
  %t40 = icmp ne i64 %t39, 0
  br i1 %t40, label %L10, label %L9
L9:
  %t41 = call %KValue @k_err_hop(%KValue %x0, ptr @s314)
  ret %KValue %t41
L10:
  call void @k_die(ptr @s315)
  unreachable
}

define tailcc %KValue @"d_query/decode_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_bytes(%KValue %x0)
  %t2 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t3 = call tailcc %parsed @"d_query/parse_value_2"(%KValue %t1, i64 %t2)
  %t4 = musttail call tailcc %KValue @"d_query/finish_2"(%KValue %t1, %parsed %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s316)
  ret %KValue %t7
L2:
  call void @k_die(ptr @s317)
  unreachable
}

define tailcc %KValue @"d_query/elem_onto_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 44 })
  %t2 = musttail call tailcc %KValue @"d_query/encode_onto_2"(%KValue %t1, %KValue %x1)
  ret %KValue %t2
fail0:
  %t3 = call i64 @k_not_failure(%KValue %x0)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %L1
L1:
  %t5 = call %KValue @k_err_hop(%KValue %x0, ptr @s318)
  ret %KValue %t5
L2:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L4, label %L3
L3:
  %t8 = call %KValue @k_err_hop(%KValue %x1, ptr @s318)
  ret %KValue %t8
L4:
  call void @k_die(ptr @s319)
  unreachable
}

define %KValue @"d_query/encode_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_str_lit(ptr @s259, i64 0, ptr @s259_lit)
  %t4 = call %KValue @k_b_bytes(%KValue %t3)
  %t5 = call tailcc %KValue @"d_query/encode_onto_2"(%KValue %t4, %KValue %x0)
  call void @k_beat_push()
  %t6 = call %KValue @"d_query/text/utf8_1"(%KValue %t5)
  %t7 = call %KValue @k_cohort_pop(%KValue %t6)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L2
L2:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s320)
  ret %KValue %t10
L3:
  call void @k_die(ptr @s321)
  unreachable
}

define tailcc %KValue @"d_query/encode_items_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_length_fast(%KValue %x1)
  %t4 = extractvalue %KValue %t3, 1
  %t5 = extractvalue %KValue %x2, 1
  %t6 = icmp slt i64 %t4, %t5
  %t7 = select i1 %t6, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t8 = call i64 @k_not_failure(%KValue %t7)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L3
L3:
  ret %KValue %t7
L2:
  %t10 = call i64 @k_truthy(%KValue %t7)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L5
L4:
  ret %KValue %x0
L5:
  %t12 = extractvalue %KValue %x1, 0
  %t13 = icmp eq i64 %t12, 13
  %t14 = extractvalue %KValue %x2, 0
  %t15 = icmp eq i64 %t14, 0
  %t16 = and i1 %t13, %t15
  br i1 %t16, label %L6, label %L7
L6:
  %t17 = extractvalue %KValue %x1, 1
  %t18 = inttoptr i64 %t17 to ptr
  %t19 = getelementptr %KBytes, ptr %t18, i64 0, i32 0
  %t20 = load i64, ptr %t19
  %t21 = extractvalue %KValue %x2, 1
  %t22 = icmp sge i64 %t21, 1
  %t23 = icmp sle i64 %t21, %t20
  %t24 = and i1 %t22, %t23
  br i1 %t24, label %L9, label %L7
L9:
  %t25 = getelementptr %KBytes, ptr %t18, i64 0, i32 1
  %t26 = load ptr, ptr %t25
  %t27 = add i64 %t21, -1
  %t28 = getelementptr i8, ptr %t26, i64 %t27
  %t29 = load i8, ptr %t28
  %t30 = zext i8 %t29 to i64
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t30, 1
  br label %L8
L7:
  %t32 = call %KValue @k_b_at(%KValue %x1, %KValue %x2)
  br label %L8
L8:
  %t33 = phi %KValue [ %t31, %L9 ], [ %t32, %L7 ]
  %t34 = call tailcc %KValue @"d_query/elem_onto_2"(%KValue %x0, %KValue %t33)
  %t35 = extractvalue %KValue %x2, 1
  %t36 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t37 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t35, i64 %t36)
  %t38 = extractvalue { i64, i1 } %t37, 0
  %t39 = extractvalue { i64, i1 } %t37, 1
  br i1 %t39, label %L11, label %L10
L11:
  call void @k_die(ptr @s94)
  unreachable
L10:
  %t40 = insertvalue %KValue { i64 0, i64 undef }, i64 %t38, 1
  call void @k_beat_iter()
  %t41 = extractvalue %KValue %t40, 1
  %t42 = musttail call tailcc %KValue @"d_query/encode_items_3"(%KValue %t34, %KValue %x1, i64 %t41)
  ret %KValue %t42
fail0:
  %t43 = call i64 @k_not_failure(%KValue %x0)
  %t44 = icmp ne i64 %t43, 0
  br i1 %t44, label %L13, label %L12
L12:
  %t45 = call %KValue @k_err_hop(%KValue %x0, ptr @s322)
  ret %KValue %t45
L13:
  %t46 = call i64 @k_not_failure(%KValue %x1)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L15, label %L14
L14:
  %t48 = call %KValue @k_err_hop(%KValue %x1, ptr @s322)
  ret %KValue %t48
L15:
  %t49 = call i64 @k_not_failure(%KValue %x2)
  %t50 = icmp ne i64 %t49, 0
  br i1 %t50, label %L17, label %L16
L16:
  %t51 = call %KValue @k_err_hop(%KValue %x2, ptr @s322)
  ret %KValue %t51
L17:
  call void @k_die(ptr @s323)
  unreachable
}

define tailcc %KValue @"d_query/encode_list_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 91 })
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 13
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t5 = icmp eq i64 %t4, 0
  %t6 = and i1 %t3, %t5
  br i1 %t6, label %L1, label %L2
L1:
  %t7 = extractvalue %KValue %x1, 1
  %t8 = inttoptr i64 %t7 to ptr
  %t9 = getelementptr %KBytes, ptr %t8, i64 0, i32 0
  %t10 = load i64, ptr %t9
  %t11 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t12 = icmp sge i64 %t11, 1
  %t13 = icmp sle i64 %t11, %t10
  %t14 = and i1 %t12, %t13
  br i1 %t14, label %L4, label %L2
L4:
  %t15 = getelementptr %KBytes, ptr %t8, i64 0, i32 1
  %t16 = load ptr, ptr %t15
  %t17 = add i64 %t11, -1
  %t18 = getelementptr i8, ptr %t16, i64 %t17
  %t19 = load i8, ptr %t18
  %t20 = zext i8 %t19 to i64
  %t21 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  br label %L3
L2:
  %t22 = call %KValue @k_b_at(%KValue %x1, %KValue { i64 0, i64 1 })
  br label %L3
L3:
  %t23 = phi %KValue [ %t21, %L4 ], [ %t22, %L2 ]
  %t24 = call tailcc %KValue @"d_query/encode_onto_2"(%KValue %t1, %KValue %t23)
  %t25 = extractvalue %KValue { i64 0, i64 2 }, 1
  call void @k_beat_push()
  %t26 = call tailcc %KValue @"d_query/encode_items_3"(%KValue %t24, %KValue %x1, i64 %t25)
  %t27 = call %KValue @k_beat_pop(%KValue %t26)
  %t28 = call %KValue @k_b_append_mut(%KValue %t27, %KValue { i64 0, i64 93 })
  ret %KValue %t28
fail0:
  %t29 = call i64 @k_not_failure(%KValue %x0)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L6, label %L5
L5:
  %t31 = call %KValue @k_err_hop(%KValue %x0, ptr @s324)
  ret %KValue %t31
L6:
  %t32 = call i64 @k_not_failure(%KValue %x1)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L8, label %L7
L7:
  %t34 = call %KValue @k_err_hop(%KValue %x1, ptr @s324)
  ret %KValue %t34
L8:
  call void @k_die(ptr @s325)
  unreachable
}

define tailcc %KValue @"d_query/encode_map_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 123 })
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 13
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t5 = icmp eq i64 %t4, 0
  %t6 = and i1 %t3, %t5
  br i1 %t6, label %L1, label %L2
L1:
  %t7 = extractvalue %KValue %x1, 1
  %t8 = inttoptr i64 %t7 to ptr
  %t9 = getelementptr %KBytes, ptr %t8, i64 0, i32 0
  %t10 = load i64, ptr %t9
  %t11 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t12 = icmp sge i64 %t11, 1
  %t13 = icmp sle i64 %t11, %t10
  %t14 = and i1 %t12, %t13
  br i1 %t14, label %L4, label %L2
L4:
  %t15 = getelementptr %KBytes, ptr %t8, i64 0, i32 1
  %t16 = load ptr, ptr %t15
  %t17 = add i64 %t11, -1
  %t18 = getelementptr i8, ptr %t16, i64 %t17
  %t19 = load i8, ptr %t18
  %t20 = zext i8 %t19 to i64
  %t21 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  br label %L3
L2:
  %t22 = call %KValue @k_b_at(%KValue %x1, %KValue { i64 0, i64 1 })
  br label %L3
L3:
  %t23 = phi %KValue [ %t21, %L4 ], [ %t22, %L2 ]
  %t24 = call tailcc %KValue @"d_query/entry_onto_2"(%KValue %t1, %KValue %t23)
  %t25 = extractvalue %KValue { i64 0, i64 2 }, 1
  call void @k_beat_push()
  %t26 = call tailcc %KValue @"d_query/encode_pairs_3"(%KValue %t24, %KValue %x1, i64 %t25)
  %t27 = call %KValue @k_beat_pop(%KValue %t26)
  %t28 = call %KValue @k_b_append_mut(%KValue %t27, %KValue { i64 0, i64 125 })
  ret %KValue %t28
fail0:
  %t29 = call i64 @k_not_failure(%KValue %x0)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L6, label %L5
L5:
  %t31 = call %KValue @k_err_hop(%KValue %x0, ptr @s326)
  ret %KValue %t31
L6:
  %t32 = call i64 @k_not_failure(%KValue %x1)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L8, label %L7
L7:
  %t34 = call %KValue @k_err_hop(%KValue %x1, ptr @s326)
  ret %KValue %t34
L8:
  call void @k_die(ptr @s327)
  unreachable
}

define tailcc %KValue @"d_query/encode_onto_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1, 0
  %t4 = icmp eq i64 %t3, 2
  br i1 %t4, label %L2, label %fail0
L2:
  %t5 = call %KValue @k_str_lit(ptr @s329, i64 4, ptr @s329_lit)
  %t6 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t5)
  ret %KValue %t6
fail0:
  %t7 = call i64 @k_not_failure(%KValue %x0)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail1
L3:
  %t9 = extractvalue %KValue %x1, 0
  %t10 = icmp eq i64 %t9, 3
  br i1 %t10, label %L4, label %fail1
L4:
  %t11 = call %KValue @k_str_lit(ptr @s330, i64 5, ptr @s330_lit)
  %t12 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t11)
  ret %KValue %t12
fail1:
  %t13 = call i64 @k_not_failure(%KValue %x0)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L5, label %fail2
L5:
  %t15 = call i64 @k_check_rec(%KValue %x1, i64 35, i64 0)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L6, label %fail2
L6:
  %t17 = call %KValue @k_str_lit(ptr @s331, i64 4, ptr @s331_lit)
  %t18 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t17)
  ret %KValue %t18
fail2:
  %t19 = call i64 @k_not_failure(%KValue %x0)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L7, label %fail3
L7:
  %t21 = call i64 @k_check_tag(%KValue %x1, i64 0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L8, label %fail3
L8:
  %t23 = call %KValue @"d_render/to_string_1"(%KValue %x1)
  %t24 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t23)
  ret %KValue %t24
fail3:
  %t25 = call i64 @k_not_failure(%KValue %x0)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L9, label %fail4
L9:
  %t27 = call i64 @k_check_tag(%KValue %x1, i64 1)
  %t28 = icmp ne i64 %t27, 0
  br i1 %t28, label %L10, label %fail4
L10:
  %t29 = call %KValue @"d_render/to_string_1"(%KValue %x1)
  %t30 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t29)
  ret %KValue %t30
fail4:
  %t31 = call i64 @k_not_failure(%KValue %x0)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L11, label %fail5
L11:
  %t33 = call i64 @k_check_tag(%KValue %x1, i64 6)
  %t34 = icmp ne i64 %t33, 0
  br i1 %t34, label %L12, label %fail5
L12:
  %t35 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 34 })
  %t36 = call tailcc %KValue @"d_query/escape_onto_2"(%KValue %t35, %KValue %x1)
  %t37 = call %KValue @k_b_append_mut(%KValue %t36, %KValue { i64 0, i64 34 })
  ret %KValue %t37
fail5:
  %t38 = call i64 @k_not_failure(%KValue %x0)
  %t39 = icmp ne i64 %t38, 0
  br i1 %t39, label %L13, label %fail6
L13:
  %t40 = call i64 @k_check_tag(%KValue %x1, i64 9)
  %t41 = icmp ne i64 %t40, 0
  br i1 %t41, label %L14, label %fail6
L14:
  %t42 = call %KValue @k_b_length_fast(%KValue %x1)
  %t43 = extractvalue %KValue %t42, 0
  %t44 = extractvalue %KValue { i64 0, i64 0 }, 0
  %t45 = icmp eq i64 %t43, 0
  %t46 = icmp eq i64 %t44, 0
  %t47 = and i1 %t45, %t46
  br i1 %t47, label %L15, label %L16
L15:
  %t48 = extractvalue %KValue %t42, 1
  %t49 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t50 = icmp eq i64 %t48, %t49
  %t51 = select i1 %t50, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L17
L16:
  %t52 = call %KValue @k_cmp(%KValue %t42, %KValue { i64 0, i64 0 }, i64 0)
  br label %L17
L17:
  %t53 = phi %KValue [ %t51, %L15 ], [ %t52, %L16 ]
  %t54 = call i64 @k_not_failure(%KValue %t53)
  %t55 = icmp ne i64 %t54, 0
  br i1 %t55, label %L18, label %L19
L19:
  ret %KValue %t53
L18:
  %t56 = call i64 @k_truthy(%KValue %t53)
  %t57 = icmp ne i64 %t56, 0
  br i1 %t57, label %L20, label %L21
L20:
  %t58 = call %KValue @k_str_lit(ptr @s297, i64 2, ptr @s297_lit)
  %t59 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t58)
  ret %KValue %t59
L21:
  %t60 = musttail call tailcc %KValue @"d_query/encode_list_2"(%KValue %x0, %KValue %x1)
  ret %KValue %t60
fail6:
  %t61 = call i64 @k_not_failure(%KValue %x0)
  %t62 = icmp ne i64 %t61, 0
  br i1 %t62, label %L22, label %fail7
L22:
  %t63 = call i64 @k_check_tag(%KValue %x1, i64 10)
  %t64 = icmp ne i64 %t63, 0
  br i1 %t64, label %L23, label %fail7
L23:
  %t65 = call %KValue @k_b_entries(%KValue %x1)
  %t66 = call %KValue @k_b_length_fast(%KValue %t65)
  %t67 = extractvalue %KValue %t66, 0
  %t68 = extractvalue %KValue { i64 0, i64 0 }, 0
  %t69 = icmp eq i64 %t67, 0
  %t70 = icmp eq i64 %t68, 0
  %t71 = and i1 %t69, %t70
  br i1 %t71, label %L24, label %L25
L24:
  %t72 = extractvalue %KValue %t66, 1
  %t73 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t74 = icmp eq i64 %t72, %t73
  %t75 = select i1 %t74, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L26
L25:
  %t76 = call %KValue @k_cmp(%KValue %t66, %KValue { i64 0, i64 0 }, i64 0)
  br label %L26
L26:
  %t77 = phi %KValue [ %t75, %L24 ], [ %t76, %L25 ]
  %t78 = call i64 @k_not_failure(%KValue %t77)
  %t79 = icmp ne i64 %t78, 0
  br i1 %t79, label %L27, label %L28
L28:
  ret %KValue %t77
L27:
  %t80 = call i64 @k_truthy(%KValue %t77)
  %t81 = icmp ne i64 %t80, 0
  br i1 %t81, label %L29, label %L30
L29:
  %t82 = call %KValue @k_str_lit(ptr @s332, i64 2, ptr @s332_lit)
  %t83 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t82)
  ret %KValue %t83
L30:
  %t84 = musttail call tailcc %KValue @"d_query/encode_map_2"(%KValue %x0, %KValue %t65)
  ret %KValue %t84
fail7:
  %t85 = call i64 @k_not_failure(%KValue %x0)
  %t86 = icmp ne i64 %t85, 0
  br i1 %t86, label %L32, label %L31
L31:
  %t87 = call %KValue @k_err_hop(%KValue %x0, ptr @s328)
  ret %KValue %t87
L32:
  %t88 = call i64 @k_not_failure(%KValue %x1)
  %t89 = icmp ne i64 %t88, 0
  br i1 %t89, label %L34, label %L33
L33:
  %t90 = call %KValue @k_err_hop(%KValue %x1, ptr @s328)
  ret %KValue %t90
L34:
  call void @k_die(ptr @s333)
  unreachable
}

define tailcc %KValue @"d_query/encode_pairs_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_length_fast(%KValue %x1)
  %t4 = extractvalue %KValue %t3, 1
  %t5 = extractvalue %KValue %x2, 1
  %t6 = icmp slt i64 %t4, %t5
  %t7 = select i1 %t6, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t8 = call i64 @k_not_failure(%KValue %t7)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L3
L3:
  ret %KValue %t7
L2:
  %t10 = call i64 @k_truthy(%KValue %t7)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L5
L4:
  ret %KValue %x0
L5:
  %t12 = extractvalue %KValue %x1, 0
  %t13 = icmp eq i64 %t12, 13
  %t14 = extractvalue %KValue %x2, 0
  %t15 = icmp eq i64 %t14, 0
  %t16 = and i1 %t13, %t15
  br i1 %t16, label %L6, label %L7
L6:
  %t17 = extractvalue %KValue %x1, 1
  %t18 = inttoptr i64 %t17 to ptr
  %t19 = getelementptr %KBytes, ptr %t18, i64 0, i32 0
  %t20 = load i64, ptr %t19
  %t21 = extractvalue %KValue %x2, 1
  %t22 = icmp sge i64 %t21, 1
  %t23 = icmp sle i64 %t21, %t20
  %t24 = and i1 %t22, %t23
  br i1 %t24, label %L9, label %L7
L9:
  %t25 = getelementptr %KBytes, ptr %t18, i64 0, i32 1
  %t26 = load ptr, ptr %t25
  %t27 = add i64 %t21, -1
  %t28 = getelementptr i8, ptr %t26, i64 %t27
  %t29 = load i8, ptr %t28
  %t30 = zext i8 %t29 to i64
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t30, 1
  br label %L8
L7:
  %t32 = call %KValue @k_b_at(%KValue %x1, %KValue %x2)
  br label %L8
L8:
  %t33 = phi %KValue [ %t31, %L9 ], [ %t32, %L7 ]
  %t34 = call tailcc %KValue @"d_query/pair_onto_2"(%KValue %x0, %KValue %t33)
  %t35 = extractvalue %KValue %x2, 1
  %t36 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t37 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t35, i64 %t36)
  %t38 = extractvalue { i64, i1 } %t37, 0
  %t39 = extractvalue { i64, i1 } %t37, 1
  br i1 %t39, label %L11, label %L10
L11:
  call void @k_die(ptr @s94)
  unreachable
L10:
  %t40 = insertvalue %KValue { i64 0, i64 undef }, i64 %t38, 1
  call void @k_beat_iter()
  %t41 = extractvalue %KValue %t40, 1
  %t42 = musttail call tailcc %KValue @"d_query/encode_pairs_3"(%KValue %t34, %KValue %x1, i64 %t41)
  ret %KValue %t42
fail0:
  %t43 = call i64 @k_not_failure(%KValue %x0)
  %t44 = icmp ne i64 %t43, 0
  br i1 %t44, label %L13, label %L12
L12:
  %t45 = call %KValue @k_err_hop(%KValue %x0, ptr @s334)
  ret %KValue %t45
L13:
  %t46 = call i64 @k_not_failure(%KValue %x1)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L15, label %L14
L14:
  %t48 = call %KValue @k_err_hop(%KValue %x1, ptr @s334)
  ret %KValue %t48
L15:
  %t49 = call i64 @k_not_failure(%KValue %x2)
  %t50 = icmp ne i64 %t49, 0
  br i1 %t50, label %L17, label %L16
L16:
  %t51 = call %KValue @k_err_hop(%KValue %x2, ptr @s334)
  ret %KValue %t51
L17:
  call void @k_die(ptr @s335)
  unreachable
}

define tailcc %KValue @"d_query/entry_onto_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_check_rec(%KValue %x1, i64 0, i64 2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x1, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %x1, i64 1)
  %t7 = call i64 @k_not_failure(%KValue %t6)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = call tailcc %KValue @"d_query/encode_onto_2"(%KValue %x0, %KValue %t3)
  %t10 = call %KValue @k_b_append_mut(%KValue %t9, %KValue { i64 0, i64 58 })
  %t11 = musttail call tailcc %KValue @"d_query/encode_onto_2"(%KValue %t10, %KValue %t6)
  ret %KValue %t11
fail0:
  %t12 = call i64 @k_not_failure(%KValue %x0)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L5, label %L4
L4:
  %t14 = call %KValue @k_err_hop(%KValue %x0, ptr @s336)
  ret %KValue %t14
L5:
  %t15 = call i64 @k_not_failure(%KValue %x1)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L7, label %L6
L6:
  %t17 = call %KValue @k_err_hop(%KValue %x1, ptr @s336)
  ret %KValue %t17
L7:
  call void @k_die(ptr @s337)
  unreachable
}

define %KValue @"d_query/failure_position_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_check_tag(%KValue %x0, i64 5)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_err_inner(%KValue %x0)
  %t4 = call i64 @k_check_rec(%KValue %t3, i64 36, i64 2)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %t3, i64 0)
  %t7 = call i64 @k_not_failure(%KValue %t6)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = call %KValue @k_field(%KValue %t3, i64 1)
  %t10 = call i64 @k_not_failure(%KValue %t9)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %fail0
L4:
  ret %KValue %t6
fail0:
  ret %KValue { i64 0, i64 0 }
fail1:
  %t12 = call i64 @k_not_failure(%KValue %x0)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L6, label %L5
L5:
  %t14 = call %KValue @k_err_hop(%KValue %x0, ptr @s338)
  ret %KValue %t14
L6:
  call void @k_die(ptr @s339)
  unreachable
}

define %KValue @"d_query/failure_reason_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_check_tag(%KValue %x0, i64 5)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_err_inner(%KValue %x0)
  %t4 = call i64 @k_check_rec(%KValue %t3, i64 36, i64 2)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %t3, i64 0)
  %t7 = call i64 @k_not_failure(%KValue %t6)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = call %KValue @k_field(%KValue %t3, i64 1)
  %t10 = call i64 @k_not_failure(%KValue %t9)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %fail0
L4:
  ret %KValue %t9
fail0:
  %t12 = call %KValue @k_str_lit(ptr @s259, i64 0, ptr @s259_lit)
  ret %KValue %t12
fail1:
  %t13 = call i64 @k_not_failure(%KValue %x0)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L6, label %L5
L5:
  %t15 = call %KValue @k_err_hop(%KValue %x0, ptr @s340)
  ret %KValue %t15
L6:
  call void @k_die(ptr @s341)
  unreachable
}

define tailcc %KValue @"d_query/finish_2"(%KValue %x0, %parsed %x1) {
entry:
  %x1w0 = extractvalue %parsed %x1, 0
  %x1w1 = extractvalue %parsed %x1, 1
  %x1sa = insertvalue %KValue undef, i64 %x1w0, 0
  %x1s = insertvalue %KValue %x1sa, i64 %x1w1, 1
  %t1 = extractvalue %KValue %x1s, 0
  %t2 = icmp eq i64 %t1, 4
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_str_lit(ptr @s343, i64 23, ptr @s343_lit)
  %t4 = alloca [2 x %KValue]
  %t5 = getelementptr [2 x %KValue], ptr %t4, i64 0, i64 0
  store %KValue { i64 0, i64 0 }, ptr %t5
  %t6 = getelementptr [2 x %KValue], ptr %t4, i64 0, i64 1
  store %KValue %t3, ptr %t6
  %t7 = call %KValue @k_rec(i64 36, i64 2, ptr %t4)
  %t8 = call %KValue @k_err(%KValue %t7, ptr @s344)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_not_failure(%KValue %x1s)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L2, label %fail1
L2:
  %t11 = extractvalue %KValue %x1s, 0
  %t12 = extractvalue %KValue %x1s, 1
  %t13 = lshr i64 %t11, 8
  %t14 = insertvalue %KValue undef, i64 0, 0
  %t15 = insertvalue %KValue %t14, i64 %t13, 1
  %t16 = call i64 @k_not_failure(%KValue %t15)
  %t17 = icmp ne i64 %t16, 0
  br i1 %t17, label %L3, label %fail1
L3:
  %t18 = and i64 %t11, 255
  %t19 = insertvalue %KValue undef, i64 %t18, 0
  %t20 = insertvalue %KValue %t19, i64 %t12, 1
  %t21 = call i64 @k_not_failure(%KValue %t20)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L4, label %fail1
L4:
  %t23 = extractvalue %KValue %t15, 1
  %t24 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t23)
  %t25 = call %KValue @k_b_length_fast(%KValue %x0)
  %t26 = extractvalue %KValue %t24, 1
  %t27 = extractvalue %KValue %t25, 1
  %t28 = icmp sgt i64 %t26, %t27
  %t29 = select i1 %t28, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t30 = call i64 @k_not_failure(%KValue %t29)
  %t31 = icmp ne i64 %t30, 0
  br i1 %t31, label %L5, label %L6
L6:
  ret %KValue %t29
L5:
  %t32 = call i64 @k_truthy(%KValue %t29)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L7, label %L8
L7:
  ret %KValue %t20
L8:
  %t34 = call %KValue @k_str_lit(ptr @s345, i64 30, ptr @s345_lit)
  %t35 = extractvalue %KValue %t24, 1
  %t36 = musttail call tailcc %KValue @"d_query/fail_2"(i64 %t35, %KValue %t34)
  ret %KValue %t36
fail1:
  %t37 = call i64 @k_not_failure(%KValue %x0)
  %t38 = icmp ne i64 %t37, 0
  br i1 %t38, label %L10, label %L9
L9:
  %t39 = call %KValue @k_err_hop(%KValue %x0, ptr @s342)
  ret %KValue %t39
L10:
  %t40 = call i64 @k_not_failure(%KValue %x1s)
  %t41 = icmp ne i64 %t40, 0
  br i1 %t41, label %L12, label %L11
L11:
  %t42 = call %KValue @k_err_hop(%KValue %x1s, ptr @s342)
  ret %KValue %t42
L12:
  call void @k_die(ptr @s346)
  unreachable
}

define %KValue @"d_query/must_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_check_tag(%KValue %x0, i64 5)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_err_inner(%KValue %x0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @"d_render/to_string_1"(%KValue %t3)
  %t7 = alloca [1 x %KValue]
  %t8 = getelementptr [1 x %KValue], ptr %t7, i64 0, i64 0
  store %KValue %t6, ptr %t8
  %t9 = call %KValue @k_rec(i64 34, i64 1, ptr %t7)
  %t10 = call %KValue @k_err(%KValue %t9, ptr @s348)
  ret %KValue %t10
fail0:
  %t11 = call i64 @k_not_failure(%KValue %x0)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L3, label %fail1
L3:
  ret %KValue %x0
fail1:
  %t13 = call i64 @k_not_failure(%KValue %x0)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L5, label %L4
L4:
  %t15 = call %KValue @k_err_hop(%KValue %x0, ptr @s347)
  ret %KValue %t15
L5:
  call void @k_die(ptr @s349)
  unreachable
}

define tailcc %KValue @"d_query/pair_onto_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 44 })
  %t2 = musttail call tailcc %KValue @"d_query/entry_onto_2"(%KValue %t1, %KValue %x1)
  ret %KValue %t2
fail0:
  %t3 = call i64 @k_not_failure(%KValue %x0)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %L1
L1:
  %t5 = call %KValue @k_err_hop(%KValue %x0, ptr @s350)
  ret %KValue %t5
L2:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L4, label %L3
L3:
  %t8 = call %KValue @k_err_hop(%KValue %x1, ptr @s350)
  ret %KValue %t8
L4:
  call void @k_die(ptr @s351)
  unreachable
}

define %KValue @"d_query/test_path_trail_0"() {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s353, i64 14, ptr @s353_lit)
  %t2 = call tailcc %KValue @"d_query/parse_path_1"(%KValue %t1)
  %t3 = call %KValue @"d_query/encode_1"(%KValue %t2)
  %t4 = call %KValue @k_str_lit(ptr @s354, i64 18, ptr @s354_lit)
  %t5 = extractvalue %KValue %t3, 0
  %t6 = extractvalue %KValue %t4, 0
  %t7 = icmp eq i64 %t5, 0
  %t8 = icmp eq i64 %t6, 0
  %t9 = and i1 %t7, %t8
  br i1 %t9, label %L1, label %L2
L1:
  %t10 = extractvalue %KValue %t3, 1
  %t11 = extractvalue %KValue %t4, 1
  %t12 = icmp eq i64 %t10, %t11
  %t13 = select i1 %t12, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t14 = call %KValue @k_cmp(%KValue %t3, %KValue %t4, i64 0)
  br label %L3
L3:
  %t15 = phi %KValue [ %t13, %L1 ], [ %t14, %L2 ]
  ret %KValue %t15
fail0:
  call void @k_die(ptr @s355)
  unreachable
}

define %KValue @"d_query/test_pretty_list_0"() {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s357, i64 5, ptr @s357_lit)
  %t2 = call tailcc %KValue @"d_query/decode_1"(%KValue %t1)
  %t3 = call %KValue @"d_query/must_1"(%KValue %t2)
  %t4 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t5 = call %KValue @"d_query/pretty_2"(%KValue %t3, i64 %t4)
  %t6 = call %KValue @k_str_lit(ptr @s358, i64 12, ptr @s358_lit)
  %t7 = extractvalue %KValue %t5, 0
  %t8 = extractvalue %KValue %t6, 0
  %t9 = icmp eq i64 %t7, 0
  %t10 = icmp eq i64 %t8, 0
  %t11 = and i1 %t9, %t10
  br i1 %t11, label %L1, label %L2
L1:
  %t12 = extractvalue %KValue %t5, 1
  %t13 = extractvalue %KValue %t6, 1
  %t14 = icmp eq i64 %t12, %t13
  %t15 = select i1 %t14, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t16 = call %KValue @k_cmp(%KValue %t5, %KValue %t6, i64 0)
  br label %L3
L3:
  %t17 = phi %KValue [ %t15, %L1 ], [ %t16, %L2 ]
  ret %KValue %t17
fail0:
  call void @k_die(ptr @s359)
  unreachable
}

define %KValue @"d_query/test_pretty_map_0"() {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s361, i64 13, ptr @s361_lit)
  %t2 = call tailcc %KValue @"d_query/decode_1"(%KValue %t1)
  %t3 = call %KValue @"d_query/must_1"(%KValue %t2)
  %t4 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t5 = call %KValue @"d_query/pretty_2"(%KValue %t3, i64 %t4)
  %t6 = call %KValue @k_str_lit(ptr @s362, i64 22, ptr @s362_lit)
  %t7 = extractvalue %KValue %t5, 0
  %t8 = extractvalue %KValue %t6, 0
  %t9 = icmp eq i64 %t7, 0
  %t10 = icmp eq i64 %t8, 0
  %t11 = and i1 %t9, %t10
  br i1 %t11, label %L1, label %L2
L1:
  %t12 = extractvalue %KValue %t5, 1
  %t13 = extractvalue %KValue %t6, 1
  %t14 = icmp eq i64 %t12, %t13
  %t15 = select i1 %t14, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t16 = call %KValue @k_cmp(%KValue %t5, %KValue %t6, i64 0)
  br label %L3
L3:
  %t17 = phi %KValue [ %t15, %L1 ], [ %t16, %L2 ]
  ret %KValue %t17
fail0:
  call void @k_die(ptr @s363)
  unreachable
}

define %KValue @"d_query/test_pretty_scalar_0"() {
entry:
  %t1 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t2 = call %KValue @"d_query/pretty_2"(%KValue { i64 0, i64 42 }, i64 %t1)
  %t3 = call %KValue @k_str_lit(ptr @s365, i64 2, ptr @s365_lit)
  %t4 = extractvalue %KValue %t2, 0
  %t5 = extractvalue %KValue %t3, 0
  %t6 = icmp eq i64 %t4, 0
  %t7 = icmp eq i64 %t5, 0
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = extractvalue %KValue %t2, 1
  %t10 = extractvalue %KValue %t3, 1
  %t11 = icmp eq i64 %t9, %t10
  %t12 = select i1 %t11, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t13 = call %KValue @k_cmp(%KValue %t2, %KValue %t3, i64 0)
  br label %L3
L3:
  %t14 = phi %KValue [ %t12, %L1 ], [ %t13, %L2 ]
  ret %KValue %t14
fail0:
  call void @k_die(ptr @s366)
  unreachable
}

define %KValue @"d_query/test_walk_0"() {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s368, i64 15, ptr @s368_lit)
  %t2 = call tailcc %KValue @"d_query/decode_1"(%KValue %t1)
  %t3 = call %KValue @"d_query/must_1"(%KValue %t2)
  %t4 = call %KValue @k_str_lit(ptr @s369, i64 7, ptr @s369_lit)
  %t5 = call tailcc %KValue @"d_query/parse_path_1"(%KValue %t4)
  %t6 = call tailcc %KValue @"d_query/walk_2"(%KValue %t3, %KValue %t5)
  %t7 = extractvalue %KValue %t6, 0
  %t8 = extractvalue %KValue { i64 0, i64 7 }, 0
  %t9 = icmp eq i64 %t7, 0
  %t10 = icmp eq i64 %t8, 0
  %t11 = and i1 %t9, %t10
  br i1 %t11, label %L1, label %L2
L1:
  %t12 = extractvalue %KValue %t6, 1
  %t13 = extractvalue %KValue { i64 0, i64 7 }, 1
  %t14 = icmp eq i64 %t12, %t13
  %t15 = select i1 %t14, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t16 = call %KValue @k_cmp(%KValue %t6, %KValue { i64 0, i64 7 }, i64 0)
  br label %L3
L3:
  %t17 = phi %KValue [ %t15, %L1 ], [ %t16, %L2 ]
  ret %KValue %t17
fail0:
  call void @k_die(ptr @s370)
  unreachable
}

define tailcc %KValue @"d_query/mark_from?_3"(%KValue %x0, i64 %x1r, i64 %x2r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = extractvalue %KValue %x2, 1
  %t3 = icmp sgt i64 %t1, %t2
  %t4 = select i1 %t3, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t5 = call i64 @k_not_failure(%KValue %t4)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L1, label %L2
L2:
  ret %KValue %t4
L1:
  %t7 = call i64 @k_truthy(%KValue %t4)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %L4
L3:
  ret %KValue { i64 3, i64 0 }
L4:
  %t9 = extractvalue %KValue %x0, 1
  %t10 = inttoptr i64 %t9 to ptr
  %t11 = getelementptr %KBytes, ptr %t10, i64 0, i32 0
  %t12 = load i64, ptr %t11
  %t13 = extractvalue %KValue %x1, 1
  %t14 = icmp sge i64 %t13, 1
  %t15 = icmp sle i64 %t13, %t12
  %t16 = and i1 %t14, %t15
  br i1 %t16, label %L5, label %L6
L5:
  %t17 = getelementptr %KBytes, ptr %t10, i64 0, i32 1
  %t18 = load ptr, ptr %t17
  %t19 = add i64 %t13, -1
  %t20 = getelementptr i8, ptr %t18, i64 %t19
  %t21 = load i8, ptr %t20
  %t22 = zext i8 %t21 to i64
  %t23 = insertvalue %KValue { i64 0, i64 undef }, i64 %t22, 1
  br label %L7
L6:
  br label %L7
L7:
  %t24 = phi %KValue [ %t23, %L5 ], [ { i64 4, i64 0 }, %L6 ]
  %t25 = extractvalue %KValue %t24, 0
  %t26 = extractvalue %KValue %t24, 1
  %t27 = icmp eq i64 %t25, 4
  %t28 = select i1 %t27, i64 256, i64 %t26
  %t29 = extractvalue %KValue %x1, 1
  %t30 = extractvalue %KValue %x2, 1
  %t31 = musttail call tailcc %KValue @"d_query/mark_step?_4"(%KValue %x0, i64 %t28, i64 %t29, i64 %t30)
  ret %KValue %t31
fail0:
  %t32 = call i64 @k_not_failure(%KValue %x0)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L9, label %L8
L8:
  %t34 = call %KValue @k_err_hop(%KValue %x0, ptr @s371)
  ret %KValue %t34
L9:
  %t35 = call i64 @k_not_failure(%KValue %x1)
  %t36 = icmp ne i64 %t35, 0
  br i1 %t36, label %L11, label %L10
L10:
  %t37 = call %KValue @k_err_hop(%KValue %x1, ptr @s371)
  ret %KValue %t37
L11:
  %t38 = call i64 @k_not_failure(%KValue %x2)
  %t39 = icmp ne i64 %t38, 0
  br i1 %t39, label %L13, label %L12
L12:
  %t40 = call %KValue @k_err_hop(%KValue %x2, ptr @s371)
  ret %KValue %t40
L13:
  call void @k_die(ptr @s372)
  unreachable
}

define tailcc %KValue @"d_query/mark_step?_4"(%KValue %x0, i64 %x1r, i64 %x2r, i64 %x3r) {
entry:
  %t1 = icmp eq i64 %x1r, 256
  %x1b = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x1 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x1b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x1, 1
  switch i64 %t4, label %arm3 [
    i64 46, label %arm0
    i64 69, label %arm1
    i64 101, label %arm2
  ]
L3:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %arm3, label %nomatch
nomatch:
  %t7 = extractvalue %KValue %x1, 0
  %t8 = icmp eq i64 %t7, 5
  %t9 = icmp eq i64 %t7, 4
  %t10 = or i1 %t8, %t9
  br i1 %t10, label %L4, label %L5
L4:
  %t11 = call %KValue @k_err_hop(%KValue %x1, ptr @s373)
  ret %KValue %t11
L5:
  call void @k_die(ptr @s374)
  unreachable
arm0:
  ret %KValue { i64 2, i64 0 }
arm1:
  ret %KValue { i64 2, i64 0 }
arm2:
  ret %KValue { i64 2, i64 0 }
arm3:
  %t12 = extractvalue %KValue %x2, 1
  %t13 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t14 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t12, i64 %t13)
  %t15 = extractvalue { i64, i1 } %t14, 0
  %t16 = extractvalue { i64, i1 } %t14, 1
  br i1 %t16, label %L7, label %L6
L7:
  call void @k_die(ptr @s94)
  unreachable
L6:
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t15, 1
  %t18 = extractvalue %KValue %t17, 1
  %t19 = extractvalue %KValue %x3, 1
  %t20 = musttail call tailcc %KValue @"d_query/mark_from?_3"(%KValue %x0, i64 %t18, i64 %t19)
  ret %KValue %t20
}

define %KValue @"d_query/number_char?_1"(i64 %x0r) {
entry:
  %t1 = icmp eq i64 %x0r, 256
  %x0b = insertvalue %KValue { i64 0, i64 undef }, i64 %x0r, 1
  %x0 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x0b
  br label %L1
L1:
  %t2 = extractvalue %KValue %x0, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x0, 1
  switch i64 %t4, label %arm6 [
    i64 43, label %arm0
    i64 45, label %arm1
    i64 46, label %arm2
    i64 69, label %arm3
    i64 101, label %arm4
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm5, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm6, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x0, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x0, ptr @s375)
  ret %KValue %t12
L6:
  call void @k_die(ptr @s376)
  unreachable
arm0:
  ret %KValue { i64 2, i64 0 }
arm1:
  ret %KValue { i64 2, i64 0 }
arm2:
  ret %KValue { i64 2, i64 0 }
arm3:
  ret %KValue { i64 2, i64 0 }
arm4:
  ret %KValue { i64 2, i64 0 }
arm5:
  ret %KValue { i64 3, i64 0 }
arm6:
  %t13 = extractvalue %KValue { i64 0, i64 47 }, 0
  %t14 = extractvalue %KValue %x0, 0
  %t15 = icmp eq i64 %t13, 0
  %t16 = icmp eq i64 %t14, 0
  %t17 = and i1 %t15, %t16
  br i1 %t17, label %L7, label %L8
L7:
  %t18 = extractvalue %KValue { i64 0, i64 47 }, 1
  %t19 = extractvalue %KValue %x0, 1
  %t20 = icmp slt i64 %t18, %t19
  %t21 = select i1 %t20, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L9
L8:
  %t22 = call %KValue @k_cmp(%KValue { i64 0, i64 47 }, %KValue %x0, i64 2)
  br label %L9
L9:
  %t23 = phi %KValue [ %t21, %L7 ], [ %t22, %L8 ]
  %t24 = call i64 @k_not_failure(%KValue %t23)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L10, label %L11
L11:
  ret %KValue %t23
L10:
  %t26 = call i64 @k_truthy(%KValue %t23)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L12, label %L13
L12:
  %t28 = extractvalue %KValue %x0, 0
  %t29 = extractvalue %KValue { i64 0, i64 58 }, 0
  %t30 = icmp eq i64 %t28, 0
  %t31 = icmp eq i64 %t29, 0
  %t32 = and i1 %t30, %t31
  br i1 %t32, label %L14, label %L15
L14:
  %t33 = extractvalue %KValue %x0, 1
  %t34 = extractvalue %KValue { i64 0, i64 58 }, 1
  %t35 = icmp slt i64 %t33, %t34
  %t36 = select i1 %t35, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L16
L15:
  %t37 = call %KValue @k_cmp(%KValue %x0, %KValue { i64 0, i64 58 }, i64 2)
  br label %L16
L16:
  %t38 = phi %KValue [ %t36, %L14 ], [ %t37, %L15 ]
  ret %KValue %t38
L13:
  ret %KValue { i64 3, i64 0 }
}

define tailcc %KValue @"d_query/number_end_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x0, 1
  %t2 = inttoptr i64 %t1 to ptr
  %t3 = getelementptr %KBytes, ptr %t2, i64 0, i32 0
  %t4 = load i64, ptr %t3
  %t5 = extractvalue %KValue %x1, 1
  %t6 = icmp sge i64 %t5, 1
  %t7 = icmp sle i64 %t5, %t4
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = getelementptr %KBytes, ptr %t2, i64 0, i32 1
  %t10 = load ptr, ptr %t9
  %t11 = add i64 %t5, -1
  %t12 = getelementptr i8, ptr %t10, i64 %t11
  %t13 = load i8, ptr %t12
  %t14 = zext i8 %t13 to i64
  %t15 = insertvalue %KValue { i64 0, i64 undef }, i64 %t14, 1
  br label %L3
L2:
  br label %L3
L3:
  %t16 = phi %KValue [ %t15, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t17 = extractvalue %KValue %t16, 0
  %t18 = extractvalue %KValue %t16, 1
  %t19 = icmp eq i64 %t17, 4
  %t20 = select i1 %t19, i64 256, i64 %t18
  %t21 = call %KValue @"d_query/number_char?_1"(i64 %t20)
  %t22 = call i64 @k_not_failure(%KValue %t21)
  %t23 = icmp ne i64 %t22, 0
  br i1 %t23, label %L4, label %L5
L5:
  ret %KValue %t21
L4:
  %t24 = call i64 @k_truthy(%KValue %t21)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L6, label %L7
L6:
  %t26 = extractvalue %KValue %x1, 1
  %t27 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t28 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t26, i64 %t27)
  %t29 = extractvalue { i64, i1 } %t28, 0
  %t30 = extractvalue { i64, i1 } %t28, 1
  br i1 %t30, label %L9, label %L8
L9:
  call void @k_die(ptr @s94)
  unreachable
L8:
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t29, 1
  %t32 = extractvalue %KValue %t31, 1
  %t33 = musttail call tailcc %KValue @"d_query/number_end_2"(%KValue %x0, i64 %t32)
  ret %KValue %t33
L7:
  ret %KValue %x1
fail0:
  %t34 = call i64 @k_not_failure(%KValue %x0)
  %t35 = icmp ne i64 %t34, 0
  br i1 %t35, label %L11, label %L10
L10:
  %t36 = call %KValue @k_err_hop(%KValue %x0, ptr @s377)
  ret %KValue %t36
L11:
  %t37 = call i64 @k_not_failure(%KValue %x1)
  %t38 = icmp ne i64 %t37, 0
  br i1 %t38, label %L13, label %L12
L12:
  %t39 = call %KValue @k_err_hop(%KValue %x1, ptr @s377)
  ret %KValue %t39
L13:
  call void @k_die(ptr @s378)
  unreachable
}

define tailcc %KValue @"d_query/number_ok_2"(i64 %x0r, %KValue %x1) {
entry:
  %x0 = insertvalue %KValue { i64 0, i64 undef }, i64 %x0r, 1
  %t1 = call i64 @k_check_tag(%KValue %x1, i64 5)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_err_inner(%KValue %x1)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_str_lit(ptr @s380, i64 14, ptr @s380_lit)
  %t7 = extractvalue %KValue %x0, 1
  %t8 = musttail call tailcc %KValue @"d_query/fail_2"(i64 %t7, %KValue %t6)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_not_failure(%KValue %x1)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L3, label %fail1
L3:
  ret %KValue %x1
fail1:
  %t11 = call i64 @k_not_failure(%KValue %x0)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L5, label %L4
L4:
  %t13 = call %KValue @k_err_hop(%KValue %x0, ptr @s379)
  ret %KValue %t13
L5:
  %t14 = call i64 @k_not_failure(%KValue %x1)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L7, label %L6
L6:
  %t16 = call %KValue @k_err_hop(%KValue %x1, ptr @s379)
  ret %KValue %t16
L7:
  call void @k_die(ptr @s381)
  unreachable
}

define %KValue @"d_query/number_start?_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 0
  %t3 = extractvalue %KValue %x0, 1
  %t4 = icmp eq i64 %t3, 45
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %fail0
L1:
  ret %KValue { i64 2, i64 0 }
fail0:
  %t6 = extractvalue %KValue %x0, 0
  %t7 = icmp eq i64 %t6, 4
  br i1 %t7, label %L2, label %fail1
L2:
  ret %KValue { i64 3, i64 0 }
fail1:
  %t8 = extractvalue %KValue { i64 0, i64 47 }, 0
  %t9 = extractvalue %KValue %x0, 0
  %t10 = icmp eq i64 %t8, 0
  %t11 = icmp eq i64 %t9, 0
  %t12 = and i1 %t10, %t11
  br i1 %t12, label %L3, label %L4
L3:
  %t13 = extractvalue %KValue { i64 0, i64 47 }, 1
  %t14 = extractvalue %KValue %x0, 1
  %t15 = icmp slt i64 %t13, %t14
  %t16 = select i1 %t15, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L5
L4:
  %t17 = call %KValue @k_cmp(%KValue { i64 0, i64 47 }, %KValue %x0, i64 2)
  br label %L5
L5:
  %t18 = phi %KValue [ %t16, %L3 ], [ %t17, %L4 ]
  %t19 = call i64 @k_not_failure(%KValue %t18)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L6, label %L7
L7:
  ret %KValue %t18
L6:
  %t21 = call i64 @k_truthy(%KValue %t18)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L8, label %L9
L8:
  %t23 = extractvalue %KValue %x0, 0
  %t24 = extractvalue %KValue { i64 0, i64 58 }, 0
  %t25 = icmp eq i64 %t23, 0
  %t26 = icmp eq i64 %t24, 0
  %t27 = and i1 %t25, %t26
  br i1 %t27, label %L10, label %L11
L10:
  %t28 = extractvalue %KValue %x0, 1
  %t29 = extractvalue %KValue { i64 0, i64 58 }, 1
  %t30 = icmp slt i64 %t28, %t29
  %t31 = select i1 %t30, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L12
L11:
  %t32 = call %KValue @k_cmp(%KValue %x0, %KValue { i64 0, i64 58 }, i64 2)
  br label %L12
L12:
  %t33 = phi %KValue [ %t31, %L10 ], [ %t32, %L11 ]
  ret %KValue %t33
L9:
  ret %KValue { i64 3, i64 0 }
fail2:
  %t34 = call i64 @k_not_failure(%KValue %x0)
  %t35 = icmp ne i64 %t34, 0
  br i1 %t35, label %L14, label %L13
L13:
  %t36 = call %KValue @k_err_hop(%KValue %x0, ptr @s382)
  ret %KValue %t36
L14:
  call void @k_die(ptr @s383)
  unreachable
}

define tailcc %KValue @"d_query/number_value_3"(%KValue %x0, i64 %x1r, i64 %x2r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_b_slice(%KValue %x0, %KValue %x1, %KValue %x2)
  %t2 = extractvalue %KValue %x1, 1
  %t3 = extractvalue %KValue %x2, 1
  %t4 = call tailcc %KValue @"d_query/mark_from?_3"(%KValue %x0, i64 %t2, i64 %t3)
  %t5 = call i64 @k_not_failure(%KValue %t4)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L1, label %L2
L1:
  %t7 = call i64 @k_truthy(%KValue %t4)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %L4
L3:
  call void @k_beat_push()
  %t9 = call %KValue @"d_query/text/to_float_1"(%KValue %t1)
  %t10 = call %KValue @k_cohort_pop(%KValue %t9)
  br label %L2
L4:
  call void @k_beat_push()
  %t11 = call %KValue @"d_query/text/to_int_1"(%KValue %t1)
  %t12 = call %KValue @k_cohort_pop(%KValue %t11)
  br label %L2
L2:
  %t13 = phi %KValue [ %t4, %entry ], [ %t10, %L3 ], [ %t12, %L4 ]
  %t14 = extractvalue %KValue %x1, 1
  %t15 = musttail call tailcc %KValue @"d_query/number_ok_2"(i64 %t14, %KValue %t13)
  ret %KValue %t15
fail0:
  %t16 = call i64 @k_not_failure(%KValue %x0)
  %t17 = icmp ne i64 %t16, 0
  br i1 %t17, label %L6, label %L5
L5:
  %t18 = call %KValue @k_err_hop(%KValue %x0, ptr @s384)
  ret %KValue %t18
L6:
  %t19 = call i64 @k_not_failure(%KValue %x1)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L8, label %L7
L7:
  %t21 = call %KValue @k_err_hop(%KValue %x1, ptr @s384)
  ret %KValue %t21
L8:
  %t22 = call i64 @k_not_failure(%KValue %x2)
  %t23 = icmp ne i64 %t22, 0
  br i1 %t23, label %L10, label %L9
L9:
  %t24 = call %KValue @k_err_hop(%KValue %x2, ptr @s384)
  ret %KValue %t24
L10:
  call void @k_die(ptr @s385)
  unreachable
}

define tailcc %KValue @"d_query/index_end_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x0, 1
  %t2 = inttoptr i64 %t1 to ptr
  %t3 = getelementptr %KBytes, ptr %t2, i64 0, i32 0
  %t4 = load i64, ptr %t3
  %t5 = extractvalue %KValue %x1, 1
  %t6 = icmp sge i64 %t5, 1
  %t7 = icmp sle i64 %t5, %t4
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = getelementptr %KBytes, ptr %t2, i64 0, i32 1
  %t10 = load ptr, ptr %t9
  %t11 = add i64 %t5, -1
  %t12 = getelementptr i8, ptr %t10, i64 %t11
  %t13 = load i8, ptr %t12
  %t14 = zext i8 %t13 to i64
  %t15 = insertvalue %KValue { i64 0, i64 undef }, i64 %t14, 1
  br label %L3
L2:
  br label %L3
L3:
  %t16 = phi %KValue [ %t15, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t17 = extractvalue %KValue { i64 0, i64 47 }, 0
  %t18 = extractvalue %KValue %t16, 0
  %t19 = icmp eq i64 %t17, 0
  %t20 = icmp eq i64 %t18, 0
  %t21 = and i1 %t19, %t20
  br i1 %t21, label %L4, label %L5
L4:
  %t22 = extractvalue %KValue { i64 0, i64 47 }, 1
  %t23 = extractvalue %KValue %t16, 1
  %t24 = icmp slt i64 %t22, %t23
  %t25 = select i1 %t24, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L6
L5:
  %t26 = call %KValue @k_cmp(%KValue { i64 0, i64 47 }, %KValue %t16, i64 2)
  br label %L6
L6:
  %t27 = phi %KValue [ %t25, %L4 ], [ %t26, %L5 ]
  %t28 = call i64 @k_not_failure(%KValue %t27)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L7, label %L8
L7:
  %t30 = call i64 @k_truthy(%KValue %t27)
  %t31 = icmp ne i64 %t30, 0
  br i1 %t31, label %L9, label %L10
L9:
  %t32 = extractvalue %KValue %x0, 1
  %t33 = inttoptr i64 %t32 to ptr
  %t34 = getelementptr %KBytes, ptr %t33, i64 0, i32 0
  %t35 = load i64, ptr %t34
  %t36 = extractvalue %KValue %x1, 1
  %t37 = icmp sge i64 %t36, 1
  %t38 = icmp sle i64 %t36, %t35
  %t39 = and i1 %t37, %t38
  br i1 %t39, label %L11, label %L12
L11:
  %t40 = getelementptr %KBytes, ptr %t33, i64 0, i32 1
  %t41 = load ptr, ptr %t40
  %t42 = add i64 %t36, -1
  %t43 = getelementptr i8, ptr %t41, i64 %t42
  %t44 = load i8, ptr %t43
  %t45 = zext i8 %t44 to i64
  %t46 = insertvalue %KValue { i64 0, i64 undef }, i64 %t45, 1
  br label %L13
L12:
  br label %L13
L13:
  %t47 = phi %KValue [ %t46, %L11 ], [ { i64 4, i64 0 }, %L12 ]
  %t48 = extractvalue %KValue %t47, 0
  %t49 = extractvalue %KValue { i64 0, i64 58 }, 0
  %t50 = icmp eq i64 %t48, 0
  %t51 = icmp eq i64 %t49, 0
  %t52 = and i1 %t50, %t51
  br i1 %t52, label %L14, label %L15
L14:
  %t53 = extractvalue %KValue %t47, 1
  %t54 = extractvalue %KValue { i64 0, i64 58 }, 1
  %t55 = icmp slt i64 %t53, %t54
  %t56 = select i1 %t55, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L16
L15:
  %t57 = call %KValue @k_cmp(%KValue %t47, %KValue { i64 0, i64 58 }, i64 2)
  br label %L16
L16:
  %t58 = phi %KValue [ %t56, %L14 ], [ %t57, %L15 ]
  br label %L8
L10:
  br label %L8
L8:
  %t59 = phi %KValue [ %t27, %L6 ], [ %t58, %L16 ], [ { i64 3, i64 0 }, %L10 ]
  %t60 = call i64 @k_not_failure(%KValue %t59)
  %t61 = icmp ne i64 %t60, 0
  br i1 %t61, label %L17, label %L18
L18:
  ret %KValue %t59
L17:
  %t62 = call i64 @k_truthy(%KValue %t59)
  %t63 = icmp ne i64 %t62, 0
  br i1 %t63, label %L19, label %L20
L19:
  %t64 = extractvalue %KValue %x1, 1
  %t65 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t66 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t64, i64 %t65)
  %t67 = extractvalue { i64, i1 } %t66, 0
  %t68 = extractvalue { i64, i1 } %t66, 1
  br i1 %t68, label %L22, label %L21
L22:
  call void @k_die(ptr @s94)
  unreachable
L21:
  %t69 = insertvalue %KValue { i64 0, i64 undef }, i64 %t67, 1
  %t70 = extractvalue %KValue %t69, 1
  %t71 = musttail call tailcc %KValue @"d_query/index_end_2"(%KValue %x0, i64 %t70)
  ret %KValue %t71
L20:
  ret %KValue %x1
fail0:
  %t72 = call i64 @k_not_failure(%KValue %x0)
  %t73 = icmp ne i64 %t72, 0
  br i1 %t73, label %L24, label %L23
L23:
  %t74 = call %KValue @k_err_hop(%KValue %x0, ptr @s386)
  ret %KValue %t74
L24:
  %t75 = call i64 @k_not_failure(%KValue %x1)
  %t76 = icmp ne i64 %t75, 0
  br i1 %t76, label %L26, label %L25
L25:
  %t77 = call %KValue @k_err_hop(%KValue %x1, ptr @s386)
  ret %KValue %t77
L26:
  call void @k_die(ptr @s387)
  unreachable
}

define tailcc %KValue @"d_query/key_end_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x0, 1
  %t2 = inttoptr i64 %t1 to ptr
  %t3 = getelementptr %KBytes, ptr %t2, i64 0, i32 0
  %t4 = load i64, ptr %t3
  %t5 = extractvalue %KValue %x1, 1
  %t6 = icmp sge i64 %t5, 1
  %t7 = icmp sle i64 %t5, %t4
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = getelementptr %KBytes, ptr %t2, i64 0, i32 1
  %t10 = load ptr, ptr %t9
  %t11 = add i64 %t5, -1
  %t12 = getelementptr i8, ptr %t10, i64 %t11
  %t13 = load i8, ptr %t12
  %t14 = zext i8 %t13 to i64
  %t15 = insertvalue %KValue { i64 0, i64 undef }, i64 %t14, 1
  br label %L3
L2:
  br label %L3
L3:
  %t16 = phi %KValue [ %t15, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t17 = extractvalue %KValue %t16, 0
  %t18 = extractvalue %KValue %t16, 1
  %t19 = icmp eq i64 %t17, 4
  %t20 = select i1 %t19, i64 256, i64 %t18
  %t21 = extractvalue %KValue %x1, 1
  %t22 = musttail call tailcc %KValue @"d_query/key_end_at_3"(%KValue %x0, i64 %t20, i64 %t21)
  ret %KValue %t22
fail0:
  %t23 = call i64 @k_not_failure(%KValue %x0)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L5, label %L4
L4:
  %t25 = call %KValue @k_err_hop(%KValue %x0, ptr @s388)
  ret %KValue %t25
L5:
  %t26 = call i64 @k_not_failure(%KValue %x1)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L7, label %L6
L6:
  %t28 = call %KValue @k_err_hop(%KValue %x1, ptr @s388)
  ret %KValue %t28
L7:
  call void @k_die(ptr @s389)
  unreachable
}

define tailcc %KValue @"d_query/key_end_at_3"(%KValue %x0, i64 %x1r, i64 %x2r) {
entry:
  %t1 = icmp eq i64 %x1r, 256
  %x1b = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x1 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x1b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x1, 1
  switch i64 %t4, label %arm3 [
    i64 46, label %arm0
    i64 91, label %arm1
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm2, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm3, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x1, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s390)
  ret %KValue %t12
L6:
  call void @k_die(ptr @s391)
  unreachable
arm0:
  ret %KValue %x2
arm1:
  ret %KValue %x2
arm2:
  ret %KValue %x2
arm3:
  %t13 = extractvalue %KValue %x2, 1
  %t14 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t15 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t13, i64 %t14)
  %t16 = extractvalue { i64, i1 } %t15, 0
  %t17 = extractvalue { i64, i1 } %t15, 1
  br i1 %t17, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t18 = insertvalue %KValue { i64 0, i64 undef }, i64 %t16, 1
  %t19 = extractvalue %KValue %t18, 1
  %t20 = musttail call tailcc %KValue @"d_query/key_end_2"(%KValue %x0, i64 %t19)
  ret %KValue %t20
}

define tailcc %KValue @"d_query/parse_path_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_bytes(%KValue %x0)
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_list_lit(i64 0, ptr %t2)
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t5 = musttail call tailcc %KValue @"d_query/scan_steps_3"(%KValue %t1, i64 %t4, %KValue %t3)
  ret %KValue %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s392)
  ret %KValue %t8
L2:
  call void @k_die(ptr @s393)
  unreachable
}

define tailcc %KValue @"d_query/scan_steps_3"(%KValue %x0, i64 %x1r, %KValue %x2) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = call i64 @k_not_failure(%KValue %x2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x0, 1
  %t4 = inttoptr i64 %t3 to ptr
  %t5 = getelementptr %KBytes, ptr %t4, i64 0, i32 0
  %t6 = load i64, ptr %t5
  %t7 = extractvalue %KValue %x1, 1
  %t8 = icmp sge i64 %t7, 1
  %t9 = icmp sle i64 %t7, %t6
  %t10 = and i1 %t8, %t9
  br i1 %t10, label %L2, label %L3
L2:
  %t11 = getelementptr %KBytes, ptr %t4, i64 0, i32 1
  %t12 = load ptr, ptr %t11
  %t13 = add i64 %t7, -1
  %t14 = getelementptr i8, ptr %t12, i64 %t13
  %t15 = load i8, ptr %t14
  %t16 = zext i8 %t15 to i64
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t16, 1
  br label %L4
L3:
  br label %L4
L4:
  %t18 = phi %KValue [ %t17, %L2 ], [ { i64 4, i64 0 }, %L3 ]
  %t19 = extractvalue %KValue %t18, 0
  %t20 = extractvalue %KValue %t18, 1
  %t21 = icmp eq i64 %t19, 4
  %t22 = select i1 %t21, i64 256, i64 %t20
  %t23 = extractvalue %KValue %x1, 1
  %t24 = musttail call tailcc %KValue @"d_query/step_at_4"(%KValue %x0, i64 %t22, i64 %t23, %KValue %x2)
  ret %KValue %t24
fail0:
  %t25 = call i64 @k_not_failure(%KValue %x0)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L6, label %L5
L5:
  %t27 = call %KValue @k_err_hop(%KValue %x0, ptr @s394)
  ret %KValue %t27
L6:
  %t28 = call i64 @k_not_failure(%KValue %x1)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L8, label %L7
L7:
  %t30 = call %KValue @k_err_hop(%KValue %x1, ptr @s394)
  ret %KValue %t30
L8:
  %t31 = call i64 @k_not_failure(%KValue %x2)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L10, label %L9
L9:
  %t33 = call %KValue @k_err_hop(%KValue %x2, ptr @s394)
  ret %KValue %t33
L10:
  call void @k_die(ptr @s395)
  unreachable
}

define tailcc %KValue @"d_query/step_at_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %t1 = icmp eq i64 %x1r, 256
  %x1b = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x1 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x1b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x1, 1
  switch i64 %t4, label %arm3 [
    i64 46, label %arm0
    i64 91, label %arm1
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm2, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm3, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x1, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s396)
  ret %KValue %t12
L6:
  call void @k_die(ptr @s397)
  unreachable
arm0:
  %t13 = extractvalue %KValue %x2, 1
  %t14 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t15 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t13, i64 %t14)
  %t16 = extractvalue { i64, i1 } %t15, 0
  %t17 = extractvalue { i64, i1 } %t15, 1
  br i1 %t17, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t18 = insertvalue %KValue { i64 0, i64 undef }, i64 %t16, 1
  %t19 = extractvalue %KValue %t18, 1
  %t20 = call tailcc %KValue @"d_query/key_end_2"(%KValue %x0, i64 %t19)
  %t21 = extractvalue %KValue %x2, 1
  %t22 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t23 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t21, i64 %t22)
  %t24 = extractvalue { i64, i1 } %t23, 0
  %t25 = extractvalue { i64, i1 } %t23, 1
  br i1 %t25, label %L10, label %L9
L10:
  call void @k_die(ptr @s94)
  unreachable
L9:
  %t26 = insertvalue %KValue { i64 0, i64 undef }, i64 %t24, 1
  %t27 = extractvalue %KValue %t26, 1
  %t28 = extractvalue %KValue %t20, 1
  %t29 = musttail call tailcc %KValue @"d_query/steps_key_4"(%KValue %x0, i64 %t27, i64 %t28, %KValue %x3)
  ret %KValue %t29
arm1:
  %t30 = extractvalue %KValue %x2, 1
  %t31 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t32 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t30, i64 %t31)
  %t33 = extractvalue { i64, i1 } %t32, 0
  %t34 = extractvalue { i64, i1 } %t32, 1
  br i1 %t34, label %L12, label %L11
L12:
  call void @k_die(ptr @s94)
  unreachable
L11:
  %t35 = insertvalue %KValue { i64 0, i64 undef }, i64 %t33, 1
  %t36 = extractvalue %KValue %t35, 1
  %t37 = call tailcc %KValue @"d_query/index_end_2"(%KValue %x0, i64 %t36)
  %t38 = extractvalue %KValue %x2, 1
  %t39 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t40 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t38, i64 %t39)
  %t41 = extractvalue { i64, i1 } %t40, 0
  %t42 = extractvalue { i64, i1 } %t40, 1
  br i1 %t42, label %L14, label %L13
L14:
  call void @k_die(ptr @s94)
  unreachable
L13:
  %t43 = insertvalue %KValue { i64 0, i64 undef }, i64 %t41, 1
  %t44 = extractvalue %KValue %t43, 1
  %t45 = extractvalue %KValue %t37, 1
  %t46 = musttail call tailcc %KValue @"d_query/steps_index_4"(%KValue %x0, i64 %t44, i64 %t45, %KValue %x3)
  ret %KValue %t46
arm2:
  ret %KValue %x3
arm3:
  %t47 = call %KValue @k_str_lit(ptr @s398, i64 22, ptr @s398_lit)
  %t48 = alloca [1 x %KValue]
  %t49 = getelementptr [1 x %KValue], ptr %t48, i64 0, i64 0
  store %KValue %x1, ptr %t49
  %t50 = call %KValue @k_list_lit(i64 1, ptr %t48)
  %t51 = call %KValue @"d_query/text/utf8_1"(%KValue %t50)
  %t52 = call %KValue @k_render(%KValue %t51, i64 0)
  %t53 = call %KValue @k_str_lit(ptr @s399, i64 1, ptr @s399_lit)
  %t54 = alloca [3 x %KValue]
  %t55 = getelementptr [3 x %KValue], ptr %t54, i64 0, i64 0
  store %KValue %t47, ptr %t55
  %t56 = getelementptr [3 x %KValue], ptr %t54, i64 0, i64 1
  store %KValue %t52, ptr %t56
  %t57 = getelementptr [3 x %KValue], ptr %t54, i64 0, i64 2
  store %KValue %t53, ptr %t57
  %t58 = call %KValue @k_concat_arr(i64 3, ptr %t54)
  %t59 = alloca [2 x %KValue]
  %t60 = getelementptr [2 x %KValue], ptr %t59, i64 0, i64 0
  store %KValue %x2, ptr %t60
  %t61 = getelementptr [2 x %KValue], ptr %t59, i64 0, i64 1
  store %KValue %t58, ptr %t61
  %t62 = call %KValue @k_rec(i64 36, i64 2, ptr %t59)
  %t63 = call %KValue @k_err(%KValue %t62, ptr @s400)
  ret %KValue %t63
}

define tailcc %KValue @"d_query/steps_index_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x0, 1
  %t2 = inttoptr i64 %t1 to ptr
  %t3 = getelementptr %KBytes, ptr %t2, i64 0, i32 0
  %t4 = load i64, ptr %t3
  %t5 = extractvalue %KValue %x2, 1
  %t6 = icmp sge i64 %t5, 1
  %t7 = icmp sle i64 %t5, %t4
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = getelementptr %KBytes, ptr %t2, i64 0, i32 1
  %t10 = load ptr, ptr %t9
  %t11 = add i64 %t5, -1
  %t12 = getelementptr i8, ptr %t10, i64 %t11
  %t13 = load i8, ptr %t12
  %t14 = zext i8 %t13 to i64
  %t15 = insertvalue %KValue { i64 0, i64 undef }, i64 %t14, 1
  br label %L3
L2:
  br label %L3
L3:
  %t16 = phi %KValue [ %t15, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t17 = extractvalue %KValue %x1, 1
  %t18 = extractvalue %KValue %x2, 1
  %t19 = musttail call tailcc %KValue @"d_query/steps_index_close_5"(%KValue %x0, %KValue %t16, i64 %t17, i64 %t18, %KValue %x3)
  ret %KValue %t19
fail0:
  %t20 = call i64 @k_not_failure(%KValue %x0)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L5, label %L4
L4:
  %t22 = call %KValue @k_err_hop(%KValue %x0, ptr @s401)
  ret %KValue %t22
L5:
  %t23 = call i64 @k_not_failure(%KValue %x1)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L7, label %L6
L6:
  %t25 = call %KValue @k_err_hop(%KValue %x1, ptr @s401)
  ret %KValue %t25
L7:
  %t26 = call i64 @k_not_failure(%KValue %x2)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L9, label %L8
L8:
  %t28 = call %KValue @k_err_hop(%KValue %x2, ptr @s401)
  ret %KValue %t28
L9:
  %t29 = call i64 @k_not_failure(%KValue %x3)
  %t30 = icmp ne i64 %t29, 0
  br i1 %t30, label %L11, label %L10
L10:
  %t31 = call %KValue @k_err_hop(%KValue %x3, ptr @s401)
  ret %KValue %t31
L11:
  call void @k_die(ptr @s402)
  unreachable
}

define tailcc %KValue @"d_query/steps_index_close_5"(%KValue %x0, %KValue %x1, i64 %x2r, i64 %x3r, %KValue %x4) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %t1 = extractvalue %KValue %x1, 0
  %t2 = icmp eq i64 %t1, 0
  %t3 = extractvalue %KValue %x1, 1
  %t4 = icmp eq i64 %t3, 93
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %fail0
L1:
  %t6 = extractvalue %KValue %x3, 1
  %t7 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t8 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t6, i64 %t7)
  %t9 = extractvalue { i64, i1 } %t8, 0
  %t10 = extractvalue { i64, i1 } %t8, 1
  br i1 %t10, label %L3, label %L2
L3:
  call void @k_die(ptr @s94)
  unreachable
L2:
  %t11 = insertvalue %KValue { i64 0, i64 undef }, i64 %t9, 1
  %t12 = call %KValue @k_b_slice(%KValue %x0, %KValue %x2, %KValue %t11)
  call void @k_beat_push()
  %t13 = call %KValue @"d_query/text/utf8_1"(%KValue %t12)
  %t14 = call %KValue @k_cohort_pop(%KValue %t13)
  call void @k_beat_push()
  %t15 = call %KValue @"d_query/text/to_int_1"(%KValue %t14)
  %t16 = call %KValue @k_cohort_pop(%KValue %t15)
  %t17 = extractvalue %KValue %x3, 1
  %t18 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t19 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t17, i64 %t18)
  %t20 = extractvalue { i64, i1 } %t19, 0
  %t21 = extractvalue { i64, i1 } %t19, 1
  br i1 %t21, label %L5, label %L4
L5:
  call void @k_die(ptr @s94)
  unreachable
L4:
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  %t23 = extractvalue %KValue %t16, 0
  %t24 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t25 = icmp eq i64 %t23, 0
  %t26 = icmp eq i64 %t24, 0
  %t27 = and i1 %t25, %t26
  br i1 %t27, label %L6, label %L7
L6:
  %t28 = extractvalue %KValue %t16, 1
  %t29 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t30 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t28, i64 %t29)
  %t31 = extractvalue { i64, i1 } %t30, 0
  %t32 = extractvalue { i64, i1 } %t30, 1
  br i1 %t32, label %L7, label %L9
L9:
  %t33 = insertvalue %KValue { i64 0, i64 undef }, i64 %t31, 1
  br label %L8
L7:
  %t34 = call %KValue @k_add(%KValue %t16, %KValue { i64 0, i64 1 })
  br label %L8
L8:
  %t35 = phi %KValue [ %t33, %L9 ], [ %t34, %L7 ]
  %t36 = call %KValue @k_b_push_mut(%KValue %x4, %KValue %t35)
  %t37 = extractvalue %KValue %t22, 1
  %t38 = musttail call tailcc %KValue @"d_query/scan_steps_3"(%KValue %x0, i64 %t37, %KValue %t36)
  ret %KValue %t38
fail0:
  %t39 = call %KValue @k_str_lit(ptr @s404, i64 22, ptr @s404_lit)
  %t40 = alloca [2 x %KValue]
  %t41 = getelementptr [2 x %KValue], ptr %t40, i64 0, i64 0
  store %KValue %x2, ptr %t41
  %t42 = getelementptr [2 x %KValue], ptr %t40, i64 0, i64 1
  store %KValue %t39, ptr %t42
  %t43 = call %KValue @k_rec(i64 36, i64 2, ptr %t40)
  %t44 = call %KValue @k_err(%KValue %t43, ptr @s405)
  ret %KValue %t44
fail1:
  %t45 = call i64 @k_not_failure(%KValue %x0)
  %t46 = icmp ne i64 %t45, 0
  br i1 %t46, label %L11, label %L10
L10:
  %t47 = call %KValue @k_err_hop(%KValue %x0, ptr @s403)
  ret %KValue %t47
L11:
  %t48 = call i64 @k_not_failure(%KValue %x1)
  %t49 = icmp ne i64 %t48, 0
  br i1 %t49, label %L13, label %L12
L12:
  %t50 = call %KValue @k_err_hop(%KValue %x1, ptr @s403)
  ret %KValue %t50
L13:
  %t51 = call i64 @k_not_failure(%KValue %x2)
  %t52 = icmp ne i64 %t51, 0
  br i1 %t52, label %L15, label %L14
L14:
  %t53 = call %KValue @k_err_hop(%KValue %x2, ptr @s403)
  ret %KValue %t53
L15:
  %t54 = call i64 @k_not_failure(%KValue %x3)
  %t55 = icmp ne i64 %t54, 0
  br i1 %t55, label %L17, label %L16
L16:
  %t56 = call %KValue @k_err_hop(%KValue %x3, ptr @s403)
  ret %KValue %t56
L17:
  %t57 = call i64 @k_not_failure(%KValue %x4)
  %t58 = icmp ne i64 %t57, 0
  br i1 %t58, label %L19, label %L18
L18:
  %t59 = call %KValue @k_err_hop(%KValue %x4, ptr @s403)
  ret %KValue %t59
L19:
  call void @k_die(ptr @s406)
  unreachable
}

define tailcc %KValue @"d_query/steps_key_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x2, 1
  %t2 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t3 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t1, i64 %t2)
  %t4 = extractvalue { i64, i1 } %t3, 0
  %t5 = extractvalue { i64, i1 } %t3, 1
  br i1 %t5, label %L2, label %L1
L2:
  call void @k_die(ptr @s94)
  unreachable
L1:
  %t6 = insertvalue %KValue { i64 0, i64 undef }, i64 %t4, 1
  %t7 = call %KValue @k_b_slice(%KValue %x0, %KValue %x1, %KValue %t6)
  call void @k_beat_push()
  %t8 = call %KValue @"d_query/text/utf8_1"(%KValue %t7)
  %t9 = call %KValue @k_cohort_pop(%KValue %t8)
  %t10 = extractvalue %KValue %x2, 1
  %t11 = musttail call tailcc %KValue @"d_query/steps_key_checked_4"(%KValue %x0, i64 %t10, %KValue %x3, %KValue %t9)
  ret %KValue %t11
fail0:
  %t12 = call i64 @k_not_failure(%KValue %x0)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L3
L3:
  %t14 = call %KValue @k_err_hop(%KValue %x0, ptr @s407)
  ret %KValue %t14
L4:
  %t15 = call i64 @k_not_failure(%KValue %x1)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L6, label %L5
L5:
  %t17 = call %KValue @k_err_hop(%KValue %x1, ptr @s407)
  ret %KValue %t17
L6:
  %t18 = call i64 @k_not_failure(%KValue %x2)
  %t19 = icmp ne i64 %t18, 0
  br i1 %t19, label %L8, label %L7
L7:
  %t20 = call %KValue @k_err_hop(%KValue %x2, ptr @s407)
  ret %KValue %t20
L8:
  %t21 = call i64 @k_not_failure(%KValue %x3)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L10, label %L9
L9:
  %t23 = call %KValue @k_err_hop(%KValue %x3, ptr @s407)
  ret %KValue %t23
L10:
  call void @k_die(ptr @s408)
  unreachable
}

define tailcc %KValue @"d_query/steps_key_checked_4"(%KValue %x0, i64 %x1r, %KValue %x2, %KValue %x3) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = call i64 @k_check_str(%KValue %x3, ptr @s259, i64 0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1, 1
  %t4 = musttail call tailcc %KValue @"d_query/scan_steps_3"(%KValue %x0, i64 %t3, %KValue %x2)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x3)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %fail1
L2:
  %t7 = call %KValue @k_b_push_mut(%KValue %x2, %KValue %x3)
  %t8 = extractvalue %KValue %x1, 1
  %t9 = musttail call tailcc %KValue @"d_query/scan_steps_3"(%KValue %x0, i64 %t8, %KValue %t7)
  ret %KValue %t9
fail1:
  %t10 = call i64 @k_not_failure(%KValue %x0)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L3
L3:
  %t12 = call %KValue @k_err_hop(%KValue %x0, ptr @s409)
  ret %KValue %t12
L4:
  %t13 = call i64 @k_not_failure(%KValue %x1)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L6, label %L5
L5:
  %t15 = call %KValue @k_err_hop(%KValue %x1, ptr @s409)
  ret %KValue %t15
L6:
  %t16 = call i64 @k_not_failure(%KValue %x2)
  %t17 = icmp ne i64 %t16, 0
  br i1 %t17, label %L8, label %L7
L7:
  %t18 = call %KValue @k_err_hop(%KValue %x2, ptr @s409)
  ret %KValue %t18
L8:
  %t19 = call i64 @k_not_failure(%KValue %x3)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L10, label %L9
L9:
  %t21 = call %KValue @k_err_hop(%KValue %x3, ptr @s409)
  ret %KValue %t21
L10:
  call void @k_die(ptr @s410)
  unreachable
}

define tailcc %KValue @"d_query/walk_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call i64 @k_not_failure(%KValue %x1)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L2, label %fail0
L2:
  %t5 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t6 = musttail call tailcc %KValue @"d_query/walk_at_3"(%KValue %x0, %KValue %x1, i64 %t5)
  ret %KValue %t6
fail0:
  %t7 = call i64 @k_not_failure(%KValue %x0)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L4, label %L3
L3:
  %t9 = call %KValue @k_err_hop(%KValue %x0, ptr @s411)
  ret %KValue %t9
L4:
  %t10 = call i64 @k_not_failure(%KValue %x1)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L6, label %L5
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s411)
  ret %KValue %t12
L6:
  call void @k_die(ptr @s412)
  unreachable
}

define tailcc %KValue @"d_query/walk_at_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_b_length_fast(%KValue %x1)
  %t2 = extractvalue %KValue %x2, 1
  %t3 = extractvalue %KValue %t1, 1
  %t4 = icmp sgt i64 %t2, %t3
  %t5 = select i1 %t4, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L1, label %L2
L2:
  ret %KValue %t5
L1:
  %t8 = call i64 @k_truthy(%KValue %t5)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L4
L3:
  ret %KValue %x0
L4:
  %t10 = extractvalue %KValue %x2, 1
  %t11 = musttail call tailcc %KValue @"d_query/walk_step_3"(%KValue %x0, %KValue %x1, i64 %t10)
  ret %KValue %t11
fail0:
  %t12 = call i64 @k_not_failure(%KValue %x0)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L6, label %L5
L5:
  %t14 = call %KValue @k_err_hop(%KValue %x0, ptr @s413)
  ret %KValue %t14
L6:
  %t15 = call i64 @k_not_failure(%KValue %x1)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L8, label %L7
L7:
  %t17 = call %KValue @k_err_hop(%KValue %x1, ptr @s413)
  ret %KValue %t17
L8:
  %t18 = call i64 @k_not_failure(%KValue %x2)
  %t19 = icmp ne i64 %t18, 0
  br i1 %t19, label %L10, label %L9
L9:
  %t20 = call %KValue @k_err_hop(%KValue %x2, ptr @s413)
  ret %KValue %t20
L10:
  call void @k_die(ptr @s414)
  unreachable
}

define tailcc %KValue @"d_query/walk_step_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x1, 0
  %t2 = icmp eq i64 %t1, 13
  %t3 = extractvalue %KValue %x2, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %x1, 1
  %t7 = inttoptr i64 %t6 to ptr
  %t8 = getelementptr %KBytes, ptr %t7, i64 0, i32 0
  %t9 = load i64, ptr %t8
  %t10 = extractvalue %KValue %x2, 1
  %t11 = icmp sge i64 %t10, 1
  %t12 = icmp sle i64 %t10, %t9
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L2
L4:
  %t14 = getelementptr %KBytes, ptr %t7, i64 0, i32 1
  %t15 = load ptr, ptr %t14
  %t16 = add i64 %t10, -1
  %t17 = getelementptr i8, ptr %t15, i64 %t16
  %t18 = load i8, ptr %t17
  %t19 = zext i8 %t18 to i64
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  br label %L3
L2:
  %t21 = call %KValue @k_b_at(%KValue %x1, %KValue %x2)
  br label %L3
L3:
  %t22 = phi %KValue [ %t20, %L4 ], [ %t21, %L2 ]
  %t23 = extractvalue %KValue %x0, 0
  %t24 = icmp eq i64 %t23, 13
  %t25 = extractvalue %KValue %t22, 0
  %t26 = icmp eq i64 %t25, 0
  %t27 = and i1 %t24, %t26
  br i1 %t27, label %L5, label %L6
L5:
  %t28 = extractvalue %KValue %x0, 1
  %t29 = inttoptr i64 %t28 to ptr
  %t30 = getelementptr %KBytes, ptr %t29, i64 0, i32 0
  %t31 = load i64, ptr %t30
  %t32 = extractvalue %KValue %t22, 1
  %t33 = icmp sge i64 %t32, 1
  %t34 = icmp sle i64 %t32, %t31
  %t35 = and i1 %t33, %t34
  br i1 %t35, label %L8, label %L6
L8:
  %t36 = getelementptr %KBytes, ptr %t29, i64 0, i32 1
  %t37 = load ptr, ptr %t36
  %t38 = add i64 %t32, -1
  %t39 = getelementptr i8, ptr %t37, i64 %t38
  %t40 = load i8, ptr %t39
  %t41 = zext i8 %t40 to i64
  %t42 = insertvalue %KValue { i64 0, i64 undef }, i64 %t41, 1
  br label %L7
L6:
  %t43 = call %KValue @k_b_at(%KValue %x0, %KValue %t22)
  br label %L7
L7:
  %t44 = phi %KValue [ %t42, %L8 ], [ %t43, %L6 ]
  %t45 = extractvalue %KValue %x2, 1
  %t46 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t47 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t45, i64 %t46)
  %t48 = extractvalue { i64, i1 } %t47, 0
  %t49 = extractvalue { i64, i1 } %t47, 1
  br i1 %t49, label %L10, label %L9
L10:
  call void @k_die(ptr @s94)
  unreachable
L9:
  %t50 = insertvalue %KValue { i64 0, i64 undef }, i64 %t48, 1
  %t51 = extractvalue %KValue %t50, 1
  %t52 = musttail call tailcc %KValue @"d_query/walk_at_3"(%KValue %t44, %KValue %x1, i64 %t51)
  ret %KValue %t52
fail0:
  %t53 = call i64 @k_not_failure(%KValue %x0)
  %t54 = icmp ne i64 %t53, 0
  br i1 %t54, label %L12, label %L11
L11:
  %t55 = call %KValue @k_err_hop(%KValue %x0, ptr @s415)
  ret %KValue %t55
L12:
  %t56 = call i64 @k_not_failure(%KValue %x1)
  %t57 = icmp ne i64 %t56, 0
  br i1 %t57, label %L14, label %L13
L13:
  %t58 = call %KValue @k_err_hop(%KValue %x1, ptr @s415)
  ret %KValue %t58
L14:
  %t59 = call i64 @k_not_failure(%KValue %x2)
  %t60 = icmp ne i64 %t59, 0
  br i1 %t60, label %L16, label %L15
L15:
  %t61 = call %KValue @k_err_hop(%KValue %x2, ptr @s415)
  ret %KValue %t61
L16:
  call void @k_die(ptr @s416)
  unreachable
}

define tailcc %KValue @"d_query/elem_row_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_str_lit(ptr @s301, i64 2, ptr @s301_lit)
  %t2 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t1)
  %t3 = extractvalue %KValue %x2, 1
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t5 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t3, i64 %t4)
  %t6 = extractvalue { i64, i1 } %t5, 0
  %t7 = extractvalue { i64, i1 } %t5, 1
  br i1 %t7, label %L2, label %L1
L2:
  call void @k_die(ptr @s94)
  unreachable
L1:
  %t8 = insertvalue %KValue { i64 0, i64 undef }, i64 %t6, 1
  %t9 = extractvalue %KValue %t8, 1
  call void @k_beat_push()
  %t10 = call tailcc %KValue @"d_query/indent_onto_2"(%KValue %t2, i64 %t9)
  %t11 = call %KValue @k_beat_pop(%KValue %t10)
  %t12 = extractvalue %KValue %x2, 1
  %t13 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t14 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t12, i64 %t13)
  %t15 = extractvalue { i64, i1 } %t14, 0
  %t16 = extractvalue { i64, i1 } %t14, 1
  br i1 %t16, label %L4, label %L3
L4:
  call void @k_die(ptr @s94)
  unreachable
L3:
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t15, 1
  %t18 = extractvalue %KValue %t17, 1
  %t19 = musttail call tailcc %KValue @"d_query/pretty_onto_3"(%KValue %t11, %KValue %x1, i64 %t18)
  ret %KValue %t19
fail0:
  %t20 = call i64 @k_not_failure(%KValue %x0)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L6, label %L5
L5:
  %t22 = call %KValue @k_err_hop(%KValue %x0, ptr @s417)
  ret %KValue %t22
L6:
  %t23 = call i64 @k_not_failure(%KValue %x1)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L8, label %L7
L7:
  %t25 = call %KValue @k_err_hop(%KValue %x1, ptr @s417)
  ret %KValue %t25
L8:
  %t26 = call i64 @k_not_failure(%KValue %x2)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L10, label %L9
L9:
  %t28 = call %KValue @k_err_hop(%KValue %x2, ptr @s417)
  ret %KValue %t28
L10:
  call void @k_die(ptr @s418)
  unreachable
}

define tailcc %KValue @"d_query/indent_onto_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = extractvalue %KValue %x1, 1
  %t6 = icmp eq i64 %t5, 0
  %t7 = and i1 %t4, %t6
  br i1 %t7, label %L2, label %fail0
L2:
  ret %KValue %x0
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %fail1
L3:
  %t10 = call %KValue @k_str_lit(ptr @s292, i64 2, ptr @s292_lit)
  %t11 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t10)
  %t12 = extractvalue %KValue %x1, 1
  %t13 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t14 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t12, i64 %t13)
  %t15 = extractvalue { i64, i1 } %t14, 0
  %t16 = extractvalue { i64, i1 } %t14, 1
  br i1 %t16, label %L5, label %L4
L5:
  call void @k_die(ptr @s94)
  unreachable
L4:
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t15, 1
  call void @k_beat_iter()
  %t18 = extractvalue %KValue %t17, 1
  %t19 = musttail call tailcc %KValue @"d_query/indent_onto_2"(%KValue %t11, i64 %t18)
  ret %KValue %t19
fail1:
  %t20 = call i64 @k_not_failure(%KValue %x0)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L7, label %L6
L6:
  %t22 = call %KValue @k_err_hop(%KValue %x0, ptr @s419)
  ret %KValue %t22
L7:
  %t23 = call i64 @k_not_failure(%KValue %x1)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L9, label %L8
L8:
  %t25 = call %KValue @k_err_hop(%KValue %x1, ptr @s419)
  ret %KValue %t25
L9:
  call void @k_die(ptr @s420)
  unreachable
}

define tailcc %KValue @"d_query/pair_row_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_str_lit(ptr @s301, i64 2, ptr @s301_lit)
  %t2 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t1)
  %t3 = extractvalue %KValue %x2, 1
  %t4 = musttail call tailcc %KValue @"d_query/pretty_entry_3"(%KValue %t2, %KValue %x1, i64 %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s421)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s421)
  ret %KValue %t10
L4:
  %t11 = call i64 @k_not_failure(%KValue %x2)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L6, label %L5
L5:
  %t13 = call %KValue @k_err_hop(%KValue %x2, ptr @s421)
  ret %KValue %t13
L6:
  call void @k_die(ptr @s422)
  unreachable
}

define %KValue @"d_query/pretty_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_str_lit(ptr @s259, i64 0, ptr @s259_lit)
  %t4 = call %KValue @k_b_bytes(%KValue %t3)
  %t5 = extractvalue %KValue %x1, 1
  %t6 = call tailcc %KValue @"d_query/pretty_onto_3"(%KValue %t4, %KValue %x0, i64 %t5)
  call void @k_beat_push()
  %t7 = call %KValue @"d_query/text/utf8_1"(%KValue %t6)
  %t8 = call %KValue @k_cohort_pop(%KValue %t7)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_not_failure(%KValue %x0)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L3, label %L2
L2:
  %t11 = call %KValue @k_err_hop(%KValue %x0, ptr @s423)
  ret %KValue %t11
L3:
  %t12 = call i64 @k_not_failure(%KValue %x1)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L5, label %L4
L4:
  %t14 = call %KValue @k_err_hop(%KValue %x1, ptr @s423)
  ret %KValue %t14
L5:
  call void @k_die(ptr @s424)
  unreachable
}

define tailcc %KValue @"d_query/pretty_elems_4"(%KValue %x0, %KValue %x1, i64 %x2r, i64 %x3r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_length_fast(%KValue %x1)
  %t4 = extractvalue %KValue %t3, 1
  %t5 = extractvalue %KValue %x2, 1
  %t6 = icmp slt i64 %t4, %t5
  %t7 = select i1 %t6, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t8 = call i64 @k_not_failure(%KValue %t7)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L3
L3:
  ret %KValue %t7
L2:
  %t10 = call i64 @k_truthy(%KValue %t7)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L5
L4:
  ret %KValue %x0
L5:
  %t12 = extractvalue %KValue %x1, 0
  %t13 = icmp eq i64 %t12, 13
  %t14 = extractvalue %KValue %x2, 0
  %t15 = icmp eq i64 %t14, 0
  %t16 = and i1 %t13, %t15
  br i1 %t16, label %L6, label %L7
L6:
  %t17 = extractvalue %KValue %x1, 1
  %t18 = inttoptr i64 %t17 to ptr
  %t19 = getelementptr %KBytes, ptr %t18, i64 0, i32 0
  %t20 = load i64, ptr %t19
  %t21 = extractvalue %KValue %x2, 1
  %t22 = icmp sge i64 %t21, 1
  %t23 = icmp sle i64 %t21, %t20
  %t24 = and i1 %t22, %t23
  br i1 %t24, label %L9, label %L7
L9:
  %t25 = getelementptr %KBytes, ptr %t18, i64 0, i32 1
  %t26 = load ptr, ptr %t25
  %t27 = add i64 %t21, -1
  %t28 = getelementptr i8, ptr %t26, i64 %t27
  %t29 = load i8, ptr %t28
  %t30 = zext i8 %t29 to i64
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t30, 1
  br label %L8
L7:
  %t32 = call %KValue @k_b_at(%KValue %x1, %KValue %x2)
  br label %L8
L8:
  %t33 = phi %KValue [ %t31, %L9 ], [ %t32, %L7 ]
  %t34 = extractvalue %KValue %x3, 1
  %t35 = call tailcc %KValue @"d_query/elem_row_3"(%KValue %x0, %KValue %t33, i64 %t34)
  %t36 = extractvalue %KValue %x2, 1
  %t37 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t38 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t36, i64 %t37)
  %t39 = extractvalue { i64, i1 } %t38, 0
  %t40 = extractvalue { i64, i1 } %t38, 1
  br i1 %t40, label %L11, label %L10
L11:
  call void @k_die(ptr @s94)
  unreachable
L10:
  %t41 = insertvalue %KValue { i64 0, i64 undef }, i64 %t39, 1
  call void @k_beat_iter()
  %t42 = extractvalue %KValue %t41, 1
  %t43 = extractvalue %KValue %x3, 1
  %t44 = musttail call tailcc %KValue @"d_query/pretty_elems_4"(%KValue %t35, %KValue %x1, i64 %t42, i64 %t43)
  ret %KValue %t44
fail0:
  %t45 = call i64 @k_not_failure(%KValue %x0)
  %t46 = icmp ne i64 %t45, 0
  br i1 %t46, label %L13, label %L12
L12:
  %t47 = call %KValue @k_err_hop(%KValue %x0, ptr @s425)
  ret %KValue %t47
L13:
  %t48 = call i64 @k_not_failure(%KValue %x1)
  %t49 = icmp ne i64 %t48, 0
  br i1 %t49, label %L15, label %L14
L14:
  %t50 = call %KValue @k_err_hop(%KValue %x1, ptr @s425)
  ret %KValue %t50
L15:
  %t51 = call i64 @k_not_failure(%KValue %x2)
  %t52 = icmp ne i64 %t51, 0
  br i1 %t52, label %L17, label %L16
L16:
  %t53 = call %KValue @k_err_hop(%KValue %x2, ptr @s425)
  ret %KValue %t53
L17:
  %t54 = call i64 @k_not_failure(%KValue %x3)
  %t55 = icmp ne i64 %t54, 0
  br i1 %t55, label %L19, label %L18
L18:
  %t56 = call %KValue @k_err_hop(%KValue %x3, ptr @s425)
  ret %KValue %t56
L19:
  call void @k_die(ptr @s426)
  unreachable
}

define tailcc %KValue @"d_query/pretty_entry_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call i64 @k_check_rec(%KValue %x1, i64 0, i64 2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_field(%KValue %x1, i64 0)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_field(%KValue %x1, i64 1)
  %t7 = call i64 @k_not_failure(%KValue %t6)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail0
L3:
  %t9 = extractvalue %KValue %x2, 1
  %t10 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t11 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t9, i64 %t10)
  %t12 = extractvalue { i64, i1 } %t11, 0
  %t13 = extractvalue { i64, i1 } %t11, 1
  br i1 %t13, label %L5, label %L4
L5:
  call void @k_die(ptr @s94)
  unreachable
L4:
  %t14 = insertvalue %KValue { i64 0, i64 undef }, i64 %t12, 1
  %t15 = extractvalue %KValue %t14, 1
  call void @k_beat_push()
  %t16 = call tailcc %KValue @"d_query/indent_onto_2"(%KValue %x0, i64 %t15)
  %t17 = call %KValue @k_beat_pop(%KValue %t16)
  %t18 = call %KValue @k_b_append_mut(%KValue %t17, %KValue { i64 0, i64 34 })
  %t19 = call tailcc %KValue @"d_query/escape_onto_2"(%KValue %t18, %KValue %t3)
  %t20 = call %KValue @k_str_lit(ptr @s428, i64 3, ptr @s428_lit)
  %t21 = call %KValue @k_b_append_mut(%KValue %t19, %KValue %t20)
  %t22 = extractvalue %KValue %x2, 1
  %t23 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t24 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t22, i64 %t23)
  %t25 = extractvalue { i64, i1 } %t24, 0
  %t26 = extractvalue { i64, i1 } %t24, 1
  br i1 %t26, label %L7, label %L6
L7:
  call void @k_die(ptr @s94)
  unreachable
L6:
  %t27 = insertvalue %KValue { i64 0, i64 undef }, i64 %t25, 1
  %t28 = extractvalue %KValue %t27, 1
  %t29 = musttail call tailcc %KValue @"d_query/pretty_onto_3"(%KValue %t21, %KValue %t6, i64 %t28)
  ret %KValue %t29
fail0:
  %t30 = call i64 @k_not_failure(%KValue %x0)
  %t31 = icmp ne i64 %t30, 0
  br i1 %t31, label %L9, label %L8
L8:
  %t32 = call %KValue @k_err_hop(%KValue %x0, ptr @s427)
  ret %KValue %t32
L9:
  %t33 = call i64 @k_not_failure(%KValue %x1)
  %t34 = icmp ne i64 %t33, 0
  br i1 %t34, label %L11, label %L10
L10:
  %t35 = call %KValue @k_err_hop(%KValue %x1, ptr @s427)
  ret %KValue %t35
L11:
  %t36 = call i64 @k_not_failure(%KValue %x2)
  %t37 = icmp ne i64 %t36, 0
  br i1 %t37, label %L13, label %L12
L12:
  %t38 = call %KValue @k_err_hop(%KValue %x2, ptr @s427)
  ret %KValue %t38
L13:
  call void @k_die(ptr @s429)
  unreachable
}

define tailcc %KValue @"d_query/pretty_list_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_str_lit(ptr @s307, i64 2, ptr @s307_lit)
  %t2 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t1)
  %t3 = extractvalue %KValue %x2, 1
  %t4 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t5 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t3, i64 %t4)
  %t6 = extractvalue { i64, i1 } %t5, 0
  %t7 = extractvalue { i64, i1 } %t5, 1
  br i1 %t7, label %L2, label %L1
L2:
  call void @k_die(ptr @s94)
  unreachable
L1:
  %t8 = insertvalue %KValue { i64 0, i64 undef }, i64 %t6, 1
  %t9 = extractvalue %KValue %t8, 1
  call void @k_beat_push()
  %t10 = call tailcc %KValue @"d_query/indent_onto_2"(%KValue %t2, i64 %t9)
  %t11 = call %KValue @k_beat_pop(%KValue %t10)
  %t12 = extractvalue %KValue %x1, 0
  %t13 = icmp eq i64 %t12, 13
  %t14 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t15 = icmp eq i64 %t14, 0
  %t16 = and i1 %t13, %t15
  br i1 %t16, label %L3, label %L4
L3:
  %t17 = extractvalue %KValue %x1, 1
  %t18 = inttoptr i64 %t17 to ptr
  %t19 = getelementptr %KBytes, ptr %t18, i64 0, i32 0
  %t20 = load i64, ptr %t19
  %t21 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t22 = icmp sge i64 %t21, 1
  %t23 = icmp sle i64 %t21, %t20
  %t24 = and i1 %t22, %t23
  br i1 %t24, label %L6, label %L4
L6:
  %t25 = getelementptr %KBytes, ptr %t18, i64 0, i32 1
  %t26 = load ptr, ptr %t25
  %t27 = add i64 %t21, -1
  %t28 = getelementptr i8, ptr %t26, i64 %t27
  %t29 = load i8, ptr %t28
  %t30 = zext i8 %t29 to i64
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t30, 1
  br label %L5
L4:
  %t32 = call %KValue @k_b_at(%KValue %x1, %KValue { i64 0, i64 1 })
  br label %L5
L5:
  %t33 = phi %KValue [ %t31, %L6 ], [ %t32, %L4 ]
  %t34 = extractvalue %KValue %x2, 1
  %t35 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t36 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t34, i64 %t35)
  %t37 = extractvalue { i64, i1 } %t36, 0
  %t38 = extractvalue { i64, i1 } %t36, 1
  br i1 %t38, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t39 = insertvalue %KValue { i64 0, i64 undef }, i64 %t37, 1
  %t40 = extractvalue %KValue %t39, 1
  %t41 = call tailcc %KValue @"d_query/pretty_onto_3"(%KValue %t11, %KValue %t33, i64 %t40)
  %t42 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t43 = extractvalue %KValue %x2, 1
  call void @k_beat_push()
  %t44 = call tailcc %KValue @"d_query/pretty_elems_4"(%KValue %t41, %KValue %x1, i64 %t42, i64 %t43)
  %t45 = call %KValue @k_beat_pop(%KValue %t44)
  %t46 = call %KValue @k_str_lit(ptr @s431, i64 1, ptr @s431_lit)
  %t47 = call %KValue @k_b_append_mut(%KValue %t45, %KValue %t46)
  %t48 = extractvalue %KValue %x2, 1
  call void @k_beat_push()
  %t49 = call tailcc %KValue @"d_query/indent_onto_2"(%KValue %t47, i64 %t48)
  %t50 = call %KValue @k_beat_pop(%KValue %t49)
  %t51 = call %KValue @k_b_append_mut(%KValue %t50, %KValue { i64 0, i64 93 })
  ret %KValue %t51
fail0:
  %t52 = call i64 @k_not_failure(%KValue %x0)
  %t53 = icmp ne i64 %t52, 0
  br i1 %t53, label %L10, label %L9
L9:
  %t54 = call %KValue @k_err_hop(%KValue %x0, ptr @s430)
  ret %KValue %t54
L10:
  %t55 = call i64 @k_not_failure(%KValue %x1)
  %t56 = icmp ne i64 %t55, 0
  br i1 %t56, label %L12, label %L11
L11:
  %t57 = call %KValue @k_err_hop(%KValue %x1, ptr @s430)
  ret %KValue %t57
L12:
  %t58 = call i64 @k_not_failure(%KValue %x2)
  %t59 = icmp ne i64 %t58, 0
  br i1 %t59, label %L14, label %L13
L13:
  %t60 = call %KValue @k_err_hop(%KValue %x2, ptr @s430)
  ret %KValue %t60
L14:
  call void @k_die(ptr @s432)
  unreachable
}

define tailcc %KValue @"d_query/pretty_map_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_b_entries(%KValue %x1)
  %t2 = call %KValue @k_str_lit(ptr @s434, i64 2, ptr @s434_lit)
  %t3 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t2)
  %t4 = extractvalue %KValue %t1, 0
  %t5 = icmp eq i64 %t4, 13
  %t6 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t7 = icmp eq i64 %t6, 0
  %t8 = and i1 %t5, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = extractvalue %KValue %t1, 1
  %t10 = inttoptr i64 %t9 to ptr
  %t11 = getelementptr %KBytes, ptr %t10, i64 0, i32 0
  %t12 = load i64, ptr %t11
  %t13 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t14 = icmp sge i64 %t13, 1
  %t15 = icmp sle i64 %t13, %t12
  %t16 = and i1 %t14, %t15
  br i1 %t16, label %L4, label %L2
L4:
  %t17 = getelementptr %KBytes, ptr %t10, i64 0, i32 1
  %t18 = load ptr, ptr %t17
  %t19 = add i64 %t13, -1
  %t20 = getelementptr i8, ptr %t18, i64 %t19
  %t21 = load i8, ptr %t20
  %t22 = zext i8 %t21 to i64
  %t23 = insertvalue %KValue { i64 0, i64 undef }, i64 %t22, 1
  br label %L3
L2:
  %t24 = call %KValue @k_b_at(%KValue %t1, %KValue { i64 0, i64 1 })
  br label %L3
L3:
  %t25 = phi %KValue [ %t23, %L4 ], [ %t24, %L2 ]
  %t26 = extractvalue %KValue %x2, 1
  %t27 = call tailcc %KValue @"d_query/pretty_entry_3"(%KValue %t3, %KValue %t25, i64 %t26)
  %t28 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t29 = extractvalue %KValue %x2, 1
  call void @k_beat_push()
  %t30 = call tailcc %KValue @"d_query/pretty_pairs_4"(%KValue %t27, %KValue %t1, i64 %t28, i64 %t29)
  %t31 = call %KValue @k_beat_pop(%KValue %t30)
  %t32 = call %KValue @k_str_lit(ptr @s431, i64 1, ptr @s431_lit)
  %t33 = call %KValue @k_b_append_mut(%KValue %t31, %KValue %t32)
  %t34 = extractvalue %KValue %x2, 1
  call void @k_beat_push()
  %t35 = call tailcc %KValue @"d_query/indent_onto_2"(%KValue %t33, i64 %t34)
  %t36 = call %KValue @k_beat_pop(%KValue %t35)
  %t37 = call %KValue @k_b_append_mut(%KValue %t36, %KValue { i64 0, i64 125 })
  ret %KValue %t37
fail0:
  %t38 = call i64 @k_not_failure(%KValue %x0)
  %t39 = icmp ne i64 %t38, 0
  br i1 %t39, label %L6, label %L5
L5:
  %t40 = call %KValue @k_err_hop(%KValue %x0, ptr @s433)
  ret %KValue %t40
L6:
  %t41 = call i64 @k_not_failure(%KValue %x1)
  %t42 = icmp ne i64 %t41, 0
  br i1 %t42, label %L8, label %L7
L7:
  %t43 = call %KValue @k_err_hop(%KValue %x1, ptr @s433)
  ret %KValue %t43
L8:
  %t44 = call i64 @k_not_failure(%KValue %x2)
  %t45 = icmp ne i64 %t44, 0
  br i1 %t45, label %L10, label %L9
L9:
  %t46 = call %KValue @k_err_hop(%KValue %x2, ptr @s433)
  ret %KValue %t46
L10:
  call void @k_die(ptr @s435)
  unreachable
}

define tailcc %KValue @"d_query/pretty_onto_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1, 0
  %t4 = icmp eq i64 %t3, 2
  br i1 %t4, label %L2, label %fail0
L2:
  %t5 = call %KValue @k_str_lit(ptr @s329, i64 4, ptr @s329_lit)
  %t6 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t5)
  ret %KValue %t6
fail0:
  %t7 = call i64 @k_not_failure(%KValue %x0)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L3, label %fail1
L3:
  %t9 = extractvalue %KValue %x1, 0
  %t10 = icmp eq i64 %t9, 3
  br i1 %t10, label %L4, label %fail1
L4:
  %t11 = call %KValue @k_str_lit(ptr @s330, i64 5, ptr @s330_lit)
  %t12 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t11)
  ret %KValue %t12
fail1:
  %t13 = call i64 @k_not_failure(%KValue %x0)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L5, label %fail2
L5:
  %t15 = call i64 @k_check_rec(%KValue %x1, i64 35, i64 0)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L6, label %fail2
L6:
  %t17 = call %KValue @k_str_lit(ptr @s331, i64 4, ptr @s331_lit)
  %t18 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t17)
  ret %KValue %t18
fail2:
  %t19 = call i64 @k_not_failure(%KValue %x0)
  %t20 = icmp ne i64 %t19, 0
  br i1 %t20, label %L7, label %fail3
L7:
  %t21 = call i64 @k_check_tag(%KValue %x1, i64 0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L8, label %fail3
L8:
  %t23 = call %KValue @"d_render/to_string_1"(%KValue %x1)
  %t24 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t23)
  ret %KValue %t24
fail3:
  %t25 = call i64 @k_not_failure(%KValue %x0)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L9, label %fail4
L9:
  %t27 = call i64 @k_check_tag(%KValue %x1, i64 1)
  %t28 = icmp ne i64 %t27, 0
  br i1 %t28, label %L10, label %fail4
L10:
  %t29 = call %KValue @"d_render/to_string_1"(%KValue %x1)
  %t30 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t29)
  ret %KValue %t30
fail4:
  %t31 = call i64 @k_not_failure(%KValue %x0)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L11, label %fail5
L11:
  %t33 = call i64 @k_check_tag(%KValue %x1, i64 6)
  %t34 = icmp ne i64 %t33, 0
  br i1 %t34, label %L12, label %fail5
L12:
  %t35 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 34 })
  %t36 = call tailcc %KValue @"d_query/escape_onto_2"(%KValue %t35, %KValue %x1)
  %t37 = call %KValue @k_b_append_mut(%KValue %t36, %KValue { i64 0, i64 34 })
  ret %KValue %t37
fail5:
  %t38 = call i64 @k_not_failure(%KValue %x0)
  %t39 = icmp ne i64 %t38, 0
  br i1 %t39, label %L13, label %fail6
L13:
  %t40 = call i64 @k_check_tag(%KValue %x1, i64 9)
  %t41 = icmp ne i64 %t40, 0
  br i1 %t41, label %L14, label %fail6
L14:
  %t42 = call %KValue @k_b_length_fast(%KValue %x1)
  %t43 = extractvalue %KValue %t42, 0
  %t44 = extractvalue %KValue { i64 0, i64 0 }, 0
  %t45 = icmp eq i64 %t43, 0
  %t46 = icmp eq i64 %t44, 0
  %t47 = and i1 %t45, %t46
  br i1 %t47, label %L15, label %L16
L15:
  %t48 = extractvalue %KValue %t42, 1
  %t49 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t50 = icmp eq i64 %t48, %t49
  %t51 = select i1 %t50, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L17
L16:
  %t52 = call %KValue @k_cmp(%KValue %t42, %KValue { i64 0, i64 0 }, i64 0)
  br label %L17
L17:
  %t53 = phi %KValue [ %t51, %L15 ], [ %t52, %L16 ]
  %t54 = call i64 @k_not_failure(%KValue %t53)
  %t55 = icmp ne i64 %t54, 0
  br i1 %t55, label %L18, label %L19
L19:
  ret %KValue %t53
L18:
  %t56 = call i64 @k_truthy(%KValue %t53)
  %t57 = icmp ne i64 %t56, 0
  br i1 %t57, label %L20, label %L21
L20:
  %t58 = call %KValue @k_str_lit(ptr @s297, i64 2, ptr @s297_lit)
  %t59 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t58)
  ret %KValue %t59
L21:
  %t60 = extractvalue %KValue %x2, 1
  %t61 = musttail call tailcc %KValue @"d_query/pretty_list_3"(%KValue %x0, %KValue %x1, i64 %t60)
  ret %KValue %t61
fail6:
  %t62 = call i64 @k_not_failure(%KValue %x0)
  %t63 = icmp ne i64 %t62, 0
  br i1 %t63, label %L22, label %fail7
L22:
  %t64 = call i64 @k_check_tag(%KValue %x1, i64 10)
  %t65 = icmp ne i64 %t64, 0
  br i1 %t65, label %L23, label %fail7
L23:
  %t66 = call %KValue @k_b_length_fast(%KValue %x1)
  %t67 = extractvalue %KValue %t66, 0
  %t68 = extractvalue %KValue { i64 0, i64 0 }, 0
  %t69 = icmp eq i64 %t67, 0
  %t70 = icmp eq i64 %t68, 0
  %t71 = and i1 %t69, %t70
  br i1 %t71, label %L24, label %L25
L24:
  %t72 = extractvalue %KValue %t66, 1
  %t73 = extractvalue %KValue { i64 0, i64 0 }, 1
  %t74 = icmp eq i64 %t72, %t73
  %t75 = select i1 %t74, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L26
L25:
  %t76 = call %KValue @k_cmp(%KValue %t66, %KValue { i64 0, i64 0 }, i64 0)
  br label %L26
L26:
  %t77 = phi %KValue [ %t75, %L24 ], [ %t76, %L25 ]
  %t78 = call i64 @k_not_failure(%KValue %t77)
  %t79 = icmp ne i64 %t78, 0
  br i1 %t79, label %L27, label %L28
L28:
  ret %KValue %t77
L27:
  %t80 = call i64 @k_truthy(%KValue %t77)
  %t81 = icmp ne i64 %t80, 0
  br i1 %t81, label %L29, label %L30
L29:
  %t82 = call %KValue @k_str_lit(ptr @s332, i64 2, ptr @s332_lit)
  %t83 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t82)
  ret %KValue %t83
L30:
  %t84 = extractvalue %KValue %x2, 1
  %t85 = musttail call tailcc %KValue @"d_query/pretty_map_3"(%KValue %x0, %KValue %x1, i64 %t84)
  ret %KValue %t85
fail7:
  %t86 = call i64 @k_not_failure(%KValue %x0)
  %t87 = icmp ne i64 %t86, 0
  br i1 %t87, label %L32, label %L31
L31:
  %t88 = call %KValue @k_err_hop(%KValue %x0, ptr @s436)
  ret %KValue %t88
L32:
  %t89 = call i64 @k_not_failure(%KValue %x1)
  %t90 = icmp ne i64 %t89, 0
  br i1 %t90, label %L34, label %L33
L33:
  %t91 = call %KValue @k_err_hop(%KValue %x1, ptr @s436)
  ret %KValue %t91
L34:
  %t92 = call i64 @k_not_failure(%KValue %x2)
  %t93 = icmp ne i64 %t92, 0
  br i1 %t93, label %L36, label %L35
L35:
  %t94 = call %KValue @k_err_hop(%KValue %x2, ptr @s436)
  ret %KValue %t94
L36:
  call void @k_die(ptr @s437)
  unreachable
}

define tailcc %KValue @"d_query/pretty_pairs_4"(%KValue %x0, %KValue %x1, i64 %x2r, i64 %x3r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_b_length_fast(%KValue %x1)
  %t4 = extractvalue %KValue %t3, 1
  %t5 = extractvalue %KValue %x2, 1
  %t6 = icmp slt i64 %t4, %t5
  %t7 = select i1 %t6, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t8 = call i64 @k_not_failure(%KValue %t7)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %L3
L3:
  ret %KValue %t7
L2:
  %t10 = call i64 @k_truthy(%KValue %t7)
  %t11 = icmp ne i64 %t10, 0
  br i1 %t11, label %L4, label %L5
L4:
  ret %KValue %x0
L5:
  %t12 = extractvalue %KValue %x1, 0
  %t13 = icmp eq i64 %t12, 13
  %t14 = extractvalue %KValue %x2, 0
  %t15 = icmp eq i64 %t14, 0
  %t16 = and i1 %t13, %t15
  br i1 %t16, label %L6, label %L7
L6:
  %t17 = extractvalue %KValue %x1, 1
  %t18 = inttoptr i64 %t17 to ptr
  %t19 = getelementptr %KBytes, ptr %t18, i64 0, i32 0
  %t20 = load i64, ptr %t19
  %t21 = extractvalue %KValue %x2, 1
  %t22 = icmp sge i64 %t21, 1
  %t23 = icmp sle i64 %t21, %t20
  %t24 = and i1 %t22, %t23
  br i1 %t24, label %L9, label %L7
L9:
  %t25 = getelementptr %KBytes, ptr %t18, i64 0, i32 1
  %t26 = load ptr, ptr %t25
  %t27 = add i64 %t21, -1
  %t28 = getelementptr i8, ptr %t26, i64 %t27
  %t29 = load i8, ptr %t28
  %t30 = zext i8 %t29 to i64
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t30, 1
  br label %L8
L7:
  %t32 = call %KValue @k_b_at(%KValue %x1, %KValue %x2)
  br label %L8
L8:
  %t33 = phi %KValue [ %t31, %L9 ], [ %t32, %L7 ]
  %t34 = extractvalue %KValue %x3, 1
  %t35 = call tailcc %KValue @"d_query/pair_row_3"(%KValue %x0, %KValue %t33, i64 %t34)
  %t36 = extractvalue %KValue %x2, 1
  %t37 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t38 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t36, i64 %t37)
  %t39 = extractvalue { i64, i1 } %t38, 0
  %t40 = extractvalue { i64, i1 } %t38, 1
  br i1 %t40, label %L11, label %L10
L11:
  call void @k_die(ptr @s94)
  unreachable
L10:
  %t41 = insertvalue %KValue { i64 0, i64 undef }, i64 %t39, 1
  call void @k_beat_iter()
  %t42 = extractvalue %KValue %t41, 1
  %t43 = extractvalue %KValue %x3, 1
  %t44 = musttail call tailcc %KValue @"d_query/pretty_pairs_4"(%KValue %t35, %KValue %x1, i64 %t42, i64 %t43)
  ret %KValue %t44
fail0:
  %t45 = call i64 @k_not_failure(%KValue %x0)
  %t46 = icmp ne i64 %t45, 0
  br i1 %t46, label %L13, label %L12
L12:
  %t47 = call %KValue @k_err_hop(%KValue %x0, ptr @s438)
  ret %KValue %t47
L13:
  %t48 = call i64 @k_not_failure(%KValue %x1)
  %t49 = icmp ne i64 %t48, 0
  br i1 %t49, label %L15, label %L14
L14:
  %t50 = call %KValue @k_err_hop(%KValue %x1, ptr @s438)
  ret %KValue %t50
L15:
  %t51 = call i64 @k_not_failure(%KValue %x2)
  %t52 = icmp ne i64 %t51, 0
  br i1 %t52, label %L17, label %L16
L16:
  %t53 = call %KValue @k_err_hop(%KValue %x2, ptr @s438)
  ret %KValue %t53
L17:
  %t54 = call i64 @k_not_failure(%KValue %x3)
  %t55 = icmp ne i64 %t54, 0
  br i1 %t55, label %L19, label %L18
L18:
  %t56 = call %KValue @k_err_hop(%KValue %x3, ptr @s438)
  ret %KValue %t56
L19:
  call void @k_die(ptr @s439)
  unreachable
}

define tailcc %KValue @"d_query/expect_char_3"(%KValue %x0, i64 %x1r, i64 %x2r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x0, 1
  %t2 = inttoptr i64 %t1 to ptr
  %t3 = getelementptr %KBytes, ptr %t2, i64 0, i32 0
  %t4 = load i64, ptr %t3
  %t5 = extractvalue %KValue %x1, 1
  %t6 = icmp sge i64 %t5, 1
  %t7 = icmp sle i64 %t5, %t4
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = getelementptr %KBytes, ptr %t2, i64 0, i32 1
  %t10 = load ptr, ptr %t9
  %t11 = add i64 %t5, -1
  %t12 = getelementptr i8, ptr %t10, i64 %t11
  %t13 = load i8, ptr %t12
  %t14 = zext i8 %t13 to i64
  %t15 = insertvalue %KValue { i64 0, i64 undef }, i64 %t14, 1
  br label %L3
L2:
  br label %L3
L3:
  %t16 = phi %KValue [ %t15, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t17 = extractvalue %KValue %x1, 1
  %t18 = extractvalue %KValue %x2, 1
  %t19 = musttail call tailcc %KValue @"d_query/expect_check_3"(%KValue %t16, i64 %t17, i64 %t18)
  ret %KValue %t19
fail0:
  %t20 = call i64 @k_not_failure(%KValue %x0)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L5, label %L4
L4:
  %t22 = call %KValue @k_err_hop(%KValue %x0, ptr @s440)
  ret %KValue %t22
L5:
  %t23 = call i64 @k_not_failure(%KValue %x1)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L7, label %L6
L6:
  %t25 = call %KValue @k_err_hop(%KValue %x1, ptr @s440)
  ret %KValue %t25
L7:
  %t26 = call i64 @k_not_failure(%KValue %x2)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L9, label %L8
L8:
  %t28 = call %KValue @k_err_hop(%KValue %x2, ptr @s440)
  ret %KValue %t28
L9:
  call void @k_die(ptr @s441)
  unreachable
}

define tailcc %KValue @"d_query/expect_check_3"(%KValue %x0, i64 %x1r, i64 %x2r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x0, 0
  %t2 = extractvalue %KValue %x2, 0
  %t3 = icmp eq i64 %t1, 0
  %t4 = icmp eq i64 %t2, 0
  %t5 = and i1 %t3, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %x0, 1
  %t7 = extractvalue %KValue %x2, 1
  %t8 = icmp eq i64 %t6, %t7
  %t9 = select i1 %t8, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t10 = call %KValue @k_cmp(%KValue %x0, %KValue %x2, i64 0)
  br label %L3
L3:
  %t11 = phi %KValue [ %t9, %L1 ], [ %t10, %L2 ]
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L5
L5:
  ret %KValue %t11
L4:
  %t14 = call i64 @k_truthy(%KValue %t11)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %L7
L6:
  %t16 = extractvalue %KValue %x1, 1
  %t17 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t18 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t16, i64 %t17)
  %t19 = extractvalue { i64, i1 } %t18, 0
  %t20 = extractvalue { i64, i1 } %t18, 1
  br i1 %t20, label %L9, label %L8
L9:
  call void @k_die(ptr @s94)
  unreachable
L8:
  %t21 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  ret %KValue %t21
L7:
  %t22 = call %KValue @k_str_lit(ptr @s443, i64 10, ptr @s443_lit)
  %t23 = alloca [1 x %KValue]
  %t24 = getelementptr [1 x %KValue], ptr %t23, i64 0, i64 0
  store %KValue %x2, ptr %t24
  %t25 = call %KValue @k_list_lit(i64 1, ptr %t23)
  %t26 = call %KValue @"d_query/text/utf8_1"(%KValue %t25)
  %t27 = call %KValue @k_render(%KValue %t26, i64 0)
  %t28 = call %KValue @k_str_lit(ptr @s399, i64 1, ptr @s399_lit)
  %t29 = alloca [3 x %KValue]
  %t30 = getelementptr [3 x %KValue], ptr %t29, i64 0, i64 0
  store %KValue %t22, ptr %t30
  %t31 = getelementptr [3 x %KValue], ptr %t29, i64 0, i64 1
  store %KValue %t27, ptr %t31
  %t32 = getelementptr [3 x %KValue], ptr %t29, i64 0, i64 2
  store %KValue %t28, ptr %t32
  %t33 = call %KValue @k_concat_arr(i64 3, ptr %t29)
  %t34 = extractvalue %KValue %x1, 1
  %t35 = musttail call tailcc %KValue @"d_query/fail_2"(i64 %t34, %KValue %t33)
  ret %KValue %t35
fail0:
  %t36 = call i64 @k_not_failure(%KValue %x0)
  %t37 = icmp ne i64 %t36, 0
  br i1 %t37, label %L11, label %L10
L10:
  %t38 = call %KValue @k_err_hop(%KValue %x0, ptr @s442)
  ret %KValue %t38
L11:
  %t39 = call i64 @k_not_failure(%KValue %x1)
  %t40 = icmp ne i64 %t39, 0
  br i1 %t40, label %L13, label %L12
L12:
  %t41 = call %KValue @k_err_hop(%KValue %x1, ptr @s442)
  ret %KValue %t41
L13:
  %t42 = call i64 @k_not_failure(%KValue %x2)
  %t43 = icmp ne i64 %t42, 0
  br i1 %t43, label %L15, label %L14
L14:
  %t44 = call %KValue @k_err_hop(%KValue %x2, ptr @s442)
  ret %KValue %t44
L15:
  call void @k_die(ptr @s444)
  unreachable
}

define tailcc %KValue @"d_query/fail_2"(i64 %x0r, %KValue %x1) {
entry:
  %x0 = insertvalue %KValue { i64 0, i64 undef }, i64 %x0r, 1
  %t1 = call i64 @k_not_failure(%KValue %x1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = alloca [2 x %KValue]
  %t4 = getelementptr [2 x %KValue], ptr %t3, i64 0, i64 0
  store %KValue %x0, ptr %t4
  %t5 = getelementptr [2 x %KValue], ptr %t3, i64 0, i64 1
  store %KValue %x1, ptr %t5
  %t6 = call %KValue @k_rec_reuse(i64 36, i64 2, ptr %t3, %KValue %x1)
  %t7 = call %KValue @k_err(%KValue %t6, ptr @s446)
  ret %KValue %t7
fail0:
  %t8 = call i64 @k_not_failure(%KValue %x0)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L2
L2:
  %t10 = call %KValue @k_err_hop(%KValue %x0, ptr @s445)
  ret %KValue %t10
L3:
  %t11 = call i64 @k_not_failure(%KValue %x1)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L5, label %L4
L4:
  %t13 = call %KValue @k_err_hop(%KValue %x1, ptr @s445)
  ret %KValue %t13
L5:
  call void @k_die(ptr @s447)
  unreachable
}

define tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x0, 1
  %t2 = inttoptr i64 %t1 to ptr
  %t3 = getelementptr %KBytes, ptr %t2, i64 0, i32 0
  %t4 = load i64, ptr %t3
  %t5 = extractvalue %KValue %x1, 1
  %t6 = icmp sge i64 %t5, 1
  %t7 = icmp sle i64 %t5, %t4
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L1, label %L2
L1:
  %t9 = getelementptr %KBytes, ptr %t2, i64 0, i32 1
  %t10 = load ptr, ptr %t9
  %t11 = add i64 %t5, -1
  %t12 = getelementptr i8, ptr %t10, i64 %t11
  %t13 = load i8, ptr %t12
  %t14 = zext i8 %t13 to i64
  %t15 = insertvalue %KValue { i64 0, i64 undef }, i64 %t14, 1
  br label %L3
L2:
  br label %L3
L3:
  %t16 = phi %KValue [ %t15, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t17 = extractvalue %KValue %t16, 0
  %t18 = extractvalue %KValue %t16, 1
  %t19 = icmp eq i64 %t17, 4
  %t20 = select i1 %t19, i64 256, i64 %t18
  %t21 = call %KValue @"d_query/ws?_1"(i64 %t20)
  %t22 = call i64 @k_not_failure(%KValue %t21)
  %t23 = icmp ne i64 %t22, 0
  br i1 %t23, label %L4, label %L5
L5:
  ret %KValue %t21
L4:
  %t24 = call i64 @k_truthy(%KValue %t21)
  %t25 = icmp ne i64 %t24, 0
  br i1 %t25, label %L6, label %L7
L6:
  %t26 = extractvalue %KValue %x1, 1
  %t27 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t28 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t26, i64 %t27)
  %t29 = extractvalue { i64, i1 } %t28, 0
  %t30 = extractvalue { i64, i1 } %t28, 1
  br i1 %t30, label %L9, label %L8
L9:
  call void @k_die(ptr @s94)
  unreachable
L8:
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t29, 1
  %t32 = extractvalue %KValue %t31, 1
  %t33 = musttail call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t32)
  ret %KValue %t33
L7:
  ret %KValue %x1
fail0:
  %t34 = call i64 @k_not_failure(%KValue %x0)
  %t35 = icmp ne i64 %t34, 0
  br i1 %t35, label %L11, label %L10
L10:
  %t36 = call %KValue @k_err_hop(%KValue %x0, ptr @s448)
  ret %KValue %t36
L11:
  %t37 = call i64 @k_not_failure(%KValue %x1)
  %t38 = icmp ne i64 %t37, 0
  br i1 %t38, label %L13, label %L12
L12:
  %t39 = call %KValue @k_err_hop(%KValue %x1, ptr @s448)
  ret %KValue %t39
L13:
  call void @k_die(ptr @s449)
  unreachable
}

define %KValue @"d_query/ws?_1"(i64 %x0r) {
entry:
  %t1 = icmp eq i64 %x0r, 256
  %x0b = insertvalue %KValue { i64 0, i64 undef }, i64 %x0r, 1
  %x0 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x0b
  br label %L1
L1:
  %t2 = extractvalue %KValue %x0, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x0, 1
  switch i64 %t4, label %arm5 [
    i64 9, label %arm0
    i64 10, label %arm1
    i64 13, label %arm2
    i64 32, label %arm3
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm4, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm5, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x0, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x0, ptr @s450)
  ret %KValue %t12
L6:
  call void @k_die(ptr @s451)
  unreachable
arm0:
  ret %KValue { i64 2, i64 0 }
arm1:
  ret %KValue { i64 2, i64 0 }
arm2:
  ret %KValue { i64 2, i64 0 }
arm3:
  ret %KValue { i64 2, i64 0 }
arm4:
  ret %KValue { i64 3, i64 0 }
arm5:
  ret %KValue { i64 3, i64 0 }
}

define tailcc %KValue @"d_query/esc_byte_2"(%KValue %x0, %KValue %x1) {
entry:
  br label %L1
L1:
  %t1 = extractvalue %KValue %x1, 0
  %t2 = icmp eq i64 %t1, 0
  br i1 %t2, label %L2, label %L3
L2:
  %t3 = extractvalue %KValue %x1, 1
  switch i64 %t3, label %arm5 [
    i64 9, label %arm0
    i64 10, label %arm1
    i64 13, label %arm2
    i64 34, label %arm3
    i64 92, label %arm4
  ]
L3:
  %t4 = call i64 @k_not_failure(%KValue %x1)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %arm5, label %nomatch
nomatch:
  %t6 = extractvalue %KValue %x1, 0
  %t7 = icmp eq i64 %t6, 5
  %t8 = icmp eq i64 %t6, 4
  %t9 = or i1 %t7, %t8
  br i1 %t9, label %L4, label %L5
L4:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s452)
  ret %KValue %t10
L5:
  call void @k_die(ptr @s453)
  unreachable
arm0:
  %t11 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 92 })
  %t12 = call %KValue @k_b_append_mut(%KValue %t11, %KValue { i64 0, i64 116 })
  ret %KValue %t12
arm1:
  %t13 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 92 })
  %t14 = call %KValue @k_b_append_mut(%KValue %t13, %KValue { i64 0, i64 110 })
  ret %KValue %t14
arm2:
  %t15 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 92 })
  %t16 = call %KValue @k_b_append_mut(%KValue %t15, %KValue { i64 0, i64 114 })
  ret %KValue %t16
arm3:
  %t17 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 92 })
  %t18 = call %KValue @k_b_append_mut(%KValue %t17, %KValue { i64 0, i64 34 })
  ret %KValue %t18
arm4:
  %t19 = call %KValue @k_b_append_mut(%KValue %x0, %KValue { i64 0, i64 92 })
  %t20 = call %KValue @k_b_append_mut(%KValue %t19, %KValue { i64 0, i64 92 })
  ret %KValue %t20
arm5:
  %t21 = extractvalue %KValue %x1, 0
  %t22 = extractvalue %KValue { i64 0, i64 32 }, 0
  %t23 = icmp eq i64 %t21, 0
  %t24 = icmp eq i64 %t22, 0
  %t25 = and i1 %t23, %t24
  br i1 %t25, label %L6, label %L7
L6:
  %t26 = extractvalue %KValue %x1, 1
  %t27 = extractvalue %KValue { i64 0, i64 32 }, 1
  %t28 = icmp slt i64 %t26, %t27
  %t29 = select i1 %t28, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L8
L7:
  %t30 = call %KValue @k_cmp(%KValue %x1, %KValue { i64 0, i64 32 }, i64 2)
  br label %L8
L8:
  %t31 = phi %KValue [ %t29, %L6 ], [ %t30, %L7 ]
  %t32 = call i64 @k_not_failure(%KValue %t31)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L9, label %L10
L10:
  ret %KValue %t31
L9:
  %t34 = call i64 @k_truthy(%KValue %t31)
  %t35 = icmp ne i64 %t34, 0
  br i1 %t35, label %L11, label %L12
L11:
  %t36 = musttail call tailcc %KValue @"d_query/u_bytes_2"(%KValue %x0, %KValue %x1)
  ret %KValue %t36
L12:
  %t37 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %x1)
  ret %KValue %t37
}

define tailcc %KValue @klam21(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %t1 = musttail call tailcc %KValue @"d_query/esc_byte_2"(%KValue %a0, %KValue %a1)
  ret %KValue %t1
}

define %KValue @w_klam21(ptr %env, %KValue %a0, %KValue %a1) {
entry:
  %r = call tailcc %KValue @klam21(ptr %env, %KValue %a0, %KValue %a1)
  ret %KValue %r
}

define tailcc %KValue @"d_query/escape_able_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = call %KValue @k_closure(ptr @w_klam21, i64 2, i64 0, ptr %t1)
  %t3 = musttail call tailcc %KValue @"d_query/list/fold_3"(%KValue %x1, %KValue %x0, %KValue %t2)
  ret %KValue %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s454)
  ret %KValue %t6
L2:
  %t7 = call i64 @k_not_failure(%KValue %x1)
  %t8 = icmp ne i64 %t7, 0
  br i1 %t8, label %L4, label %L3
L3:
  %t9 = call %KValue @k_err_hop(%KValue %x1, ptr @s454)
  ret %KValue %t9
L4:
  call void @k_die(ptr @s455)
  unreachable
}

define tailcc %KValue @"d_query/escape_clean_4"(%KValue %x0, %KValue %x1, %KValue %x2, i64 %x3r) {
entry:
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  %t1 = call %KValue @k_b_length_fast(%KValue %x2)
  %t2 = extractvalue %KValue %t1, 1
  %t3 = extractvalue %KValue %x3, 1
  %t4 = icmp slt i64 %t2, %t3
  %t5 = select i1 %t4, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  %t6 = call i64 @k_not_failure(%KValue %t5)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L1, label %L2
L2:
  ret %KValue %t5
L1:
  %t8 = call i64 @k_truthy(%KValue %t5)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L3, label %L4
L3:
  %t10 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %x1)
  ret %KValue %t10
L4:
  %t11 = musttail call tailcc %KValue @"d_query/escape_able_2"(%KValue %x0, %KValue %x2)
  ret %KValue %t11
fail0:
  %t12 = call i64 @k_not_failure(%KValue %x0)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L6, label %L5
L5:
  %t14 = call %KValue @k_err_hop(%KValue %x0, ptr @s456)
  ret %KValue %t14
L6:
  %t15 = call i64 @k_not_failure(%KValue %x1)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L8, label %L7
L7:
  %t17 = call %KValue @k_err_hop(%KValue %x1, ptr @s456)
  ret %KValue %t17
L8:
  %t18 = call i64 @k_not_failure(%KValue %x2)
  %t19 = icmp ne i64 %t18, 0
  br i1 %t19, label %L10, label %L9
L9:
  %t20 = call %KValue @k_err_hop(%KValue %x2, ptr @s456)
  ret %KValue %t20
L10:
  %t21 = call i64 @k_not_failure(%KValue %x3)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L12, label %L11
L11:
  %t23 = call %KValue @k_err_hop(%KValue %x3, ptr @s456)
  ret %KValue %t23
L12:
  call void @k_die(ptr @s457)
  unreachable
}

define tailcc %KValue @"d_query/escape_onto_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_bytes(%KValue %x1)
  %t2 = call %KValue @k_b_find2_below(%KValue %t1, %KValue { i64 0, i64 1 }, %KValue { i64 0, i64 34 }, %KValue { i64 0, i64 92 }, %KValue { i64 0, i64 32 })
  %t3 = extractvalue %KValue %t2, 1
  %t4 = musttail call tailcc %KValue @"d_query/escape_clean_4"(%KValue %x0, %KValue %x1, %KValue %t1, i64 %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s458)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s458)
  ret %KValue %t10
L4:
  call void @k_die(ptr @s459)
  unreachable
}

define %KValue @"d_query/escape_str_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s259, i64 0, ptr @s259_lit)
  %t2 = call %KValue @k_b_bytes(%KValue %t1)
  %t3 = call tailcc %KValue @"d_query/escape_onto_2"(%KValue %t2, %KValue %x0)
  %t4 = call %KValue @"d_query/text/utf8_1"(%KValue %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s460)
  ret %KValue %t7
L2:
  call void @k_die(ptr @s461)
  unreachable
}

define %KValue @"d_query/hex4_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_div(%KValue %x0, %KValue { i64 0, i64 4096 }, ptr @s463)
  %t2 = extractvalue %KValue %t1, 0
  %t3 = extractvalue %KValue { i64 0, i64 4096 }, 0
  %t4 = icmp eq i64 %t2, 0
  %t5 = icmp eq i64 %t3, 0
  %t6 = and i1 %t4, %t5
  br i1 %t6, label %L1, label %L2
L1:
  %t7 = extractvalue %KValue %t1, 1
  %t8 = extractvalue %KValue { i64 0, i64 4096 }, 1
  %t9 = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %t7, i64 %t8)
  %t10 = extractvalue { i64, i1 } %t9, 0
  %t11 = extractvalue { i64, i1 } %t9, 1
  br i1 %t11, label %L2, label %L4
L4:
  %t12 = insertvalue %KValue { i64 0, i64 undef }, i64 %t10, 1
  br label %L3
L2:
  %t13 = call %KValue @k_mul(%KValue %t1, %KValue { i64 0, i64 4096 })
  br label %L3
L3:
  %t14 = phi %KValue [ %t12, %L4 ], [ %t13, %L2 ]
  %t15 = extractvalue %KValue %x0, 0
  %t16 = extractvalue %KValue %t14, 0
  %t17 = icmp eq i64 %t15, 0
  %t18 = icmp eq i64 %t16, 0
  %t19 = and i1 %t17, %t18
  br i1 %t19, label %L5, label %L6
L5:
  %t20 = extractvalue %KValue %x0, 1
  %t21 = extractvalue %KValue %t14, 1
  %t22 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t20, i64 %t21)
  %t23 = extractvalue { i64, i1 } %t22, 0
  %t24 = extractvalue { i64, i1 } %t22, 1
  br i1 %t24, label %L6, label %L8
L8:
  %t25 = insertvalue %KValue { i64 0, i64 undef }, i64 %t23, 1
  br label %L7
L6:
  %t26 = call %KValue @k_sub(%KValue %x0, %KValue %t14)
  br label %L7
L7:
  %t27 = phi %KValue [ %t25, %L8 ], [ %t26, %L6 ]
  %t28 = call %KValue @k_div(%KValue %t27, %KValue { i64 0, i64 256 }, ptr @s464)
  %t29 = extractvalue %KValue %t28, 0
  %t30 = extractvalue %KValue { i64 0, i64 256 }, 0
  %t31 = icmp eq i64 %t29, 0
  %t32 = icmp eq i64 %t30, 0
  %t33 = and i1 %t31, %t32
  br i1 %t33, label %L9, label %L10
L9:
  %t34 = extractvalue %KValue %t28, 1
  %t35 = extractvalue %KValue { i64 0, i64 256 }, 1
  %t36 = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %t34, i64 %t35)
  %t37 = extractvalue { i64, i1 } %t36, 0
  %t38 = extractvalue { i64, i1 } %t36, 1
  br i1 %t38, label %L10, label %L12
L12:
  %t39 = insertvalue %KValue { i64 0, i64 undef }, i64 %t37, 1
  br label %L11
L10:
  %t40 = call %KValue @k_mul(%KValue %t28, %KValue { i64 0, i64 256 })
  br label %L11
L11:
  %t41 = phi %KValue [ %t39, %L12 ], [ %t40, %L10 ]
  %t42 = extractvalue %KValue %t27, 0
  %t43 = extractvalue %KValue %t41, 0
  %t44 = icmp eq i64 %t42, 0
  %t45 = icmp eq i64 %t43, 0
  %t46 = and i1 %t44, %t45
  br i1 %t46, label %L13, label %L14
L13:
  %t47 = extractvalue %KValue %t27, 1
  %t48 = extractvalue %KValue %t41, 1
  %t49 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t47, i64 %t48)
  %t50 = extractvalue { i64, i1 } %t49, 0
  %t51 = extractvalue { i64, i1 } %t49, 1
  br i1 %t51, label %L14, label %L16
L16:
  %t52 = insertvalue %KValue { i64 0, i64 undef }, i64 %t50, 1
  br label %L15
L14:
  %t53 = call %KValue @k_sub(%KValue %t27, %KValue %t41)
  br label %L15
L15:
  %t54 = phi %KValue [ %t52, %L16 ], [ %t53, %L14 ]
  %t55 = call %KValue @k_div(%KValue %t54, %KValue { i64 0, i64 16 }, ptr @s465)
  %t56 = extractvalue %KValue %t55, 0
  %t57 = extractvalue %KValue { i64 0, i64 16 }, 0
  %t58 = icmp eq i64 %t56, 0
  %t59 = icmp eq i64 %t57, 0
  %t60 = and i1 %t58, %t59
  br i1 %t60, label %L17, label %L18
L17:
  %t61 = extractvalue %KValue %t55, 1
  %t62 = extractvalue %KValue { i64 0, i64 16 }, 1
  %t63 = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %t61, i64 %t62)
  %t64 = extractvalue { i64, i1 } %t63, 0
  %t65 = extractvalue { i64, i1 } %t63, 1
  br i1 %t65, label %L18, label %L20
L20:
  %t66 = insertvalue %KValue { i64 0, i64 undef }, i64 %t64, 1
  br label %L19
L18:
  %t67 = call %KValue @k_mul(%KValue %t55, %KValue { i64 0, i64 16 })
  br label %L19
L19:
  %t68 = phi %KValue [ %t66, %L20 ], [ %t67, %L18 ]
  %t69 = extractvalue %KValue %t54, 0
  %t70 = extractvalue %KValue %t68, 0
  %t71 = icmp eq i64 %t69, 0
  %t72 = icmp eq i64 %t70, 0
  %t73 = and i1 %t71, %t72
  br i1 %t73, label %L21, label %L22
L21:
  %t74 = extractvalue %KValue %t54, 1
  %t75 = extractvalue %KValue %t68, 1
  %t76 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t74, i64 %t75)
  %t77 = extractvalue { i64, i1 } %t76, 0
  %t78 = extractvalue { i64, i1 } %t76, 1
  br i1 %t78, label %L22, label %L24
L24:
  %t79 = insertvalue %KValue { i64 0, i64 undef }, i64 %t77, 1
  br label %L23
L22:
  %t80 = call %KValue @k_sub(%KValue %t54, %KValue %t68)
  br label %L23
L23:
  %t81 = phi %KValue [ %t79, %L24 ], [ %t80, %L22 ]
  %t82 = call %KValue @"d_query/hex_char_1"(%KValue %t1)
  %t83 = call %KValue @"d_query/hex_char_1"(%KValue %t28)
  %t84 = call %KValue @"d_query/hex_char_1"(%KValue %t55)
  %t85 = call %KValue @"d_query/hex_char_1"(%KValue %t81)
  %t86 = alloca [4 x %KValue]
  %t87 = getelementptr [4 x %KValue], ptr %t86, i64 0, i64 0
  store %KValue %t82, ptr %t87
  %t88 = getelementptr [4 x %KValue], ptr %t86, i64 0, i64 1
  store %KValue %t83, ptr %t88
  %t89 = getelementptr [4 x %KValue], ptr %t86, i64 0, i64 2
  store %KValue %t84, ptr %t89
  %t90 = getelementptr [4 x %KValue], ptr %t86, i64 0, i64 3
  store %KValue %t85, ptr %t90
  %t91 = call %KValue @k_list_lit(i64 4, ptr %t86)
  %t92 = call %KValue @k_str_lit(ptr @s259, i64 0, ptr @s259_lit)
  %t93 = call %KValue @k_b_join(%KValue %t91, %KValue %t92)
  ret %KValue %t93
fail0:
  %t94 = call i64 @k_not_failure(%KValue %x0)
  %t95 = icmp ne i64 %t94, 0
  br i1 %t95, label %L26, label %L25
L25:
  %t96 = call %KValue @k_err_hop(%KValue %x0, ptr @s462)
  ret %KValue %t96
L26:
  call void @k_die(ptr @s466)
  unreachable
}

define tailcc %KValue @"d_query/hex_alpha_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue { i64 0, i64 96 }, 0
  %t2 = extractvalue %KValue %x0, 0
  %t3 = icmp eq i64 %t1, 0
  %t4 = icmp eq i64 %t2, 0
  %t5 = and i1 %t3, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue { i64 0, i64 96 }, 1
  %t7 = extractvalue %KValue %x0, 1
  %t8 = icmp slt i64 %t6, %t7
  %t9 = select i1 %t8, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t10 = call %KValue @k_cmp(%KValue { i64 0, i64 96 }, %KValue %x0, i64 2)
  br label %L3
L3:
  %t11 = phi %KValue [ %t9, %L1 ], [ %t10, %L2 ]
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L5
L4:
  %t14 = call i64 @k_truthy(%KValue %t11)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %L7
L6:
  %t16 = extractvalue %KValue %x0, 0
  %t17 = extractvalue %KValue { i64 0, i64 103 }, 0
  %t18 = icmp eq i64 %t16, 0
  %t19 = icmp eq i64 %t17, 0
  %t20 = and i1 %t18, %t19
  br i1 %t20, label %L8, label %L9
L8:
  %t21 = extractvalue %KValue %x0, 1
  %t22 = extractvalue %KValue { i64 0, i64 103 }, 1
  %t23 = icmp slt i64 %t21, %t22
  %t24 = select i1 %t23, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L10
L9:
  %t25 = call %KValue @k_cmp(%KValue %x0, %KValue { i64 0, i64 103 }, i64 2)
  br label %L10
L10:
  %t26 = phi %KValue [ %t24, %L8 ], [ %t25, %L9 ]
  br label %L5
L7:
  br label %L5
L5:
  %t27 = phi %KValue [ %t11, %L3 ], [ %t26, %L10 ], [ { i64 3, i64 0 }, %L7 ]
  %t28 = call i64 @k_not_failure(%KValue %t27)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L11, label %L12
L12:
  ret %KValue %t27
L11:
  %t30 = call i64 @k_truthy(%KValue %t27)
  %t31 = icmp ne i64 %t30, 0
  br i1 %t31, label %L13, label %L14
L13:
  %t32 = extractvalue %KValue %x0, 0
  %t33 = extractvalue %KValue { i64 0, i64 87 }, 0
  %t34 = icmp eq i64 %t32, 0
  %t35 = icmp eq i64 %t33, 0
  %t36 = and i1 %t34, %t35
  br i1 %t36, label %L15, label %L16
L15:
  %t37 = extractvalue %KValue %x0, 1
  %t38 = extractvalue %KValue { i64 0, i64 87 }, 1
  %t39 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t37, i64 %t38)
  %t40 = extractvalue { i64, i1 } %t39, 0
  %t41 = extractvalue { i64, i1 } %t39, 1
  br i1 %t41, label %L16, label %L18
L18:
  %t42 = insertvalue %KValue { i64 0, i64 undef }, i64 %t40, 1
  br label %L17
L16:
  %t43 = call %KValue @k_sub(%KValue %x0, %KValue { i64 0, i64 87 })
  br label %L17
L17:
  %t44 = phi %KValue [ %t42, %L18 ], [ %t43, %L16 ]
  ret %KValue %t44
L14:
  %t45 = musttail call tailcc %KValue @"d_query/hex_upper_1"(%KValue %x0)
  ret %KValue %t45
fail0:
  %t46 = call i64 @k_not_failure(%KValue %x0)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L20, label %L19
L19:
  %t48 = call %KValue @k_err_hop(%KValue %x0, ptr @s467)
  ret %KValue %t48
L20:
  call void @k_die(ptr @s468)
  unreachable
}

define %KValue @"d_query/hex_byte_table_0"() {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s470, i64 16, ptr @s470_lit)
  %t2 = call %KValue @k_b_bytes(%KValue %t1)
  ret %KValue %t2
fail0:
  call void @k_die(ptr @s471)
  unreachable
}

define %KValue @"d_query/hex_char_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @"d_query/hex_digits_0"()
  %t4 = extractvalue %KValue %x0, 0
  %t5 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t6 = icmp eq i64 %t4, 0
  %t7 = icmp eq i64 %t5, 0
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L2, label %L3
L2:
  %t9 = extractvalue %KValue %x0, 1
  %t10 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t11 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t9, i64 %t10)
  %t12 = extractvalue { i64, i1 } %t11, 0
  %t13 = extractvalue { i64, i1 } %t11, 1
  br i1 %t13, label %L3, label %L5
L5:
  %t14 = insertvalue %KValue { i64 0, i64 undef }, i64 %t12, 1
  br label %L4
L3:
  %t15 = call %KValue @k_add(%KValue %x0, %KValue { i64 0, i64 1 })
  br label %L4
L4:
  %t16 = phi %KValue [ %t14, %L5 ], [ %t15, %L3 ]
  %t17 = extractvalue %KValue %t3, 0
  %t18 = icmp eq i64 %t17, 13
  %t19 = extractvalue %KValue %t16, 0
  %t20 = icmp eq i64 %t19, 0
  %t21 = and i1 %t18, %t20
  br i1 %t21, label %L6, label %L7
L6:
  %t22 = extractvalue %KValue %t3, 1
  %t23 = inttoptr i64 %t22 to ptr
  %t24 = getelementptr %KBytes, ptr %t23, i64 0, i32 0
  %t25 = load i64, ptr %t24
  %t26 = extractvalue %KValue %t16, 1
  %t27 = icmp sge i64 %t26, 1
  %t28 = icmp sle i64 %t26, %t25
  %t29 = and i1 %t27, %t28
  br i1 %t29, label %L9, label %L7
L9:
  %t30 = getelementptr %KBytes, ptr %t23, i64 0, i32 1
  %t31 = load ptr, ptr %t30
  %t32 = add i64 %t26, -1
  %t33 = getelementptr i8, ptr %t31, i64 %t32
  %t34 = load i8, ptr %t33
  %t35 = zext i8 %t34 to i64
  %t36 = insertvalue %KValue { i64 0, i64 undef }, i64 %t35, 1
  br label %L8
L7:
  %t37 = call %KValue @k_b_at(%KValue %t3, %KValue %t16)
  br label %L8
L8:
  %t38 = phi %KValue [ %t36, %L9 ], [ %t37, %L7 ]
  ret %KValue %t38
fail0:
  %t39 = call i64 @k_not_failure(%KValue %x0)
  %t40 = icmp ne i64 %t39, 0
  br i1 %t40, label %L11, label %L10
L10:
  %t41 = call %KValue @k_err_hop(%KValue %x0, ptr @s472)
  ret %KValue %t41
L11:
  call void @k_die(ptr @s473)
  unreachable
}

define %KValue @"d_query/hex_code_1"(%KValue %x0) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x0)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @"d_query/hex_byte_table_0"()
  %t4 = extractvalue %KValue %x0, 0
  %t5 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t6 = icmp eq i64 %t4, 0
  %t7 = icmp eq i64 %t5, 0
  %t8 = and i1 %t6, %t7
  br i1 %t8, label %L2, label %L3
L2:
  %t9 = extractvalue %KValue %x0, 1
  %t10 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t11 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t9, i64 %t10)
  %t12 = extractvalue { i64, i1 } %t11, 0
  %t13 = extractvalue { i64, i1 } %t11, 1
  br i1 %t13, label %L3, label %L5
L5:
  %t14 = insertvalue %KValue { i64 0, i64 undef }, i64 %t12, 1
  br label %L4
L3:
  %t15 = call %KValue @k_add(%KValue %x0, %KValue { i64 0, i64 1 })
  br label %L4
L4:
  %t16 = phi %KValue [ %t14, %L5 ], [ %t15, %L3 ]
  %t17 = extractvalue %KValue %t3, 0
  %t18 = icmp eq i64 %t17, 13
  %t19 = extractvalue %KValue %t16, 0
  %t20 = icmp eq i64 %t19, 0
  %t21 = and i1 %t18, %t20
  br i1 %t21, label %L6, label %L7
L6:
  %t22 = extractvalue %KValue %t3, 1
  %t23 = inttoptr i64 %t22 to ptr
  %t24 = getelementptr %KBytes, ptr %t23, i64 0, i32 0
  %t25 = load i64, ptr %t24
  %t26 = extractvalue %KValue %t16, 1
  %t27 = icmp sge i64 %t26, 1
  %t28 = icmp sle i64 %t26, %t25
  %t29 = and i1 %t27, %t28
  br i1 %t29, label %L9, label %L7
L9:
  %t30 = getelementptr %KBytes, ptr %t23, i64 0, i32 1
  %t31 = load ptr, ptr %t30
  %t32 = add i64 %t26, -1
  %t33 = getelementptr i8, ptr %t31, i64 %t32
  %t34 = load i8, ptr %t33
  %t35 = zext i8 %t34 to i64
  %t36 = insertvalue %KValue { i64 0, i64 undef }, i64 %t35, 1
  br label %L8
L7:
  %t37 = call %KValue @k_b_at(%KValue %t3, %KValue %t16)
  br label %L8
L8:
  %t38 = phi %KValue [ %t36, %L9 ], [ %t37, %L7 ]
  ret %KValue %t38
fail0:
  %t39 = call i64 @k_not_failure(%KValue %x0)
  %t40 = icmp ne i64 %t39, 0
  br i1 %t40, label %L11, label %L10
L10:
  %t41 = call %KValue @k_err_hop(%KValue %x0, ptr @s474)
  ret %KValue %t41
L11:
  call void @k_die(ptr @s475)
  unreachable
}

define tailcc %KValue @"d_query/hex_digit_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue { i64 0, i64 47 }, 0
  %t2 = extractvalue %KValue %x0, 0
  %t3 = icmp eq i64 %t1, 0
  %t4 = icmp eq i64 %t2, 0
  %t5 = and i1 %t3, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue { i64 0, i64 47 }, 1
  %t7 = extractvalue %KValue %x0, 1
  %t8 = icmp slt i64 %t6, %t7
  %t9 = select i1 %t8, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t10 = call %KValue @k_cmp(%KValue { i64 0, i64 47 }, %KValue %x0, i64 2)
  br label %L3
L3:
  %t11 = phi %KValue [ %t9, %L1 ], [ %t10, %L2 ]
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L5
L4:
  %t14 = call i64 @k_truthy(%KValue %t11)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %L7
L6:
  %t16 = extractvalue %KValue %x0, 0
  %t17 = extractvalue %KValue { i64 0, i64 58 }, 0
  %t18 = icmp eq i64 %t16, 0
  %t19 = icmp eq i64 %t17, 0
  %t20 = and i1 %t18, %t19
  br i1 %t20, label %L8, label %L9
L8:
  %t21 = extractvalue %KValue %x0, 1
  %t22 = extractvalue %KValue { i64 0, i64 58 }, 1
  %t23 = icmp slt i64 %t21, %t22
  %t24 = select i1 %t23, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L10
L9:
  %t25 = call %KValue @k_cmp(%KValue %x0, %KValue { i64 0, i64 58 }, i64 2)
  br label %L10
L10:
  %t26 = phi %KValue [ %t24, %L8 ], [ %t25, %L9 ]
  br label %L5
L7:
  br label %L5
L5:
  %t27 = phi %KValue [ %t11, %L3 ], [ %t26, %L10 ], [ { i64 3, i64 0 }, %L7 ]
  %t28 = call i64 @k_not_failure(%KValue %t27)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L11, label %L12
L12:
  ret %KValue %t27
L11:
  %t30 = call i64 @k_truthy(%KValue %t27)
  %t31 = icmp ne i64 %t30, 0
  br i1 %t31, label %L13, label %L14
L13:
  %t32 = extractvalue %KValue %x0, 0
  %t33 = extractvalue %KValue { i64 0, i64 48 }, 0
  %t34 = icmp eq i64 %t32, 0
  %t35 = icmp eq i64 %t33, 0
  %t36 = and i1 %t34, %t35
  br i1 %t36, label %L15, label %L16
L15:
  %t37 = extractvalue %KValue %x0, 1
  %t38 = extractvalue %KValue { i64 0, i64 48 }, 1
  %t39 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t37, i64 %t38)
  %t40 = extractvalue { i64, i1 } %t39, 0
  %t41 = extractvalue { i64, i1 } %t39, 1
  br i1 %t41, label %L16, label %L18
L18:
  %t42 = insertvalue %KValue { i64 0, i64 undef }, i64 %t40, 1
  br label %L17
L16:
  %t43 = call %KValue @k_sub(%KValue %x0, %KValue { i64 0, i64 48 })
  br label %L17
L17:
  %t44 = phi %KValue [ %t42, %L18 ], [ %t43, %L16 ]
  ret %KValue %t44
L14:
  %t45 = musttail call tailcc %KValue @"d_query/hex_alpha_1"(%KValue %x0)
  ret %KValue %t45
fail0:
  %t46 = call i64 @k_not_failure(%KValue %x0)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L20, label %L19
L19:
  %t48 = call %KValue @k_err_hop(%KValue %x0, ptr @s476)
  ret %KValue %t48
L20:
  call void @k_die(ptr @s477)
  unreachable
}

define %KValue @"d_query/hex_digits_0_build"() {
entry:
  %t1 = call %KValue @k_str_lit(ptr @s470, i64 16, ptr @s470_lit)
  ret %KValue %t1
fail0:
  call void @k_die(ptr @s479)
  unreachable
}

define %KValue @"d_query/hex_digits_0"() {
entry:
  %c = load %KValue, ptr @caf_0
  ret %KValue %c
}

define tailcc %KValue @"d_query/hex_upper_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue { i64 0, i64 64 }, 0
  %t2 = extractvalue %KValue %x0, 0
  %t3 = icmp eq i64 %t1, 0
  %t4 = icmp eq i64 %t2, 0
  %t5 = and i1 %t3, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue { i64 0, i64 64 }, 1
  %t7 = extractvalue %KValue %x0, 1
  %t8 = icmp slt i64 %t6, %t7
  %t9 = select i1 %t8, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L3
L2:
  %t10 = call %KValue @k_cmp(%KValue { i64 0, i64 64 }, %KValue %x0, i64 2)
  br label %L3
L3:
  %t11 = phi %KValue [ %t9, %L1 ], [ %t10, %L2 ]
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L5
L4:
  %t14 = call i64 @k_truthy(%KValue %t11)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L6, label %L7
L6:
  %t16 = extractvalue %KValue %x0, 0
  %t17 = extractvalue %KValue { i64 0, i64 71 }, 0
  %t18 = icmp eq i64 %t16, 0
  %t19 = icmp eq i64 %t17, 0
  %t20 = and i1 %t18, %t19
  br i1 %t20, label %L8, label %L9
L8:
  %t21 = extractvalue %KValue %x0, 1
  %t22 = extractvalue %KValue { i64 0, i64 71 }, 1
  %t23 = icmp slt i64 %t21, %t22
  %t24 = select i1 %t23, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L10
L9:
  %t25 = call %KValue @k_cmp(%KValue %x0, %KValue { i64 0, i64 71 }, i64 2)
  br label %L10
L10:
  %t26 = phi %KValue [ %t24, %L8 ], [ %t25, %L9 ]
  br label %L5
L7:
  br label %L5
L5:
  %t27 = phi %KValue [ %t11, %L3 ], [ %t26, %L10 ], [ { i64 3, i64 0 }, %L7 ]
  %t28 = call i64 @k_not_failure(%KValue %t27)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L11, label %L12
L12:
  ret %KValue %t27
L11:
  %t30 = call i64 @k_truthy(%KValue %t27)
  %t31 = icmp ne i64 %t30, 0
  br i1 %t31, label %L13, label %L14
L13:
  %t32 = extractvalue %KValue %x0, 0
  %t33 = extractvalue %KValue { i64 0, i64 55 }, 0
  %t34 = icmp eq i64 %t32, 0
  %t35 = icmp eq i64 %t33, 0
  %t36 = and i1 %t34, %t35
  br i1 %t36, label %L15, label %L16
L15:
  %t37 = extractvalue %KValue %x0, 1
  %t38 = extractvalue %KValue { i64 0, i64 55 }, 1
  %t39 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t37, i64 %t38)
  %t40 = extractvalue { i64, i1 } %t39, 0
  %t41 = extractvalue { i64, i1 } %t39, 1
  br i1 %t41, label %L16, label %L18
L18:
  %t42 = insertvalue %KValue { i64 0, i64 undef }, i64 %t40, 1
  br label %L17
L16:
  %t43 = call %KValue @k_sub(%KValue %x0, %KValue { i64 0, i64 55 })
  br label %L17
L17:
  %t44 = phi %KValue [ %t42, %L18 ], [ %t43, %L16 ]
  ret %KValue %t44
L14:
  %t45 = call %KValue @k_str_lit(ptr @s481, i64 17, ptr @s481_lit)
  %t46 = call %KValue @k_err(%KValue %t45, ptr @s482)
  ret %KValue %t46
fail0:
  %t47 = call i64 @k_not_failure(%KValue %x0)
  %t48 = icmp ne i64 %t47, 0
  br i1 %t48, label %L20, label %L19
L19:
  %t49 = call %KValue @k_err_hop(%KValue %x0, ptr @s480)
  ret %KValue %t49
L20:
  call void @k_die(ptr @s483)
  unreachable
}

define tailcc %parsed @"d_query/parse_string_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = extractvalue %KValue %x1, 1
  %t3 = musttail call tailcc %parsed @"d_query/string_scan_3"(%KValue %x0, i64 %t1, i64 %t2)
  ret %parsed %t3
fail0:
  %t4 = call i64 @k_not_failure(%KValue %x0)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %L1
L1:
  %t6 = call %KValue @k_err_hop(%KValue %x0, ptr @s484)
  %t7 = extractvalue %KValue %t6, 0
  %t8 = extractvalue %KValue %t6, 1
  %t9 = insertvalue %parsed undef, i64 %t7, 0
  %t10 = insertvalue %parsed %t9, i64 %t8, 1
  ret %parsed %t10
L2:
  %t11 = call i64 @k_not_failure(%KValue %x1)
  %t12 = icmp ne i64 %t11, 0
  br i1 %t12, label %L4, label %L3
L3:
  %t13 = call %KValue @k_err_hop(%KValue %x1, ptr @s484)
  %t14 = extractvalue %KValue %t13, 0
  %t15 = extractvalue %KValue %t13, 1
  %t16 = insertvalue %parsed undef, i64 %t14, 0
  %t17 = insertvalue %parsed %t16, i64 %t15, 1
  ret %parsed %t17
L4:
  call void @k_die(ptr @s485)
  unreachable
}

define tailcc %parsed @"d_query/str_char_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %t1 = icmp eq i64 %x1r, 256
  %x1b = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x1 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x1b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x1, 1
  switch i64 %t4, label %arm3 [
    i64 34, label %arm0
    i64 92, label %arm1
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm2, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm3, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x1, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s486)
  %t13 = extractvalue %KValue %t12, 0
  %t14 = extractvalue %KValue %t12, 1
  %t15 = insertvalue %parsed undef, i64 %t13, 0
  %t16 = insertvalue %parsed %t15, i64 %t14, 1
  ret %parsed %t16
L6:
  call void @k_die(ptr @s487)
  unreachable
arm0:
  %t17 = extractvalue %KValue %x2, 1
  %t18 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t19 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t17, i64 %t18)
  %t20 = extractvalue { i64, i1 } %t19, 0
  %t21 = extractvalue { i64, i1 } %t19, 1
  br i1 %t21, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  %t23 = call i64 @k_not_failure(%KValue %t22)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L9, label %L10
L10:
  %t25 = extractvalue %KValue %t22, 0
  %t26 = extractvalue %KValue %t22, 1
  %t27 = insertvalue %parsed undef, i64 %t25, 0
  %t28 = insertvalue %parsed %t27, i64 %t26, 1
  ret %parsed %t28
L9:
  %t29 = call %KValue @"d_query/text/utf8_1"(%KValue %x3)
  %t30 = extractvalue %KValue %x2, 1
  %t31 = call %KValue @"d_query/string_ok_2"(i64 %t30, %KValue %t29)
  %t32 = call i64 @k_not_failure(%KValue %t31)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L11, label %L12
L12:
  %t34 = extractvalue %KValue %t31, 0
  %t35 = extractvalue %KValue %t31, 1
  %t36 = insertvalue %parsed undef, i64 %t34, 0
  %t37 = insertvalue %parsed %t36, i64 %t35, 1
  ret %parsed %t37
L11:
  %t38 = extractvalue %KValue %t22, 1
  %t39 = shl i64 %t38, 8
  %t40 = extractvalue %KValue %t31, 0
  %t41 = or i64 %t39, %t40
  %t42 = extractvalue %KValue %t31, 1
  %t43 = insertvalue %parsed undef, i64 %t41, 0
  %t44 = insertvalue %parsed %t43, i64 %t42, 1
  ret %parsed %t44
arm1:
  %t45 = extractvalue %KValue %x2, 1
  %t46 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t47 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t45, i64 %t46)
  %t48 = extractvalue { i64, i1 } %t47, 0
  %t49 = extractvalue { i64, i1 } %t47, 1
  br i1 %t49, label %L14, label %L13
L14:
  call void @k_die(ptr @s94)
  unreachable
L13:
  %t50 = insertvalue %KValue { i64 0, i64 undef }, i64 %t48, 1
  %t51 = extractvalue %KValue %x0, 0
  %t52 = icmp eq i64 %t51, 13
  %t53 = extractvalue %KValue %t50, 0
  %t54 = icmp eq i64 %t53, 0
  %t55 = and i1 %t52, %t54
  br i1 %t55, label %L15, label %L16
L15:
  %t56 = extractvalue %KValue %x0, 1
  %t57 = inttoptr i64 %t56 to ptr
  %t58 = getelementptr %KBytes, ptr %t57, i64 0, i32 0
  %t59 = load i64, ptr %t58
  %t60 = extractvalue %KValue %t50, 1
  %t61 = icmp sge i64 %t60, 1
  %t62 = icmp sle i64 %t60, %t59
  %t63 = and i1 %t61, %t62
  br i1 %t63, label %L18, label %L16
L18:
  %t64 = getelementptr %KBytes, ptr %t57, i64 0, i32 1
  %t65 = load ptr, ptr %t64
  %t66 = add i64 %t60, -1
  %t67 = getelementptr i8, ptr %t65, i64 %t66
  %t68 = load i8, ptr %t67
  %t69 = zext i8 %t68 to i64
  %t70 = insertvalue %KValue { i64 0, i64 undef }, i64 %t69, 1
  br label %L17
L16:
  %t71 = call %KValue @k_b_at(%KValue %x0, %KValue %t50)
  br label %L17
L17:
  %t72 = phi %KValue [ %t70, %L18 ], [ %t71, %L16 ]
  %t73 = extractvalue %KValue %t72, 0
  %t74 = extractvalue %KValue %t72, 1
  %t75 = icmp eq i64 %t73, 4
  %t76 = select i1 %t75, i64 256, i64 %t74
  %t77 = extractvalue %KValue %x2, 1
  %t78 = musttail call tailcc %parsed @"d_query/str_escape_4"(%KValue %x0, i64 %t76, i64 %t77, %KValue %x3)
  ret %parsed %t78
arm2:
  %t79 = call %KValue @k_str_lit(ptr @s488, i64 19, ptr @s488_lit)
  %t80 = extractvalue %KValue %x2, 1
  %t81 = call tailcc %KValue @"d_query/fail_2"(i64 %t80, %KValue %t79)
  %t82 = extractvalue %KValue %t81, 0
  %t83 = extractvalue %KValue %t81, 1
  %t84 = insertvalue %parsed undef, i64 %t82, 0
  %t85 = insertvalue %parsed %t84, i64 %t83, 1
  ret %parsed %t85
arm3:
  %t86 = extractvalue %KValue %x2, 1
  %t87 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t88 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t86, i64 %t87)
  %t89 = extractvalue { i64, i1 } %t88, 0
  %t90 = extractvalue { i64, i1 } %t88, 1
  br i1 %t90, label %L20, label %L19
L20:
  call void @k_die(ptr @s94)
  unreachable
L19:
  %t91 = insertvalue %KValue { i64 0, i64 undef }, i64 %t89, 1
  %t92 = call %KValue @k_b_append_mut(%KValue %x3, %KValue %x1)
  %t93 = extractvalue %KValue %t91, 1
  %t94 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t93, %KValue %t92)
  ret %parsed %t94
}

define tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %x1r, %KValue %x2) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = call i64 @k_not_failure(%KValue %x2)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x0, 1
  %t4 = inttoptr i64 %t3 to ptr
  %t5 = getelementptr %KBytes, ptr %t4, i64 0, i32 0
  %t6 = load i64, ptr %t5
  %t7 = extractvalue %KValue %x1, 1
  %t8 = icmp sge i64 %t7, 1
  %t9 = icmp sle i64 %t7, %t6
  %t10 = and i1 %t8, %t9
  br i1 %t10, label %L2, label %L3
L2:
  %t11 = getelementptr %KBytes, ptr %t4, i64 0, i32 1
  %t12 = load ptr, ptr %t11
  %t13 = add i64 %t7, -1
  %t14 = getelementptr i8, ptr %t12, i64 %t13
  %t15 = load i8, ptr %t14
  %t16 = zext i8 %t15 to i64
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t16, 1
  br label %L4
L3:
  br label %L4
L4:
  %t18 = phi %KValue [ %t17, %L2 ], [ { i64 4, i64 0 }, %L3 ]
  %t19 = extractvalue %KValue %t18, 0
  %t20 = extractvalue %KValue %t18, 1
  %t21 = icmp eq i64 %t19, 4
  %t22 = select i1 %t21, i64 256, i64 %t20
  %t23 = extractvalue %KValue %x1, 1
  %t24 = musttail call tailcc %parsed @"d_query/str_char_4"(%KValue %x0, i64 %t22, i64 %t23, %KValue %x2)
  ret %parsed %t24
fail0:
  %t25 = call i64 @k_not_failure(%KValue %x0)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L6, label %L5
L5:
  %t27 = call %KValue @k_err_hop(%KValue %x0, ptr @s489)
  %t28 = extractvalue %KValue %t27, 0
  %t29 = extractvalue %KValue %t27, 1
  %t30 = insertvalue %parsed undef, i64 %t28, 0
  %t31 = insertvalue %parsed %t30, i64 %t29, 1
  ret %parsed %t31
L6:
  %t32 = call i64 @k_not_failure(%KValue %x1)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L8, label %L7
L7:
  %t34 = call %KValue @k_err_hop(%KValue %x1, ptr @s489)
  %t35 = extractvalue %KValue %t34, 0
  %t36 = extractvalue %KValue %t34, 1
  %t37 = insertvalue %parsed undef, i64 %t35, 0
  %t38 = insertvalue %parsed %t37, i64 %t36, 1
  ret %parsed %t38
L8:
  %t39 = call i64 @k_not_failure(%KValue %x2)
  %t40 = icmp ne i64 %t39, 0
  br i1 %t40, label %L10, label %L9
L9:
  %t41 = call %KValue @k_err_hop(%KValue %x2, ptr @s489)
  %t42 = extractvalue %KValue %t41, 0
  %t43 = extractvalue %KValue %t41, 1
  %t44 = insertvalue %parsed undef, i64 %t42, 0
  %t45 = insertvalue %parsed %t44, i64 %t43, 1
  ret %parsed %t45
L10:
  call void @k_die(ptr @s490)
  unreachable
}

define tailcc %parsed @"d_query/str_escape_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %t1 = icmp eq i64 %x1r, 256
  %x1b = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x1 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x1b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x1, 1
  switch i64 %t4, label %arm10 [
    i64 34, label %arm0
    i64 47, label %arm1
    i64 92, label %arm2
    i64 98, label %arm3
    i64 102, label %arm4
    i64 110, label %arm5
    i64 114, label %arm6
    i64 116, label %arm7
    i64 117, label %arm8
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm9, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm10, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x1, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s491)
  %t13 = extractvalue %KValue %t12, 0
  %t14 = extractvalue %KValue %t12, 1
  %t15 = insertvalue %parsed undef, i64 %t13, 0
  %t16 = insertvalue %parsed %t15, i64 %t14, 1
  ret %parsed %t16
L6:
  call void @k_die(ptr @s492)
  unreachable
arm0:
  %t17 = extractvalue %KValue %x2, 1
  %t18 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t19 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t17, i64 %t18)
  %t20 = extractvalue { i64, i1 } %t19, 0
  %t21 = extractvalue { i64, i1 } %t19, 1
  br i1 %t21, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  %t23 = call %KValue @k_b_append_mut(%KValue %x3, %KValue { i64 0, i64 34 })
  %t24 = extractvalue %KValue %t22, 1
  %t25 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t24, %KValue %t23)
  ret %parsed %t25
arm1:
  %t26 = extractvalue %KValue %x2, 1
  %t27 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t28 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t26, i64 %t27)
  %t29 = extractvalue { i64, i1 } %t28, 0
  %t30 = extractvalue { i64, i1 } %t28, 1
  br i1 %t30, label %L10, label %L9
L10:
  call void @k_die(ptr @s94)
  unreachable
L9:
  %t31 = insertvalue %KValue { i64 0, i64 undef }, i64 %t29, 1
  %t32 = call %KValue @k_b_append_mut(%KValue %x3, %KValue { i64 0, i64 47 })
  %t33 = extractvalue %KValue %t31, 1
  %t34 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t33, %KValue %t32)
  ret %parsed %t34
arm2:
  %t35 = extractvalue %KValue %x2, 1
  %t36 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t37 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t35, i64 %t36)
  %t38 = extractvalue { i64, i1 } %t37, 0
  %t39 = extractvalue { i64, i1 } %t37, 1
  br i1 %t39, label %L12, label %L11
L12:
  call void @k_die(ptr @s94)
  unreachable
L11:
  %t40 = insertvalue %KValue { i64 0, i64 undef }, i64 %t38, 1
  %t41 = call %KValue @k_b_append_mut(%KValue %x3, %KValue { i64 0, i64 92 })
  %t42 = extractvalue %KValue %t40, 1
  %t43 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t42, %KValue %t41)
  ret %parsed %t43
arm3:
  %t44 = extractvalue %KValue %x2, 1
  %t45 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t46 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t44, i64 %t45)
  %t47 = extractvalue { i64, i1 } %t46, 0
  %t48 = extractvalue { i64, i1 } %t46, 1
  br i1 %t48, label %L14, label %L13
L14:
  call void @k_die(ptr @s94)
  unreachable
L13:
  %t49 = insertvalue %KValue { i64 0, i64 undef }, i64 %t47, 1
  %t50 = call %KValue @k_b_append_mut(%KValue %x3, %KValue { i64 0, i64 8 })
  %t51 = extractvalue %KValue %t49, 1
  %t52 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t51, %KValue %t50)
  ret %parsed %t52
arm4:
  %t53 = extractvalue %KValue %x2, 1
  %t54 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t55 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t53, i64 %t54)
  %t56 = extractvalue { i64, i1 } %t55, 0
  %t57 = extractvalue { i64, i1 } %t55, 1
  br i1 %t57, label %L16, label %L15
L16:
  call void @k_die(ptr @s94)
  unreachable
L15:
  %t58 = insertvalue %KValue { i64 0, i64 undef }, i64 %t56, 1
  %t59 = call %KValue @k_b_append_mut(%KValue %x3, %KValue { i64 0, i64 12 })
  %t60 = extractvalue %KValue %t58, 1
  %t61 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t60, %KValue %t59)
  ret %parsed %t61
arm5:
  %t62 = extractvalue %KValue %x2, 1
  %t63 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t64 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t62, i64 %t63)
  %t65 = extractvalue { i64, i1 } %t64, 0
  %t66 = extractvalue { i64, i1 } %t64, 1
  br i1 %t66, label %L18, label %L17
L18:
  call void @k_die(ptr @s94)
  unreachable
L17:
  %t67 = insertvalue %KValue { i64 0, i64 undef }, i64 %t65, 1
  %t68 = call %KValue @k_b_append_mut(%KValue %x3, %KValue { i64 0, i64 10 })
  %t69 = extractvalue %KValue %t67, 1
  %t70 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t69, %KValue %t68)
  ret %parsed %t70
arm6:
  %t71 = extractvalue %KValue %x2, 1
  %t72 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t73 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t71, i64 %t72)
  %t74 = extractvalue { i64, i1 } %t73, 0
  %t75 = extractvalue { i64, i1 } %t73, 1
  br i1 %t75, label %L20, label %L19
L20:
  call void @k_die(ptr @s94)
  unreachable
L19:
  %t76 = insertvalue %KValue { i64 0, i64 undef }, i64 %t74, 1
  %t77 = call %KValue @k_b_append_mut(%KValue %x3, %KValue { i64 0, i64 13 })
  %t78 = extractvalue %KValue %t76, 1
  %t79 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t78, %KValue %t77)
  ret %parsed %t79
arm7:
  %t80 = extractvalue %KValue %x2, 1
  %t81 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t82 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t80, i64 %t81)
  %t83 = extractvalue { i64, i1 } %t82, 0
  %t84 = extractvalue { i64, i1 } %t82, 1
  br i1 %t84, label %L22, label %L21
L22:
  call void @k_die(ptr @s94)
  unreachable
L21:
  %t85 = insertvalue %KValue { i64 0, i64 undef }, i64 %t83, 1
  %t86 = call %KValue @k_b_append_mut(%KValue %x3, %KValue { i64 0, i64 9 })
  %t87 = extractvalue %KValue %t85, 1
  %t88 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t87, %KValue %t86)
  ret %parsed %t88
arm8:
  %t89 = extractvalue %KValue %x2, 1
  %t90 = musttail call tailcc %parsed @"d_query/str_unicode_3"(%KValue %x0, i64 %t89, %KValue %x3)
  ret %parsed %t90
arm9:
  %t91 = call %KValue @k_str_lit(ptr @s488, i64 19, ptr @s488_lit)
  %t92 = extractvalue %KValue %x2, 1
  %t93 = call tailcc %KValue @"d_query/fail_2"(i64 %t92, %KValue %t91)
  %t94 = extractvalue %KValue %t93, 0
  %t95 = extractvalue %KValue %t93, 1
  %t96 = insertvalue %parsed undef, i64 %t94, 0
  %t97 = insertvalue %parsed %t96, i64 %t95, 1
  ret %parsed %t97
arm10:
  %t98 = call %KValue @k_str_lit(ptr @s493, i64 17, ptr @s493_lit)
  %t99 = alloca [1 x %KValue]
  %t100 = getelementptr [1 x %KValue], ptr %t99, i64 0, i64 0
  store %KValue %x1, ptr %t100
  %t101 = call %KValue @k_list_lit(i64 1, ptr %t99)
  %t102 = call %KValue @"d_query/text/utf8_1"(%KValue %t101)
  %t103 = call %KValue @k_render(%KValue %t102, i64 0)
  %t104 = call %KValue @k_str_lit(ptr @s399, i64 1, ptr @s399_lit)
  %t105 = alloca [3 x %KValue]
  %t106 = getelementptr [3 x %KValue], ptr %t105, i64 0, i64 0
  store %KValue %t98, ptr %t106
  %t107 = getelementptr [3 x %KValue], ptr %t105, i64 0, i64 1
  store %KValue %t103, ptr %t107
  %t108 = getelementptr [3 x %KValue], ptr %t105, i64 0, i64 2
  store %KValue %t104, ptr %t108
  %t109 = call %KValue @k_concat_arr(i64 3, ptr %t105)
  %t110 = extractvalue %KValue %x2, 1
  %t111 = call tailcc %KValue @"d_query/fail_2"(i64 %t110, %KValue %t109)
  %t112 = extractvalue %KValue %t111, 0
  %t113 = extractvalue %KValue %t111, 1
  %t114 = insertvalue %parsed undef, i64 %t112, 0
  %t115 = insertvalue %parsed %t114, i64 %t113, 1
  ret %parsed %t115
}

define tailcc %parsed @"d_query/str_unicode_3"(%KValue %x0, i64 %x1r, %KValue %x2) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t3 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t1, i64 %t2)
  %t4 = extractvalue { i64, i1 } %t3, 0
  %t5 = extractvalue { i64, i1 } %t3, 1
  br i1 %t5, label %L2, label %L1
L2:
  call void @k_die(ptr @s94)
  unreachable
L1:
  %t6 = insertvalue %KValue { i64 0, i64 undef }, i64 %t4, 1
  %t7 = extractvalue %KValue %x0, 1
  %t8 = inttoptr i64 %t7 to ptr
  %t9 = getelementptr %KBytes, ptr %t8, i64 0, i32 0
  %t10 = load i64, ptr %t9
  %t11 = extractvalue %KValue %t6, 1
  %t12 = icmp sge i64 %t11, 1
  %t13 = icmp sle i64 %t11, %t10
  %t14 = and i1 %t12, %t13
  br i1 %t14, label %L3, label %L4
L3:
  %t15 = getelementptr %KBytes, ptr %t8, i64 0, i32 1
  %t16 = load ptr, ptr %t15
  %t17 = add i64 %t11, -1
  %t18 = getelementptr i8, ptr %t16, i64 %t17
  %t19 = load i8, ptr %t18
  %t20 = zext i8 %t19 to i64
  %t21 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  br label %L5
L4:
  br label %L5
L5:
  %t22 = phi %KValue [ %t21, %L3 ], [ { i64 4, i64 0 }, %L4 ]
  %t23 = call tailcc %KValue @"d_query/hex_digit_1"(%KValue %t22)
  %t24 = extractvalue %KValue %x1, 1
  %t25 = extractvalue %KValue { i64 0, i64 3 }, 1
  %t26 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t24, i64 %t25)
  %t27 = extractvalue { i64, i1 } %t26, 0
  %t28 = extractvalue { i64, i1 } %t26, 1
  br i1 %t28, label %L7, label %L6
L7:
  call void @k_die(ptr @s94)
  unreachable
L6:
  %t29 = insertvalue %KValue { i64 0, i64 undef }, i64 %t27, 1
  %t30 = extractvalue %KValue %x0, 1
  %t31 = inttoptr i64 %t30 to ptr
  %t32 = getelementptr %KBytes, ptr %t31, i64 0, i32 0
  %t33 = load i64, ptr %t32
  %t34 = extractvalue %KValue %t29, 1
  %t35 = icmp sge i64 %t34, 1
  %t36 = icmp sle i64 %t34, %t33
  %t37 = and i1 %t35, %t36
  br i1 %t37, label %L8, label %L9
L8:
  %t38 = getelementptr %KBytes, ptr %t31, i64 0, i32 1
  %t39 = load ptr, ptr %t38
  %t40 = add i64 %t34, -1
  %t41 = getelementptr i8, ptr %t39, i64 %t40
  %t42 = load i8, ptr %t41
  %t43 = zext i8 %t42 to i64
  %t44 = insertvalue %KValue { i64 0, i64 undef }, i64 %t43, 1
  br label %L10
L9:
  br label %L10
L10:
  %t45 = phi %KValue [ %t44, %L8 ], [ { i64 4, i64 0 }, %L9 ]
  %t46 = call tailcc %KValue @"d_query/hex_digit_1"(%KValue %t45)
  %t47 = extractvalue %KValue %x1, 1
  %t48 = extractvalue %KValue { i64 0, i64 4 }, 1
  %t49 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t47, i64 %t48)
  %t50 = extractvalue { i64, i1 } %t49, 0
  %t51 = extractvalue { i64, i1 } %t49, 1
  br i1 %t51, label %L12, label %L11
L12:
  call void @k_die(ptr @s94)
  unreachable
L11:
  %t52 = insertvalue %KValue { i64 0, i64 undef }, i64 %t50, 1
  %t53 = extractvalue %KValue %x0, 1
  %t54 = inttoptr i64 %t53 to ptr
  %t55 = getelementptr %KBytes, ptr %t54, i64 0, i32 0
  %t56 = load i64, ptr %t55
  %t57 = extractvalue %KValue %t52, 1
  %t58 = icmp sge i64 %t57, 1
  %t59 = icmp sle i64 %t57, %t56
  %t60 = and i1 %t58, %t59
  br i1 %t60, label %L13, label %L14
L13:
  %t61 = getelementptr %KBytes, ptr %t54, i64 0, i32 1
  %t62 = load ptr, ptr %t61
  %t63 = add i64 %t57, -1
  %t64 = getelementptr i8, ptr %t62, i64 %t63
  %t65 = load i8, ptr %t64
  %t66 = zext i8 %t65 to i64
  %t67 = insertvalue %KValue { i64 0, i64 undef }, i64 %t66, 1
  br label %L15
L14:
  br label %L15
L15:
  %t68 = phi %KValue [ %t67, %L13 ], [ { i64 4, i64 0 }, %L14 ]
  %t69 = call tailcc %KValue @"d_query/hex_digit_1"(%KValue %t68)
  %t70 = extractvalue %KValue %x1, 1
  %t71 = extractvalue %KValue { i64 0, i64 5 }, 1
  %t72 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t70, i64 %t71)
  %t73 = extractvalue { i64, i1 } %t72, 0
  %t74 = extractvalue { i64, i1 } %t72, 1
  br i1 %t74, label %L17, label %L16
L17:
  call void @k_die(ptr @s94)
  unreachable
L16:
  %t75 = insertvalue %KValue { i64 0, i64 undef }, i64 %t73, 1
  %t76 = extractvalue %KValue %x0, 1
  %t77 = inttoptr i64 %t76 to ptr
  %t78 = getelementptr %KBytes, ptr %t77, i64 0, i32 0
  %t79 = load i64, ptr %t78
  %t80 = extractvalue %KValue %t75, 1
  %t81 = icmp sge i64 %t80, 1
  %t82 = icmp sle i64 %t80, %t79
  %t83 = and i1 %t81, %t82
  br i1 %t83, label %L18, label %L19
L18:
  %t84 = getelementptr %KBytes, ptr %t77, i64 0, i32 1
  %t85 = load ptr, ptr %t84
  %t86 = add i64 %t80, -1
  %t87 = getelementptr i8, ptr %t85, i64 %t86
  %t88 = load i8, ptr %t87
  %t89 = zext i8 %t88 to i64
  %t90 = insertvalue %KValue { i64 0, i64 undef }, i64 %t89, 1
  br label %L20
L19:
  br label %L20
L20:
  %t91 = phi %KValue [ %t90, %L18 ], [ { i64 4, i64 0 }, %L19 ]
  %t92 = call tailcc %KValue @"d_query/hex_digit_1"(%KValue %t91)
  %t93 = extractvalue %KValue %t23, 0
  %t94 = extractvalue %KValue { i64 0, i64 4096 }, 0
  %t95 = icmp eq i64 %t93, 0
  %t96 = icmp eq i64 %t94, 0
  %t97 = and i1 %t95, %t96
  br i1 %t97, label %L21, label %L22
L21:
  %t98 = extractvalue %KValue %t23, 1
  %t99 = extractvalue %KValue { i64 0, i64 4096 }, 1
  %t100 = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %t98, i64 %t99)
  %t101 = extractvalue { i64, i1 } %t100, 0
  %t102 = extractvalue { i64, i1 } %t100, 1
  br i1 %t102, label %L22, label %L24
L24:
  %t103 = insertvalue %KValue { i64 0, i64 undef }, i64 %t101, 1
  br label %L23
L22:
  %t104 = call %KValue @k_mul(%KValue %t23, %KValue { i64 0, i64 4096 })
  br label %L23
L23:
  %t105 = phi %KValue [ %t103, %L24 ], [ %t104, %L22 ]
  %t106 = extractvalue %KValue %t46, 0
  %t107 = extractvalue %KValue { i64 0, i64 256 }, 0
  %t108 = icmp eq i64 %t106, 0
  %t109 = icmp eq i64 %t107, 0
  %t110 = and i1 %t108, %t109
  br i1 %t110, label %L25, label %L26
L25:
  %t111 = extractvalue %KValue %t46, 1
  %t112 = extractvalue %KValue { i64 0, i64 256 }, 1
  %t113 = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %t111, i64 %t112)
  %t114 = extractvalue { i64, i1 } %t113, 0
  %t115 = extractvalue { i64, i1 } %t113, 1
  br i1 %t115, label %L26, label %L28
L28:
  %t116 = insertvalue %KValue { i64 0, i64 undef }, i64 %t114, 1
  br label %L27
L26:
  %t117 = call %KValue @k_mul(%KValue %t46, %KValue { i64 0, i64 256 })
  br label %L27
L27:
  %t118 = phi %KValue [ %t116, %L28 ], [ %t117, %L26 ]
  %t119 = extractvalue %KValue %t105, 0
  %t120 = extractvalue %KValue %t118, 0
  %t121 = icmp eq i64 %t119, 0
  %t122 = icmp eq i64 %t120, 0
  %t123 = and i1 %t121, %t122
  br i1 %t123, label %L29, label %L30
L29:
  %t124 = extractvalue %KValue %t105, 1
  %t125 = extractvalue %KValue %t118, 1
  %t126 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t124, i64 %t125)
  %t127 = extractvalue { i64, i1 } %t126, 0
  %t128 = extractvalue { i64, i1 } %t126, 1
  br i1 %t128, label %L30, label %L32
L32:
  %t129 = insertvalue %KValue { i64 0, i64 undef }, i64 %t127, 1
  br label %L31
L30:
  %t130 = call %KValue @k_add(%KValue %t105, %KValue %t118)
  br label %L31
L31:
  %t131 = phi %KValue [ %t129, %L32 ], [ %t130, %L30 ]
  %t132 = extractvalue %KValue %t69, 0
  %t133 = extractvalue %KValue { i64 0, i64 16 }, 0
  %t134 = icmp eq i64 %t132, 0
  %t135 = icmp eq i64 %t133, 0
  %t136 = and i1 %t134, %t135
  br i1 %t136, label %L33, label %L34
L33:
  %t137 = extractvalue %KValue %t69, 1
  %t138 = extractvalue %KValue { i64 0, i64 16 }, 1
  %t139 = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %t137, i64 %t138)
  %t140 = extractvalue { i64, i1 } %t139, 0
  %t141 = extractvalue { i64, i1 } %t139, 1
  br i1 %t141, label %L34, label %L36
L36:
  %t142 = insertvalue %KValue { i64 0, i64 undef }, i64 %t140, 1
  br label %L35
L34:
  %t143 = call %KValue @k_mul(%KValue %t69, %KValue { i64 0, i64 16 })
  br label %L35
L35:
  %t144 = phi %KValue [ %t142, %L36 ], [ %t143, %L34 ]
  %t145 = extractvalue %KValue %t131, 0
  %t146 = extractvalue %KValue %t144, 0
  %t147 = icmp eq i64 %t145, 0
  %t148 = icmp eq i64 %t146, 0
  %t149 = and i1 %t147, %t148
  br i1 %t149, label %L37, label %L38
L37:
  %t150 = extractvalue %KValue %t131, 1
  %t151 = extractvalue %KValue %t144, 1
  %t152 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t150, i64 %t151)
  %t153 = extractvalue { i64, i1 } %t152, 0
  %t154 = extractvalue { i64, i1 } %t152, 1
  br i1 %t154, label %L38, label %L40
L40:
  %t155 = insertvalue %KValue { i64 0, i64 undef }, i64 %t153, 1
  br label %L39
L38:
  %t156 = call %KValue @k_add(%KValue %t131, %KValue %t144)
  br label %L39
L39:
  %t157 = phi %KValue [ %t155, %L40 ], [ %t156, %L38 ]
  %t158 = extractvalue %KValue %t157, 0
  %t159 = extractvalue %KValue %t92, 0
  %t160 = icmp eq i64 %t158, 0
  %t161 = icmp eq i64 %t159, 0
  %t162 = and i1 %t160, %t161
  br i1 %t162, label %L41, label %L42
L41:
  %t163 = extractvalue %KValue %t157, 1
  %t164 = extractvalue %KValue %t92, 1
  %t165 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t163, i64 %t164)
  %t166 = extractvalue { i64, i1 } %t165, 0
  %t167 = extractvalue { i64, i1 } %t165, 1
  br i1 %t167, label %L42, label %L44
L44:
  %t168 = insertvalue %KValue { i64 0, i64 undef }, i64 %t166, 1
  br label %L43
L42:
  %t169 = call %KValue @k_add(%KValue %t157, %KValue %t92)
  br label %L43
L43:
  %t170 = phi %KValue [ %t168, %L44 ], [ %t169, %L42 ]
  %t171 = extractvalue %KValue %x1, 1
  %t172 = extractvalue %KValue { i64 0, i64 6 }, 1
  %t173 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t171, i64 %t172)
  %t174 = extractvalue { i64, i1 } %t173, 0
  %t175 = extractvalue { i64, i1 } %t173, 1
  br i1 %t175, label %L46, label %L45
L46:
  call void @k_die(ptr @s94)
  unreachable
L45:
  %t176 = insertvalue %KValue { i64 0, i64 undef }, i64 %t174, 1
  %t177 = call %KValue @"d_query/text/from_code_1"(%KValue %t170)
  %t178 = call %KValue @k_b_append_mut(%KValue %x2, %KValue %t177)
  %t179 = extractvalue %KValue %t176, 1
  %t180 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t179, %KValue %t178)
  ret %parsed %t180
fail0:
  %t181 = call i64 @k_not_failure(%KValue %x0)
  %t182 = icmp ne i64 %t181, 0
  br i1 %t182, label %L48, label %L47
L47:
  %t183 = call %KValue @k_err_hop(%KValue %x0, ptr @s494)
  %t184 = extractvalue %KValue %t183, 0
  %t185 = extractvalue %KValue %t183, 1
  %t186 = insertvalue %parsed undef, i64 %t184, 0
  %t187 = insertvalue %parsed %t186, i64 %t185, 1
  ret %parsed %t187
L48:
  %t188 = call i64 @k_not_failure(%KValue %x1)
  %t189 = icmp ne i64 %t188, 0
  br i1 %t189, label %L50, label %L49
L49:
  %t190 = call %KValue @k_err_hop(%KValue %x1, ptr @s494)
  %t191 = extractvalue %KValue %t190, 0
  %t192 = extractvalue %KValue %t190, 1
  %t193 = insertvalue %parsed undef, i64 %t191, 0
  %t194 = insertvalue %parsed %t193, i64 %t192, 1
  ret %parsed %t194
L50:
  %t195 = call i64 @k_not_failure(%KValue %x2)
  %t196 = icmp ne i64 %t195, 0
  br i1 %t196, label %L52, label %L51
L51:
  %t197 = call %KValue @k_err_hop(%KValue %x2, ptr @s494)
  %t198 = extractvalue %KValue %t197, 0
  %t199 = extractvalue %KValue %t197, 1
  %t200 = insertvalue %parsed undef, i64 %t198, 0
  %t201 = insertvalue %parsed %t200, i64 %t199, 1
  ret %parsed %t201
L52:
  call void @k_die(ptr @s495)
  unreachable
}

define tailcc %parsed @"d_query/string_at_4"(%KValue %x0, i64 %x1r, i64 %x2r, i64 %x3r) {
entry:
  %t1 = icmp eq i64 %x1r, 256
  %x1b = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x1 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x1b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %x3 = insertvalue %KValue { i64 0, i64 undef }, i64 %x3r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x1, 1
  switch i64 %t4, label %arm3 [
    i64 34, label %arm0
    i64 92, label %arm1
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm2, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm3, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x1, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s496)
  %t13 = extractvalue %KValue %t12, 0
  %t14 = extractvalue %KValue %t12, 1
  %t15 = insertvalue %parsed undef, i64 %t13, 0
  %t16 = insertvalue %parsed %t15, i64 %t14, 1
  ret %parsed %t16
L6:
  call void @k_die(ptr @s497)
  unreachable
arm0:
  %t17 = extractvalue %KValue %x3, 1
  %t18 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t19 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t17, i64 %t18)
  %t20 = extractvalue { i64, i1 } %t19, 0
  %t21 = extractvalue { i64, i1 } %t19, 1
  br i1 %t21, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  %t23 = call i64 @k_not_failure(%KValue %t22)
  %t24 = icmp ne i64 %t23, 0
  br i1 %t24, label %L9, label %L10
L10:
  %t25 = extractvalue %KValue %t22, 0
  %t26 = extractvalue %KValue %t22, 1
  %t27 = insertvalue %parsed undef, i64 %t25, 0
  %t28 = insertvalue %parsed %t27, i64 %t26, 1
  ret %parsed %t28
L9:
  %t29 = extractvalue %KValue %x3, 1
  %t30 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t31 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t29, i64 %t30)
  %t32 = extractvalue { i64, i1 } %t31, 0
  %t33 = extractvalue { i64, i1 } %t31, 1
  br i1 %t33, label %L12, label %L11
L12:
  call void @k_die(ptr @s94)
  unreachable
L11:
  %t34 = insertvalue %KValue { i64 0, i64 undef }, i64 %t32, 1
  %t35 = call %KValue @k_b_slice(%KValue %x0, %KValue %x2, %KValue %t34)
  %t36 = call %KValue @"d_query/text/utf8_1"(%KValue %t35)
  %t37 = extractvalue %KValue %x3, 1
  %t38 = call %KValue @"d_query/string_ok_2"(i64 %t37, %KValue %t36)
  %t39 = call i64 @k_not_failure(%KValue %t38)
  %t40 = icmp ne i64 %t39, 0
  br i1 %t40, label %L13, label %L14
L14:
  %t41 = extractvalue %KValue %t38, 0
  %t42 = extractvalue %KValue %t38, 1
  %t43 = insertvalue %parsed undef, i64 %t41, 0
  %t44 = insertvalue %parsed %t43, i64 %t42, 1
  ret %parsed %t44
L13:
  %t45 = extractvalue %KValue %t22, 1
  %t46 = shl i64 %t45, 8
  %t47 = extractvalue %KValue %t38, 0
  %t48 = or i64 %t46, %t47
  %t49 = extractvalue %KValue %t38, 1
  %t50 = insertvalue %parsed undef, i64 %t48, 0
  %t51 = insertvalue %parsed %t50, i64 %t49, 1
  ret %parsed %t51
arm1:
  %t52 = call %KValue @k_str_lit(ptr @s259, i64 0, ptr @s259_lit)
  %t53 = call %KValue @k_b_bytes(%KValue %t52)
  %t54 = extractvalue %KValue %x3, 1
  %t55 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t56 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t54, i64 %t55)
  %t57 = extractvalue { i64, i1 } %t56, 0
  %t58 = extractvalue { i64, i1 } %t56, 1
  br i1 %t58, label %L16, label %L15
L16:
  call void @k_die(ptr @s94)
  unreachable
L15:
  %t59 = insertvalue %KValue { i64 0, i64 undef }, i64 %t57, 1
  %t60 = call %KValue @k_b_slice(%KValue %x0, %KValue %x2, %KValue %t59)
  %t61 = call %KValue @k_b_append_mut(%KValue %t53, %KValue %t60)
  %t62 = extractvalue %KValue %x3, 1
  %t63 = musttail call tailcc %parsed @"d_query/str_chars_3"(%KValue %x0, i64 %t62, %KValue %t61)
  ret %parsed %t63
arm2:
  %t64 = call %KValue @k_str_lit(ptr @s488, i64 19, ptr @s488_lit)
  %t65 = extractvalue %KValue %x3, 1
  %t66 = call tailcc %KValue @"d_query/fail_2"(i64 %t65, %KValue %t64)
  %t67 = extractvalue %KValue %t66, 0
  %t68 = extractvalue %KValue %t66, 1
  %t69 = insertvalue %parsed undef, i64 %t67, 0
  %t70 = insertvalue %parsed %t69, i64 %t68, 1
  ret %parsed %t70
arm3:
  %t71 = extractvalue %KValue %x3, 1
  %t72 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t73 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t71, i64 %t72)
  %t74 = extractvalue { i64, i1 } %t73, 0
  %t75 = extractvalue { i64, i1 } %t73, 1
  br i1 %t75, label %L18, label %L17
L18:
  call void @k_die(ptr @s94)
  unreachable
L17:
  %t76 = insertvalue %KValue { i64 0, i64 undef }, i64 %t74, 1
  %t77 = extractvalue %KValue %x2, 1
  %t78 = extractvalue %KValue %t76, 1
  %t79 = musttail call tailcc %parsed @"d_query/string_scan_3"(%KValue %x0, i64 %t77, i64 %t78)
  ret %parsed %t79
}

define %KValue @"d_query/string_ok_2"(i64 %x0r, %KValue %x1) {
entry:
  %x0 = insertvalue %KValue { i64 0, i64 undef }, i64 %x0r, 1
  %t1 = call i64 @k_check_tag(%KValue %x1, i64 5)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_err_inner(%KValue %x1)
  %t4 = call i64 @k_not_failure(%KValue %t3)
  %t5 = icmp ne i64 %t4, 0
  br i1 %t5, label %L2, label %fail0
L2:
  %t6 = call %KValue @k_str_lit(ptr @s499, i64 23, ptr @s499_lit)
  %t7 = alloca [2 x %KValue]
  %t8 = getelementptr [2 x %KValue], ptr %t7, i64 0, i64 0
  store %KValue %x0, ptr %t8
  %t9 = getelementptr [2 x %KValue], ptr %t7, i64 0, i64 1
  store %KValue %t6, ptr %t9
  %t10 = call %KValue @k_rec(i64 36, i64 2, ptr %t7)
  %t11 = call %KValue @k_err(%KValue %t10, ptr @s500)
  ret %KValue %t11
fail0:
  %t12 = call i64 @k_not_failure(%KValue %x1)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L3, label %fail1
L3:
  ret %KValue %x1
fail1:
  %t14 = call i64 @k_not_failure(%KValue %x0)
  %t15 = icmp ne i64 %t14, 0
  br i1 %t15, label %L5, label %L4
L4:
  %t16 = call %KValue @k_err_hop(%KValue %x0, ptr @s498)
  ret %KValue %t16
L5:
  %t17 = call i64 @k_not_failure(%KValue %x1)
  %t18 = icmp ne i64 %t17, 0
  br i1 %t18, label %L7, label %L6
L6:
  %t19 = call %KValue @k_err_hop(%KValue %x1, ptr @s498)
  ret %KValue %t19
L7:
  call void @k_die(ptr @s501)
  unreachable
}

define tailcc %parsed @"d_query/string_scan_3"(%KValue %x0, i64 %x1r, i64 %x2r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = call %KValue @k_b_find2(%KValue %x0, %KValue %x2, %KValue { i64 0, i64 34 }, %KValue { i64 0, i64 92 })
  %t2 = extractvalue %KValue %x0, 1
  %t3 = inttoptr i64 %t2 to ptr
  %t4 = getelementptr %KBytes, ptr %t3, i64 0, i32 0
  %t5 = load i64, ptr %t4
  %t6 = extractvalue %KValue %t1, 1
  %t7 = icmp sge i64 %t6, 1
  %t8 = icmp sle i64 %t6, %t5
  %t9 = and i1 %t7, %t8
  br i1 %t9, label %L1, label %L2
L1:
  %t10 = getelementptr %KBytes, ptr %t3, i64 0, i32 1
  %t11 = load ptr, ptr %t10
  %t12 = add i64 %t6, -1
  %t13 = getelementptr i8, ptr %t11, i64 %t12
  %t14 = load i8, ptr %t13
  %t15 = zext i8 %t14 to i64
  %t16 = insertvalue %KValue { i64 0, i64 undef }, i64 %t15, 1
  br label %L3
L2:
  br label %L3
L3:
  %t17 = phi %KValue [ %t16, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t18 = extractvalue %KValue %t17, 0
  %t19 = extractvalue %KValue %t17, 1
  %t20 = icmp eq i64 %t18, 4
  %t21 = select i1 %t20, i64 256, i64 %t19
  %t22 = extractvalue %KValue %x1, 1
  %t23 = extractvalue %KValue %t1, 1
  %t24 = musttail call tailcc %parsed @"d_query/string_at_4"(%KValue %x0, i64 %t21, i64 %t22, i64 %t23)
  ret %parsed %t24
fail0:
  %t25 = call i64 @k_not_failure(%KValue %x0)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L5, label %L4
L4:
  %t27 = call %KValue @k_err_hop(%KValue %x0, ptr @s502)
  %t28 = extractvalue %KValue %t27, 0
  %t29 = extractvalue %KValue %t27, 1
  %t30 = insertvalue %parsed undef, i64 %t28, 0
  %t31 = insertvalue %parsed %t30, i64 %t29, 1
  ret %parsed %t31
L5:
  %t32 = call i64 @k_not_failure(%KValue %x1)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L7, label %L6
L6:
  %t34 = call %KValue @k_err_hop(%KValue %x1, ptr @s502)
  %t35 = extractvalue %KValue %t34, 0
  %t36 = extractvalue %KValue %t34, 1
  %t37 = insertvalue %parsed undef, i64 %t35, 0
  %t38 = insertvalue %parsed %t37, i64 %t36, 1
  ret %parsed %t38
L7:
  %t39 = call i64 @k_not_failure(%KValue %x2)
  %t40 = icmp ne i64 %t39, 0
  br i1 %t40, label %L9, label %L8
L8:
  %t41 = call %KValue @k_err_hop(%KValue %x2, ptr @s502)
  %t42 = extractvalue %KValue %t41, 0
  %t43 = extractvalue %KValue %t41, 1
  %t44 = insertvalue %parsed undef, i64 %t42, 0
  %t45 = insertvalue %parsed %t44, i64 %t43, 1
  ret %parsed %t45
L9:
  call void @k_die(ptr @s503)
  unreachable
}

define tailcc %KValue @"d_query/u_bytes_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_mod(%KValue %x1, %KValue { i64 0, i64 16 }, ptr @s505)
  %t2 = call %KValue @"d_query/hex_code_1"(%KValue %t1)
  %t3 = call %KValue @k_div(%KValue %x1, %KValue { i64 0, i64 16 }, ptr @s506)
  %t4 = call %KValue @"d_query/hex_code_1"(%KValue %t3)
  %t5 = call %KValue @k_str_lit(ptr @s507, i64 4, ptr @s507_lit)
  %t6 = call %KValue @k_b_append_mut(%KValue %x0, %KValue %t5)
  %t7 = call %KValue @k_b_append_mut(%KValue %t6, %KValue %t4)
  %t8 = call %KValue @k_b_append_mut(%KValue %t7, %KValue %t2)
  ret %KValue %t8
fail0:
  %t9 = call i64 @k_not_failure(%KValue %x0)
  %t10 = icmp ne i64 %t9, 0
  br i1 %t10, label %L2, label %L1
L1:
  %t11 = call %KValue @k_err_hop(%KValue %x0, ptr @s504)
  ret %KValue %t11
L2:
  %t12 = call i64 @k_not_failure(%KValue %x1)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L3
L3:
  %t14 = call %KValue @k_err_hop(%KValue %x1, ptr @s504)
  ret %KValue %t14
L4:
  call void @k_die(ptr @s508)
  unreachable
}

define tailcc %parsed @"d_query/array_delim_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %t1 = icmp eq i64 %x1r, 256
  %x1b = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x1 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x1b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x1, 1
  switch i64 %t4, label %arm3 [
    i64 44, label %arm0
    i64 93, label %arm1
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm2, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm3, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x1, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s509)
  %t13 = extractvalue %KValue %t12, 0
  %t14 = extractvalue %KValue %t12, 1
  %t15 = insertvalue %parsed undef, i64 %t13, 0
  %t16 = insertvalue %parsed %t15, i64 %t14, 1
  ret %parsed %t16
L6:
  call void @k_die(ptr @s510)
  unreachable
arm0:
  %t17 = extractvalue %KValue %x2, 1
  %t18 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t19 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t17, i64 %t18)
  %t20 = extractvalue { i64, i1 } %t19, 0
  %t21 = extractvalue { i64, i1 } %t19, 1
  br i1 %t21, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  %t23 = extractvalue %KValue %t22, 1
  %t24 = musttail call tailcc %parsed @"d_query/array_items_3"(%KValue %x0, i64 %t23, %KValue %x3)
  ret %parsed %t24
arm1:
  %t25 = extractvalue %KValue %x2, 1
  %t26 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t27 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t25, i64 %t26)
  %t28 = extractvalue { i64, i1 } %t27, 0
  %t29 = extractvalue { i64, i1 } %t27, 1
  br i1 %t29, label %L10, label %L9
L10:
  call void @k_die(ptr @s94)
  unreachable
L9:
  %t30 = insertvalue %KValue { i64 0, i64 undef }, i64 %t28, 1
  %t31 = call i64 @k_not_failure(%KValue %t30)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L11, label %L12
L12:
  %t33 = extractvalue %KValue %t30, 0
  %t34 = extractvalue %KValue %t30, 1
  %t35 = insertvalue %parsed undef, i64 %t33, 0
  %t36 = insertvalue %parsed %t35, i64 %t34, 1
  ret %parsed %t36
L11:
  %t37 = call i64 @k_not_failure(%KValue %x3)
  %t38 = icmp ne i64 %t37, 0
  br i1 %t38, label %L13, label %L14
L14:
  %t39 = extractvalue %KValue %x3, 0
  %t40 = extractvalue %KValue %x3, 1
  %t41 = insertvalue %parsed undef, i64 %t39, 0
  %t42 = insertvalue %parsed %t41, i64 %t40, 1
  ret %parsed %t42
L13:
  %t43 = extractvalue %KValue %t30, 1
  %t44 = shl i64 %t43, 8
  %t45 = extractvalue %KValue %x3, 0
  %t46 = or i64 %t44, %t45
  %t47 = extractvalue %KValue %x3, 1
  %t48 = insertvalue %parsed undef, i64 %t46, 0
  %t49 = insertvalue %parsed %t48, i64 %t47, 1
  ret %parsed %t49
arm2:
  %t50 = call %KValue @k_str_lit(ptr @s343, i64 23, ptr @s343_lit)
  %t51 = extractvalue %KValue %x2, 1
  %t52 = call tailcc %KValue @"d_query/fail_2"(i64 %t51, %KValue %t50)
  %t53 = extractvalue %KValue %t52, 0
  %t54 = extractvalue %KValue %t52, 1
  %t55 = insertvalue %parsed undef, i64 %t53, 0
  %t56 = insertvalue %parsed %t55, i64 %t54, 1
  ret %parsed %t56
arm3:
  %t57 = call %KValue @k_str_lit(ptr @s511, i64 28, ptr @s511_lit)
  %t58 = alloca [1 x %KValue]
  %t59 = getelementptr [1 x %KValue], ptr %t58, i64 0, i64 0
  store %KValue %x1, ptr %t59
  %t60 = call %KValue @k_list_lit(i64 1, ptr %t58)
  %t61 = call %KValue @"d_query/text/utf8_1"(%KValue %t60)
  %t62 = call %KValue @k_render(%KValue %t61, i64 0)
  %t63 = call %KValue @k_str_lit(ptr @s399, i64 1, ptr @s399_lit)
  %t64 = alloca [3 x %KValue]
  %t65 = getelementptr [3 x %KValue], ptr %t64, i64 0, i64 0
  store %KValue %t57, ptr %t65
  %t66 = getelementptr [3 x %KValue], ptr %t64, i64 0, i64 1
  store %KValue %t62, ptr %t66
  %t67 = getelementptr [3 x %KValue], ptr %t64, i64 0, i64 2
  store %KValue %t63, ptr %t67
  %t68 = call %KValue @k_concat_arr(i64 3, ptr %t64)
  %t69 = extractvalue %KValue %x2, 1
  %t70 = call tailcc %KValue @"d_query/fail_2"(i64 %t69, %KValue %t68)
  %t71 = extractvalue %KValue %t70, 0
  %t72 = extractvalue %KValue %t70, 1
  %t73 = insertvalue %parsed undef, i64 %t71, 0
  %t74 = insertvalue %parsed %t73, i64 %t72, 1
  ret %parsed %t74
}

define tailcc %parsed @"d_query/array_items_3"(%KValue %x0, i64 %x1r, %KValue %x2) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t1)
  %t3 = extractvalue %KValue %t2, 1
  %t4 = call tailcc %parsed @"d_query/parse_value_2"(%KValue %x0, i64 %t3)
  %t5 = musttail call tailcc %parsed @"d_query/array_step_3"(%KValue %x0, %parsed %t4, %KValue %x2)
  ret %parsed %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L2, label %L1
L1:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s512)
  %t9 = extractvalue %KValue %t8, 0
  %t10 = extractvalue %KValue %t8, 1
  %t11 = insertvalue %parsed undef, i64 %t9, 0
  %t12 = insertvalue %parsed %t11, i64 %t10, 1
  ret %parsed %t12
L2:
  %t13 = call i64 @k_not_failure(%KValue %x1)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L4, label %L3
L3:
  %t15 = call %KValue @k_err_hop(%KValue %x1, ptr @s512)
  %t16 = extractvalue %KValue %t15, 0
  %t17 = extractvalue %KValue %t15, 1
  %t18 = insertvalue %parsed undef, i64 %t16, 0
  %t19 = insertvalue %parsed %t18, i64 %t17, 1
  ret %parsed %t19
L4:
  %t20 = call i64 @k_not_failure(%KValue %x2)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L6, label %L5
L5:
  %t22 = call %KValue @k_err_hop(%KValue %x2, ptr @s512)
  %t23 = extractvalue %KValue %t22, 0
  %t24 = extractvalue %KValue %t22, 1
  %t25 = insertvalue %parsed undef, i64 %t23, 0
  %t26 = insertvalue %parsed %t25, i64 %t24, 1
  ret %parsed %t26
L6:
  call void @k_die(ptr @s513)
  unreachable
}

define tailcc %parsed @"d_query/array_open_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x1, 0
  %t2 = icmp eq i64 %t1, 0
  %t3 = extractvalue %KValue %x1, 1
  %t4 = icmp eq i64 %t3, 93
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %fail0
L1:
  %t6 = extractvalue %KValue %x2, 1
  %t7 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t8 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t6, i64 %t7)
  %t9 = extractvalue { i64, i1 } %t8, 0
  %t10 = extractvalue { i64, i1 } %t8, 1
  br i1 %t10, label %L3, label %L2
L3:
  call void @k_die(ptr @s94)
  unreachable
L2:
  %t11 = insertvalue %KValue { i64 0, i64 undef }, i64 %t9, 1
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L5
L5:
  %t14 = extractvalue %KValue %t11, 0
  %t15 = extractvalue %KValue %t11, 1
  %t16 = insertvalue %parsed undef, i64 %t14, 0
  %t17 = insertvalue %parsed %t16, i64 %t15, 1
  ret %parsed %t17
L4:
  %t18 = alloca [1 x %KValue]
  %t19 = call %KValue @k_list_lit(i64 0, ptr %t18)
  %t20 = call i64 @k_not_failure(%KValue %t19)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L6, label %L7
L7:
  %t22 = extractvalue %KValue %t19, 0
  %t23 = extractvalue %KValue %t19, 1
  %t24 = insertvalue %parsed undef, i64 %t22, 0
  %t25 = insertvalue %parsed %t24, i64 %t23, 1
  ret %parsed %t25
L6:
  %t26 = extractvalue %KValue %t11, 1
  %t27 = shl i64 %t26, 8
  %t28 = extractvalue %KValue %t19, 0
  %t29 = or i64 %t27, %t28
  %t30 = extractvalue %KValue %t19, 1
  %t31 = insertvalue %parsed undef, i64 %t29, 0
  %t32 = insertvalue %parsed %t31, i64 %t30, 1
  ret %parsed %t32
fail0:
  %t33 = extractvalue %KValue %x1, 0
  %t34 = icmp eq i64 %t33, 4
  br i1 %t34, label %L8, label %fail1
L8:
  %t35 = call %KValue @k_str_lit(ptr @s343, i64 23, ptr @s343_lit)
  %t36 = extractvalue %KValue %x2, 1
  %t37 = call tailcc %KValue @"d_query/fail_2"(i64 %t36, %KValue %t35)
  %t38 = extractvalue %KValue %t37, 0
  %t39 = extractvalue %KValue %t37, 1
  %t40 = insertvalue %parsed undef, i64 %t38, 0
  %t41 = insertvalue %parsed %t40, i64 %t39, 1
  ret %parsed %t41
fail1:
  %t42 = alloca [1 x %KValue]
  %t43 = call %KValue @k_list_lit(i64 0, ptr %t42)
  %t44 = extractvalue %KValue %x2, 1
  %t45 = musttail call tailcc %parsed @"d_query/array_items_3"(%KValue %x0, i64 %t44, %KValue %t43)
  ret %parsed %t45
fail2:
  %t46 = call i64 @k_not_failure(%KValue %x0)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L10, label %L9
L9:
  %t48 = call %KValue @k_err_hop(%KValue %x0, ptr @s514)
  %t49 = extractvalue %KValue %t48, 0
  %t50 = extractvalue %KValue %t48, 1
  %t51 = insertvalue %parsed undef, i64 %t49, 0
  %t52 = insertvalue %parsed %t51, i64 %t50, 1
  ret %parsed %t52
L10:
  %t53 = call i64 @k_not_failure(%KValue %x1)
  %t54 = icmp ne i64 %t53, 0
  br i1 %t54, label %L12, label %L11
L11:
  %t55 = call %KValue @k_err_hop(%KValue %x1, ptr @s514)
  %t56 = extractvalue %KValue %t55, 0
  %t57 = extractvalue %KValue %t55, 1
  %t58 = insertvalue %parsed undef, i64 %t56, 0
  %t59 = insertvalue %parsed %t58, i64 %t57, 1
  ret %parsed %t59
L12:
  %t60 = call i64 @k_not_failure(%KValue %x2)
  %t61 = icmp ne i64 %t60, 0
  br i1 %t61, label %L14, label %L13
L13:
  %t62 = call %KValue @k_err_hop(%KValue %x2, ptr @s514)
  %t63 = extractvalue %KValue %t62, 0
  %t64 = extractvalue %KValue %t62, 1
  %t65 = insertvalue %parsed undef, i64 %t63, 0
  %t66 = insertvalue %parsed %t65, i64 %t64, 1
  ret %parsed %t66
L14:
  call void @k_die(ptr @s515)
  unreachable
}

define tailcc %parsed @"d_query/array_step_3"(%KValue %x0, %parsed %x1, %KValue %x2) {
entry:
  %x1w0 = extractvalue %parsed %x1, 0
  %x1w1 = extractvalue %parsed %x1, 1
  %x1sa = insertvalue %KValue undef, i64 %x1w0, 0
  %x1s = insertvalue %KValue %x1sa, i64 %x1w1, 1
  %t1 = call i64 @k_not_failure(%KValue %x1s)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1s, 0
  %t4 = extractvalue %KValue %x1s, 1
  %t5 = lshr i64 %t3, 8
  %t6 = insertvalue %KValue undef, i64 0, 0
  %t7 = insertvalue %KValue %t6, i64 %t5, 1
  %t8 = call i64 @k_not_failure(%KValue %t7)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %fail0
L2:
  %t10 = and i64 %t3, 255
  %t11 = insertvalue %KValue undef, i64 %t10, 0
  %t12 = insertvalue %KValue %t11, i64 %t4, 1
  %t13 = call i64 @k_not_failure(%KValue %t12)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L3, label %fail0
L3:
  %t15 = call %KValue @k_b_push_mut(%KValue %x2, %KValue %t12)
  %t16 = extractvalue %KValue %t7, 1
  %t17 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t16)
  %t18 = extractvalue %KValue %x0, 1
  %t19 = inttoptr i64 %t18 to ptr
  %t20 = getelementptr %KBytes, ptr %t19, i64 0, i32 0
  %t21 = load i64, ptr %t20
  %t22 = extractvalue %KValue %t17, 1
  %t23 = icmp sge i64 %t22, 1
  %t24 = icmp sle i64 %t22, %t21
  %t25 = and i1 %t23, %t24
  br i1 %t25, label %L4, label %L5
L4:
  %t26 = getelementptr %KBytes, ptr %t19, i64 0, i32 1
  %t27 = load ptr, ptr %t26
  %t28 = add i64 %t22, -1
  %t29 = getelementptr i8, ptr %t27, i64 %t28
  %t30 = load i8, ptr %t29
  %t31 = zext i8 %t30 to i64
  %t32 = insertvalue %KValue { i64 0, i64 undef }, i64 %t31, 1
  br label %L6
L5:
  br label %L6
L6:
  %t33 = phi %KValue [ %t32, %L4 ], [ { i64 4, i64 0 }, %L5 ]
  %t34 = extractvalue %KValue %t33, 0
  %t35 = extractvalue %KValue %t33, 1
  %t36 = icmp eq i64 %t34, 4
  %t37 = select i1 %t36, i64 256, i64 %t35
  %t38 = extractvalue %KValue %t17, 1
  %t39 = musttail call tailcc %parsed @"d_query/array_delim_4"(%KValue %x0, i64 %t37, i64 %t38, %KValue %t15)
  ret %parsed %t39
fail0:
  %t40 = call i64 @k_not_failure(%KValue %x0)
  %t41 = icmp ne i64 %t40, 0
  br i1 %t41, label %L8, label %L7
L7:
  %t42 = call %KValue @k_err_hop(%KValue %x0, ptr @s516)
  %t43 = extractvalue %KValue %t42, 0
  %t44 = extractvalue %KValue %t42, 1
  %t45 = insertvalue %parsed undef, i64 %t43, 0
  %t46 = insertvalue %parsed %t45, i64 %t44, 1
  ret %parsed %t46
L8:
  %t47 = call i64 @k_not_failure(%KValue %x1s)
  %t48 = icmp ne i64 %t47, 0
  br i1 %t48, label %L10, label %L9
L9:
  %t49 = call %KValue @k_err_hop(%KValue %x1s, ptr @s516)
  %t50 = extractvalue %KValue %t49, 0
  %t51 = extractvalue %KValue %t49, 1
  %t52 = insertvalue %parsed undef, i64 %t50, 0
  %t53 = insertvalue %parsed %t52, i64 %t51, 1
  ret %parsed %t53
L10:
  %t54 = call i64 @k_not_failure(%KValue %x2)
  %t55 = icmp ne i64 %t54, 0
  br i1 %t55, label %L12, label %L11
L11:
  %t56 = call %KValue @k_err_hop(%KValue %x2, ptr @s516)
  %t57 = extractvalue %KValue %t56, 0
  %t58 = extractvalue %KValue %t56, 1
  %t59 = insertvalue %parsed undef, i64 %t57, 0
  %t60 = insertvalue %parsed %t59, i64 %t58, 1
  ret %parsed %t60
L12:
  call void @k_die(ptr @s517)
  unreachable
}

define tailcc %KValue @"d_query/bad_value_char_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = call %KValue @k_str_lit(ptr @s519, i64 22, ptr @s519_lit)
  %t2 = alloca [1 x %KValue]
  %t3 = getelementptr [1 x %KValue], ptr %t2, i64 0, i64 0
  store %KValue %x0, ptr %t3
  %t4 = call %KValue @k_list_lit(i64 1, ptr %t2)
  %t5 = call %KValue @"d_query/text/utf8_1"(%KValue %t4)
  %t6 = call %KValue @k_render(%KValue %t5, i64 0)
  %t7 = call %KValue @k_str_lit(ptr @s399, i64 1, ptr @s399_lit)
  %t8 = alloca [3 x %KValue]
  %t9 = getelementptr [3 x %KValue], ptr %t8, i64 0, i64 0
  store %KValue %t1, ptr %t9
  %t10 = getelementptr [3 x %KValue], ptr %t8, i64 0, i64 1
  store %KValue %t6, ptr %t10
  %t11 = getelementptr [3 x %KValue], ptr %t8, i64 0, i64 2
  store %KValue %t7, ptr %t11
  %t12 = call %KValue @k_concat_arr(i64 3, ptr %t8)
  %t13 = extractvalue %KValue %x1, 1
  %t14 = musttail call tailcc %KValue @"d_query/fail_2"(i64 %t13, %KValue %t12)
  ret %KValue %t14
fail0:
  %t15 = call i64 @k_not_failure(%KValue %x0)
  %t16 = icmp ne i64 %t15, 0
  br i1 %t16, label %L2, label %L1
L1:
  %t17 = call %KValue @k_err_hop(%KValue %x0, ptr @s518)
  ret %KValue %t17
L2:
  %t18 = call i64 @k_not_failure(%KValue %x1)
  %t19 = icmp ne i64 %t18, 0
  br i1 %t19, label %L4, label %L3
L3:
  %t20 = call %KValue @k_err_hop(%KValue %x1, ptr @s518)
  ret %KValue %t20
L4:
  call void @k_die(ptr @s520)
  unreachable
}

define %KValue @"d_query/bytes_false_0_build"() {
entry:
  %t1 = alloca [5 x %KValue]
  %t2 = getelementptr [5 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 0, i64 102 }, ptr %t2
  %t3 = getelementptr [5 x %KValue], ptr %t1, i64 0, i64 1
  store %KValue { i64 0, i64 97 }, ptr %t3
  %t4 = getelementptr [5 x %KValue], ptr %t1, i64 0, i64 2
  store %KValue { i64 0, i64 108 }, ptr %t4
  %t5 = getelementptr [5 x %KValue], ptr %t1, i64 0, i64 3
  store %KValue { i64 0, i64 115 }, ptr %t5
  %t6 = getelementptr [5 x %KValue], ptr %t1, i64 0, i64 4
  store %KValue { i64 0, i64 101 }, ptr %t6
  %t7 = call %KValue @k_list_lit(i64 5, ptr %t1)
  ret %KValue %t7
fail0:
  call void @k_die(ptr @s522)
  unreachable
}

define %KValue @"d_query/bytes_false_0"() {
entry:
  %c = load %KValue, ptr @caf_1
  ret %KValue %c
}

define %KValue @"d_query/bytes_null_0_build"() {
entry:
  %t1 = alloca [4 x %KValue]
  %t2 = getelementptr [4 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 0, i64 110 }, ptr %t2
  %t3 = getelementptr [4 x %KValue], ptr %t1, i64 0, i64 1
  store %KValue { i64 0, i64 117 }, ptr %t3
  %t4 = getelementptr [4 x %KValue], ptr %t1, i64 0, i64 2
  store %KValue { i64 0, i64 108 }, ptr %t4
  %t5 = getelementptr [4 x %KValue], ptr %t1, i64 0, i64 3
  store %KValue { i64 0, i64 108 }, ptr %t5
  %t6 = call %KValue @k_list_lit(i64 4, ptr %t1)
  ret %KValue %t6
fail0:
  call void @k_die(ptr @s524)
  unreachable
}

define %KValue @"d_query/bytes_null_0"() {
entry:
  %c = load %KValue, ptr @caf_2
  ret %KValue %c
}

define %KValue @"d_query/bytes_true_0_build"() {
entry:
  %t1 = alloca [4 x %KValue]
  %t2 = getelementptr [4 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue { i64 0, i64 116 }, ptr %t2
  %t3 = getelementptr [4 x %KValue], ptr %t1, i64 0, i64 1
  store %KValue { i64 0, i64 114 }, ptr %t3
  %t4 = getelementptr [4 x %KValue], ptr %t1, i64 0, i64 2
  store %KValue { i64 0, i64 117 }, ptr %t4
  %t5 = getelementptr [4 x %KValue], ptr %t1, i64 0, i64 3
  store %KValue { i64 0, i64 101 }, ptr %t5
  %t6 = call %KValue @k_list_lit(i64 4, ptr %t1)
  ret %KValue %t6
fail0:
  call void @k_die(ptr @s526)
  unreachable
}

define %KValue @"d_query/bytes_true_0"() {
entry:
  %c = load %KValue, ptr @caf_3
  ret %KValue %c
}

define tailcc %parsed @"d_query/obj_colon_4"(%KValue %x0, %KValue %x1, %KValue %x2, %KValue %x3) {
entry:
  %t1 = call i64 @k_not_failure(%KValue %x1)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1, 1
  %t4 = call tailcc %parsed @"d_query/parse_value_2"(%KValue %x0, i64 %t3)
  %t5 = musttail call tailcc %parsed @"d_query/obj_value_4"(%KValue %x0, %parsed %t4, %KValue %x2, %KValue %x3)
  ret %parsed %t5
fail0:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %L3, label %L2
L2:
  %t8 = call %KValue @k_err_hop(%KValue %x0, ptr @s527)
  %t9 = extractvalue %KValue %t8, 0
  %t10 = extractvalue %KValue %t8, 1
  %t11 = insertvalue %parsed undef, i64 %t9, 0
  %t12 = insertvalue %parsed %t11, i64 %t10, 1
  ret %parsed %t12
L3:
  %t13 = call i64 @k_not_failure(%KValue %x1)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L5, label %L4
L4:
  %t15 = call %KValue @k_err_hop(%KValue %x1, ptr @s527)
  %t16 = extractvalue %KValue %t15, 0
  %t17 = extractvalue %KValue %t15, 1
  %t18 = insertvalue %parsed undef, i64 %t16, 0
  %t19 = insertvalue %parsed %t18, i64 %t17, 1
  ret %parsed %t19
L5:
  %t20 = call i64 @k_not_failure(%KValue %x2)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L7, label %L6
L6:
  %t22 = call %KValue @k_err_hop(%KValue %x2, ptr @s527)
  %t23 = extractvalue %KValue %t22, 0
  %t24 = extractvalue %KValue %t22, 1
  %t25 = insertvalue %parsed undef, i64 %t23, 0
  %t26 = insertvalue %parsed %t25, i64 %t24, 1
  ret %parsed %t26
L7:
  %t27 = call i64 @k_not_failure(%KValue %x3)
  %t28 = icmp ne i64 %t27, 0
  br i1 %t28, label %L9, label %L8
L8:
  %t29 = call %KValue @k_err_hop(%KValue %x3, ptr @s527)
  %t30 = extractvalue %KValue %t29, 0
  %t31 = extractvalue %KValue %t29, 1
  %t32 = insertvalue %parsed undef, i64 %t30, 0
  %t33 = insertvalue %parsed %t32, i64 %t31, 1
  ret %parsed %t33
L9:
  call void @k_die(ptr @s528)
  unreachable
}

define tailcc %parsed @"d_query/obj_delim_4"(%KValue %x0, i64 %x1r, i64 %x2r, %KValue %x3) {
entry:
  %t1 = icmp eq i64 %x1r, 256
  %x1b = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %x1 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x1b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x1, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x1, 1
  switch i64 %t4, label %arm3 [
    i64 44, label %arm0
    i64 125, label %arm1
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm2, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x1)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm3, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x1, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x1, ptr @s529)
  %t13 = extractvalue %KValue %t12, 0
  %t14 = extractvalue %KValue %t12, 1
  %t15 = insertvalue %parsed undef, i64 %t13, 0
  %t16 = insertvalue %parsed %t15, i64 %t14, 1
  ret %parsed %t16
L6:
  call void @k_die(ptr @s530)
  unreachable
arm0:
  %t17 = extractvalue %KValue %x2, 1
  %t18 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t19 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t17, i64 %t18)
  %t20 = extractvalue { i64, i1 } %t19, 0
  %t21 = extractvalue { i64, i1 } %t19, 1
  br i1 %t21, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  %t23 = extractvalue %KValue %t22, 1
  %t24 = musttail call tailcc %parsed @"d_query/obj_items_3"(%KValue %x0, i64 %t23, %KValue %x3)
  ret %parsed %t24
arm1:
  %t25 = extractvalue %KValue %x2, 1
  %t26 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t27 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t25, i64 %t26)
  %t28 = extractvalue { i64, i1 } %t27, 0
  %t29 = extractvalue { i64, i1 } %t27, 1
  br i1 %t29, label %L10, label %L9
L10:
  call void @k_die(ptr @s94)
  unreachable
L9:
  %t30 = insertvalue %KValue { i64 0, i64 undef }, i64 %t28, 1
  %t31 = call i64 @k_not_failure(%KValue %t30)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L11, label %L12
L12:
  %t33 = extractvalue %KValue %t30, 0
  %t34 = extractvalue %KValue %t30, 1
  %t35 = insertvalue %parsed undef, i64 %t33, 0
  %t36 = insertvalue %parsed %t35, i64 %t34, 1
  ret %parsed %t36
L11:
  %t37 = call i64 @k_not_failure(%KValue %x3)
  %t38 = icmp ne i64 %t37, 0
  br i1 %t38, label %L13, label %L14
L14:
  %t39 = extractvalue %KValue %x3, 0
  %t40 = extractvalue %KValue %x3, 1
  %t41 = insertvalue %parsed undef, i64 %t39, 0
  %t42 = insertvalue %parsed %t41, i64 %t40, 1
  ret %parsed %t42
L13:
  %t43 = extractvalue %KValue %t30, 1
  %t44 = shl i64 %t43, 8
  %t45 = extractvalue %KValue %x3, 0
  %t46 = or i64 %t44, %t45
  %t47 = extractvalue %KValue %x3, 1
  %t48 = insertvalue %parsed undef, i64 %t46, 0
  %t49 = insertvalue %parsed %t48, i64 %t47, 1
  ret %parsed %t49
arm2:
  %t50 = call %KValue @k_str_lit(ptr @s343, i64 23, ptr @s343_lit)
  %t51 = extractvalue %KValue %x2, 1
  %t52 = call tailcc %KValue @"d_query/fail_2"(i64 %t51, %KValue %t50)
  %t53 = extractvalue %KValue %t52, 0
  %t54 = extractvalue %KValue %t52, 1
  %t55 = insertvalue %parsed undef, i64 %t53, 0
  %t56 = insertvalue %parsed %t55, i64 %t54, 1
  ret %parsed %t56
arm3:
  %t57 = call %KValue @k_str_lit(ptr @s531, i64 28, ptr @s531_lit)
  %t58 = alloca [1 x %KValue]
  %t59 = getelementptr [1 x %KValue], ptr %t58, i64 0, i64 0
  store %KValue %x1, ptr %t59
  %t60 = call %KValue @k_list_lit(i64 1, ptr %t58)
  %t61 = call %KValue @"d_query/text/utf8_1"(%KValue %t60)
  %t62 = call %KValue @k_render(%KValue %t61, i64 0)
  %t63 = call %KValue @k_str_lit(ptr @s399, i64 1, ptr @s399_lit)
  %t64 = alloca [3 x %KValue]
  %t65 = getelementptr [3 x %KValue], ptr %t64, i64 0, i64 0
  store %KValue %t57, ptr %t65
  %t66 = getelementptr [3 x %KValue], ptr %t64, i64 0, i64 1
  store %KValue %t62, ptr %t66
  %t67 = getelementptr [3 x %KValue], ptr %t64, i64 0, i64 2
  store %KValue %t63, ptr %t67
  %t68 = call %KValue @k_concat_arr(i64 3, ptr %t64)
  %t69 = extractvalue %KValue %x2, 1
  %t70 = call tailcc %KValue @"d_query/fail_2"(i64 %t69, %KValue %t68)
  %t71 = extractvalue %KValue %t70, 0
  %t72 = extractvalue %KValue %t70, 1
  %t73 = insertvalue %parsed undef, i64 %t71, 0
  %t74 = insertvalue %parsed %t73, i64 %t72, 1
  ret %parsed %t74
}

define tailcc %parsed @"d_query/obj_items_3"(%KValue %x0, i64 %x1r, %KValue %x2) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t1)
  %t3 = extractvalue %KValue %x0, 1
  %t4 = inttoptr i64 %t3 to ptr
  %t5 = getelementptr %KBytes, ptr %t4, i64 0, i32 0
  %t6 = load i64, ptr %t5
  %t7 = extractvalue %KValue %t2, 1
  %t8 = icmp sge i64 %t7, 1
  %t9 = icmp sle i64 %t7, %t6
  %t10 = and i1 %t8, %t9
  br i1 %t10, label %L1, label %L2
L1:
  %t11 = getelementptr %KBytes, ptr %t4, i64 0, i32 1
  %t12 = load ptr, ptr %t11
  %t13 = add i64 %t7, -1
  %t14 = getelementptr i8, ptr %t12, i64 %t13
  %t15 = load i8, ptr %t14
  %t16 = zext i8 %t15 to i64
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t16, 1
  br label %L3
L2:
  br label %L3
L3:
  %t18 = phi %KValue [ %t17, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t19 = extractvalue %KValue %t2, 1
  %t20 = musttail call tailcc %parsed @"d_query/obj_key_start_4"(%KValue %x0, %KValue %t18, i64 %t19, %KValue %x2)
  ret %parsed %t20
fail0:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L5, label %L4
L4:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s532)
  %t24 = extractvalue %KValue %t23, 0
  %t25 = extractvalue %KValue %t23, 1
  %t26 = insertvalue %parsed undef, i64 %t24, 0
  %t27 = insertvalue %parsed %t26, i64 %t25, 1
  ret %parsed %t27
L5:
  %t28 = call i64 @k_not_failure(%KValue %x1)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L7, label %L6
L6:
  %t30 = call %KValue @k_err_hop(%KValue %x1, ptr @s532)
  %t31 = extractvalue %KValue %t30, 0
  %t32 = extractvalue %KValue %t30, 1
  %t33 = insertvalue %parsed undef, i64 %t31, 0
  %t34 = insertvalue %parsed %t33, i64 %t32, 1
  ret %parsed %t34
L7:
  %t35 = call i64 @k_not_failure(%KValue %x2)
  %t36 = icmp ne i64 %t35, 0
  br i1 %t36, label %L9, label %L8
L8:
  %t37 = call %KValue @k_err_hop(%KValue %x2, ptr @s532)
  %t38 = extractvalue %KValue %t37, 0
  %t39 = extractvalue %KValue %t37, 1
  %t40 = insertvalue %parsed undef, i64 %t38, 0
  %t41 = insertvalue %parsed %t40, i64 %t39, 1
  ret %parsed %t41
L9:
  call void @k_die(ptr @s533)
  unreachable
}

define tailcc %parsed @"d_query/obj_key_3"(%KValue %x0, %parsed %x1, %KValue %x2) {
entry:
  %x1w0 = extractvalue %parsed %x1, 0
  %x1w1 = extractvalue %parsed %x1, 1
  %x1sa = insertvalue %KValue undef, i64 %x1w0, 0
  %x1s = insertvalue %KValue %x1sa, i64 %x1w1, 1
  %t1 = call i64 @k_not_failure(%KValue %x1s)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1s, 0
  %t4 = extractvalue %KValue %x1s, 1
  %t5 = lshr i64 %t3, 8
  %t6 = insertvalue %KValue undef, i64 0, 0
  %t7 = insertvalue %KValue %t6, i64 %t5, 1
  %t8 = call i64 @k_not_failure(%KValue %t7)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %fail0
L2:
  %t10 = and i64 %t3, 255
  %t11 = insertvalue %KValue undef, i64 %t10, 0
  %t12 = insertvalue %KValue %t11, i64 %t4, 1
  %t13 = call i64 @k_not_failure(%KValue %t12)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L3, label %fail0
L3:
  %t15 = extractvalue %KValue %t7, 1
  %t16 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t15)
  %t17 = extractvalue %KValue %t16, 1
  %t18 = extractvalue %KValue { i64 0, i64 58 }, 1
  %t19 = call tailcc %KValue @"d_query/expect_char_3"(%KValue %x0, i64 %t17, i64 %t18)
  %t20 = musttail call tailcc %parsed @"d_query/obj_colon_4"(%KValue %x0, %KValue %t19, %KValue %t12, %KValue %x2)
  ret %parsed %t20
fail0:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L5, label %L4
L4:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s534)
  %t24 = extractvalue %KValue %t23, 0
  %t25 = extractvalue %KValue %t23, 1
  %t26 = insertvalue %parsed undef, i64 %t24, 0
  %t27 = insertvalue %parsed %t26, i64 %t25, 1
  ret %parsed %t27
L5:
  %t28 = call i64 @k_not_failure(%KValue %x1s)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L7, label %L6
L6:
  %t30 = call %KValue @k_err_hop(%KValue %x1s, ptr @s534)
  %t31 = extractvalue %KValue %t30, 0
  %t32 = extractvalue %KValue %t30, 1
  %t33 = insertvalue %parsed undef, i64 %t31, 0
  %t34 = insertvalue %parsed %t33, i64 %t32, 1
  ret %parsed %t34
L7:
  %t35 = call i64 @k_not_failure(%KValue %x2)
  %t36 = icmp ne i64 %t35, 0
  br i1 %t36, label %L9, label %L8
L8:
  %t37 = call %KValue @k_err_hop(%KValue %x2, ptr @s534)
  %t38 = extractvalue %KValue %t37, 0
  %t39 = extractvalue %KValue %t37, 1
  %t40 = insertvalue %parsed undef, i64 %t38, 0
  %t41 = insertvalue %parsed %t40, i64 %t39, 1
  ret %parsed %t41
L9:
  call void @k_die(ptr @s535)
  unreachable
}

define tailcc %parsed @"d_query/obj_key_start_4"(%KValue %x0, %KValue %x1, i64 %x2r, %KValue %x3) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x1, 0
  %t2 = icmp eq i64 %t1, 0
  %t3 = extractvalue %KValue %x1, 1
  %t4 = icmp eq i64 %t3, 34
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %fail0
L1:
  %t6 = extractvalue %KValue %x2, 1
  %t7 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t8 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t6, i64 %t7)
  %t9 = extractvalue { i64, i1 } %t8, 0
  %t10 = extractvalue { i64, i1 } %t8, 1
  br i1 %t10, label %L3, label %L2
L3:
  call void @k_die(ptr @s94)
  unreachable
L2:
  %t11 = insertvalue %KValue { i64 0, i64 undef }, i64 %t9, 1
  %t12 = extractvalue %KValue %t11, 1
  %t13 = call tailcc %parsed @"d_query/parse_string_2"(%KValue %x0, i64 %t12)
  %t14 = musttail call tailcc %parsed @"d_query/obj_key_3"(%KValue %x0, %parsed %t13, %KValue %x3)
  ret %parsed %t14
fail0:
  %t15 = extractvalue %KValue %x1, 0
  %t16 = icmp eq i64 %t15, 4
  br i1 %t16, label %L4, label %fail1
L4:
  %t17 = call %KValue @k_str_lit(ptr @s343, i64 23, ptr @s343_lit)
  %t18 = extractvalue %KValue %x2, 1
  %t19 = call tailcc %KValue @"d_query/fail_2"(i64 %t18, %KValue %t17)
  %t20 = extractvalue %KValue %t19, 0
  %t21 = extractvalue %KValue %t19, 1
  %t22 = insertvalue %parsed undef, i64 %t20, 0
  %t23 = insertvalue %parsed %t22, i64 %t21, 1
  ret %parsed %t23
fail1:
  %t24 = call %KValue @k_str_lit(ptr @s537, i64 21, ptr @s537_lit)
  %t25 = extractvalue %KValue %x2, 1
  %t26 = call tailcc %KValue @"d_query/fail_2"(i64 %t25, %KValue %t24)
  %t27 = extractvalue %KValue %t26, 0
  %t28 = extractvalue %KValue %t26, 1
  %t29 = insertvalue %parsed undef, i64 %t27, 0
  %t30 = insertvalue %parsed %t29, i64 %t28, 1
  ret %parsed %t30
fail2:
  %t31 = call i64 @k_not_failure(%KValue %x0)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L6, label %L5
L5:
  %t33 = call %KValue @k_err_hop(%KValue %x0, ptr @s536)
  %t34 = extractvalue %KValue %t33, 0
  %t35 = extractvalue %KValue %t33, 1
  %t36 = insertvalue %parsed undef, i64 %t34, 0
  %t37 = insertvalue %parsed %t36, i64 %t35, 1
  ret %parsed %t37
L6:
  %t38 = call i64 @k_not_failure(%KValue %x1)
  %t39 = icmp ne i64 %t38, 0
  br i1 %t39, label %L8, label %L7
L7:
  %t40 = call %KValue @k_err_hop(%KValue %x1, ptr @s536)
  %t41 = extractvalue %KValue %t40, 0
  %t42 = extractvalue %KValue %t40, 1
  %t43 = insertvalue %parsed undef, i64 %t41, 0
  %t44 = insertvalue %parsed %t43, i64 %t42, 1
  ret %parsed %t44
L8:
  %t45 = call i64 @k_not_failure(%KValue %x2)
  %t46 = icmp ne i64 %t45, 0
  br i1 %t46, label %L10, label %L9
L9:
  %t47 = call %KValue @k_err_hop(%KValue %x2, ptr @s536)
  %t48 = extractvalue %KValue %t47, 0
  %t49 = extractvalue %KValue %t47, 1
  %t50 = insertvalue %parsed undef, i64 %t48, 0
  %t51 = insertvalue %parsed %t50, i64 %t49, 1
  ret %parsed %t51
L10:
  %t52 = call i64 @k_not_failure(%KValue %x3)
  %t53 = icmp ne i64 %t52, 0
  br i1 %t53, label %L12, label %L11
L11:
  %t54 = call %KValue @k_err_hop(%KValue %x3, ptr @s536)
  %t55 = extractvalue %KValue %t54, 0
  %t56 = extractvalue %KValue %t54, 1
  %t57 = insertvalue %parsed undef, i64 %t55, 0
  %t58 = insertvalue %parsed %t57, i64 %t56, 1
  ret %parsed %t58
L12:
  call void @k_die(ptr @s538)
  unreachable
}

define tailcc %parsed @"d_query/obj_open_3"(%KValue %x0, %KValue %x1, i64 %x2r) {
entry:
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  %t1 = extractvalue %KValue %x1, 0
  %t2 = icmp eq i64 %t1, 0
  %t3 = extractvalue %KValue %x1, 1
  %t4 = icmp eq i64 %t3, 125
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %fail0
L1:
  %t6 = extractvalue %KValue %x2, 1
  %t7 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t8 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t6, i64 %t7)
  %t9 = extractvalue { i64, i1 } %t8, 0
  %t10 = extractvalue { i64, i1 } %t8, 1
  br i1 %t10, label %L3, label %L2
L3:
  call void @k_die(ptr @s94)
  unreachable
L2:
  %t11 = insertvalue %KValue { i64 0, i64 undef }, i64 %t9, 1
  %t12 = call i64 @k_not_failure(%KValue %t11)
  %t13 = icmp ne i64 %t12, 0
  br i1 %t13, label %L4, label %L5
L5:
  %t14 = extractvalue %KValue %t11, 0
  %t15 = extractvalue %KValue %t11, 1
  %t16 = insertvalue %parsed undef, i64 %t14, 0
  %t17 = insertvalue %parsed %t16, i64 %t15, 1
  ret %parsed %t17
L4:
  %t18 = alloca [1 x %KValue]
  %t19 = call %KValue @k_map_lit(i64 0, ptr %t18)
  %t20 = call i64 @k_not_failure(%KValue %t19)
  %t21 = icmp ne i64 %t20, 0
  br i1 %t21, label %L6, label %L7
L7:
  %t22 = extractvalue %KValue %t19, 0
  %t23 = extractvalue %KValue %t19, 1
  %t24 = insertvalue %parsed undef, i64 %t22, 0
  %t25 = insertvalue %parsed %t24, i64 %t23, 1
  ret %parsed %t25
L6:
  %t26 = extractvalue %KValue %t11, 1
  %t27 = shl i64 %t26, 8
  %t28 = extractvalue %KValue %t19, 0
  %t29 = or i64 %t27, %t28
  %t30 = extractvalue %KValue %t19, 1
  %t31 = insertvalue %parsed undef, i64 %t29, 0
  %t32 = insertvalue %parsed %t31, i64 %t30, 1
  ret %parsed %t32
fail0:
  %t33 = extractvalue %KValue %x1, 0
  %t34 = icmp eq i64 %t33, 4
  br i1 %t34, label %L8, label %fail1
L8:
  %t35 = call %KValue @k_str_lit(ptr @s343, i64 23, ptr @s343_lit)
  %t36 = extractvalue %KValue %x2, 1
  %t37 = call tailcc %KValue @"d_query/fail_2"(i64 %t36, %KValue %t35)
  %t38 = extractvalue %KValue %t37, 0
  %t39 = extractvalue %KValue %t37, 1
  %t40 = insertvalue %parsed undef, i64 %t38, 0
  %t41 = insertvalue %parsed %t40, i64 %t39, 1
  ret %parsed %t41
fail1:
  %t42 = alloca [1 x %KValue]
  %t43 = call %KValue @k_map_lit(i64 0, ptr %t42)
  %t44 = extractvalue %KValue %x2, 1
  %t45 = musttail call tailcc %parsed @"d_query/obj_items_3"(%KValue %x0, i64 %t44, %KValue %t43)
  ret %parsed %t45
fail2:
  %t46 = call i64 @k_not_failure(%KValue %x0)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L10, label %L9
L9:
  %t48 = call %KValue @k_err_hop(%KValue %x0, ptr @s539)
  %t49 = extractvalue %KValue %t48, 0
  %t50 = extractvalue %KValue %t48, 1
  %t51 = insertvalue %parsed undef, i64 %t49, 0
  %t52 = insertvalue %parsed %t51, i64 %t50, 1
  ret %parsed %t52
L10:
  %t53 = call i64 @k_not_failure(%KValue %x1)
  %t54 = icmp ne i64 %t53, 0
  br i1 %t54, label %L12, label %L11
L11:
  %t55 = call %KValue @k_err_hop(%KValue %x1, ptr @s539)
  %t56 = extractvalue %KValue %t55, 0
  %t57 = extractvalue %KValue %t55, 1
  %t58 = insertvalue %parsed undef, i64 %t56, 0
  %t59 = insertvalue %parsed %t58, i64 %t57, 1
  ret %parsed %t59
L12:
  %t60 = call i64 @k_not_failure(%KValue %x2)
  %t61 = icmp ne i64 %t60, 0
  br i1 %t61, label %L14, label %L13
L13:
  %t62 = call %KValue @k_err_hop(%KValue %x2, ptr @s539)
  %t63 = extractvalue %KValue %t62, 0
  %t64 = extractvalue %KValue %t62, 1
  %t65 = insertvalue %parsed undef, i64 %t63, 0
  %t66 = insertvalue %parsed %t65, i64 %t64, 1
  ret %parsed %t66
L14:
  call void @k_die(ptr @s540)
  unreachable
}

define tailcc %parsed @"d_query/obj_value_4"(%KValue %x0, %parsed %x1, %KValue %x2, %KValue %x3) {
entry:
  %x1w0 = extractvalue %parsed %x1, 0
  %x1w1 = extractvalue %parsed %x1, 1
  %x1sa = insertvalue %KValue undef, i64 %x1w0, 0
  %x1s = insertvalue %KValue %x1sa, i64 %x1w1, 1
  %t1 = call i64 @k_not_failure(%KValue %x1s)
  %t2 = icmp ne i64 %t1, 0
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = extractvalue %KValue %x1s, 0
  %t4 = extractvalue %KValue %x1s, 1
  %t5 = lshr i64 %t3, 8
  %t6 = insertvalue %KValue undef, i64 0, 0
  %t7 = insertvalue %KValue %t6, i64 %t5, 1
  %t8 = call i64 @k_not_failure(%KValue %t7)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L2, label %fail0
L2:
  %t10 = and i64 %t3, 255
  %t11 = insertvalue %KValue undef, i64 %t10, 0
  %t12 = insertvalue %KValue %t11, i64 %t4, 1
  %t13 = call i64 @k_not_failure(%KValue %t12)
  %t14 = icmp ne i64 %t13, 0
  br i1 %t14, label %L3, label %fail0
L3:
  %t15 = call %KValue @k_b_put_mut(%KValue %x3, %KValue %x2, %KValue %t12)
  %t16 = extractvalue %KValue %t7, 1
  %t17 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t16)
  %t18 = extractvalue %KValue %x0, 1
  %t19 = inttoptr i64 %t18 to ptr
  %t20 = getelementptr %KBytes, ptr %t19, i64 0, i32 0
  %t21 = load i64, ptr %t20
  %t22 = extractvalue %KValue %t17, 1
  %t23 = icmp sge i64 %t22, 1
  %t24 = icmp sle i64 %t22, %t21
  %t25 = and i1 %t23, %t24
  br i1 %t25, label %L4, label %L5
L4:
  %t26 = getelementptr %KBytes, ptr %t19, i64 0, i32 1
  %t27 = load ptr, ptr %t26
  %t28 = add i64 %t22, -1
  %t29 = getelementptr i8, ptr %t27, i64 %t28
  %t30 = load i8, ptr %t29
  %t31 = zext i8 %t30 to i64
  %t32 = insertvalue %KValue { i64 0, i64 undef }, i64 %t31, 1
  br label %L6
L5:
  br label %L6
L6:
  %t33 = phi %KValue [ %t32, %L4 ], [ { i64 4, i64 0 }, %L5 ]
  %t34 = extractvalue %KValue %t33, 0
  %t35 = extractvalue %KValue %t33, 1
  %t36 = icmp eq i64 %t34, 4
  %t37 = select i1 %t36, i64 256, i64 %t35
  %t38 = extractvalue %KValue %t17, 1
  %t39 = musttail call tailcc %parsed @"d_query/obj_delim_4"(%KValue %x0, i64 %t37, i64 %t38, %KValue %t15)
  ret %parsed %t39
fail0:
  %t40 = call i64 @k_not_failure(%KValue %x0)
  %t41 = icmp ne i64 %t40, 0
  br i1 %t41, label %L8, label %L7
L7:
  %t42 = call %KValue @k_err_hop(%KValue %x0, ptr @s541)
  %t43 = extractvalue %KValue %t42, 0
  %t44 = extractvalue %KValue %t42, 1
  %t45 = insertvalue %parsed undef, i64 %t43, 0
  %t46 = insertvalue %parsed %t45, i64 %t44, 1
  ret %parsed %t46
L8:
  %t47 = call i64 @k_not_failure(%KValue %x1s)
  %t48 = icmp ne i64 %t47, 0
  br i1 %t48, label %L10, label %L9
L9:
  %t49 = call %KValue @k_err_hop(%KValue %x1s, ptr @s541)
  %t50 = extractvalue %KValue %t49, 0
  %t51 = extractvalue %KValue %t49, 1
  %t52 = insertvalue %parsed undef, i64 %t50, 0
  %t53 = insertvalue %parsed %t52, i64 %t51, 1
  ret %parsed %t53
L10:
  %t54 = call i64 @k_not_failure(%KValue %x2)
  %t55 = icmp ne i64 %t54, 0
  br i1 %t55, label %L12, label %L11
L11:
  %t56 = call %KValue @k_err_hop(%KValue %x2, ptr @s541)
  %t57 = extractvalue %KValue %t56, 0
  %t58 = extractvalue %KValue %t56, 1
  %t59 = insertvalue %parsed undef, i64 %t57, 0
  %t60 = insertvalue %parsed %t59, i64 %t58, 1
  ret %parsed %t60
L12:
  %t61 = call i64 @k_not_failure(%KValue %x3)
  %t62 = icmp ne i64 %t61, 0
  br i1 %t62, label %L14, label %L13
L13:
  %t63 = call %KValue @k_err_hop(%KValue %x3, ptr @s541)
  %t64 = extractvalue %KValue %t63, 0
  %t65 = extractvalue %KValue %t63, 1
  %t66 = insertvalue %parsed undef, i64 %t64, 0
  %t67 = insertvalue %parsed %t66, i64 %t65, 1
  ret %parsed %t67
L14:
  call void @k_die(ptr @s542)
  unreachable
}

define tailcc %parsed @"d_query/parse_array_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t1)
  %t3 = extractvalue %KValue %x0, 1
  %t4 = inttoptr i64 %t3 to ptr
  %t5 = getelementptr %KBytes, ptr %t4, i64 0, i32 0
  %t6 = load i64, ptr %t5
  %t7 = extractvalue %KValue %t2, 1
  %t8 = icmp sge i64 %t7, 1
  %t9 = icmp sle i64 %t7, %t6
  %t10 = and i1 %t8, %t9
  br i1 %t10, label %L1, label %L2
L1:
  %t11 = getelementptr %KBytes, ptr %t4, i64 0, i32 1
  %t12 = load ptr, ptr %t11
  %t13 = add i64 %t7, -1
  %t14 = getelementptr i8, ptr %t12, i64 %t13
  %t15 = load i8, ptr %t14
  %t16 = zext i8 %t15 to i64
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t16, 1
  br label %L3
L2:
  br label %L3
L3:
  %t18 = phi %KValue [ %t17, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t19 = extractvalue %KValue %t2, 1
  %t20 = musttail call tailcc %parsed @"d_query/array_open_3"(%KValue %x0, %KValue %t18, i64 %t19)
  ret %parsed %t20
fail0:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L5, label %L4
L4:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s543)
  %t24 = extractvalue %KValue %t23, 0
  %t25 = extractvalue %KValue %t23, 1
  %t26 = insertvalue %parsed undef, i64 %t24, 0
  %t27 = insertvalue %parsed %t26, i64 %t25, 1
  ret %parsed %t27
L5:
  %t28 = call i64 @k_not_failure(%KValue %x1)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L7, label %L6
L6:
  %t30 = call %KValue @k_err_hop(%KValue %x1, ptr @s543)
  %t31 = extractvalue %KValue %t30, 0
  %t32 = extractvalue %KValue %t30, 1
  %t33 = insertvalue %parsed undef, i64 %t31, 0
  %t34 = insertvalue %parsed %t33, i64 %t32, 1
  ret %parsed %t34
L7:
  call void @k_die(ptr @s544)
  unreachable
}

define tailcc %parsed @"d_query/parse_number_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = call tailcc %KValue @"d_query/number_end_2"(%KValue %x0, i64 %t1)
  %t3 = call i64 @k_not_failure(%KValue %t2)
  %t4 = icmp ne i64 %t3, 0
  br i1 %t4, label %L1, label %L2
L2:
  %t5 = extractvalue %KValue %t2, 0
  %t6 = extractvalue %KValue %t2, 1
  %t7 = insertvalue %parsed undef, i64 %t5, 0
  %t8 = insertvalue %parsed %t7, i64 %t6, 1
  ret %parsed %t8
L1:
  %t9 = extractvalue %KValue %t2, 1
  %t10 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t11 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t9, i64 %t10)
  %t12 = extractvalue { i64, i1 } %t11, 0
  %t13 = extractvalue { i64, i1 } %t11, 1
  br i1 %t13, label %L4, label %L3
L4:
  call void @k_die(ptr @s94)
  unreachable
L3:
  %t14 = insertvalue %KValue { i64 0, i64 undef }, i64 %t12, 1
  %t15 = extractvalue %KValue %x1, 1
  %t16 = extractvalue %KValue %t14, 1
  %t17 = call tailcc %KValue @"d_query/number_value_3"(%KValue %x0, i64 %t15, i64 %t16)
  %t18 = call i64 @k_not_failure(%KValue %t17)
  %t19 = icmp ne i64 %t18, 0
  br i1 %t19, label %L5, label %L6
L6:
  %t20 = extractvalue %KValue %t17, 0
  %t21 = extractvalue %KValue %t17, 1
  %t22 = insertvalue %parsed undef, i64 %t20, 0
  %t23 = insertvalue %parsed %t22, i64 %t21, 1
  ret %parsed %t23
L5:
  %t24 = extractvalue %KValue %t2, 1
  %t25 = shl i64 %t24, 8
  %t26 = extractvalue %KValue %t17, 0
  %t27 = or i64 %t25, %t26
  %t28 = extractvalue %KValue %t17, 1
  %t29 = insertvalue %parsed undef, i64 %t27, 0
  %t30 = insertvalue %parsed %t29, i64 %t28, 1
  ret %parsed %t30
fail0:
  %t31 = call i64 @k_not_failure(%KValue %x0)
  %t32 = icmp ne i64 %t31, 0
  br i1 %t32, label %L8, label %L7
L7:
  %t33 = call %KValue @k_err_hop(%KValue %x0, ptr @s545)
  %t34 = extractvalue %KValue %t33, 0
  %t35 = extractvalue %KValue %t33, 1
  %t36 = insertvalue %parsed undef, i64 %t34, 0
  %t37 = insertvalue %parsed %t36, i64 %t35, 1
  ret %parsed %t37
L8:
  %t38 = call i64 @k_not_failure(%KValue %x1)
  %t39 = icmp ne i64 %t38, 0
  br i1 %t39, label %L10, label %L9
L9:
  %t40 = call %KValue @k_err_hop(%KValue %x1, ptr @s545)
  %t41 = extractvalue %KValue %t40, 0
  %t42 = extractvalue %KValue %t40, 1
  %t43 = insertvalue %parsed undef, i64 %t41, 0
  %t44 = insertvalue %parsed %t43, i64 %t42, 1
  ret %parsed %t44
L10:
  call void @k_die(ptr @s546)
  unreachable
}

define tailcc %parsed @"d_query/parse_object_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t1)
  %t3 = extractvalue %KValue %x0, 1
  %t4 = inttoptr i64 %t3 to ptr
  %t5 = getelementptr %KBytes, ptr %t4, i64 0, i32 0
  %t6 = load i64, ptr %t5
  %t7 = extractvalue %KValue %t2, 1
  %t8 = icmp sge i64 %t7, 1
  %t9 = icmp sle i64 %t7, %t6
  %t10 = and i1 %t8, %t9
  br i1 %t10, label %L1, label %L2
L1:
  %t11 = getelementptr %KBytes, ptr %t4, i64 0, i32 1
  %t12 = load ptr, ptr %t11
  %t13 = add i64 %t7, -1
  %t14 = getelementptr i8, ptr %t12, i64 %t13
  %t15 = load i8, ptr %t14
  %t16 = zext i8 %t15 to i64
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t16, 1
  br label %L3
L2:
  br label %L3
L3:
  %t18 = phi %KValue [ %t17, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t19 = extractvalue %KValue %t2, 1
  %t20 = musttail call tailcc %parsed @"d_query/obj_open_3"(%KValue %x0, %KValue %t18, i64 %t19)
  ret %parsed %t20
fail0:
  %t21 = call i64 @k_not_failure(%KValue %x0)
  %t22 = icmp ne i64 %t21, 0
  br i1 %t22, label %L5, label %L4
L4:
  %t23 = call %KValue @k_err_hop(%KValue %x0, ptr @s547)
  %t24 = extractvalue %KValue %t23, 0
  %t25 = extractvalue %KValue %t23, 1
  %t26 = insertvalue %parsed undef, i64 %t24, 0
  %t27 = insertvalue %parsed %t26, i64 %t25, 1
  ret %parsed %t27
L5:
  %t28 = call i64 @k_not_failure(%KValue %x1)
  %t29 = icmp ne i64 %t28, 0
  br i1 %t29, label %L7, label %L6
L6:
  %t30 = call %KValue @k_err_hop(%KValue %x1, ptr @s547)
  %t31 = extractvalue %KValue %t30, 0
  %t32 = extractvalue %KValue %t30, 1
  %t33 = insertvalue %parsed undef, i64 %t31, 0
  %t34 = insertvalue %parsed %t33, i64 %t32, 1
  ret %parsed %t34
L7:
  call void @k_die(ptr @s548)
  unreachable
}

define tailcc %parsed @"d_query/parse_value_2"(%KValue %x0, i64 %x1r) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = extractvalue %KValue %x1, 1
  %t2 = call tailcc %KValue @"d_query/skip_ws_2"(%KValue %x0, i64 %t1)
  %t3 = extractvalue %KValue %x0, 1
  %t4 = inttoptr i64 %t3 to ptr
  %t5 = getelementptr %KBytes, ptr %t4, i64 0, i32 0
  %t6 = load i64, ptr %t5
  %t7 = extractvalue %KValue %t2, 1
  %t8 = icmp sge i64 %t7, 1
  %t9 = icmp sle i64 %t7, %t6
  %t10 = and i1 %t8, %t9
  br i1 %t10, label %L1, label %L2
L1:
  %t11 = getelementptr %KBytes, ptr %t4, i64 0, i32 1
  %t12 = load ptr, ptr %t11
  %t13 = add i64 %t7, -1
  %t14 = getelementptr i8, ptr %t12, i64 %t13
  %t15 = load i8, ptr %t14
  %t16 = zext i8 %t15 to i64
  %t17 = insertvalue %KValue { i64 0, i64 undef }, i64 %t16, 1
  br label %L3
L2:
  br label %L3
L3:
  %t18 = phi %KValue [ %t17, %L1 ], [ { i64 4, i64 0 }, %L2 ]
  %t19 = extractvalue %KValue %t18, 0
  %t20 = extractvalue %KValue %t18, 1
  %t21 = icmp eq i64 %t19, 4
  %t22 = select i1 %t21, i64 256, i64 %t20
  %t23 = extractvalue %KValue %t2, 1
  %t24 = musttail call tailcc %parsed @"d_query/value_for_3"(i64 %t22, %KValue %x0, i64 %t23)
  ret %parsed %t24
fail0:
  %t25 = call i64 @k_not_failure(%KValue %x0)
  %t26 = icmp ne i64 %t25, 0
  br i1 %t26, label %L5, label %L4
L4:
  %t27 = call %KValue @k_err_hop(%KValue %x0, ptr @s549)
  %t28 = extractvalue %KValue %t27, 0
  %t29 = extractvalue %KValue %t27, 1
  %t30 = insertvalue %parsed undef, i64 %t28, 0
  %t31 = insertvalue %parsed %t30, i64 %t29, 1
  ret %parsed %t31
L5:
  %t32 = call i64 @k_not_failure(%KValue %x1)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L7, label %L6
L6:
  %t34 = call %KValue @k_err_hop(%KValue %x1, ptr @s549)
  %t35 = extractvalue %KValue %t34, 0
  %t36 = extractvalue %KValue %t34, 1
  %t37 = insertvalue %parsed undef, i64 %t35, 0
  %t38 = insertvalue %parsed %t37, i64 %t36, 1
  ret %parsed %t38
L7:
  call void @k_die(ptr @s550)
  unreachable
}

define tailcc %parsed @"d_query/value_for_3"(i64 %x0r, %KValue %x1, i64 %x2r) {
entry:
  %t1 = icmp eq i64 %x0r, 256
  %x0b = insertvalue %KValue { i64 0, i64 undef }, i64 %x0r, 1
  %x0 = select i1 %t1, %KValue { i64 4, i64 0 }, %KValue %x0b
  %x2 = insertvalue %KValue { i64 0, i64 undef }, i64 %x2r, 1
  br label %L1
L1:
  %t2 = extractvalue %KValue %x0, 0
  %t3 = icmp eq i64 %t2, 0
  br i1 %t3, label %L2, label %L3
L2:
  %t4 = extractvalue %KValue %x0, 1
  switch i64 %t4, label %arm7 [
    i64 34, label %arm0
    i64 91, label %arm1
    i64 102, label %arm2
    i64 110, label %arm3
    i64 116, label %arm4
    i64 123, label %arm5
  ]
L3:
  %t5 = icmp eq i64 %t2, 4
  br i1 %t5, label %arm6, label %L4
L4:
  %t6 = call i64 @k_not_failure(%KValue %x0)
  %t7 = icmp ne i64 %t6, 0
  br i1 %t7, label %arm7, label %nomatch
nomatch:
  %t8 = extractvalue %KValue %x0, 0
  %t9 = icmp eq i64 %t8, 5
  %t10 = icmp eq i64 %t8, 4
  %t11 = or i1 %t9, %t10
  br i1 %t11, label %L5, label %L6
L5:
  %t12 = call %KValue @k_err_hop(%KValue %x0, ptr @s551)
  %t13 = extractvalue %KValue %t12, 0
  %t14 = extractvalue %KValue %t12, 1
  %t15 = insertvalue %parsed undef, i64 %t13, 0
  %t16 = insertvalue %parsed %t15, i64 %t14, 1
  ret %parsed %t16
L6:
  call void @k_die(ptr @s552)
  unreachable
arm0:
  %t17 = extractvalue %KValue %x2, 1
  %t18 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t19 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t17, i64 %t18)
  %t20 = extractvalue { i64, i1 } %t19, 0
  %t21 = extractvalue { i64, i1 } %t19, 1
  br i1 %t21, label %L8, label %L7
L8:
  call void @k_die(ptr @s94)
  unreachable
L7:
  %t22 = insertvalue %KValue { i64 0, i64 undef }, i64 %t20, 1
  %t23 = extractvalue %KValue %t22, 1
  %t24 = musttail call tailcc %parsed @"d_query/parse_string_2"(%KValue %x1, i64 %t23)
  ret %parsed %t24
arm1:
  %t25 = extractvalue %KValue %x2, 1
  %t26 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t27 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t25, i64 %t26)
  %t28 = extractvalue { i64, i1 } %t27, 0
  %t29 = extractvalue { i64, i1 } %t27, 1
  br i1 %t29, label %L10, label %L9
L10:
  call void @k_die(ptr @s94)
  unreachable
L9:
  %t30 = insertvalue %KValue { i64 0, i64 undef }, i64 %t28, 1
  %t31 = extractvalue %KValue %t30, 1
  %t32 = musttail call tailcc %parsed @"d_query/parse_array_2"(%KValue %x1, i64 %t31)
  ret %parsed %t32
arm2:
  %t33 = call %KValue @"d_query/bytes_false_0"()
  %t34 = extractvalue %KValue %x2, 1
  %t35 = musttail call tailcc %parsed @"d_query/word_4"(%KValue %x1, i64 %t34, %KValue %t33, %KValue { i64 3, i64 0 })
  ret %parsed %t35
arm3:
  %t36 = call %KValue @"d_query/bytes_null_0"()
  %t37 = alloca [1 x %KValue]
  %t38 = call %KValue @k_rec(i64 35, i64 0, ptr %t37)
  %t39 = extractvalue %KValue %x2, 1
  %t40 = musttail call tailcc %parsed @"d_query/word_4"(%KValue %x1, i64 %t39, %KValue %t36, %KValue %t38)
  ret %parsed %t40
arm4:
  %t41 = call %KValue @"d_query/bytes_true_0"()
  %t42 = extractvalue %KValue %x2, 1
  %t43 = musttail call tailcc %parsed @"d_query/word_4"(%KValue %x1, i64 %t42, %KValue %t41, %KValue { i64 2, i64 0 })
  ret %parsed %t43
arm5:
  %t44 = extractvalue %KValue %x2, 1
  %t45 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t46 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t44, i64 %t45)
  %t47 = extractvalue { i64, i1 } %t46, 0
  %t48 = extractvalue { i64, i1 } %t46, 1
  br i1 %t48, label %L12, label %L11
L12:
  call void @k_die(ptr @s94)
  unreachable
L11:
  %t49 = insertvalue %KValue { i64 0, i64 undef }, i64 %t47, 1
  %t50 = extractvalue %KValue %t49, 1
  %t51 = musttail call tailcc %parsed @"d_query/parse_object_2"(%KValue %x1, i64 %t50)
  ret %parsed %t51
arm6:
  %t52 = call %KValue @k_str_lit(ptr @s343, i64 23, ptr @s343_lit)
  %t53 = extractvalue %KValue %x2, 1
  %t54 = call tailcc %KValue @"d_query/fail_2"(i64 %t53, %KValue %t52)
  %t55 = extractvalue %KValue %t54, 0
  %t56 = extractvalue %KValue %t54, 1
  %t57 = insertvalue %parsed undef, i64 %t55, 0
  %t58 = insertvalue %parsed %t57, i64 %t56, 1
  ret %parsed %t58
arm7:
  %t59 = call %KValue @"d_query/number_start?_1"(%KValue %x0)
  %t60 = call i64 @k_not_failure(%KValue %t59)
  %t61 = icmp ne i64 %t60, 0
  br i1 %t61, label %L13, label %L14
L14:
  %t62 = extractvalue %KValue %t59, 0
  %t63 = extractvalue %KValue %t59, 1
  %t64 = insertvalue %parsed undef, i64 %t62, 0
  %t65 = insertvalue %parsed %t64, i64 %t63, 1
  ret %parsed %t65
L13:
  %t66 = call i64 @k_truthy(%KValue %t59)
  %t67 = icmp ne i64 %t66, 0
  br i1 %t67, label %L15, label %L16
L15:
  %t68 = extractvalue %KValue %x2, 1
  %t69 = musttail call tailcc %parsed @"d_query/parse_number_2"(%KValue %x1, i64 %t68)
  ret %parsed %t69
L16:
  %t70 = extractvalue %KValue %x2, 1
  %t71 = call tailcc %KValue @"d_query/bad_value_char_2"(%KValue %x0, i64 %t70)
  %t72 = extractvalue %KValue %t71, 0
  %t73 = extractvalue %KValue %t71, 1
  %t74 = insertvalue %parsed undef, i64 %t72, 0
  %t75 = insertvalue %parsed %t74, i64 %t73, 1
  ret %parsed %t75
}

define tailcc %parsed @"d_query/word_4"(%KValue %x0, i64 %x1r, %KValue %x2, %KValue %x3) {
entry:
  %x1 = insertvalue %KValue { i64 0, i64 undef }, i64 %x1r, 1
  %t1 = call %KValue @k_b_length_fast(%KValue %x2)
  %t2 = extractvalue %KValue %x1, 1
  %t3 = extractvalue %KValue %t1, 1
  %t4 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t2, i64 %t3)
  %t5 = extractvalue { i64, i1 } %t4, 0
  %t6 = extractvalue { i64, i1 } %t4, 1
  br i1 %t6, label %L2, label %L1
L2:
  call void @k_die(ptr @s94)
  unreachable
L1:
  %t7 = insertvalue %KValue { i64 0, i64 undef }, i64 %t5, 1
  %t8 = extractvalue %KValue %t7, 1
  %t9 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t10 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %t8, i64 %t9)
  %t11 = extractvalue { i64, i1 } %t10, 0
  %t12 = extractvalue { i64, i1 } %t10, 1
  br i1 %t12, label %L4, label %L3
L4:
  call void @k_die(ptr @s94)
  unreachable
L3:
  %t13 = insertvalue %KValue { i64 0, i64 undef }, i64 %t11, 1
  %t14 = call %KValue @k_b_slice(%KValue %x0, %KValue %x1, %KValue %t13)
  %t15 = extractvalue %KValue %t14, 0
  %t16 = extractvalue %KValue %x2, 0
  %t17 = icmp eq i64 %t15, 0
  %t18 = icmp eq i64 %t16, 0
  %t19 = and i1 %t17, %t18
  br i1 %t19, label %L5, label %L6
L5:
  %t20 = extractvalue %KValue %t14, 1
  %t21 = extractvalue %KValue %x2, 1
  %t22 = icmp eq i64 %t20, %t21
  %t23 = select i1 %t22, %KValue { i64 2, i64 0 }, %KValue { i64 3, i64 0 }
  br label %L7
L6:
  %t24 = call %KValue @k_cmp(%KValue %t14, %KValue %x2, i64 0)
  br label %L7
L7:
  %t25 = phi %KValue [ %t23, %L5 ], [ %t24, %L6 ]
  %t26 = call i64 @k_not_failure(%KValue %t25)
  %t27 = icmp ne i64 %t26, 0
  br i1 %t27, label %L8, label %L9
L9:
  %t28 = extractvalue %KValue %t25, 0
  %t29 = extractvalue %KValue %t25, 1
  %t30 = insertvalue %parsed undef, i64 %t28, 0
  %t31 = insertvalue %parsed %t30, i64 %t29, 1
  ret %parsed %t31
L8:
  %t32 = call i64 @k_truthy(%KValue %t25)
  %t33 = icmp ne i64 %t32, 0
  br i1 %t33, label %L10, label %L11
L10:
  %t34 = extractvalue %KValue %x1, 1
  %t35 = extractvalue %KValue %t1, 1
  %t36 = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %t34, i64 %t35)
  %t37 = extractvalue { i64, i1 } %t36, 0
  %t38 = extractvalue { i64, i1 } %t36, 1
  br i1 %t38, label %L13, label %L12
L13:
  call void @k_die(ptr @s94)
  unreachable
L12:
  %t39 = insertvalue %KValue { i64 0, i64 undef }, i64 %t37, 1
  %t40 = call i64 @k_not_failure(%KValue %t39)
  %t41 = icmp ne i64 %t40, 0
  br i1 %t41, label %L14, label %L15
L15:
  %t42 = extractvalue %KValue %t39, 0
  %t43 = extractvalue %KValue %t39, 1
  %t44 = insertvalue %parsed undef, i64 %t42, 0
  %t45 = insertvalue %parsed %t44, i64 %t43, 1
  ret %parsed %t45
L14:
  %t46 = call i64 @k_not_failure(%KValue %x3)
  %t47 = icmp ne i64 %t46, 0
  br i1 %t47, label %L16, label %L17
L17:
  %t48 = extractvalue %KValue %x3, 0
  %t49 = extractvalue %KValue %x3, 1
  %t50 = insertvalue %parsed undef, i64 %t48, 0
  %t51 = insertvalue %parsed %t50, i64 %t49, 1
  ret %parsed %t51
L16:
  %t52 = extractvalue %KValue %t39, 1
  %t53 = shl i64 %t52, 8
  %t54 = extractvalue %KValue %x3, 0
  %t55 = or i64 %t53, %t54
  %t56 = extractvalue %KValue %x3, 1
  %t57 = insertvalue %parsed undef, i64 %t55, 0
  %t58 = insertvalue %parsed %t57, i64 %t56, 1
  ret %parsed %t58
L11:
  %t59 = call %KValue @k_str_lit(ptr @s554, i64 15, ptr @s554_lit)
  %t60 = extractvalue %KValue %x1, 1
  %t61 = call tailcc %KValue @"d_query/fail_2"(i64 %t60, %KValue %t59)
  %t62 = extractvalue %KValue %t61, 0
  %t63 = extractvalue %KValue %t61, 1
  %t64 = insertvalue %parsed undef, i64 %t62, 0
  %t65 = insertvalue %parsed %t64, i64 %t63, 1
  ret %parsed %t65
fail0:
  %t66 = call i64 @k_not_failure(%KValue %x0)
  %t67 = icmp ne i64 %t66, 0
  br i1 %t67, label %L19, label %L18
L18:
  %t68 = call %KValue @k_err_hop(%KValue %x0, ptr @s553)
  %t69 = extractvalue %KValue %t68, 0
  %t70 = extractvalue %KValue %t68, 1
  %t71 = insertvalue %parsed undef, i64 %t69, 0
  %t72 = insertvalue %parsed %t71, i64 %t70, 1
  ret %parsed %t72
L19:
  %t73 = call i64 @k_not_failure(%KValue %x1)
  %t74 = icmp ne i64 %t73, 0
  br i1 %t74, label %L21, label %L20
L20:
  %t75 = call %KValue @k_err_hop(%KValue %x1, ptr @s553)
  %t76 = extractvalue %KValue %t75, 0
  %t77 = extractvalue %KValue %t75, 1
  %t78 = insertvalue %parsed undef, i64 %t76, 0
  %t79 = insertvalue %parsed %t78, i64 %t77, 1
  ret %parsed %t79
L21:
  %t80 = call i64 @k_not_failure(%KValue %x2)
  %t81 = icmp ne i64 %t80, 0
  br i1 %t81, label %L23, label %L22
L22:
  %t82 = call %KValue @k_err_hop(%KValue %x2, ptr @s553)
  %t83 = extractvalue %KValue %t82, 0
  %t84 = extractvalue %KValue %t82, 1
  %t85 = insertvalue %parsed undef, i64 %t83, 0
  %t86 = insertvalue %parsed %t85, i64 %t84, 1
  ret %parsed %t86
L23:
  %t87 = call i64 @k_not_failure(%KValue %x3)
  %t88 = icmp ne i64 %t87, 0
  br i1 %t88, label %L25, label %L24
L24:
  %t89 = call %KValue @k_err_hop(%KValue %x3, ptr @s553)
  %t90 = extractvalue %KValue %t89, 0
  %t91 = extractvalue %KValue %t89, 1
  %t92 = insertvalue %parsed undef, i64 %t90, 0
  %t93 = insertvalue %parsed %t92, i64 %t91, 1
  ret %parsed %t93
L25:
  call void @k_die(ptr @s555)
  unreachable
}

define %KValue @"d_io/args_0"() {
entry:
  %t1 = call %KValue @k_desc_args()
  ret %KValue %t1
fail0:
  call void @k_die(ptr @s557)
  unreachable
}

define %KValue @"d_io/env_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_env(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s558)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s559)
  unreachable
}

define %KValue @"d_io/exit_1"(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue %x0, ptr %t2
  %t3 = call %KValue @k_rec_reuse(i64 38, i64 1, ptr %t1, %KValue %x0)
  %t4 = call %KValue @k_err(%KValue %t3, ptr @s561)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s560)
  ret %KValue %t7
L2:
  call void @k_die(ptr @s562)
  unreachable
}

define %KValue @"d_io/exists_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_exists(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s563)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s564)
  unreachable
}

define %KValue @"d_io/is_dir_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_is_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s565)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s566)
  unreachable
}

define %KValue @"d_io/list_dir_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_list_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s567)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s568)
  unreachable
}

define %KValue @"d_io/read_file_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_read_file(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s569)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s570)
  unreachable
}

define tailcc %KValue @klam22(ptr %env, %KValue %a0) {
entry:
  %t1 = musttail call tailcc %KValue @"d_io/answered_1"(%KValue %a0)
  ret %KValue %t1
}

define %KValue @w_klam22(ptr %env, %KValue %a0) {
entry:
  %r = call tailcc %KValue @klam22(ptr %env, %KValue %a0)
  ret %KValue %r
}

define %KValue @"d_io/run_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_run(%KValue %x0, %KValue %x1)
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_closure(ptr @w_klam22, i64 1, i64 0, ptr %t2)
  %t4 = call %KValue @k_maybe_bind(%KValue %t1, %KValue %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s571)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s571)
  ret %KValue %t10
L4:
  call void @k_die(ptr @s572)
  unreachable
}

define tailcc %KValue @"d_io/answered_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 13
  %t3 = extractvalue %KValue { i64 0, i64 1 }, 0
  %t4 = icmp eq i64 %t3, 0
  %t5 = and i1 %t2, %t4
  br i1 %t5, label %L1, label %L2
L1:
  %t6 = extractvalue %KValue %x0, 1
  %t7 = inttoptr i64 %t6 to ptr
  %t8 = getelementptr %KBytes, ptr %t7, i64 0, i32 0
  %t9 = load i64, ptr %t8
  %t10 = extractvalue %KValue { i64 0, i64 1 }, 1
  %t11 = icmp sge i64 %t10, 1
  %t12 = icmp sle i64 %t10, %t9
  %t13 = and i1 %t11, %t12
  br i1 %t13, label %L4, label %L2
L4:
  %t14 = getelementptr %KBytes, ptr %t7, i64 0, i32 1
  %t15 = load ptr, ptr %t14
  %t16 = add i64 %t10, -1
  %t17 = getelementptr i8, ptr %t15, i64 %t16
  %t18 = load i8, ptr %t17
  %t19 = zext i8 %t18 to i64
  %t20 = insertvalue %KValue { i64 0, i64 undef }, i64 %t19, 1
  br label %L3
L2:
  %t21 = call %KValue @k_index(%KValue %x0, %KValue { i64 0, i64 1 }, ptr @s574)
  br label %L3
L3:
  %t22 = phi %KValue [ %t20, %L4 ], [ %t21, %L2 ]
  %t23 = extractvalue %KValue %x0, 0
  %t24 = icmp eq i64 %t23, 13
  %t25 = extractvalue %KValue { i64 0, i64 3 }, 0
  %t26 = icmp eq i64 %t25, 0
  %t27 = and i1 %t24, %t26
  br i1 %t27, label %L5, label %L6
L5:
  %t28 = extractvalue %KValue %x0, 1
  %t29 = inttoptr i64 %t28 to ptr
  %t30 = getelementptr %KBytes, ptr %t29, i64 0, i32 0
  %t31 = load i64, ptr %t30
  %t32 = extractvalue %KValue { i64 0, i64 3 }, 1
  %t33 = icmp sge i64 %t32, 1
  %t34 = icmp sle i64 %t32, %t31
  %t35 = and i1 %t33, %t34
  br i1 %t35, label %L8, label %L6
L8:
  %t36 = getelementptr %KBytes, ptr %t29, i64 0, i32 1
  %t37 = load ptr, ptr %t36
  %t38 = add i64 %t32, -1
  %t39 = getelementptr i8, ptr %t37, i64 %t38
  %t40 = load i8, ptr %t39
  %t41 = zext i8 %t40 to i64
  %t42 = insertvalue %KValue { i64 0, i64 undef }, i64 %t41, 1
  br label %L7
L6:
  %t43 = call %KValue @k_index(%KValue %x0, %KValue { i64 0, i64 3 }, ptr @s574)
  br label %L7
L7:
  %t44 = phi %KValue [ %t42, %L8 ], [ %t43, %L6 ]
  %t45 = extractvalue %KValue %x0, 0
  %t46 = icmp eq i64 %t45, 13
  %t47 = extractvalue %KValue { i64 0, i64 2 }, 0
  %t48 = icmp eq i64 %t47, 0
  %t49 = and i1 %t46, %t48
  br i1 %t49, label %L9, label %L10
L9:
  %t50 = extractvalue %KValue %x0, 1
  %t51 = inttoptr i64 %t50 to ptr
  %t52 = getelementptr %KBytes, ptr %t51, i64 0, i32 0
  %t53 = load i64, ptr %t52
  %t54 = extractvalue %KValue { i64 0, i64 2 }, 1
  %t55 = icmp sge i64 %t54, 1
  %t56 = icmp sle i64 %t54, %t53
  %t57 = and i1 %t55, %t56
  br i1 %t57, label %L12, label %L10
L12:
  %t58 = getelementptr %KBytes, ptr %t51, i64 0, i32 1
  %t59 = load ptr, ptr %t58
  %t60 = add i64 %t54, -1
  %t61 = getelementptr i8, ptr %t59, i64 %t60
  %t62 = load i8, ptr %t61
  %t63 = zext i8 %t62 to i64
  %t64 = insertvalue %KValue { i64 0, i64 undef }, i64 %t63, 1
  br label %L11
L10:
  %t65 = call %KValue @k_index(%KValue %x0, %KValue { i64 0, i64 2 }, ptr @s574)
  br label %L11
L11:
  %t66 = phi %KValue [ %t64, %L12 ], [ %t65, %L10 ]
  %t67 = alloca [3 x %KValue]
  %t68 = getelementptr [3 x %KValue], ptr %t67, i64 0, i64 0
  store %KValue %t22, ptr %t68
  %t69 = getelementptr [3 x %KValue], ptr %t67, i64 0, i64 1
  store %KValue %t44, ptr %t69
  %t70 = getelementptr [3 x %KValue], ptr %t67, i64 0, i64 2
  store %KValue %t66, ptr %t70
  %t71 = call %KValue @k_rec(i64 39, i64 3, ptr %t67)
  ret %KValue %t71
fail0:
  %t72 = call i64 @k_not_failure(%KValue %x0)
  %t73 = icmp ne i64 %t72, 0
  br i1 %t73, label %L14, label %L13
L13:
  %t74 = call %KValue @k_err_hop(%KValue %x0, ptr @s573)
  ret %KValue %t74
L14:
  call void @k_die(ptr @s575)
  unreachable
}

define %KValue @"d_io/stdin_0"() {
entry:
  %t1 = call %KValue @k_desc_stdin()
  ret %KValue %t1
fail0:
  call void @k_die(ptr @s577)
  unreachable
}

define %KValue @"d_io/write_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_write(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s578)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s579)
  unreachable
}

define %KValue @"d_io/write_err_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_write_err(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s580)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s581)
  unreachable
}

define %KValue @"d_io/make_dir_1"(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_make_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s582)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s583)
  unreachable
}

define %KValue @"d_io/write_file_2"(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_write_file(%KValue %x0, %KValue %x1)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s584)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s584)
  ret %KValue %t7
L4:
  call void @k_die(ptr @s585)
  unreachable
}

define %KValue @"d_render/to_string_1"(%KValue %x0) {
entry:
  %t1 = extractvalue %KValue %x0, 0
  %t2 = icmp eq i64 %t1, 4
  br i1 %t2, label %L1, label %fail0
L1:
  %t3 = call %KValue @k_str_lit(ptr @s587, i64 6, ptr @s587_lit)
  ret %KValue %t3
fail0:
  %t4 = call %KValue @k_b_render_value(%KValue %x0)
  ret %KValue %t4
fail1:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L3, label %L2
L2:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s586)
  ret %KValue %t7
L3:
  call void @k_die(ptr @s588)
  unreachable
}

define %KValue @d_args_0() {
entry:
  %t1 = call %KValue @k_desc_args()
  ret %KValue %t1
fail0:
  call void @k_die(ptr @s590)
  unreachable
}

define %KValue @d_env_1(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_env(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s591)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s592)
  unreachable
}

define %KValue @d_exit_1(%KValue %x0) {
entry:
  %t1 = alloca [1 x %KValue]
  %t2 = getelementptr [1 x %KValue], ptr %t1, i64 0, i64 0
  store %KValue %x0, ptr %t2
  %t3 = call %KValue @k_rec_reuse(i64 38, i64 1, ptr %t1, %KValue %x0)
  %t4 = call %KValue @k_err(%KValue %t3, ptr @s594)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s593)
  ret %KValue %t7
L2:
  call void @k_die(ptr @s595)
  unreachable
}

define %KValue @d_exists_1(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_exists(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s596)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s597)
  unreachable
}

define %KValue @d_is_dir_1(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_is_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s598)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s599)
  unreachable
}

define %KValue @d_list_dir_1(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_list_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s600)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s601)
  unreachable
}

define %KValue @d_read_file_1(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_read_file(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s602)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s603)
  unreachable
}

define tailcc %KValue @klam23(ptr %env, %KValue %a0) {
entry:
  %t1 = musttail call tailcc %KValue @"d_io/answered_1"(%KValue %a0)
  ret %KValue %t1
}

define %KValue @w_klam23(ptr %env, %KValue %a0) {
entry:
  %r = call tailcc %KValue @klam23(ptr %env, %KValue %a0)
  ret %KValue %r
}

define %KValue @d_run_2(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_run(%KValue %x0, %KValue %x1)
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_closure(ptr @w_klam23, i64 1, i64 0, ptr %t2)
  %t4 = call %KValue @k_maybe_bind(%KValue %t1, %KValue %t3)
  ret %KValue %t4
fail0:
  %t5 = call i64 @k_not_failure(%KValue %x0)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L2, label %L1
L1:
  %t7 = call %KValue @k_err_hop(%KValue %x0, ptr @s604)
  ret %KValue %t7
L2:
  %t8 = call i64 @k_not_failure(%KValue %x1)
  %t9 = icmp ne i64 %t8, 0
  br i1 %t9, label %L4, label %L3
L3:
  %t10 = call %KValue @k_err_hop(%KValue %x1, ptr @s604)
  ret %KValue %t10
L4:
  call void @k_die(ptr @s605)
  unreachable
}

define %KValue @d_stdin_0() {
entry:
  %t1 = call %KValue @k_desc_stdin()
  ret %KValue %t1
fail0:
  call void @k_die(ptr @s607)
  unreachable
}

define %KValue @d_write_1(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_write(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s608)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s609)
  unreachable
}

define %KValue @d_write_err_1(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_write_err(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s610)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s611)
  unreachable
}

define %KValue @d_make_dir_1(%KValue %x0) {
entry:
  %t1 = call %KValue @k_b_make_dir(%KValue %x0)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s612)
  ret %KValue %t4
L2:
  call void @k_die(ptr @s613)
  unreachable
}

define %KValue @d_write_file_2(%KValue %x0, %KValue %x1) {
entry:
  %t1 = call %KValue @k_b_write_file(%KValue %x0, %KValue %x1)
  ret %KValue %t1
fail0:
  %t2 = call i64 @k_not_failure(%KValue %x0)
  %t3 = icmp ne i64 %t2, 0
  br i1 %t3, label %L2, label %L1
L1:
  %t4 = call %KValue @k_err_hop(%KValue %x0, ptr @s614)
  ret %KValue %t4
L2:
  %t5 = call i64 @k_not_failure(%KValue %x1)
  %t6 = icmp ne i64 %t5, 0
  br i1 %t6, label %L4, label %L3
L3:
  %t7 = call %KValue @k_err_hop(%KValue %x1, ptr @s614)
  ret %KValue %t7
L4:
  call void @k_die(ptr @s615)
  unreachable
}

define tailcc %KValue @klam24(ptr %env, %KValue %a0) {
entry:
  %t1 = musttail call tailcc %KValue @"d_query/dispatch_1"(%KValue %a0)
  ret %KValue %t1
}

define %KValue @w_klam24(ptr %env, %KValue %a0) {
entry:
  %r = call tailcc %KValue @klam24(ptr %env, %KValue %a0)
  ret %KValue %r
}

define %KValue @d_Entry_0() {
entry:
  %t1 = call %KValue @"d_io/args_0"()
  %t2 = alloca [1 x %KValue]
  %t3 = call %KValue @k_closure(ptr @w_klam24, i64 1, i64 0, ptr %t2)
  %t4 = call %KValue @k_maybe_bind(%KValue %t1, %KValue %t3)
  ret %KValue %t4
fail0:
  call void @k_die(ptr @s617)
  unreachable
}

define %KValue @d_thunk_eval(i64 %site, ptr %args) {
entry:
  switch i64 %site, label %bad [
  ]
bad:
  unreachable
}

define void @k_caf_init() {
entry:
  %v0 = call %KValue @"d_query/hex_digits_0_build"()
  %f0 = call %KValue @k_caf_freeze(%KValue %v0)
  store %KValue %f0, ptr @caf_0
  %v1 = call %KValue @"d_query/bytes_false_0_build"()
  %f1 = call %KValue @k_caf_freeze(%KValue %v1)
  store %KValue %f1, ptr @caf_1
  %v2 = call %KValue @"d_query/bytes_null_0_build"()
  %f2 = call %KValue @k_caf_freeze(%KValue %v2)
  store %KValue %f2, ptr @caf_2
  %v3 = call %KValue @"d_query/bytes_true_0_build"()
  %f3 = call %KValue @k_caf_freeze(%KValue %v3)
  store %KValue %f3, ptr @caf_3
  ret void
}

define %KValue @k_user_main() {
entry:
  %r = call %KValue @d_Entry_0()
  ret %KValue %r
}

define %KValue @"d_query/list/bisect_5.c"(%KValue %a0, %KValue %a1, %KValue %a2, %KValue %a3, %KValue %a4) {
entry:
  %r = call tailcc %KValue @"d_query/list/bisect_5"(%KValue %a0, %KValue %a1, %KValue %a2, %KValue %a3, %KValue %a4)
  ret %KValue %r
}
define %KValue @"d_query/list/bounded_flat_5.c"(%KValue %a0, %KValue %a1, %KValue %a2, i64 %a3, %KValue %a4) {
entry:
  %r = call tailcc %KValue @"d_query/list/bounded_flat_5"(%KValue %a0, %KValue %a1, %KValue %a2, i64 %a3, %KValue %a4)
  ret %KValue %r
}
define %KValue @"d_query/list/bounded_more_5.c"(%KValue %a0, %KValue %a1, %KValue %a2, i64 %a3, %KValue %a4) {
entry:
  %r = call tailcc %KValue @"d_query/list/bounded_more_5"(%KValue %a0, %KValue %a1, %KValue %a2, i64 %a3, %KValue %a4)
  ret %KValue %r
}
define %KValue @"d_query/list/bounded_step_5.c"(%KValue %a0, %KValue %a1, %KValue %a2, i64 %a3, %KValue %a4) {
entry:
  %r = call tailcc %KValue @"d_query/list/bounded_step_5"(%KValue %a0, %KValue %a1, %KValue %a2, i64 %a3, %KValue %a4)
  ret %KValue %r
}
define %KValue @"d_query/list/advance_6.c"(%KValue %a0, %KValue %a1, %KValue %a2, %KValue %a3, i64 %a4, i64 %a5) {
entry:
  %r = call tailcc %KValue @"d_query/list/advance_6"(%KValue %a0, %KValue %a1, %KValue %a2, %KValue %a3, i64 %a4, i64 %a5)
  ret %KValue %r
}
