;; compute the digits of pi using spigot algorithm
;; for EDSAC instruction set (initial orders 2)
;;
;; uses tape for storage -
;; therefore assembled output requires modified
;; EDSAC hardware to support storage tape


inline "PFGKIFAFRDLFUFOFE@A6FG@E8FEZPF"
inline "@&*LAST!ORDERS!PI!#A*!TAPE!STORAGE"
inline "@&!EMILE!JOUBERT!#A*!MMXXVI@&@&#"

comment "LAST ORDERS PI - TAPE STORAGE"

; define entry point
start .main


org 100

;; constants
        .const_figure_shift:    #    0          F   ; teleprinter char 2 figure shift
        .const_carriage_return: @    0          F   ; teleprinter char 3 carriage return
        .const_line_feed:       &    0          F   ; teleprinter char 4 line feed

        .const_1:        def_num     1          d   ; constant 1
        .const_2:        def_num     2          f   ; constant 2
        .const_3:        def_num     3          f   ; constant 3
        .const_5:        def_num     5          f   ; constant 3
        .const_10:       def_num     10         d   ; constant 10
        .const_100:      def_num     100        d
        .const_1000:     def_num     1000       d
        .const_10000:    def_num     10000      d
        .const_f:        def_num     15         f   ; 1111

        .const_radix:    def_num     100        d   ; base: radix for output value
        .const_tape_init: def_num    20         f   ; tape initialised with this constant
        .const_radix_log: def_num    2          f   ; size of superdigit


        ;;; todo:
        ;;;   read .var_digits_remaining as parameter
        ;;;   and compute the needed array len

        ;.const_array_len: def_num      40000   f
        ;.var_digits_remaining: def_num 9878    f

        ;.const_array_len: def_num      8303    f
        ;.var_digits_remaining: def_num 2502    f

        .const_array_len: def_num      6500    f
        .var_digits_remaining: def_num 1958    f

        ;.const_array_len: def_num      2003    f
        ;.var_digits_remaining: def_num 602     f

        ;.const_array_len: def_num      830     f
        ;.var_digits_remaining: def_num 251     f

        ;.const_array_len: def_num      168     f
        ;.var_digits_remaining: def_num 52      f


        .var_tmp:            def_num     0     f   ; scratch variable
        .var_i:              def_num     0     d   ; loop counter

        .var_iteration:      def_num     0     f
        .var_iteration_prev: def_num     0     f
        .var_output_column:  def_num     0     f
        .const_max_column:   def_num    68     f

;;
;; subroutines
;;


def_proc .format_colwidth:
        add             .var_output_column      f
        add             .const_radix_log        f
        mov_dirty       .var_output_column      f
        sub             .const_max_column       f
        jlt             .format_colwidth_exit   f

        out             .const_carriage_return  f
        out             .const_line_feed        f
        mov             .var_tmp                f
        mov             .var_output_column      f
.format_colwidth_exit:
        mov             .var_tmp                f
ret_proc .format_colwidth



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

        call            .format_colwidth
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
        mov             .var_tmp                f
        add             .carry_detector_parameter f
        mov             .carry_predigit         f
        add             .const_1                f
        mov             .carry_detection_initialised f
        jge             %return%.carry_detector f
.carry_post_init:
        ;; carry_detector_parameter == radix?
        mov             .var_tmp                f
        add             .carry_detector_parameter f
        sub             .const_radix            f
        jge             .carry_overflow         f
        ;; not overflow
        mov             .var_tmp                f
        add             .carry_predigit         f
        mov             .output_superdigit_param f
        call            .output_superdigit
        add             .carry_detector_parameter f
        mov             .carry_predigit         f
        jge             %return%.carry_detector f
.carry_overflow:
        mov             .var_tmp                f
        add             .carry_predigit         f
        add             .const_1                f
        mov             .output_superdigit_param f
        call            .output_superdigit
        mov             .carry_predigit         f   ; clear predigit
