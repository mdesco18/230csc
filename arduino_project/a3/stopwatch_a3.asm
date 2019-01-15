;stopwatch_a3.asm
;Author: Marc-Andre Descoteaux
;Student: V00847029
;Date: 2017-06-30
;Description: CSC230 Assignment 3
;
; No data address definitions are needed since we use the "m2560def.inc" file
.include "m2560def.inc"
.include "lcd_function_defs.inc"
; Definitions for button values from the ADC
; Some boards may use the values in option B
; The code below used less than comparisons so option A should work for both
; Option A (v 1.1)
;.equ ADC_BTN_RIGHT = 0x032
;.equ ADC_BTN_UP = 0x0FA
;.equ ADC_BTN_DOWN = 0x1C2
;.equ ADC_BTN_LEFT = 0x28A
;.equ ADC_BTN_SELECT = 0x352
; Option B (v 1.0)
.equ ADC_BTN_RIGHT = 0x032
.equ ADC_BTN_UP = 0x0C3
.equ ADC_BTN_DOWN = 0x17C
.equ ADC_BTN_LEFT = 0x22B
.equ ADC_BTN_SELECT = 0x316

.def BUTTON_PRESSED = r18
.def TENTH_SECOND = r19
.def SECOND2 = r20
.def SECOND1 = r21
.def MINUTE2 = r22
.def MINUTE1 = r23
.def lowADC = r24
.def highADC = r25
.equ OVERFLOW_PRESCALE_COUNT = 61
.cseg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                          Reset/Interrupt Vectors                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.org 0x0000 ; RESET vector
	jmp initialize
	
; Add interrupt handlers for timer interrupts here. See Section 14 (page 101) of the datasheet for addresses.
.org 0x002E ; timer0 overflow
	jmp timer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Main Program                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; According to the datasheet, the last interrupt vector has address 0x0070, so the first
; "unreserved" location is 0x0072
.org 0x0072
initialize:
; Initialize the stack
	; Notice that we use "SPH_DATASPACE" instead of just "SPH" for our .def
	; since m2560def.inc defines a different value for SPH which is not compatible
	; with STS.
	ldi r16, high(STACK_INIT)
	sts SPH_DATASPACE, r16
	ldi r16, low(STACK_INIT)
	sts SPL_DATASPACE, r16
	
	; Initialize ADC
	; Set up ADCSRA (ADEN = 1, ADPS2:ADPS0 = 111 for divisor of 128)
	ldi	r16, 0x87
	sts	ADCSRA, r16
	; Set up ADMUX (MUX4:MUX0 = 00000, ADLAR = 0, REFS1:REFS0 = 1)
	ldi	r16, 0x40
	sts	ADMUX, r16
; Initialize timer

	sts OVERFLOW_INTERRUPT_COUNTER, r16
	call init_timer
	sei
	
	; Initialize the LCD
	call lcd_init
	ldi YL, low(DISP_STRING)
	ldi YH, high(DISP_STRING)
	
	ldi r16, 'T'
	st Y+, r16
	ldi r16, 'I'
	st Y+, r16
	ldi r16, 'M'
	st Y+, r16
	ldi r16, 'E'
	st Y+, r16
	ldi r16, ':'
	st Y+, r16 
	ldi r16, ' '
	st Y+, r16
	clr r16
	st Y+, r16

;Initialize Memory Space	
	sts PAUSE_STATE, r16
	sts RESET_STATE, r16
	mov BUTTON_PRESSED, r16
	
	push YL
	push YH
	push r16
	push r16
	
	call display_time
	
	pop r16
	pop r16
	pop YH
	pop YL
	
	call reset
	
	ldi r16, 1
	sts RESET_STATE, r16
	
	
main:

	call keep_time
	
	call button_poll
	
	cpi BUTTON_PRESSED, 0
	breq main
	cpi BUTTON_PRESSED, 1
	breq main 
	cpi BUTTON_PRESSED, 2
	breq set_lap
	cpi BUTTON_PRESSED, 3
	breq clear_lap
	cpi BUTTON_PRESSED, 4
	breq clear_timer
	cpi BUTTON_PRESSED, 5
	breq pause

	
	rjmp main
	
