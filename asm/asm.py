import re
import sys
from contextlib import nullcontext
from argparse import ArgumentParser
from dataclasses import dataclass
from typing import *
from lark import Lark, Tree, Token
from loguru import logger

# simple assembler targetting EDSAC instruction set

edsac_grammar = Lark(r"""
    start: line+
    line:   instr
          | const
          | org
          | def
          | 
          | ret
          | call
          | start_label
          | loc
          | classic
          | space
          
    # directives:
    org:                 "org"             INT
    start_label:         "start"           address
    
    # subroutines:
    def:                 "def_proc"        LABEL ":"
    ret:                 "ret_proc"        LABEL
    call:  [LABEL ":"]   "call"            LABEL
       
    loc:                 "def_loc"         LABEL INT
    instr:   [LABEL ":"] INSTR [address]   ORDER_TERMINATOR
    const:   [LABEL ":"] ("def_num" literal_num ORDER_TERMINATOR | "def_char" literal_char )            
    classic: [LABEL ":"] PERFORATOR_LETTER [address] [/#/] ( CLASSIC_TERMINATOR | CONTROL_TERMINATOR )
    
    space: "."    
    LABEL: "%return%"? "." SYMBOL
    INSTR: "add"|"sub"|"mov_mult"|"mult_add"|"mult_sub"|"mov"
           |"mov_dirty"|"and"|"rshift"|"lshift"|"jge"|"jlt"
           |"inp"|"out"|"verify"|"nop"|"round"|"halt"                      
    ORDER_TERMINATOR: /[fd]/    
    address: INT | LABEL    
        
    literal_num: literal_decimal | literal_binary
    literal_char: "\"" CHARSET+ "\""    
    literal_decimal: [/[+-]/] INT 
    literal_binary:  [/[+-]/] /[01 _]+b/

    SYMBOL: ("_"|LETTER|DIGIT)+
    CHARSET: /[PQWERTYUIOJ#SZK\*\.F@D!HNM&LXGABCV0123456789]/ # todo: add figure diacritics in charset
    PERFORATOR_LETTER: /[PQWERTYUIOJ#SZK\*\.F@D!HNM&LXGABCV]/
    CLASSIC_TERMINATOR: /[F@D!HNM&LXGABCV]/
    CONTROL_TERMINATOR: /[ZK]/

    COMMENT:   /;[^\n]*/
               | "[" /[^\]]*/ "]"    
    
    %ignore COMMENT
    %ignore WS
    %import common.INT
    %import common.CNAME
    %import common.DIGIT
    %import common.LETTER
    %import common.WS
""")


