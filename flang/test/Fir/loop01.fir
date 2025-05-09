// RUN: fir-opt --split-input-file --cfg-conversion %s | FileCheck %s
// RUN: fir-opt --split-input-file --cfg-conversion="set-nsw=false" %s | FileCheck %s --check-prefix=NO-NSW

// NO-NSW-NOT: overflow<nsw>

func.func @x(%lb : index, %ub : index, %step : index, %b : i1, %addr : !fir.ref<index>) {
  fir.do_loop %iv = %lb to %ub step %step unordered {
    // expect following conditional blocks to get fused
    fir.if %b {
      fir.store %iv to %addr : !fir.ref<index>
    } else {
      %zero = arith.constant 0 : index
      fir.store %zero to %addr : !fir.ref<index>
    }
  }
  return
}

func.func private @f2() -> i1

// CHECK:     func @x(%[[VAL_0:.*]]: index, %[[VAL_1:.*]]: index, %[[VAL_2:.*]]: index, %[[VAL_3:.*]]: i1, %[[VAL_4:.*]]: !fir.ref<index>) {
// CHECK:       %[[VAL_5:.*]] = arith.subi %[[VAL_1]], %[[VAL_0]] : index
// CHECK:       %[[VAL_6:.*]] = arith.addi %[[VAL_5]], %[[VAL_2]] : index
// CHECK:       %[[VAL_7:.*]] = arith.divsi %[[VAL_6]], %[[VAL_2]] : index
// CHECK:       br ^bb1(%[[VAL_0]], %[[VAL_7]] : index, index)
// CHECK:     ^bb1(%[[VAL_8:.*]]: index, %[[VAL_9:.*]]: index):
// CHECK:       %[[VAL_10:.*]] = arith.constant 0 : index
// CHECK:       %[[VAL_11:.*]] = arith.cmpi sgt, %[[VAL_9]], %[[VAL_10]] : index
// CHECK:       cond_br %[[VAL_11]], ^bb2, ^bb6
// CHECK:     ^bb2:
// CHECK:       cond_br %[[VAL_3]], ^bb3, ^bb4
// CHECK:     ^bb3:
// CHECK:       fir.store %[[VAL_8]] to %[[VAL_4]] : !fir.ref<index>
// CHECK:       br ^bb5
// CHECK:     ^bb4:
// CHECK:       %[[VAL_12:.*]] = arith.constant 0 : index
// CHECK:       fir.store %[[VAL_12]] to %[[VAL_4]] : !fir.ref<index>
// CHECK:       br ^bb5
// CHECK:     ^bb5:
// CHECK:       %[[VAL_13:.*]] = arith.addi %[[VAL_8]], %[[VAL_2]] overflow<nsw> : index
// CHECK:       %[[VAL_14:.*]] = arith.constant 1 : index
// CHECK:       %[[VAL_15:.*]] = arith.subi %[[VAL_9]], %[[VAL_14]] : index
// CHECK:       br ^bb1(%[[VAL_13]], %[[VAL_15]] : index, index)
// CHECK:     ^bb6:
// CHECK:       return
// CHECK:     }
// CHECK:     func private @f2() -> i1

// -----

func.func @x2(%lo : index, %up : index, %ok : i1) {
  %c1 = arith.constant 1 : index
  %unused = fir.iterate_while (%i = %lo to %up step %c1) and (%ok1 = %ok) {
    %ok2 = fir.call @f2() : () -> i1
    fir.result %ok2 : i1
  }
  return
}

func.func private @f3(i16)

// CHECK:   func @x2(%[[VAL_0:.*]]: index, %[[VAL_1:.*]]: index, %[[VAL_2:.*]]: i1) {
// CHECK:     %[[VAL_3:.*]] = arith.constant 1 : index
// CHECK:     br ^bb1(%[[VAL_0]], %[[VAL_2]] : index, i1)
// CHECK:   ^bb1(%[[VAL_4:.*]]: index, %[[VAL_5:.*]]: i1):
// CHECK:     %[[VAL_6:.*]] = arith.constant 0 : index
// CHECK:     %[[VAL_7:.*]] = arith.cmpi slt, %[[VAL_6]], %[[VAL_3]] : index
// CHECK:     %[[VAL_8:.*]] = arith.cmpi sle, %[[VAL_4]], %[[VAL_1]] : index
// CHECK:     %[[VAL_9:.*]] = arith.cmpi slt, %[[VAL_3]], %[[VAL_6]] : index
// CHECK:     %[[VAL_10:.*]] = arith.cmpi sle, %[[VAL_1]], %[[VAL_4]] : index
// CHECK:     %[[VAL_11:.*]] = arith.andi %[[VAL_7]], %[[VAL_8]] : i1
// CHECK:     %[[VAL_12:.*]] = arith.andi %[[VAL_9]], %[[VAL_10]] : i1
// CHECK:     %[[VAL_13:.*]] = arith.ori %[[VAL_11]], %[[VAL_12]] : i1
// CHECK:     %[[VAL_14:.*]] = arith.andi %[[VAL_5]], %[[VAL_13]] : i1
// CHECK:     cond_br %[[VAL_14]], ^bb2, ^bb3
// CHECK:   ^bb2:
// CHECK:     %[[VAL_15:.*]] = fir.call @f2() : () -> i1
// CHECK:     %[[VAL_16:.*]] = arith.addi %[[VAL_4]], %[[VAL_3]] overflow<nsw> : index
// CHECK:     br ^bb1(%[[VAL_16]], %[[VAL_15]] : index, i1)
// CHECK:   ^bb3:
// CHECK:     return
// CHECK:   }
// CHECK:   func private @f3(i16)