;
;
; takes in YL, YH, x, y, as arguments
; displays string Y to (x,y) on lcd
;
;
display_time:
	push r17
	push r16
	push ZH
	push ZL
	push YH
	push YL
	
	lds ZL, SPL_DATASPACE
	lds ZH, SPH_DATASPACE 
	
	ldd YL, Z+9
	ldd YH, Z+8
	ldd r16, Z+7
	ldd r17, Z+6
	
	push r16
	push r17
	
	call lcd_gotoxy
	
	pop r17
	pop r16
	
	push YH
	push YL
	
	call lcd_puts
	
	pop YL
	pop YH
	
display_time_done:
	pop YL
	pop YH
	pop ZL
	pop ZH
	pop r16
	pop r17
	ret

	
;
;
; takes in XL, XH, YL, YH as stack arguments to copy X into Y
;
;
strcpy: 
	push r16
	push ZH
	push ZL
	push YH
	push YL
	push XH
	push XL
	
	lds ZL, SPL_DATASPACE
	lds ZH, SPH_DATASPACE
	
	ldd XL, Z+14
	ldd XH, Z+13
	ldd YL, Z+12
	ldd YH, Z+11
	
strcpy_loop:

	ld r16, X+
	st Y+, r16
	cpi r16, 0
	brne strcpy_loop
	
strcpy_done
	pop XL
	pop XH
	pop YL
	pop YH
	pop ZL
	pop ZH
	pop r16
	ret
;
;
; takes in two arrays (X, Y)
; converts the numbers of X into their respective string character and stores in Y
;
;
num_to_string:
	push ZL
	push ZH
	push YL
	push YH
	push XL
	push XH
	push r16
	push r17
	clr r17
	
	lds ZL, SPL_DATASPACE
	lds ZH, SPH_DATASPACE
	
	ldd XL, Z+15
	ldd XH, Z+14
	ldd YL, Z+13
	ldd YH, Z+12
	
string_if:
	ld r16, X+
	cpi r16, 0
	breq zero
	cpi r16, 1
	breq one
	cpi r16, 2
	breq two
	cpi r16, 3
	breq three
	cpi r16, 4
	breq four
	cpi r16, 5
	breq five
	cpi r16, 6
	breq six
	cpi r16, 7
	breq seven
	cpi r16, 8
	breq eight
	cpi r16, 9
	breq nine

string_loop:
	
	inc r17
	cpi r17, 2
	breq colon
	cpi r17, 5
	breq period
	cpi r17, 7
	brne string_if
	clr r17
	st Y+, r17
	
num_to_string_done:
	pop r17
	pop r16
	pop XH
	pop XL
	pop YH
	pop YL
	pop ZH
	pop ZL
	ret

zero:
	ldi r16, '0'
	st Y+, r16
	rjmp string_loop
one: 
	ldi r16, '1'
	st Y+, r16
	rjmp string_loop
two: 
	ldi r16, '2'
	st Y+, r16
	rjmp string_loop
three:
	ldi r16, '3'
	st Y+, r16
	rjmp string_loop
four:
	ldi r16, '4'
	st Y+, r16
	rjmp string_loop
five:
	ldi r16, '5'
	st Y+, r16
	rjmp string_loop
six: 
	ldi r16, '6'
	st Y+, r16
	rjmp string_loop
seven: 
	ldi r16, '7'
	st Y+, r16
	rjmp string_loop
eight:
	ldi r16, '8'
	st Y+, r16
	rjmp string_loop
nine: 
	ldi r16, '9'
	st Y+, r16
	rjmp string_loop
colon: 
	ldi r16, ':'
	st Y+, r16
	rjmp string_loop
period:
	ldi r16, '.'
	st Y+, r16
	rjmp string_loop
	
