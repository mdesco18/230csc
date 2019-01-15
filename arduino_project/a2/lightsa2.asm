; lightsa2.asm
; Author: Marc-Andre Descoteaux (with template code from B. Bird)
; CSC230 Assignment 2
; Date: 06/15/2017
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;                        Constants and Definitions                            ; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
 
; Special register definitions 
.def XL = r26 
.def XH = r27 
.def YL = r28 
.def YH = r29 
.def ZL = r30 
.def ZH = r31 
 
; Stack pointer and SREG registers (in data space) 
.equ SPH = 0x5E 
.equ SPL = 0x5D 
.equ SREG = 0x5F 
 
; Initial address (16-bit) for the stack pointer 
.equ STACK_INIT = 0x21FF 
 
; Port and data direction register definitions (taken from AVR Studio; note that m2560def.inc does not give the data space address of PORTB) 
.equ DDRB = 0x24 
.equ PORTB = 0x25 
.equ DDRL = 0x10A 
.equ PORTL = 0x10B 

;Data registers for bits 1,3,5,7 set on/off
.equ bit7on = 0x80
.equ bit5on = 0x20
.equ bit3on = 0x08
.equ bit1on = 0x02
.equ bitL7off = 0x2A
.equ bitL5off = 0x8A
.equ bitL3off = 0xA2
.equ bitL1off = 0xA8
.equ bitB3off = 0x02
.equ bitB1off = 0x08
 
; Definitions for the analog/digital converter (ADC) (taken from m2560def.inc) 
; See the datasheet for details 
.equ ADCSRA = 0x7A ; Control and Status Register 
.equ ADMUX = 0x7C ; Multiplexer Register 
.equ ADCL = 0x78 ; Output register (high bits) 
.equ ADCH = 0x79 ; Output register (low bits) 
 
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
 
; Definitions of the special register addresses for timer 0 (in data space) 
.equ GTCCR = 0x43 
.equ OCR0A = 0x47 
.equ OCR0B = 0x48 
.equ TCCR0A = 0x44 
.equ TCCR0B = 0x45 
.equ TCNT0  = 0x46 
.equ TIFR0  = 0x35 
.equ TIMSK0 = 0x6E 
 
; Definitions of the special register addresses for timer 1 (in data space) 
.equ TCCR1A = 0x80 
.equ TCCR1B = 0x81 
.equ TCCR1C = 0x82 
.equ TCNT1H = 0x85 
.equ TCNT1L = 0x84 
.equ TIFR1  = 0x36 
.equ TIMSK1 = 0x6F 
 
; Definitions of the special register addresses for timer 2 (in data space) 
.equ ASSR = 0xB6 
.equ OCR2A = 0xB3 
.equ OCR2B = 0xB4 
.equ TCCR2A = 0xB0 
.equ TCCR2B = 0xB1 
.equ TCNT2  = 0xB2 
.equ TIFR2  = 0x37 
.equ TIMSK2 = 0x70 

; Other Variables
.def CURRENT_LED = r24
.def DIRECTION = r25
.def BUTTON_PRESSED = r19
.def lowADC = r20
.def highADC = r21
.def onoff = r22
.equ OVERFLOW_PRESCALE_COUNT = 61 ;(16000000/1024/256)

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
; "unreserved" location is 0x0074 
.org 0x0074 
	
initialize: 
; Initialize the stack 
	ldi r16, high(STACK_INIT) 
	sts SPH, r16 
	ldi r16, low(STACK_INIT) 
	sts SPL, r16 
; Initialize ADC
	; Set up ADCSRA (ADEN = 1, ADPS2:ADPS0 = 111 for divisor of 128)
	ldi	r16, 0x87
	sts	ADCSRA, r16
	; Set up ADMUX (MUX4:MUX0 = 00000, ADLAR = 0, REFS1:REFS0 = 1)
	ldi	r16, 0x40
	sts	ADMUX, r16
; Initialize timer

	
	ldi r16, 1
	sts OVERFLOW_INCREMENT, r16
	clr r16
	sts OVERFLOW_INTERRUPT_COUNTER, r16
	call init_timer
	sei

;start
	ldi r16, 0xff
	sts DDRL, r16
	sts DDRB, r16
	ldi CURRENT_LED, 0
	ldi onoff, 1
	call CLEAR_LEDS

main: 
	
	call SET_LED
	
	call button_test

	cpi BUTTON_PRESSED, 0
	breq main
	cpi BUTTON_PRESSED, 1
	breq regular 
	cpi BUTTON_PRESSED, 2
	breq faster_x4
	cpi BUTTON_PRESSED, 3
	breq slower_x1
	cpi BUTTON_PRESSED, 4
	breq inverse
	cpi BUTTON_PRESSED, 5
	breq pause
	
	rjmp main

;	call CLEAR_LEDS
;	rjmp stop



regular:
	
	ldi onoff, 1

	rjmp main

inverse:

	ldi onoff, 0
	rjmp main 

faster_x4:
	push r16
	
	ldi r16, 4 
	sts OVERFLOW_INCREMENT, r16

	pop r16
	rjmp main

slower_x1: 
	push r16

	ldi r16, 1
	sts OVERFLOW_INCREMENT, r16

	pop r16
	rjmp main

