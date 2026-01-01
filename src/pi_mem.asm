;; compute the digits of pi using spigot algorithm
;; for EDSAC instruction set
;; uses main memory only

; define entry point
start .main

; overwrite initial instructions to get more memory
def_loc .array_start 4

; locate program in top memory against upper limit
org 842

;; print a superdigit of size log10(radix)
.output_superdigit_param: def_num 0             f
def_proc .output_superdigit:
        add             .output_superdigit_param f  ; load final quotient q
        mov             .var_numerator          f   ; set up numerator for divmod
        add             .const_10               f   ; load 10
        mov             .var_denominator        f   ; set up denominator for divmod
        call            .divmod                     ; call divmod to get q div radix and q mod radix
        add             .var_quotient           f   ; load q_next from q div radix
        lshift          1024                    f   ; shift left 10 bits for teleprinter
        mov             .var_tmp                f   ; save to temp
        out             .var_tmp                f   ; output digit2 to teleprinter
        add             .var_remainder          f
        lshift          1024                    f
        mov             .var_tmp                f
        out             .var_tmp                f
ret_proc .output_superdigit


.carry_predigit:              def_num 0         f
.carry_detection_initialised: def_num 0         f
.carry_detector_parameter:    def_num 0         f
def_proc .carry_detector:
        ;; check initialisation
        add             .carry_detection_initialised f
        sub             .const_1                f
        jge             .carry_post_init        f
        ;; perform initialisation
        mov             0 f
        add             .carry_detector_parameter f
        mov             .carry_predigit         f
        add             .const_1                f
        mov             .carry_detection_initialised f
        jge             %return%.carry_detector f
.carry_post_init:
        ;; carry_detector_parameter == radix?
        mov             0 f
        add             .carry_detector_parameter f
        sub             .const_radix            f
        jge             .carry_overflow         f
        ;; not overflow
        mov             0                       f
        add             .carry_predigit         f
        mov             .output_superdigit_param f
        call            .output_superdigit
        add             .carry_detector_parameter f
        mov             .carry_predigit         f
        jge             %return%.carry_detector f
.carry_overflow:
        mov             0                       f
        add             .carry_predigit         f
        add             .const_1                f
        mov             .output_superdigit_param f
        call            .output_superdigit
        mov             .carry_predigit         f   ; clear predigit
ret_proc .carry_detector


; computes .var_numerator // var_denominator
; quotient is in .var_quotient
; remainder is is .var_remainder
;; warning: extremely slow
.var_numerator:   def_num 0 d
.var_denominator: def_num 0 d
.var_quotient:    def_num 0 d
.var_remainder:   def_num 0 d
def_proc .divmod:
        mov             .var_quotient           d   ; initialize quotient to 0
    .divmod_loop:
        add             .var_numerator          d   ; load numerator
        sub             .var_denominator        d   ; subtract denominator
        jlt             .divmod_end             f   ; if negative, exit loop
        mov             .var_numerator          d   ; save updated remainder
        add             .var_quotient           d   ; load quotient
        add             .const_1                d   ; add 1
        mov             .var_quotient           d   ; save incremented quotient
        jge             .divmod_loop            f   ; continue loop
    .divmod_end:
        mov             0                       d   ; clear accumulator
        add             .var_numerator          d
        mov             .var_remainder          d
ret_proc .divmod


def_proc .main_inner:
        mov_mult        .const_radix            d
        mult_add        .var_remainder          d
        ;; shift to 35 bit acc
        lshift 0 f
        lshift 0 f
        lshift 64 f
        mov             .var_tmp                d

        mov_mult        .var_quotient           d
        mult_add        .var_i                  d
        lshift          0                       f
        lshift          0                       f
        lshift          64                      f
        add             .var_tmp                d

        mov             .var_numerator          d
        add             .var_i                  d
        lshift          0                       d
        sub             .const_1                d
        mov             .var_denominator        d
        call            .divmod
ret_proc .main_inner


def_proc .main:
        out             .const_figure_shift     f   ; output teleprinter char for formatting
        out             .const_carriage_return  f   ; output teleprinter char for formatting
        out             .const_line_feed        f   ; output teleprinter char for formatting
        add             .const_array_len        f   ; initialize array: load array len
        mov_dirty       .var_i                  f   ; store to i