;
;
; called from main
; takes the integer values of the clock from TIME_KEEPER
; turns it into an array of strings and puts it in DISP_TIME
; displays time to LCD
;
;
keep_time:
	push XL
	push XH
	push YL
	push YH
	push r16
	
	ldi XL, low(TIME_KEEPER)
	ldi XH, high(TIME_KEEPER)
	ldi YL, low(DISP_TIME)
	ldi YH, high(DISP_TIME)
	
	push XL
	push XH
	push YL
	push YH
	
	call num_to_string
	
	pop YH
	pop YL
	pop XH
	pop XL
	
	push YL
	push YH
	clr r16
	push r16
	ldi r16, 6
	push r16
	
	call display_time
	
	pop r16
	pop r16
	pop YH
	pop YL
	
	
keep_time_done:
	pop r16
	pop YH
	pop YL
	pop XH
	pop XL
	ret

;
;
; set LAST_LAP_START to CURRENT_LAP_START
; set CURRENT_LAP_START and LAST_LAP_END to DISP_TIME
; display lap times
;
;
set_lap:
	push r16
	push YH
	push YL
	push XH
	push XL
	
	ldi XL, low(CURRENT_LAP_START)
	ldi XH, high(CURRENT_LAP_START)
	ldi YL, low(LAST_LAP_START)
	ldi YH, high(LAST_LAP_START)
	
	push XL
	push XH
	push YL
	push YH
	
	call strcpy
	
	pop YH
	pop YL
	pop XH
	pop XL
	
	ldi XL, low(DISP_TIME)
	ldi XH, high(DISP_TIME)
	ldi YL, low(CURRENT_LAP_START)
	ldi YH, high(CURRENT_LAP_START)
	
	push XL
	push XH
	push YL
	push YH
	
	call strcpy
	
	pop YH
	pop YL
	pop XH
	pop XL
	
	ldi XL, low(DISP_TIME)
	ldi XH, high(DISP_TIME)
	ldi YL, low(LAST_LAP_END)
	ldi YH, high(LAST_LAP_END)
	
	push XL
	push XH
	push YL
	push YH
	
	call strcpy
	
	pop YH
	pop YL
	pop XH
	pop XL
	
	
	
	ldi r16, low(LAST_LAP_START)
	push r16
	ldi r16, high(LAST_LAP_START)
	push r16
	ldi r16, 1
	push r16
	clr r16
	push r16
	
	call display_time
	
	pop r16
	pop r16	
	pop r16
	pop r16
	
	
	ldi r16, low(LAST_LAP_END)
	push r16
	ldi r16, high(LAST_LAP_END)
	push r16
	ldi r16, 1
	push r16
	ldi r16, 9
	push r16
	
	call display_time
	
	pop r16
	pop r16
	pop r16
	pop r16
	
	
set_lap_done:
	
	pop XL
	pop XH
	pop YL
	pop YH
	pop r16
	
	rjmp main

;
;
; calls row1_reset 
;
;	
clear_lap:
	push r16
	
	ldi r16, 2
	sts RESET_STATE, r16
	
	call reset_row1
	
	ldi r16, 1
	sts RESET_STATE, r16
	
	pop r16
	
	rjmp main
	
;
; when left is pressed
; clear the timer
; set current lap start to 0
; keep displayed lap times
;
clear_timer:
	push r16
	
	call reset 
	lds r16, PAUSE_STATE
	com r16 ; flip it 
	sts r16, PAUSE_STATE
	
	pop r16
	
	rjmp main
;
;
; Change the PAUSE_STATE
;
;

pause:
	push r16
	
	lds r16, PAUSE_STATE
	cpi r16, 0
	breq unpause
	
	clr r16
	sts PAUSE_STATE, r16

	rjmp pause_done

unpause:
	
	ldi r16, 1
	sts PAUSE_STATE, r16

	rjmp pause_done

pause_done:
	pop r16
	rjmp main
	