pause:
	push r16

	cpi DIRECTION, 0
	breq unpause

	sts PAUSE_STATE, DIRECTION
	ldi DIRECTION, 0 

	rjmp pause_done

unpause:
	
	lds r16, PAUSE_STATE
	mov DIRECTION, r16

	rjmp pause_done

pause_done:
	pop r16
	rjmp main
	
	
button_test:
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

SET_LED:

	push r17

	cpi CURRENT_LED, 0
	breq SET_LED_0
	cpi CURRENT_LED, 1
	breq SET_LED_1
	cpi CURRENT_LED, 2
	breq SET_LED_2
	cpi CURRENT_LED, 3
	breq SET_LED_3close
	cpi CURRENT_LED, 4
	breq SET_LED_4close
	cpi CURRENT_LED, 5
	breq SET_LED_5close
	rjmp SET_LED_DONE
;these branches are too far away and must be jumped too // may need to add more of these or delete later
SET_LED_3close:
	rjmp SET_LED_3
SET_LED_4close:
	rjmp SET_LED_4
SET_LED_5close:
	rjmp SET_LED_5

SET_LED_0:

	ldi DIRECTION, 1

	cpi onoff, 0
	breq SET_LED_0xoff
		
	ldi r17, bit1on
	sts PORTB, r17
	clr r17
	sts PORTL, r17

	rjmp SET_LED_DONE

SET_LED_0xoff:

	ldi r17, bitB1off
	sts PORTB, r17
	ser r17
	sts PORTL, r17
	
	rjmp SET_LED_DONE

SET_LED_1:

	cpi onoff, 0
	breq SET_LED_1xoff

	ldi r17, bit3on
	sts PORTB, r17
	clr r17
	sts PORTL, r17
	
	rjmp SET_LED_DONE

SET_LED_1xoff:

	ldi r17, bitB3off
	sts PORTB, r17
	ser r17
	sts PORTL, r17
	
	rjmp SET_LED_DONE

SET_LED_2:
	
	cpi onoff, 0
	breq SET_LED_2xoff

	ldi r17, bit1on
	sts PORTL, r17
	clr r17
	sts PORTB, r17
	
	rjmp SET_LED_DONE

SET_LED_2xoff:

	ldi r17, bitL1off
	sts PORTL, r17
	ser r17
	sts PORTB, r17
	
	rjmp SET_LED_DONE

SET_LED_3:

	cpi onoff, 0
	breq SET_LED_3xoff

	ldi r17, bit3on
	sts PORTL, r17
	clr r17
	sts PORTB, r17

	rjmp SET_LED_DONE

SET_LED_3xoff:

	ldi r17, bitL3off
	sts PORTL, r17
	ser r17
	sts PORTB, r17

	rjmp SET_LED_DONE

SET_LED_4:
	
	cpi onoff, 0
	breq SET_LED_4xoff

	ldi r17, bit5on
	sts PORTL, r17
	clr r17
	sts PORTB, r17
	
	rjmp SET_LED_DONE

SET_LED_4xoff:

	ldi r17, bitL5off
	sts PORTL, r17
	ser r17
	sts PORTB, r17
	
	rjmp SET_LED_DONE

SET_LED_5:

	ldi DIRECTION, -1

	cpi onoff, 0
	breq SET_LED_5xoff

	ldi r17, bit7on
	sts PORTL, r17
	clr r17
	sts PORTB, r17

	rjmp SET_LED_DONE

SET_LED_5xoff:

	ldi r17, bitL7off
	sts PORTL, r17
	ser r17
	sts PORTB, r17
	
	rjmp SET_LED_DONE

SET_LED_DONE:
	pop r17
	ret

CLEAR_LEDS:
	; This function uses r16, so we will save it onto the stack
	; to preserve whatever value it already has.
	push r16
	
	
	; Set PORTL and PORTB to 0x00
	ldi r16, 0x00
	sts PORTB, r16
	sts PORTL, r16
	
	; Load the saved value of r16
	pop r16
	
	; Return 
	ret

init_timer:; Initialize timers 
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
	 
timer: ;ISR 

	push r17
	push r16 
	lds r16, SREG 
	push r16 

	lds r16, OVERFLOW_INCREMENT
	lds r17, OVERFLOW_INTERRUPT_COUNTER
	add r17, r16
	cpi r17, OVERFLOW_PRESCALE_COUNT
	brlo timer_isr_done

	add CURRENT_LED, DIRECTION 
	
	clr r17 
 
timer_isr_done:

	; Store the overflow counter back to memory
	sts OVERFLOW_INTERRUPT_COUNTER, r17

	; The next stack value is the value of SREG
	pop r16 ; Pop SREG into r16
	sts SREG, r16 ; Store r16 into SREG
	; Now pop the original saved r16 value
	pop r16
	pop r17
	
	reti ; Return from interrupt

stop: 
	rjmp stop 
  
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;                               Data Section                                  ; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
 
.dseg 
.org 0x200 
; Put variables and data arrays here... 
 OVERFLOW_INTERRUPT_COUNTER: .byte 1
 OVERFLOW_INCREMENT: .byte 1
 PAUSE_STATE: .byte 1