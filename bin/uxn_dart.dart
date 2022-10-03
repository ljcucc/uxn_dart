// import 'package:uxn_dart/uxn_dart.dart' as uxn_dart;
import 'package:uxn_dart/uxn_dart.dart';

// void main(List<String> arguments) {
//   print('Hello world: ${uxn_dart.calculate()}!');
// }

import "dart:typed_data";

// var program = Uint8List.fromList(<int>[0x80, 0x41, 0x80, 0x18, 0x17]);

import "dart:typed_data";

void main() async {
  var emulator = Emu();

  Stream<int> placeholder() async* {
    yield 0;
  }

  ;

  Stream<int> stream =
      emulator.uxn?.load(program).eval(0x0100) ?? placeholder();

  run(stream);
}

Future<void> run(Stream<int> stream) async {
  await for (final value in stream) {
//     await Future.delayed(const Duration(milliseconds: 1000), () => "2");
  }
}

class Stack {
  Uxn u;
  int addr, pk = 0;

  Stack(this.u, this.addr);

  int get(int index) {
    return u.ram[this.addr + 0xff];
  }

  int ptr() {
    return get(0xff);
  }

  int inc() {
//     print("++stack inc");
    return u.ram[this.addr + 0xff]++;
  }

  int dec() {
//     print("--stack inc");
    return u.rk != 0 ? --pk : --u.ram[addr + 0xff];
  }

  pop8() {
//     print("  stack pop8");
//     u.debugMem();
    return ptr() == 0x00 ? u.halt(1) : u.ram[addr + dec()];
  }

  push8(int val) {
    if (ptr() == 0xff) return u.halt(2);

//     print("  stack push8");
//     u.debugMem();
    u.ram[addr + inc()] = val;
  }

  pop16() {
//     print("> stack pop16");
//     u.debugMem();
    return pop8() + (pop8() << 8);
  }

  push16(int val) {
//     print("> stack push16");
//     u.debugMem();
    push8(val >> 0x08);
    push8(val & 0xff);
  }
}

class Console {
  Emu emu;

  Console(this.emu);

  send(int val) {
    print("char: ");
    print(String.fromCharCode(val));
  }
}

class Emu {
  Uxn? uxn;
  Console? console;

  Emu() {
    uxn = Uxn(this);
  }

  int dei(int port) {
    return uxn?.getdev(port) ?? 0;
  }

  deo(int port, int val) {
    uxn?.setdev(port, val);

    switch (port) {
      case 0x10:
      case 0x11:
        print("Set console vector");
        break;
      case 0x00:
      case 0x01:
        print("Set system vector");
        break;
      case 0x02:
        uxn?.wst?.addr = val != 0 ? val * 0x100 : 0x10000;
        break;
      case 0x18:
        print(String.fromCharCode(val));
//         console?.send(val);
        break;
      case 0x0f:
        print("Program ended.");
        break;
      default:
        print("Unknown deo");
        print(port);
        print(val);
        break;
    }
  }
}

class Uxn {
  Uint8List ram = Uint8List(0x13000);
  Stack? wst, rst, src, dst;
  int dev = 0x12000;
  Emu emu;

  int r2 = 0, rr = 0, rk = 0;

  Uxn(this.emu) {
    wst = Stack(this, 0x10000);
    rst = Stack(this, 0x11000);
  }

  int getdev(int port) => ram[dev + port];
  setdev(int port, int val) => ram[dev + port] = val;

  int pop() {
    return r2 != 0 ? src?.pop16() : src?.pop8();
  }

  push8(int x) {
    src?.push8(x);
  }

  push16(int x) {
    src?.push16(x);
  }

  push(int val) {
    if (r2 != 0)
      push16(val);
    else
      push8(val);
  }

  int peek8(int addr) {
    return ram[addr];
  }

  int peek16(int addr) {
    return (ram[addr] << 8) + ram[addr + 1];
  }

  int peek(int addr) {
    return r2 != 0 ? peek16(addr) : ram[addr];
  }

  poke8(int addr, int val) {
    ram[addr] = val;
  }

  poke(int addr, int val) {
    if (r2 != 0) {
      ram[addr] = val >> 8;
      ram[addr + 1] = val;
    } else
      ram[addr] = val;
  }

  int devr(int port) {
    return r2 != 0 ? (emu.dei(port) << 8) + emu.dei(port + 1) : emu.dei(port);
  }

  devw(int port, val) {
    if (r2 != 0) {
      emu.deo(port, val >> 8);
      emu.deo(port + 1, val & 0xff);
    } else {
//       print("DEO");
//       print(port.toRadixString(16));
//       print(val.toRadixString(16));
      emu.deo(port, val);
    }
  }

  int jump(int addr, int pc) {
//     print("jump: ${addr.toRadixString(16)}, ${pc.toRadixString(16)}");
    return r2 != 0 ? addr : pc + rel(addr);
  }

  int pc = 0;