class Visit:

    # todo: better error messages
    # todo: warn when referencing labels in classic mode
    # todo: warn when overwriting orders
    # todo: warn when exceeding memory
    # todo: dump memory image
    # todo: annotate output
    # todo: fewer passes
    # todo: shift orders with natural parameters

    default_org = 56
    memsize = 1024

    _width = {"f": 1, "d": 2}
    _width_reverse = {"0": "F", "1": "D"}
    _charset = "PQWERTYUIOJ#SZK*.F@D!HNM&LXGABCV"
    _ops = {
        "A": "add",      # add mem[n] to the accumulator
        "S": "sub",      # subtract mem[n] from the accumulator
        "H": "mov_mult", # copy mem[n] to the multiplier
        "V": "mult_add", # multiply mem[n] by the multiplier and add to the accumulator
        "N": "mult_sub", # multiply mem[n] by the multiplier and subtract from the accumulator
        "T": "mov",      # copy accumulator to mem[n] and clear the accumulator
        "U": "mov_dirty",# copy accumulator to mem[n] without clearing the accumulator
        "C": "and",
        "R": "rshift",
        "L": "lshift",
        "E": "jge",
        "G": "jlt",
        "I": "inp",
        "O": "out",
        "F": "verify",
        "X": "nop",
        "Y": "round",
        "Z": "halt",
    }

    @dataclass
    class Order:
        order_code: str
        order_terminator: str
        order_param: int = 0
        order_pi: bool = False
        def __repr__(self):
            order_param_repr = f"{self.order_param: 5d}" if self.order_param != 0 else ""
            order_pi_repr = "#" if self.order_pi else " "
            return f"{self.order_code} {order_param_repr:5}{order_pi_repr} {self.order_terminator.upper()}"


    def __init__(self):
        self.symbols: dict[str, int] = dict()
        self.opcodes: dict[str, str] = dict(zip(self._ops.values(), self._ops.keys()))
        self.opvalues: dict[int, str] = dict(enumerate(self._charset))
        self.mem: list[Optional[Visit.Order]] = [None] * Visit.memsize
        self.start_label = ".start"
        self.start_addr = None
        self.filler_order = Visit.Order("Z", "F")

    def resolve_address(self, addr_tok: Token) -> int:
        match addr_tok:
            case Token(type="INT", value=addr):
                return int(addr)
            case Token(type="LABEL", value=label):
                return self.symbols[label]

    def maybe_set_symbol(self, label_tok: Token, mem_index: int) -> None:
        if label_tok is not None:
            self.symbols[label_tok.value] = mem_index

    def make_order_addr(self, order_param: Tree) -> int:
        if order_param is None:
            return 0
        else:
            return self.resolve_address(order_param.children[0])

    def make_order_pi(self, order_param_tok: Token) -> bool:
        if order_param_tok is None:
            return False
        else:
            assert order_param_tok.value == "#"
            return True

    def make_order(self, instr_line: list) -> Order:
        match instr_line:
            case [
                _label,
                Token("INSTR", opcode),
                order_addr_tok,
                Token(type="ORDER_TERMINATOR", value=order_term)
            ]:
                assert opcode in self.opcodes.keys()
                order_code = self.opcodes[opcode]
                order_addr = self.make_order_addr(order_addr_tok)
                order_term = order_term
            case _:
                raise Exception(f"unrecognised instruction {instr_line}")
        return Visit.Order(order_code, order_term, order_addr)

    def make_int_order(self, literal_val: int) -> Order:
        order_code = self.opvalues[literal_val >> 12]
        order_param = (literal_val & 0b11111111111111111) >> 1
        order_width = self._width_reverse[literal_val & 1]
        return Visit.Order(order_code, order_width, order_param)

    def make_const_order(self, literal_val: Tree, width: int) -> list[Order]:
        if width == 1:
            return self.make_const_order_f(literal_val)
        else:
            return self.make_const_order_d(literal_val)

    def make_const_order_f(self, literal_val: Tree) -> list[Order]:
        literal_bits = None
        literal_bits_justified = None

        if literal_val.data == "literal_binary":
            literal_bits = literal_val.children[1][:-1]
        elif literal_val.data == "literal_decimal":
            literal_bits = bin(int(literal_val.children[1]))[2:]
        literal_bits = re.sub("[_ ]", "", literal_bits)

        sign = literal_val.children[0] if literal_val.children[0] else "+"
        if sign == "-":
            literal_bits_justified = f"{literal_bits:1>17}"
        elif sign == "+":
            literal_bits_justified = f"{literal_bits:0>17}"

        order_code = self.opvalues[int(literal_bits_justified[0:5], 2)]
        param_bits = literal_bits_justified[5:16]
        order_param = int(param_bits, 2)
        order_term = self._width_reverse[literal_bits_justified[16]]
        return [Visit.Order(order_code, order_term, order_param)]

    def make_const_order_d(self, literal_val: Tree) -> list[Order]:
        literal_bits = None
        literal_bits_justified = None

        if literal_val.data == "literal_binary":
            literal_bits = literal_val.children[1][:-1]
        elif literal_val.data == "literal_decimal":
            literal_bits = bin(int(literal_val.children[1]))[2:]
        literal_bits = re.sub("[_ ]", "", literal_bits)


        sign = literal_val.children[0] if literal_val.children[0] else "+"
        if sign == "-":
            literal_bits_justified = f"{literal_bits:1>35}"
        elif sign == "+":
            literal_bits_justified = f"{literal_bits:0>35}"

        order_code1 = self.opvalues[int(literal_bits_justified[0:5], 2)]
        order_param1 = int(literal_bits_justified[5:16], 2)
        order_term1 = self._width_reverse[literal_bits_justified[17]]

        assert literal_bits_justified[17] == "0", "Sandwich bit cannot be set"

        order_code2 = self.opvalues[int(literal_bits_justified[18:23], 2)]
        order_param2 = int(literal_bits_justified[23:34], 2)
        order_term2 = self._width_reverse[literal_bits_justified[34]]

        return [
            Visit.Order(order_code2, order_term2, order_param2),
            Visit.Order(order_code1, order_term1, order_param1),
        ]

    def visit(
            self,
            tree: Tree,
            org: int,
            symbols_listing_stream = None,
            orders_output_stream = None,
            emit_pk_spaces = True,
            emit_location = False,
    ) -> None:

        emit_ekpf_launcher = True
        emit_pktk_headers = True

        # 1st pass: label positions

        mem_index = org
        for line in tree.children:
            mem_index = self.visit_labels(line, mem_index)
        if symbols_listing_stream is not None:
            for k, v in self.symbols.items():
                print(f"{k} {v}", file=symbols_listing_stream)

        # 2nd pass: assemble orders

        mem_index = org
        for line in tree.children:
            mem_index = self.visit_orders(line, mem_index)

        # 3rd pass: emit assembled orders

        indent = " " * 7
        symbols_reverse = {v:k for k,v in self.symbols.items()}
        for index, order in enumerate(self.mem):
            if index > 0 and self.mem[index - 1] is None and self.mem[index] is not None and emit_pktk_headers:
                self.emit_header(index, indent, orders_output_stream)
            if order is not None:
                # todo: keep index in sync when emitting GK
                if order.order_code == "P" and order.order_terminator in {"Z", "K"} and emit_pk_spaces:
                    print(indent + ".", file=orders_output_stream)
                    print(indent + ".", file=orders_output_stream)
                location = f"[{index:04d}] " if emit_location else indent
                if index in symbols_reverse:
                    symbol_hint = f" [{symbols_reverse[index]}]"
                else:
                    symbol_hint = ""
                print(f"{location}{order}{symbol_hint}", file=orders_output_stream)
        if emit_ekpf_launcher:
            self.ekpf_launcher(indent, orders_output_stream)

    def ekpf_launcher(self, indent, orders_output_stream):
        if self.start_label in self.symbols:
            start_order = Visit.Order("E", "K", self.symbols[self.start_label])
            print(indent + str(start_order), file=orders_output_stream)
            print(indent + str(Visit.Order("P", "F")), file=orders_output_stream)
        elif self.start_addr is not None:
            start_order = Visit.Order("E", "K", self.start_addr)
            print(indent + str(start_order), file=orders_output_stream)
            print(indent + str(Visit.Order("P", "F")), file=orders_output_stream)
        else:
            logger.warning("start address not found")

    def emit_header(self, index, indent, stream):
        print(indent + ".", file=stream)
        print(indent + ".", file=stream)
        print(indent + str(Visit.Order("P", "K")), file=stream)
        print(indent + str(Visit.Order("T", "K", index)), file=stream)

    def visit_labels(self, line: Tree, mem_index: int) -> int:
        "resolve location of labels"
        next_mem_index = mem_index
        assert line.data == "line"
        match line.children:
            case [Tree(data="org", children=[Token("INT", org)])]:
                next_mem_index = int(org)
            case [Tree(data="instr", children=[label, *_])]:
                self.maybe_set_symbol(label, mem_index)
                next_mem_index = mem_index + 1
            case [Tree(data="const", children=[label, Tree(data="literal_num"), term])]:
                width = Visit._width[term]
                if mem_index % 2 == 1 and width == 2:
                    mem_index += 1
                self.maybe_set_symbol(label, mem_index)
                next_mem_index = mem_index + width
            case [Tree(data="const",
                       children=[label, Tree(data="literal_char", children=const)])]:
                self.maybe_set_symbol(label, mem_index)
                next_mem_index = mem_index + len(const)
            case [Tree(data="def", children=[label])]:
                self.symbols[label.value] = mem_index
                if label != self.start_label:
                    next_mem_index = mem_index + 2
            case [Tree(data="ret", children=[label])]:
                self.symbols["%return%" + label.value] = mem_index
                next_mem_index = mem_index + 1
            case [Tree(data="call", children=[label, *_])]:
                self.maybe_set_symbol(label, mem_index)
                next_mem_index = mem_index + 2
            case [Tree(data="loc", children=[label, loc])]:
                addr = int(loc.value)
                self.symbols[label.value] = addr
            case [Tree(data="start_label", children=[Tree(data="address", children=[start_label])])]:
                match start_label.type:
                    case "INT": self.start_addr = int(start_label)
                    case "LABEL": self.start_label = start_label.value
            case [Tree(data="classic", children=[label, *_])]:
                self.maybe_set_symbol(label, mem_index)
                next_mem_index = mem_index + 1
            case [Tree(data=Token(_, "space"))]:
                pass
            case _:
                logger.warning(f"ignoring while computing label positions: {line.children}")
        return next_mem_index


    def visit_orders(self, line: Tree, mem_index: int) -> int:
        assert line.data == "line"
        next_mem_index = mem_index
        match line.children:
            case [Tree(data="org", children=[Token("INT", org)])]:
                next_mem_index = int(org)
            case [Tree(data="instr", children=instr)]:
                self.mem[mem_index] = self.make_order(instr)
                next_mem_index = mem_index + 1
            case [Tree(data="const", children=[_label, Tree(data="literal_num", children=[literal]), term])]:
                width = Visit._width[term]
                if mem_index % 2 == 1 and width == 2:
                    self.mem[mem_index] = self.filler_order
                    mem_index += 1
                for index, order in enumerate(self.make_const_order(literal, width)):
                    self.mem[mem_index + index] = order
                assert width == index + 1, "Order width mismatch"
                next_mem_index = mem_index + width
            case [Tree(data="const",
                       children=[_label, Tree(data="literal_char", children=const)])]:
                for index, char in enumerate(const):
                    self.mem[mem_index + index] = Visit.Order(char.value, "F")
                next_mem_index += len(const)
            case [Tree(data="def", children=[label])]:
                if label != self.start_label:
                    return_address = self.symbols["%return%" + label.value]
                    self.mem[mem_index + 0] = Visit.Order("A", "F", 3)
                    self.mem[mem_index + 1] = Visit.Order("T", "F", return_address)
                    next_mem_index = mem_index + 2
            case [Tree(data="call", children=[_label, label_callee])]:
                callee_address = self.symbols[label_callee.value]
                self.mem[mem_index + 0] = Visit.Order("A", "F", mem_index)
                self.mem[mem_index + 1] = Visit.Order("G", "F", callee_address)
                next_mem_index = mem_index + 2
            case [Tree(data="loc", children=[label, loc])]:
                pass
            case [Tree(data="ret")]:
                self.mem[mem_index] = self.filler_order
                next_mem_index = mem_index + 1
            case [Tree(data="classic",
                       children=[_, Token(value=order_code), order_addr_tok, order_pi_tok, Token(value=order_term)])]:
                order_addr = self.make_order_addr(order_addr_tok)
                order_pi = self.make_order_pi(order_pi_tok)
                classic_order = Visit.Order(order_code, order_term, order_addr, order_pi)
                self.mem[mem_index] = classic_order
                next_mem_index = mem_index + 1
            case [Tree(data="space")]:
                pass
            case [Tree(data="start_label")]:
                pass
            case _:
                logger.warning(f"ignoring while generating orders: {line.children}")
        return next_mem_index