// -----

// do_loop with an extra loop-carried value
func.func @x3(%lo : index, %up : index) -> i1 {
  %c1 = arith.constant 1 : index
  %ok1 = arith.constant true
  %ok2 = fir.do_loop %i = %lo to %up step %c1 iter_args(%j = %ok1) -> i1 {
    %ok = fir.call @f2() : () -> i1
    fir.result %ok : i1
  }
  return %ok2 : i1
}

// CHECK-LABEL:   func @x3(
// CHECK-SAME:             %[[VAL_0:.*]]: index,
// CHECK-SAME:             %[[VAL_1:.*]]: index) -> i1 {
// CHECK:           %[[VAL_2:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_3:.*]] = arith.constant true
// CHECK:           %[[VAL_4:.*]] = arith.subi %[[VAL_1]], %[[VAL_0]] : index
// CHECK:           %[[VAL_5:.*]] = arith.addi %[[VAL_4]], %[[VAL_2]] : index
// CHECK:           %[[VAL_6:.*]] = arith.divsi %[[VAL_5]], %[[VAL_2]] : index
// CHECK:           br ^bb1(%[[VAL_0]], %[[VAL_3]], %[[VAL_6]] : index, i1, index)
// CHECK:         ^bb1(%[[VAL_7:.*]]: index, %[[VAL_8:.*]]: i1, %[[VAL_9:.*]]: index):
// CHECK:           %[[VAL_10:.*]] = arith.constant 0 : index
// CHECK:           %[[VAL_11:.*]] = arith.cmpi sgt, %[[VAL_9]], %[[VAL_10]] : index
// CHECK:           cond_br %[[VAL_11]], ^bb2, ^bb3
// CHECK:         ^bb2:
// CHECK:           %[[VAL_12:.*]] = fir.call @f2() : () -> i1
// CHECK:           %[[VAL_13:.*]] = arith.addi %[[VAL_7]], %[[VAL_2]] overflow<nsw> : index
// CHECK:           %[[VAL_14:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_15:.*]] = arith.subi %[[VAL_9]], %[[VAL_14]] : index
// CHECK:           br ^bb1(%[[VAL_13]], %[[VAL_12]], %[[VAL_15]] : index, i1, index)
// CHECK:         ^bb3:
// CHECK:           return %[[VAL_8]] : i1
// CHECK:         }

// -----

// iterate_while with an extra loop-carried value
func.func @y3(%lo : index, %up : index) -> i1 {
  %c1 = arith.constant 1 : index
  %ok1 = arith.constant true
  %ok4 = fir.call @f2() : () -> i1
  %ok2:2 = fir.iterate_while (%i = %lo to %up step %c1) and (%ok3 = %ok1) iter_args(%j = %ok4) -> i1 {
    %ok = fir.call @f2() : () -> i1
    fir.result %ok3, %ok : i1, i1
  }
  %andok = arith.andi %ok2#0, %ok2#1 : i1
  return %andok : i1
}

func.func private @f4(i32) -> i1

