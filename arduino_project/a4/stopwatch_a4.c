/*
	Author: Marc-Andre Descoteaux
	Student: V00847029
	Project: CSC230 Assignment 4 - Stopwatch in C on ATmega2560
	Date: 15/07/2017
*/

#include "CSC230.h"
//#include "CSC230_LCD.c"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#define ADC_BTN_RIGHT 0x032
#define ADC_BTN_UP 0x0C3
#define ADC_BTN_DOWN 0x17C
#define ADC_BTN_LEFT 0x22B
#define ADC_BTN_SELECT 0x316
#define OVERFLOW_PRESCALE_COUNT 61

unsigned int maximum_values[] = {9, 9, 5, 9, 9};
int ignore_button = 0;
int pause_state = 0;
unsigned int overflow_interrupt_counter = 0;
unsigned int time_keeper[] = {0, 0, 0, 0, 0};
char disp_time[100] = "00:00.0";
char current_lap_start[100] = "00:00.0";


/* void lap_reset(int reset_state, char* current_lap_start)
This function sets current_lap_start to "00:00.0" and the second row of the LCD screen to " ".
It is called from the reset() function (from initiliaze() or when LEFT is pressed) and when the DOWN button is pressed.
When called from initiliaze() and a DOWN press, reset_state is 0 so that it runs through completely. When called from a
LEFT press, only current_lap_start is set. 
*/
void lap_reset(int reset_state){
	
	
	strncpy(current_lap_start, "00:00.0" , 7);

	if(reset_state){
		return;
	}
	
	lcd_xy(0,1);
	lcd_blank(16);

}
/* void reset(int reset_state)
This function sets time_keeper to all 0's, disp_time to "00:00.0" and displays it to the LCD then calls lap_reset().
The argument reset_state is for lap_reset(). disp_time and current_lap_start are char arrays modified throughout the function.
*/
void reset(int reset_state){
	int j;
	for( j = 0; j <5; j++ ){
		time_keeper[j] = 0;
	}

	strncpy(disp_time, "00:00.0" , 7);

	lcd_xy(6,0);
	lcd_puts(disp_time);
	
	lap_reset(reset_state);
	
}
/* void init_timer()
This function initializes Timer0 for overflow interrupts with a prescaler value of 1024.
*/
void init_timer(){
	
	TIMSK0 = 0x01;
	TCNT0 = 0x00;
	TCCR0A = 0x00;
	TCCR0B = 0x05;

}

/* void initialize()
This function sets the LED pins to output direction, initializes the ADC and LCD, 
displays "TIME: " to the LCD, and calls reset() and init_timer(). It is called from main().
*/
void initialize(){

	DDRB = 0xff;
	DDRL = 0xff;
	
	ADCSRA = 0x87;
	ADMUX = 0x40;	

	lcd_init();

	char disp_string[] = "TIME: ";

	lcd_xy(0,0);
	lcd_puts(disp_string);

	reset(0);
	
	init_timer();
	
}

/* void keep_time(char* disp_time)
This function transforms the ints in the array time_keeper into chars for disp_time. 
disp_time is then displayed on the LCD. It is continuously called from main().
*/
void keep_time(char disp_time[]){
	
	sprintf(disp_time, "%d%d:%d%d.%d", time_keeper[0],time_keeper[1],time_keeper[2],time_keeper[3],time_keeper[4]);

	lcd_xy(6,0);
	lcd_puts(disp_time);

	
}
/* void clear_leds()
This function sets all LED's (PORTB and PORTL) to 0. It is called from button_poll().
*/
void clear_leds(){
	
	PORTB = 0;
	PORTL = 0;

}
/* unsigned short button_poll()
This function polls the ADC with a busy-wait. Depending on the reading, it returns a short [0, 5] 
to determine which button was read as pressed. If a button was pressed, the ignore_button flag is set.
If it is set, then it will skip checking which button is pressed and return. If no button was pressed, 
the ignore_button flag is cleared, the LED's are cleared (calls clear_leds()) and returns 0. An LED is set 
depending on the button pressed. It is continuously called from main().
*/
unsigned short button_poll(){

	unsigned int threshold = 0x0317;
	ADCSRA = ADCSRA | 0x40;

	while((ADCSRA & 0x40) == 0x40);

	if(ADC > threshold){
		ignore_button = 0;
		clear_leds();
		PORTB = 0x02;
		return 0;
	}
	if(ignore_button){
		PORTB = 0x08;
		return ignore_button;
	}

	ignore_button = 1;

	if(ADC < ADC_BTN_RIGHT){
		PORTB = 0x08;
		return 1;
	}
	

	if(ADC < ADC_BTN_UP){
		PORTL = 0x08;
		return 2;
	}

	if(ADC < ADC_BTN_DOWN){
		PORTL = 0x02;
		return 3;
	}

	if(ADC < ADC_BTN_LEFT){
		PORTL = 0x20;
		return 4;
	}

	if(ADC <= ADC_BTN_SELECT){
		PORTL = 0x80;
		return 5;
	}
		
	return 0;
}

/* void set_lap()
This function uses char arrays current_lap_start, last_lap_start, last_lap_end and disp_time. 
With strncpy(), current_lap_start is copied into last_lap_start, then disp_time is copied into last_lap_end 
and current_lap_start. last_lap_start and last_lap_end are displayed to the LCD. It is called when the UP button is pressed. 
*/
void set_lap(){

	char last_lap_start[100];
	char last_lap_end[100];

	strncpy(last_lap_start, current_lap_start, 7);
	strncpy(last_lap_end, disp_time, 7);
	strncpy(current_lap_start, disp_time, 7);	
	
	lcd_xy(0,1);
	lcd_puts(last_lap_start);
	lcd_xy(9,1);
	lcd_puts(last_lap_end);
	
	
}
/*
void pause()
This function flips the pause_state. It is called when the SELECT button is pressed.
*/
void pause(){

	pause_state = ~pause_state;

}
/* void clear_timer(char* disp_time)
This function calls reset() and clears the pause_state. It is called when the LEFT button is pressed.
*/
void clear_timer(char disp_time[]){

	reset(1, disp_time);
	pause_state = 0;

}
/* void set_time()
This function is called from the ISR. If the pause_state is set, 
The values in time_keeper[] are incremented when compared to maximum_values[].
*/
void set_time(){

	int i;
	if(pause_state){

		time_keeper[4] += 1;

		for (i = 4; i >= 0; i--){
			if (time_keeper[i] > maximum_values[i]){
					time_keeper[i] = 0;
					if( i != 0)
						time_keeper[i-1] += 1;
				
			}
		}
		if (time_keeper[0] > maximum_values[0])
			time_keeper[4] += 1;
		
	}
}

/* 
This is the ISR. It is when TIMER0 overflows. 
There are 61 interrupts person second from the 1024 prescaler.  
Every tenth of a second, set_time() is called. 
*/
ISR(TIMER0_OVF_vect){

	overflow_interrupt_counter += 10;

	if( overflow_interrupt_counter >= OVERFLOW_PRESCALE_COUNT ){
		
		set_time();

		overflow_interrupt_counter -= OVERFLOW_PRESCALE_COUNT;
		
	}
}

int main(){

	unsigned short i;

	initialize();
	sei();

	
	
	while(1){

		keep_time();
		i = button_poll();
		switch(i){
			case 0:
				break;
			case 1:
				break;
			case 2:
				set_lap(last_lap_start, last_lap_end);
				break;
			case 3:
				lap_reset(0);
				break;
			case 4:
				clear_timer();
				break;
			case 5:
				pause();
				break;
			default:
				break;
		}		
	
	}

	return 0;

}
