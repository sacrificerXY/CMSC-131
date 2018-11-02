; clear screen
mov ax, 3
int 10h

call print_newline
push offset msg_intro		
call print_string			; print intro

call print_newline
call print_newline

push offset msg_length
call print_string			; ask for length
push offset input_length
call get_aligned_input		; get length input
call print_newline

push offset msg_width
call print_string			; ask for width
push offset input_width
call get_aligned_input		; get width input
call print_newline

; calculate perimeter
push offset input_length, offset input_width, offset output_peri	
call add_ascii_decimal
; at this point, output_peri = length + width
; so add it to itself to get perimeter
push offset output_peri, offset output_peri, offset output_peri
call add_ascii_decimal

; calculate area
push offset input_length, offset input_width, offset output_area
call mul_ascii_decimal

; display area
call print_newline
push offset msg_area
call print_string
push offset output_area
call print_ascii_decimal

; display perimeter
call print_newline
push offset msg_peri
call print_string
push offset output_peri
call print_ascii_decimal

call print_newline
call print_newline

int 20h	; END ---------------------------------------------------------------------

; Variables -------------------------
msg_intro  db '  This program calculates the area & perimeter of a rectangle.', 0ah,  '  - Requires 2 non-negative integer inputs.', 0ah, '  - Input can contain up to 16 digits.', 0ah, '$'
msg_length db '    Enter length : $'
msg_width  db '    Enter width  : $'
msg_area   db '            Area = $'
msg_peri   db '       Perimeter = $'

input_length db 32 dup '0', '$'
input_width  db 32 dup '0', '$'
output_peri  db 32 dup '0', '$'
output_area  db 32 dup '0', '$'


; Procedures ------------------------

; PROC mul_ascii_decimal
;
; Takes 3 parameters:
;	1. input1 address
;	2. input2 address
;	3. output buffer location
;
; Multiplies 2 decimal ascii strings from right to left 
; and stores the result to output buffer location
mul_ascii_decimal proc near
	enter 1, 0	; reserve 1 local variable for carry
	push si, di, ax, bx, cx, dx
	
	; di - used to index output buffer
	; bx - used to index input2
	; dx - used to index input1

	mov ax, [p_align_index]
	
	; set bx as index pointing to last char of input2
	mov bx, [bp+6]
	add bx, ax
	dec bx
	
	; set di to point to last char of output buffer
	mov di, [bp+4]
	add di, ax
	dec di
	
	; set counter
	mov cx, [p_max_input]
	l1:
		; set dx as index pointing to last char of input1
		mov ax, [p_align_index]
		mov dx, [bp+8]
		add dx, ax
		dec dx
		
		mov b[bp-2], 0	; set our reserved carry variable
	
		push cx
		mov cx, [p_max_input]
		l2:
			push cx	; save cx, freeing it for other uses
			
			sub ax, ax
			sub cx, cx
			
			; mov currChar of input2 to al
			mov si, bx
			mov al, [si]
			and al, 0fh
			
			; mov currChar of input1 to cl
			mov si, dx
			mov cl, [si]
			and cl, 0fh
			
			; ax = al * cl
			mul cl
			aam
			
			; add carry
			add al, b[bp-2]
			aaa
			
			; add currChar of output to al
			add al, [di]
			aaa
			mov b[bp-2], ah	; save carry to variable
			
			or al, 30h		; convert al to ASCII
			mov [di], al	; move al to output
			
			; prepare for next iteration 
			; which is (output.currChar-1 = input1.currChar * input2.currChar-1)
			dec dx
			dec di
			pop cx
		loop l2
		
		; add extra carry to output
		sub cx, cx
		mov cl, b[bp-2]
		add b[di], cl
		
		; prepare for next iteration 
		; which is (output.currChar+input_length-1 = input1.currChar-1 * input2.lastChar)
		add di, [p_max_input]
		dec di, bx
		pop cx
		; dx (for input2) is set at the top of the loop
	loop l1
	
	; at this point, the leftmost char of the output buffer
	; is not in ascii, so convert
	or b[di], 30h
	
	pop dx, cx, bx, ax, di, si
	leave
	ret 6
mul_ascii_decimal endp

; PROC add_ascii_decimal
;
; Takes 3 parameters:
;	1. input1 address
;	2. input2 address
;	3. output buffer location
;
; Adds 2 decimal ascii strings from right to left and 
; stores the result to output buffer location
add_ascii_decimal proc near
	enter
	push si, di, ax, bx, cx, dx
	
	; set dl as index to last char
	mov dx, [p_align_index]	
	dec dx

	sub bx, bx	; use bh as carry
	
	mov cx, [p_align_index]
	
	l1:
		sub ax, ax
		
		; mov char from input1 to al
		mov si, dx
		add si, [bp+8]
		mov al, [si]
		
		; add char from input2 to al
		mov si, dx
		add si, [bp+6]
		add al, [si]
		aaa
		
		add al, bh		; add carry to al
		aaa
		
		or al, 30h 		; convert al to ascii
		
		; move al to output buffer
		mov si, dx
		add si, [bp+4]
		mov [si], al
		
		mov bh, ah	; move carry to bh
		
		dec dl	; move to next char to the left
	loop l1
	
	pop dx, cx, bx, ax, di, si
	leave
	ret 6
add_ascii_decimal endp

; PROC get_aligned_input
;
; takes 1 param: output buffer location
; 
; Reads a string input from console and aligns its contents to the alignment index
; This means all inputs generated rom this procedure will have the same alignment
get_aligned_input proc near
	enter
	
	push ax, bx
	
	lea dx, p_align_buffer
	mov ah, 10
	int 21h
	
	sub ax, ax
	mov al, [p_align_buffer+1]
	push offset p_align_buffer+2, ax
	call align_ascii_decimal
	
	mov bx, [bp+4]
	push bx, offset p_align_buffer+2
	call copy_string
	
	pop bx, ax
	leave
	ret 2