// CHECK-LABEL:   func @y3(
// CHECK-SAME:             %[[VAL_0:.*]]: index,
// CHECK-SAME:             %[[VAL_1:.*]]: index) -> i1 {
// CHECK:           %[[VAL_2:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_3:.*]] = arith.constant true
// CHECK:           %[[VAL_4:.*]] = fir.call @f2() : () -> i1
// CHECK:           br ^bb1(%[[VAL_0]], %[[VAL_3]], %[[VAL_4]] : index, i1, i1)
// CHECK:         ^bb1(%[[VAL_5:.*]]: index, %[[VAL_6:.*]]: i1, %[[VAL_7:.*]]: i1):
// CHECK:           %[[VAL_8:.*]] = arith.constant 0 : index
// CHECK:           %[[VAL_9:.*]] = arith.cmpi slt, %[[VAL_8]], %[[VAL_2]] : index
// CHECK:           %[[VAL_10:.*]] = arith.cmpi sle, %[[VAL_5]], %[[VAL_1]] : index
// CHECK:           %[[VAL_11:.*]] = arith.cmpi slt, %[[VAL_2]], %[[VAL_8]] : index
// CHECK:           %[[VAL_12:.*]] = arith.cmpi sle, %[[VAL_1]], %[[VAL_5]] : index
// CHECK:           %[[VAL_13:.*]] = arith.andi %[[VAL_9]], %[[VAL_10]] : i1
// CHECK:           %[[VAL_14:.*]] = arith.andi %[[VAL_11]], %[[VAL_12]] : i1
// CHECK:           %[[VAL_15:.*]] = arith.ori %[[VAL_13]], %[[VAL_14]] : i1
// CHECK:           %[[VAL_16:.*]] = arith.andi %[[VAL_6]], %[[VAL_15]] : i1
// CHECK:           cond_br %[[VAL_16]], ^bb2, ^bb3
// CHECK:         ^bb2:
// CHECK:           %[[VAL_17:.*]] = fir.call @f2() : () -> i1
// CHECK:           %[[VAL_18:.*]] = arith.addi %[[VAL_5]], %[[VAL_2]] overflow<nsw> : index
// CHECK:           br ^bb1(%[[VAL_18]], %[[VAL_6]], %[[VAL_17]] : index, i1, i1)
// CHECK:         ^bb3:
// CHECK:           %[[VAL_19:.*]] = arith.andi %[[VAL_6]], %[[VAL_7]] : i1
// CHECK:           return %[[VAL_19]] : i1
// CHECK:         }
// CHECK:         func private @f4(i32) -> i1

// -----

// do_loop that returns the final value of the induction
func.func @x4(%lo : index, %up : index) -> index {
  %c1 = arith.constant 1 : index
  %v = fir.do_loop %i = %lo to %up step %c1 -> index {
    %i1 = fir.convert %i : (index) -> i32
    %ok = fir.call @f4(%i1) : (i32) -> i1
    fir.result %i : index
  }
  return %v : index
}

// CHECK-LABEL:   func @x4(
// CHECK-SAME:             %[[VAL_0:.*]]: index,
// CHECK-SAME:             %[[VAL_1:.*]]: index) -> index {
// CHECK:           %[[VAL_2:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_3:.*]] = arith.subi %[[VAL_1]], %[[VAL_0]] : index
// CHECK:           %[[VAL_4:.*]] = arith.addi %[[VAL_3]], %[[VAL_2]] : index
// CHECK:           %[[VAL_5:.*]] = arith.divsi %[[VAL_4]], %[[VAL_2]] : index
// CHECK:           br ^bb1(%[[VAL_0]], %[[VAL_5]] : index, index)
// CHECK:         ^bb1(%[[VAL_6:.*]]: index, %[[VAL_7:.*]]: index):
// CHECK:           %[[VAL_8:.*]] = arith.constant 0 : index
// CHECK:           %[[VAL_9:.*]] = arith.cmpi sgt, %[[VAL_7]], %[[VAL_8]] : index
// CHECK:           cond_br %[[VAL_9]], ^bb2, ^bb3
// CHECK:         ^bb2:
// CHECK:           %[[VAL_10:.*]] = fir.convert %[[VAL_6]] : (index) -> i32
// CHECK:           %[[VAL_11:.*]] = fir.call @f4(%[[VAL_10]]) : (i32) -> i1
// CHECK:           %[[VAL_12:.*]] = arith.addi %[[VAL_6]], %[[VAL_2]] overflow<nsw> : index
// CHECK:           %[[VAL_13:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_14:.*]] = arith.subi %[[VAL_7]], %[[VAL_13]] : index
// CHECK:           br ^bb1(%[[VAL_12]], %[[VAL_14]] : index, index)
// CHECK:         ^bb3:
// CHECK:           return %[[VAL_6]] : index
// CHECK:         }

// -----

// iterate_while that returns the final value of both inductions
func.func @y4(%lo : index, %up : index) -> index {
  %c1 = arith.constant 1 : index
  %ok1 = arith.constant true
  %v:2 = fir.iterate_while (%i = %lo to %up step %c1) and (%ok2 = %ok1) -> (index, i1) {
    %i1 = fir.convert %i : (index) -> i32
    %ok = fir.call @f4(%i1) : (i32) -> i1
    fir.result %i, %ok : index, i1
  }
  return %v#0 : index
}