def main(commandline: list[str]) -> None:
    logger.info("Last orders assembler")
    arg_parser = ArgumentParser()
    arg_parser.add_argument("source", help="Assembly source")
    arg_parser.add_argument("-o", "--orders_output", help="Assembled orders. Defaults to stdout")
    arg_parser.add_argument("-l", "--listing_output", help="Output symbol list to file", required=False)
    arg_parser.add_argument("-a", "--addresses", help="Output memory locations in source as comments", action="store_true", required=False, default=False)
    arg_parser.add_argument("--org", help="Default ORG (origin) location", type=int, required=False, default=Visit.default_org)

    args = vars(arg_parser.parse_args(commandline))
    for arg_k, arg_v in args.items():
        logger.debug(f"arg name {arg_k} set to {arg_v}")
    with open(args["source"], "r") as source_file:
        source_txt = "".join(source_file.readlines())

    logger.debug("parsing source")
    ast = edsac_grammar.parse(source_txt)
    logger.debug(f"ast node count: {len(list(ast.iter_subtrees()))}")

    outp = args["orders_output"]
    outlist = args["listing_output"]
    with (open(outp, "w") if outp else nullcontext()) as orders_output_stream:
        with (open(outlist, "w") if outlist else nullcontext()) as symbols_listing_string:
            Visit().visit(
                ast,
                org=args["org"],
                orders_output_stream=orders_output_stream,
                symbols_listing_stream=symbols_listing_string,
                emit_location=args["addresses"]
            )

if __name__ == "__main__":
    main(sys.argv[1:])