get_aligned_input endp

; PROC align_ascii_decimal
;
; takes 2 parameters
;	1. address of string
;	2. length of string
; 
; takes an ascii decimal and moves its contents #(alignment index - length of string) spaces to the right
; the spaces to the left of the first number after moving is filled with '0'
;	
;	Given: "1234", length=4, alignment=10 (therefore, moves contents by 10-4=6 steps)
;	After: "0000001234" - the last char '4' is now at index 9=alignment-1
;
; NOTE: Assumes that the string has usable enough space to the right
; Useful for aligning 2 decimal ASCII strings
; 	Instead of:
;		"1234"
;	  + "123456789"
;	We can shift them such that it becomes:
;		"0000001234"
;	  + "0123456789"	// the extra zero is for potential carry
align_ascii_decimal proc near
	enter
	push si, di, bx, cx, dx
	
	; setup reading of char from last to first
	
	mov si, [p_align_index]	; si = alignment index
	sub si, 1				; si = alignment index-1
	
	mov bx, [p_align_index]	; bl = alignment index
	sub bl, [bp+4]			; bl = alignment index - string length (# of spaces to move to align)
	
	mov cx, [p_align_index]	; loop = alignment index (loop from index down to 0) 
	l1:
		mov di, si			; copy di to si
		add di, [bp+6]		; di += address of string (now actually points to char at index di)
		
		cmp si, bx
		jl >l2
		; if (currIndex >= # of spaces to move)
			sub di, bx			; di -= # of spaces to move (points to char to copy)
			mov dl, b[ds:di]	; store char to copy
			add di, bx			; di += # of spaces to move (points to where to move the char)
			mov b[ds:di], dl	; paste the char
			jmp >l3
		; endif
		l2:
		; if (currIndex < # of spaces to move)	
			mov b[ds:di], '0'	; paste a zero
		; endif
		l3:
			
		dec si	; move to next char (to the left)
	loop l1
	
	pop dx, cx, bx, di, si
	leave
	ret 4
align_ascii_decimal endp

; PROC print_ascii_decimal
;
;	Takes 1 parameter: address of string
;
;	Prints the decimal string starting from the first non-zero digit from the left
print_ascii_decimal proc near
	enter
	push si, cx, dx
	
	mov si, [bp+4]		; si points to address of string (at first char)
	
	mov cx, [p_align_index]		; loop (length down to 0)
	l1: 
		cmp b[si], '0'
		jz >l2
		; if (currChar != '0')
			jmp >l3		; break loop
		; endif
		l2:
		; if (currChar = '0')
			inc si	; just move to next char to the right
		; endif
	loop l1
	; if this code is reached, si will be pointing to [address+length]
	;	which is 1 byte to the right of last char
	;	so move left once to point to last char
	dec si	
	l3:

	; ouput starting from first non-zero digit (at si location)
	mov dx, si
	mov ah, 9
	int 21h

	pop dx, cx, si
	leave
	ret 2
print_ascii_decimal endp

; PROC copy_string
;
; Takes 2 params:
;	1. destination string location
;	2. source string location
;
; Assumes that:
;	1. Both strings have equal length
;	2. Both strings ends with a '$'
;
; Copies the source to the destination byte-by-byte from left to right
copy_string proc near
	enter
	push si, di, ax
	
	mov si, [bp+4] ; src pointer
	mov di, [bp+6] ; dst pointer
	
	l1:
		mov [di], al, [si]	; al = [si] then [di] = al
		inc si, di
		cmp al, '$'
		jne l1
	
	pop ax, di, si
	leave
	ret 4
copy_string endp

; take 1 param: address of string. Then prints it
print_string proc near
	enter
	mov dx, [bp+4]
	mov ah, 9
	int 21h
	leave
	ret 2
print_string endp

; no params. Just prints a newline
print_newline proc near
	enter
	mov dl, 0ah
	mov ah, 2
	int 21h
	leave
	ret
print_newline endp

; The variables below are used by:
;	1. add_ascii_decimal	- adds 2 ascii decimals and stores the result in an output buffer
;	2. mul_ascii_decimal	- multiplies 2 ascii decimals and stores the result in an output buffer
;	3. get_aligned_input	- get the user input and aligns it such that the input can be used or add/mul
;	4. align_ascii_decimal	- aligns the an ascii decimal regardless off its length
;	5. print_ascii_decimal	- prints only the significant digits of an ascii decimal (no leading zeroes)
;
; All of them take a string buffer of this format:
;
;	<var_name> db <p_align_index> dup '0', '$'
;
; These variables should always follow the following restrictions
;	1. p_align_index >= 2 * p_max_input
;	2. p_align_index and p_max_input should be words (use DW, not DB)
;	3. p_align_buffer is defined as:
;
;		 p_align_buffer db <p_max_input+1>, 0, <p_align_index+1> dup '$'
;
;	4. These variables SHOULD NEVER be changed during program execution
;
; As long as all of these things are followed, everything should work seamlessly

; how many characters are allowed for input
p_max_input dw 16		

; how many digits each number should represented in, aligned to the right
p_align_index dw 32		
; An alignment index of 5 means all numbers are represented as 5 digits. So:
;	"123" 	becomes "00123"
;	"1" 	becomes "00001"
;	"30" 	becomes "00030"
;   "12345" becomes "12345"
; This makes them easier to add/mul

; used by get_aligned_input to temporarily store the non-aligned version of the input
p_align_buffer db 17, 0, 33 dup '$' 