  Stream<int> eval(int ipc) async* {
    pc = ipc;
    print("start eval");
    int a = 0, b = 0, c = 0, instr = 0;
    while ((instr = ram[pc++]) != 0) {
//       print("[ CYCLE START ] ${(pc-1).toRadixString(16)} ${instr.toRadixString(16)}");
//       emu.onStep(pc, instr);
      r2 = instr & 0x20;
      rr = instr & 0x40;
      rk = instr & 0x80;

      if (rk != 0) {
        wst?.pk = wst?.ptr() ?? 0;
        rst?.pk = rst?.ptr() ?? 0;
      }

      if (rr != 0) {
//         print("rst, wst switch ${(pc-1).toRadixString(16)}");
        src = rst;
        dst = wst;
      } else {
        src = wst;
        dst = rst;
      }

//       print(
//           ">>exec command [${(pc-1).toRadixString(16)}] ${(instr).toRadixString(16)} , type: ${(instr & 0x1f).toRadixString(16)}");
//       yield 0;
      switch (instr & 0x1f) {
        // Stack
        case 0x00:
//           print(">>>LIT ${r2.toRadixString(16)}");
          /* LIT */ push(peek(pc));
          pc += (r2 != 0 ? 1 : 0) + 1;
          break;
        case 0x01:
//           print(">>>INC");
          /* INC */ push(pop() + 1);
          break;
        case 0x02:
          /* POP */ pop();
          break;
        case 0x03:
          /* NIP */ a = pop();
          pop();
          push(a);
          break;
        case 0x04:
          /* SWP */ a = pop();
          b = pop();
          push(a);
          push(b);
          break;
        case 0x05:
          /* ROT */ a = pop();
          b = pop();
          c = pop();
          push(b);
          push(a);
          push(c);
          break;
        case 0x06:
          /* DUP */ a = pop();
          push(a);
          push(a);
          break;
        case 0x07:
          /* OVR */ a = pop();
          b = pop();
          push(b);
          push(a);
          push(b);
          break;
        // Logic
        case 0x08:
          /* EQU */ a = pop();
          b = pop();
          push8(b == a ? 1 : 0);
          break;
        case 0x09:
          /* NEQ */ a = pop();
          b = pop();
          push8(b != a ? 1 : 0);
          break;
        case 0x0a:
          /* GTH */ a = pop();
          b = pop();
          push8(b > a ? 1 : 0);
          break;
        case 0x0b:
          /* LTH */ a = pop();
          b = pop();
          push8(b < a ? 1 : 0);
          break;
        case 0x0c:
          /* JMP */ pc = jump(pop(), pc);
          break;
        case 0x0d:
//           print(">>JCN");
          /* JCN */ a = pop();
          if (src?.pop8() != 0) pc = jump(a, pc);
//           print("<<JCN");
          break;
        case 0x0e:
          /* JSR */ dst?.push16(pc);
          pc = jump(pop(), pc);
          break;
        case 0x0f:
          /* STH */ if (r2 != 0) {
            dst?.push16(src?.pop16());
          } else {
            dst?.push8(src?.pop8());
          }
          break;
        // Memory
        case 0x10:
          /* LDZ */ push(peek(src?.pop8()));
          break;
        case 0x11:
          /* STZ */ poke(src?.pop8(), pop());
          break;
        case 0x12:
          /* LDR */ push(peek(pc + rel(src?.pop8())));
          break;
        case 0x13:
          /* STR */ poke(pc + rel(src?.pop8()), pop());
          break;
        case 0x14:
          /* LDA */ push(peek(src?.pop16()));
          break;
        case 0x15:
          /* STA */ poke(src?.pop16(), pop());
          break;
        case 0x16:
          /* DEI */ push(devr(src?.pop8()));
          break;
        case 0x17:
          /* DEO */ devw(src?.pop8(), pop());
          break;
        // Arithmetic
        case 0x18:
          /* ADD */ a = pop();
          b = pop();
          push(b + a);
          break;
        case 0x19:
          /* SUB */ a = pop();
          b = pop();
          push(b - a);
          break;
        case 0x1a:
          /* MUL */ a = pop();
          b = pop();
          push(b * a);
          break;
        case 0x1b:
          /* DIV */ a = pop();
          b = pop();
//           if (a == 0) return halt(3);
          if (a == 0) halt(3);
          push((b / a).round());
          break;
        case 0x1c:
          /* AND */ a = pop();
          b = pop();
          push(b & a);
          break;
        case 0x1d:
          /* ORA */ a = pop();
          b = pop();
          push(b | a);
          break;
        case 0x1e:
          /* EOR */ a = pop();
          b = pop();
          push(b ^ a);
          break;
        case 0x1f:
          /* SFT */ a = src?.pop8();
          b = pop();
          push(b >> (a & 0x0f) << ((a & 0xf0) >> 4));
          break;
      }
      yield 0;
//       debugMem();
//       print("[ CYCLE DONE ]");
    }
  }

  Uxn load(Uint8List program) {
    for (var i = 0; i < program.length; i++) {
      ram[0x100 + i] = program[i];
    }
    return this;
  }

  final errors = ["underflow", "overflow", "division by zero"];

  halt(int err) {
//     var vec = peek16()
    print(
        "Error ${(rr != 0 ? " Return-stack " : " Working-stack ")} ${errors[err]} at ${pc.toRadixString(16)} , command ${ram[pc - 1].toRadixString(16)}");
    print(program[pc].toRadixString(16));
    pc = 0x0000;
    debugMem();
    throw "halt";
//     throw "Error " + (rr != 0 ? " Return-stack " : " Working-stack ") + errors[err];
  }

  debugMem() {
    var result = "";
    print("return stack: ");
    for (int i = 0; i < 0xff; i++) {
      result += (ram[0x11000 + i].toRadixString(16) + ", ");
    }
    print(result);

    result = "";
    print("working stack: ");
    for (int i = 0; i < 0xff; i++) {
      result += (ram[0x10000 + i].toRadixString(16) + ", ");
    }
    print(result);
    print("");
  }

  int rel(val) {
    return (val > 0x80 ? val - 256 : val);
  }
}