// CHECK-LABEL:   func @y4(
// CHECK-SAME:             %[[VAL_0:.*]]: index,
// CHECK-SAME:             %[[VAL_1:.*]]: index) -> index {
// CHECK:           %[[VAL_2:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_3:.*]] = arith.constant true
// CHECK:           br ^bb1(%[[VAL_0]], %[[VAL_3]] : index, i1)
// CHECK:         ^bb1(%[[VAL_4:.*]]: index, %[[VAL_5:.*]]: i1):
// CHECK:           %[[VAL_6:.*]] = arith.constant 0 : index
// CHECK:           %[[VAL_7:.*]] = arith.cmpi slt, %[[VAL_6]], %[[VAL_2]] : index
// CHECK:           %[[VAL_8:.*]] = arith.cmpi sle, %[[VAL_4]], %[[VAL_1]] : index
// CHECK:           %[[VAL_9:.*]] = arith.cmpi slt, %[[VAL_2]], %[[VAL_6]] : index
// CHECK:           %[[VAL_10:.*]] = arith.cmpi sle, %[[VAL_1]], %[[VAL_4]] : index
// CHECK:           %[[VAL_11:.*]] = arith.andi %[[VAL_7]], %[[VAL_8]] : i1
// CHECK:           %[[VAL_12:.*]] = arith.andi %[[VAL_9]], %[[VAL_10]] : i1
// CHECK:           %[[VAL_13:.*]] = arith.ori %[[VAL_11]], %[[VAL_12]] : i1
// CHECK:           %[[VAL_14:.*]] = arith.andi %[[VAL_5]], %[[VAL_13]] : i1
// CHECK:           cond_br %[[VAL_14]], ^bb2, ^bb3
// CHECK:         ^bb2:
// CHECK:           %[[VAL_15:.*]] = fir.convert %[[VAL_4]] : (index) -> i32
// CHECK:           %[[VAL_16:.*]] = fir.call @f4(%[[VAL_15]]) : (i32) -> i1
// CHECK:           %[[VAL_17:.*]] = arith.addi %[[VAL_4]], %[[VAL_2]] overflow<nsw> : index
// CHECK:           br ^bb1(%[[VAL_17]], %[[VAL_16]] : index, i1)
// CHECK:         ^bb3:
// CHECK:           return %[[VAL_4]] : index
// CHECK:         }

// -----