ret_proc .carry_detector


.var_numerator:       def_num 0 d
.var_denominator:     def_num 0 d
.var_quotient:        def_num 0 d
.var_remainder:       def_num 0 d
.var_shifted_divisor: def_num 0 d
.var_bit_value:       def_num 0 d
def_proc .divmod:
        ; initialise
        mov             0                       d   ; clear accumulator
        mov             .var_quotient           d   ; quotient = 0
        add             .var_denominator        d   ; shifted_divisor = denominator
        mov             .var_shifted_divisor    d
        mov             0                       d   ; clear accumulator
        add             .const_1                d   ; bit_value = 1
        mov             .var_bit_value          d

        ; align divisor to highest bit position
    .divmod_align_loop:
        add             .var_shifted_divisor    d   ; load shifted_divisor
        lshift          0                       d   ; double it
        jlt             .divmod_align_done      f   ; if overflow (became negative), stop
        sub             .var_numerator          d   ; check if doubled > numerator
        sub             .const_1                d   ; stop only if strictly greater (not equal)
        jge             .divmod_align_done      f   ; if doubled > numerator, stop alignment

        ; doubled value is still <= numerator, so save it
        add             .const_1                d   ; restore +1
        add             .var_numerator          d   ; restore (add back numerator)
        mov             .var_shifted_divisor    d   ; save doubled shifted_divisor

        mov             0                       d   ; clear accumulator
        add             .var_bit_value          d   ; load bit_value
        lshift          0                       d   ; double it
        mov             .var_bit_value          d   ; save doubled bit_value
        jge             .divmod_align_loop      f   ; continue alignment

    .divmod_align_done:
        ; binary division - work down from MSB to LSB
        ; initialise remainder = numerator
        mov             0                       d
        add             .var_numerator          d
        mov             .var_remainder          d

    .divmod_division_loop:
        ; check if bit_value reached 0 (done)
        add             .var_bit_value          d
        sub             .const_1                d
        jlt             .divmod_division_done   f   ; if bit_value - 1 < 0 (i.e., bit_value = 0), done

        ; check if remainder >= shifted_divisor
        mov             0                       d
        add             .var_remainder          d
        sub             .var_shifted_divisor    d
        jlt             .divmod_division_skip   f   ; if remainder < shifted_divisor, skip subtraction

        ; remainder >= shifted_divisor, so subtract and add to quotient
        mov             .var_remainder          d   ; save new remainder
        add             .var_quotient           d   ; load quotient
        add             .var_bit_value          d   ; add bit_value to quotient
        mov             .var_quotient           d   ; save new quotient

    .divmod_division_skip:
        ; halve shifted_divisor
        mov             0                       d
        add             .var_shifted_divisor    d
        rshift          0                       d   ; halve it
        mov             .var_shifted_divisor    d

        ; halve bit_value
        mov             0                       d
        add             .var_bit_value          d
        rshift          0                       d   ; halve it
        mov             .var_bit_value          d

        jge             .divmod_division_loop   f   ; continue division

    .divmod_division_done:
        mov             0                       d   ; clear accumulator
ret_proc .divmod


def_proc .main_inner:
        mov_mult        .const_radix            d
        mult_add        .var_remainder          d
        ;; shift to 35 bit acc
        lshift          0                       f
        lshift          0                       f
        lshift          64                      f
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

        ; for writing initialisation tape
        call .set_output
        call .set_input

        mov             .var_tmp                f

        add             .const_array_len        f   ; initialize array: load array len
        mov             .var_i                  f   ; store to i

.main_tape_initialise_loop:

        ;; write init value to tape
        mov             0                       f
        add             .const_tape_init        f
        mov             0                       f
        call            .print_bits
        mov             0                       f

        add             .var_i                  f   ; load i
        sub             .const_1                f   ; subtract 1
        mov_dirty       .var_i                  f   ; save decremented i
        sub             .const_1                f
        jge             .main_tape_initialise_loop f ; loop until i is 0
        ;; tape now contains init value