; Sets DISP_TIME to "00:00.0"
; places it at (0,6)
; and displays it to the lcd
; if RESET_STATE = 0, program initializing so entire function runs through
; if RESET_STATE = 1, left button was pushed and it will exit after CURRENT_LAP_START is reset
; if RESET_STATE = 2, down button was pushed and only row1_reset will be called
reset:
	push YL
	push YH
	push r16

	ldi YL, low(DISP_TIME)
	ldi YH, high(DISP_TIME)
	
	ldi r16, '0'
	st Y+, r16
	ldi r16, '0'
	st Y+, r16
	ldi r16, ':'
	st Y+, r16
	ldi r16, '0'
	st Y+, r16
	ldi r16, '0'
	st Y+, r16
	ldi r16, '.'
	st Y+, r16
	ldi r16, '0'
	st Y+, r16
	clr r16
	st Y+, r16
	
	mov TENTH_SECOND, r16
	mov SECOND2, r16
	mov SECOND1, r16
	mov MINUTE2, r16
	mov MINUTE1, r16
	
	push YL
	push YH
	push r16
	ldi r16, 6
	push r16
	
	call display_time
	
	pop r16
	pop r16
	pop YH
	pop YL
	
; this function occurs when DOWN is pressed
; set row 1 to nothing
reset_row1:
	push YL
	push YH
	push r16
; set CURRENT_LAP_START to 00:00.0

	ldi YL, low(CURRENT_LAP_START)
	ldi YH, high(CURRENT_LAP_START)
	
	ldi r16, '0'
	st Y+, r16
	ldi r16, '0'
	st Y+, r16
	ldi r16, ':'
	st Y+, r16
	ldi r16, '0'
	st Y+, r16
	ldi r16, '0'
	st Y+, r16
	ldi r16, '.'
	st Y+, r16
	ldi r16, '0'
	st Y+, r16
	ldi r16, 0
	st Y+, r16
	
	lds r16, RESET_STATE
	
	cpi r16, 1
	breq reset_almost
	
	ldi YL, low(DISP_STRING)
	ldi YH, high(DISP_STRING)

	clr r16
	st Y, r16
	
	push YL
	push YH
	ldi r16, 1
	push r16
	clr r16
	push r16
	
	call display_time
	
	pop r16
	pop r16
	pop YH
	pop YL	
	
	lds r16, RESET_STATE
	
	cpi r16, 2
	breq reset_done
	
reset_almost:
	pop r16
	pop YH
	pop YL

reset_done:
	pop r16
	pop YH
	pop YL
	ret
;
;
; ADC Polling for buttons
;
;	
button_poll:
	push r16	
	; Now, check the button values until something below the highest threshold
	; (ADC_BTN_SELECT) is returned from the ADC.
	; Store the threshold in r21:r20 (1 higher than ADC_BTN_SELECT)
	ldi	lowADC, 0x17
	ldi	highADC, 0x03
button_start:
	; Start an ADC conversion	
	; Set the ADSC bit to 1 in the ADCSRA register to start a conversion
	lds	r16, ADCSRA
	ori	r16, 0x40
	sts	ADCSRA, r16	
	; Wait for the conversion to finish
wait_for_adc:
	lds		r16, ADCSRA
	andi	r16, 0x40
	brne	wait_for_adc	
	; Load the ADC result into the X pair (XH:XL). Note that XH and XL are defined above.
	lds	XL, ADCL
	lds	XH, ADCH
	; Compare XH:XL with the threshold in r21:r20
	cp	XL, lowADC ; Low byte
	cpc	XH, highADC ; High byte
	brsh btn_none ; If the ADC value was above the threshold, no button was pressed (so try again)
	
	lds r16, IGNORE_BUTTON
	cpi r16, 1
	breq btn_input_done
	
	ldi r16, 1
	sts IGNORE_BUTTON, r16
	
	ldi lowADC, low(ADC_BTN_RIGHT)
	ldi highADC, high(ADC_BTN_RIGHT)
	cp XL, lowADC
	cpc XH, highADC
	brlo btn_right

	ldi lowADC, low(ADC_BTN_UP)
	ldi highADC, high(ADC_BTN_UP)
	cp XL, lowADC
	cpc XH, highADC
	brlo btn_up

	ldi lowADC, low(ADC_BTN_DOWN)
	ldi highADC, high(ADC_BTN_DOWN)
	cp XL, lowADC
	cpc XH, highADC
	brlo btn_down

	ldi lowADC, low(ADC_BTN_LEFT)
	ldi highADC, high(ADC_BTN_LEFT)
	cp XL, lowADC
	cpc XH, highADC
	brlo btn_left

	ldi lowADC, low(ADC_BTN_SELECT)
	ldi highADC, high(ADC_BTN_SELECT)
	cp XL, lowADC
	cpc XH, highADC
	brlo btn_select

	rjmp btn_input_done