// do_loop that returns the final induction value
// and an extra loop-carried value
func.func @x5(%lo : index, %up : index) -> index {
  %c1 = arith.constant 1 : index
  %s1 = arith.constant 42 : i16
  %v:2 = fir.do_loop %i = %lo to %up step %c1 iter_args(%s = %s1) -> (index, i16) {
    %ok = fir.call @f2() : () -> i1
    %s2 = fir.convert %ok : (i1) -> i16
    fir.result %i, %s2 : index, i16
  }
  fir.call @f3(%v#1) : (i16) -> ()
  return %v#0 : index
}

// CHECK-LABEL:   func @x5(
// CHECK-SAME:             %[[VAL_0:.*]]: index,
// CHECK-SAME:             %[[VAL_1:.*]]: index) -> index {
// CHECK:           %[[VAL_2:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_3:.*]] = arith.constant 42 : i16
// CHECK:           %[[VAL_4:.*]] = arith.subi %[[VAL_1]], %[[VAL_0]] : index
// CHECK:           %[[VAL_5:.*]] = arith.addi %[[VAL_4]], %[[VAL_2]] : index
// CHECK:           %[[VAL_6:.*]] = arith.divsi %[[VAL_5]], %[[VAL_2]] : index
// CHECK:           br ^bb1(%[[VAL_0]], %[[VAL_3]], %[[VAL_6]] : index, i16, index)
// CHECK:         ^bb1(%[[VAL_7:.*]]: index, %[[VAL_8:.*]]: i16, %[[VAL_9:.*]]: index):
// CHECK:           %[[VAL_10:.*]] = arith.constant 0 : index
// CHECK:           %[[VAL_11:.*]] = arith.cmpi sgt, %[[VAL_9]], %[[VAL_10]] : index
// CHECK:           cond_br %[[VAL_11]], ^bb2, ^bb3
// CHECK:         ^bb2:
// CHECK:           %[[VAL_12:.*]] = fir.call @f2() : () -> i1
// CHECK:           %[[VAL_13:.*]] = fir.convert %[[VAL_12]] : (i1) -> i16
// CHECK:           %[[VAL_14:.*]] = arith.addi %[[VAL_7]], %[[VAL_2]] overflow<nsw> : index
// CHECK:           %[[VAL_15:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_16:.*]] = arith.subi %[[VAL_9]], %[[VAL_15]] : index
// CHECK:           br ^bb1(%[[VAL_14]], %[[VAL_13]], %[[VAL_16]] : index, i16, index)
// CHECK:         ^bb3:
// CHECK:           fir.call @f3(%[[VAL_8]]) : (i16) -> ()
// CHECK:           return %[[VAL_7]] : index
// CHECK:         }

// -----

// iterate_while that returns the both induction values
// and an extra loop-carried value
func.func @y5(%lo : index, %up : index) -> index {
  %c1 = arith.constant 1 : index
  %s1 = arith.constant 42 : i16
  %ok1 = arith.constant true
  %v:3 = fir.iterate_while (%i = %lo to %up step %c1) and (%ok2 = %ok1) iter_args(%s = %s1) -> (index, i1, i16) {
    %ok = fir.call @f2() : () -> i1
    %s2 = fir.convert %ok : (i1) -> i16
    fir.result %i, %ok, %s2 : index, i1, i16
  }
  fir.if %v#1 {
    %arg = arith.constant 0 : i32
    %ok4 = fir.call @f4(%arg) : (i32) -> i1
  }
  fir.call @f3(%v#2) : (i16) -> ()
  return %v#0 : index
}

// CHECK-LABEL:   func @y5(
// CHECK-SAME:             %[[VAL_0:.*]]: index,
// CHECK-SAME:             %[[VAL_1:.*]]: index) -> index {
// CHECK:           %[[VAL_2:.*]] = arith.constant 1 : index
// CHECK:           %[[VAL_3:.*]] = arith.constant 42 : i16
// CHECK:           %[[VAL_4:.*]] = arith.constant true
// CHECK:           br ^bb1(%[[VAL_0]], %[[VAL_4]], %[[VAL_3]] : index, i1, i16)
// CHECK:         ^bb1(%[[VAL_5:.*]]: index, %[[VAL_6:.*]]: i1, %[[VAL_7:.*]]: i16):
// CHECK:           %[[VAL_8:.*]] = arith.constant 0 : index
// CHECK:           %[[VAL_9:.*]] = arith.cmpi slt, %[[VAL_8]], %[[VAL_2]] : index
// CHECK:           %[[VAL_10:.*]] = arith.cmpi sle, %[[VAL_5]], %[[VAL_1]] : index
// CHECK:           %[[VAL_11:.*]] = arith.cmpi slt, %[[VAL_2]], %[[VAL_8]] : index
// CHECK:           %[[VAL_12:.*]] = arith.cmpi sle, %[[VAL_1]], %[[VAL_5]] : index
// CHECK:           %[[VAL_13:.*]] = arith.andi %[[VAL_9]], %[[VAL_10]] : i1
// CHECK:           %[[VAL_14:.*]] = arith.andi %[[VAL_11]], %[[VAL_12]] : i1
// CHECK:           %[[VAL_15:.*]] = arith.ori %[[VAL_13]], %[[VAL_14]] : i1
// CHECK:           %[[VAL_16:.*]] = arith.andi %[[VAL_6]], %[[VAL_15]] : i1
// CHECK:           cond_br %[[VAL_16]], ^bb2, ^bb3
// CHECK:         ^bb2:
// CHECK:           %[[VAL_17:.*]] = fir.call @f2() : () -> i1
// CHECK:           %[[VAL_18:.*]] = fir.convert %[[VAL_17]] : (i1) -> i16
// CHECK:           %[[VAL_19:.*]] = arith.addi %[[VAL_5]], %[[VAL_2]] overflow<nsw> : index
// CHECK:           br ^bb1(%[[VAL_19]], %[[VAL_17]], %[[VAL_18]] : index, i1, i16)
// CHECK:         ^bb3:
// CHECK:           cond_br %[[VAL_6]], ^bb4, ^bb5
// CHECK:         ^bb4:
// CHECK:           %[[VAL_20:.*]] = arith.constant 0 : i32
// CHECK:           %[[VAL_21:.*]] = fir.call @f4(%[[VAL_20]]) : (i32) -> i1
// CHECK:           br ^bb5
// CHECK:         ^bb5:
// CHECK:           fir.call @f3(%[[VAL_7]]) : (i16) -> ()
// CHECK:           return %[[VAL_5]] : index
// CHECK:         }