.main_outer_loop:
        ; quotient = 0
        mov             .var_tmp                f   ; clear accumulator
        mov             .var_quotient           f   ; store q to 0
        add             .const_array_len        f   ; load array len
        mov             .var_i                  f   ; initialize i to len

        ;; incr iterations
        add             .var_iteration          f
        mov_dirty       .var_iteration_prev     f
        add             .const_1                f
        mov             .var_iteration          f

        call            .set_output

.main_i_loop:

        ;; read previous remainder from tape
        mov             .var_tmp                f
        call            .read_bits                  ; read tape
        add             .read_bits_result       f
        mov_dirty       .var_remainder          f
        mov             .var_tmp                f
        call            .main_inner                 ; call inner logic routine

        ; only write new remainder if i > 1
        ; we're on the last iteration of the loop
        ; the remainder computation takes place after the loop
        mov             .var_tmp                f
        add             .var_i                  f
        sub             .const_2                f
        jlt             .skip_if_last_iteration f

        ; write new remainder to tape
        mov             .var_tmp                f
        add             .var_remainder          f
        mov             0                       f
        call            .print_bits
        mov             .var_tmp                f

.skip_if_last_iteration:

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

        ; write remainder to tape
        mov             .var_tmp                f
        add             .var_remainder          f
        mov             0                       f
        call            .print_bits
        mov             .var_tmp                f

        ; print digits
        call            .reset_io
        mov             .var_tmp                f
        add             .var_quotient           f
        mov             .carry_detector_parameter f
        call            .carry_detector

        ;; decrement digits remaining
        add             .var_digits_remaining   f   ; load digit counter
        sub             .const_radix_log        f   ; subtract digits per iteration
        mov_dirty       .var_digits_remaining   f   ; save decremented counter
        jge             .main_outer_loop        f   ; continue outer loop if more digits needed
ret_proc .main



; set output to tape
def_proc .set_output:
        out_tape        0                       f
ret_proc .set_output


; set input to tape
def_proc .set_input:
        in_tape         0                       f
ret_proc .set_input


; switch output to printer
def_proc .reset_io:
    out_print                                   f
ret_proc .reset_io


align_even
.const_high_bit_wide:   def_num  0 f ; for removing flipped bit in tape
.const_high_bit:        def_num 16 f
.print_bits_index:      def_num  0 f
def_proc .print_bits:

        ; initialise index
        mov             .var_tmp                f
        add             .const_3                f
        mov             .print_bits_index       f

        ; load mask
        mov_mult        .const_f                f

  .print_bits_loop:

        ; clear accumulator
        mov             .var_tmp                f

        ; mask bits
        mult_and        0                       f

        ; print masked bits
        lshift          1024                    f
        mov             1                       f
        out             1                       f

    ; shift param 4 bits right
        add             0                       f
        rshift          4                       f
        mov             0                       f

        add             .print_bits_index       f
        sub             .const_1                f
        mov_dirty       .print_bits_index       f
        jge             .print_bits_loop        f
        mov             1                       f
ret_proc .print_bits


.read_bits_result: def_num 0 d
.read_bits_index:  def_num 0 f
def_proc .read_bits:

        ; clear destination
        mov             0                       d
        mov             0                       d

        ; read char
        inp             1                       f
        add             0                       d
        sub             .const_high_bit_wide    d
        rshift          4                       f
        mov             0                       d

        inp             1                       f
        add             0                       d
        sub             .const_high_bit_wide    d
        rshift          4                       f
        mov             0                       d

        inp             1                       f
        add             0                       d
        sub             .const_high_bit_wide    d
        rshift          4                       f
        mov             0                       d

        inp             1                       f
        add             0                       d
        sub             .const_high_bit_wide    d
        rshift          16                      f
        mov             .read_bits_result       d

ret_proc .read_bits