btn_none:
	ldi BUTTON_PRESSED, 0
	sts IGNORE_BUTTON, BUTTON_PRESSED
	rjmp btn_input_done
btn_right:
	ldi BUTTON_PRESSED, 1
	rjmp btn_input_done
btn_up:
	ldi BUTTON_PRESSED, 2
	rjmp btn_input_done
btn_down:
	ldi BUTTON_PRESSED, 3
	rjmp btn_input_done
btn_left:
	ldi BUTTON_PRESSED, 4
	rjmp btn_input_done
btn_select:
	ldi BUTTON_PRESSED, 5
	rjmp btn_input_done
btn_input_done:
	pop r16
	ret
	

;
;
; Initialize timers 
;
;
init_timer:
	push r16 	

	clr r16
	sts TCCR0A, r16
	ldi r16, 0x05
	sts TCCR0B, r16 
	ldi r16, 0x01 
	sts TIFR0,r16 ; Clear TOV0/ clear pending interrupts 
	sts TIMSK0,r16 ; Enable Timer/Counter0 Overflow Interrupt 

	pop r16
	ret 
;
;
; ISR
;
; 
timer:  
	push YH
	push YL
	push r17
	push r16 
	lds r16, SREG 
	push r16 

	ldi r16, 10
	lds r17, OVERFLOW_INTERRUPT_COUNTER
	add r17, r16
	cpi r17, OVERFLOW_PRESCALE_COUNT
	brlo timer_isr_done
	
	lds r16, PAUSE_STATE
	add TENTH_SECOND, r16 
	
	ldi r16, 10
	cpse TENTH_SECOND, r16
	rjmp timer_isr_almost
; set T to 0 if it passes 9
	ldi TENTH_SECOND, 0
	inc SECOND2
	cpse SECOND2, r16
	rjmp timer_isr_almost
; set S2 to 0 if it passes 9
	ldi SECOND2, 0
	inc SECOND1
	ldi r16, 6
	cpse SECOND1, r16
	rjmp timer_isr_almost
; set S1 to 0 if it passes 5
	ldi SECOND1, 0
	inc MINUTE2
	ldi r16, 10
	cpse MINUTE2, r16
	rjmp timer_isr_almost
; set M2 to 0 if it passes 9
	ldi MINUTE2, 0
; if M1 = 9, don't increment it
	ldi r16, 9
	cpi MINUTE1, r16
	brsh timer_isr_almost
	inc MINUTE1
	
timer_isr_almost:
	ldi YL, low(TIME_KEEPER)
	ldi YH, high(TIME_KEEPER)
	st Y+, MINUTE1
	st Y+, MINUTE2
	st Y+, SECOND1
	st Y+, SECOND2
	st Y+, TENTH_SECOND
	ldi r16, OVERFLOW_PRESCALE_COUNT
	sub r17, r16 ;r17 - overflow prescale count
 
timer_isr_done:

	; Store the overflow counter back to memory
	sts OVERFLOW_INTERRUPT_COUNTER, r17

	; The next stack value is the value of SREG
	pop r16 ; Pop SREG into r16
	sts SREG, r16 ; Store r16 into SREG
	; Now pop the original saved r16 value
	pop r16
	pop r17
	pop YL
	pop YH

	reti ; Return from interrupt
	
	
stop:
	rjmp stop
		
	
	
; Include LCD library code
.include "lcd_function_code.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Data Section                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.dseg
; Note that no .org 0x200 statement should be present
; Put variables and data arrays here...
	
DISP_STRING: .byte 6
TIME_KEEPER: .byte 5
DISP_TIME: .byte 8
CURRENT_LAP_START: .byte 8
LAST_LAP_START: .byte 8
LAST_LAP_END: .byte 8
RESET_STATE: .byte 1
PAUSE_STATE: .byte 1
OVERFLOW_INTERRUPT_COUNTER: .byte 1
IGNORE_BUTTON: .byte 1