.main_array_initialise_loop:
        lshift          0                       d   ; multiply i by 2
        add             .var_template_write     f   ; add template transfer to get address
        mov             .main_array_initialise_instr f ; plant transfer instruction
        add             .const_array_init       f   ; load initial value
        .main_array_initialise_instr:
        halt            0                       f   ; store initial value into array element (self-modified)
        add             .var_i                  f   ; load i
        sub             .const_1                f   ; subtract 1
        mov_dirty       .var_i                  f   ; save decremented i
        jge             .main_array_initialise_loop f ; loop until i is 0
        ;; array is now initialised

.main_outer_loop:
        ; quotient = 0
        mov             0                       f   ; clear accumulator
        mov             .var_quotient           f   ; store q to 0
        add             .const_array_len        f   ; load array len
        mov             .var_i                  f   ; initialize i to len


.main_i_loop:
        ;; read a[i] (previous remainder)
        mov             0                       f   ; clear accumulator
        add             .var_i                  f   ; load i
        lshift          0                       d   ; multiply i by 2
        add             .var_template_read      f   ; add template load to get address
        mov             .main_array_read_instr  f   ; plant load instruction
        .main_array_read_instr:
        halt            0                       f   ; this instruction becomes "add a[i]"
        ;; accumulator contains a[i]

        mov             .var_remainder          f   ; save a[i] (previous remainder)
        call            .main_inner                 ; call inner logic routine

        ;; save new remainder to a[i]
        add             .var_i                  f   ; load i
        lshift          0                       d   ; multiply i by 2
        add             .var_template_write     f   ; add template transfer to get address
        mov             .var_template_write_instr f ; plant transfer instruction
        add             .var_remainder          f   ; add remainder
        .var_template_write_instr:
        halt            0                       f   ; store remainder back to array (self-modified)
        ;; a[i] now contains new remainder

        ;; decrement i and loop back
        add             .var_i                  f   ; load i
        sub             .const_1                f   ; subtract 1
        mov_dirty       .var_i                  f   ; save decremented i
        sub             .const_1                f   ; subtract 1 again, loop until i is 1
        jge             .main_i_loop            f   ; continue i-loop

        ;; quotient, remainder = divmod(quotient, radix)
        mov             0                       d   ; reset accumulator
        add             .var_quotient           f   ; load final quotient q
        mov             .var_numerator          f   ; set up numerator for divmod
        add             .const_radix            f   ; load radix
        mov             .var_denominator        f   ; set up denominator for divmod
        call            .divmod                     ; call divmod to get q div radix and q mod radix

        ; a[1] = remainder
        add             .const_2                f   ; load constant 2
        add             .var_template_write     f   ; add template to form a transfer instruction
        mov             .main_array_write_instr f   ; plant transfer instruction
        add             .var_remainder          f   ; load remainder
        .main_array_write_instr:
        halt            0                       f   ; store remainder to first array element (self-modified)

        add             .var_quotient           f
        mov             .carry_detector_parameter f
        call            .carry_detector

        ;; decrement digits remaining
        add             .var_digits_remaining   f   ; load digit counter
        sub             .const_radix_log        f   ; subtract digits per iteration
        mov_dirty       .var_digits_remaining   f   ; save decremented counter
        jge             .main_outer_loop        f   ; continue outer loop if more digits needed
ret_proc .main

;; constants / globals
        .const_figure_shift:    #    0          F   ; teleprinter char 2 figure shift
        .const_carriage_return: @    0          F   ; teleprinter char 3 carriage return
        .const_line_feed:       &    0          F   ; teleprinter char 4 line feed

        .const_1:        def_num     1          d   ; constant 1
        .const_2:        def_num     2          f   ; constant 2
        .const_10:       def_num     10         f   ; constant 10

        .const_radix:    def_num     100        d   ; base: radix for output value
        .const_array_init: def_num   20         f   ; array initialised with this constant
        .const_radix_log: def_num    2          f   ; size of superdigit

        .const_array_len: def_num    838        f   ; len: length of remainder array
        .var_digits_remaining: def_num 252      f   ; n: number of iterations

        .var_tmp:        def_num     0          f   ; scratch variable
        .var_i:          def_num     0          d   ; i: loop counter variable
        .var_template_write: T       .array_start F ; template: transfer to array base
        .var_template_read: A        .array_start F ; template: load from array base
        .var_quotient:   def_num     0          d   ; q: quotient variable
        .var_remainder:  def_num     0          d   ; current remainder from array
        .var_temp_remainder: def_num 0          d   ; temporary remainder for digit extraction
