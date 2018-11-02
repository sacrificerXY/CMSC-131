; clear screen
mov ax, 3
int 10h

; print intro
call print_newline
push offset msg_intro
call print_string
call print_newline

call print_newline

; get oct input
push offset msg_oct
call print_string
push offset input_oct
call get_aligned_input
call print_newline

; convert oct to bin
push offset input_oct, offset binary_buffer
call convert_ascii_oct_to_bin

; convert bin to hex
push offset binary_buffer, offset output_hex
call convert_bin_to_ascii_hex

; print output hex
push offset msg_hex
call print_string
push offset output_hex
call print_ascii_number

call print_newline
call print_newline

int 20h	; END ---------------------------------------------------------------------



; Variables -------------------------
msg_intro 	db '  This program converts an octal number to hex.', 0ah,  '  - Requires a valid non-negative octal number (digits 0-7 only).', 0ah, '  - Input can contain up to 16 digits.', 0ah, '$'
msg_oct 	db '    Enter octal number : $'
msg_hex 	db '    Your number in hex = $'

input_oct 	db 48 dup '0', '$'
output_hex 	db 48 dup '0', '$'

; stores the non-ascii binary form of the input. NOTE: filled with actual value 0 (not '0')
binary_buffer	db 48 dup  0,  '$'

; Procedures ------------------------

; PROC convert_bin_to_ascii_hex
;
; Takes 3 parameters:
;	1. binary buffer address
;	2. output buffer address
;
; Converts a non-ascii binary to its ascii hex form
convert_bin_to_ascii_hex proc near
	enter
	push si, di, ax, bx, cx, dx
	
	; point dx to end of binary buffer
	mov dx, [bp+6]
	add dx, [p_align_index]
	dec dx
	
	; point di to end of output buffer
	mov di, [bp+4]
	add di, [p_align_index]
	dec di
	
	mov cx, [p_align_index]
	l1:
		; mov char to al
		sub ax, ax
		mov si, dx
		mov al, [si]
		
		; separate al nibbles into ah and al
		aam 16
		
		sub bx, bx
		mov bl, ah
		mov ah, 0
		; at this point, bx = al high nibble  ax = al low nibble
		; ax and bx now represents just 1 hex digit each (al represented 2 before)
		
		lea si, p_hex_char_array	; point si to p_hex_char_array
		add si, ax				; si now points to hex ascii representation of ax
		mov [di], al, [si]		; mov [si] to [di]
		
		dec di					; move to next char of output
		
		lea si, p_hex_char_array	; point si to p_hex_char_array
		add si, bx				; si now points to hex ascii representation of bx
		mov [di], al, [si]		; mov [si] to [di]
	
		dec di, dx
	loop l1
	
	pop dx, cx, bx, ax, di, si
	leave
	ret 4

convert_bin_to_ascii_hex endp

; PROC convert_ascii_oct_to_bin
;
; Takes 3 parameters:
;	1. octal string address
;	2. output buffer address ( stores the binary ) - must be zero filled (actual value 0)
;
; Converts an ascii octal number to its binary form (non-ascii)
convert_ascii_oct_to_bin proc near
	enter
	push si, di, ax, cx
	
	sub ax, ax
	
	; point si to beginning of octal
	mov si, [bp+6]
	
	; point di to end of buffer
	mov di, [bp+4]
	add di, [p_align_index]
	dec di
	
	mov cx, [p_align_index]
	l1:
		; shift buffer 3 bits to the left (each oct = 3 bits)
		; in preparation for this next octal number
		;   NOTE: does nothing on the first iteration
		push [bp+4], 3
		call string_bitshift_left
	
		mov al, [si]	; get curr char
		and al, 0fh		; convert it to non-ascii octal
		or [di], al		; or non-ascii octal to the buffer
		
		inc si
	loop l1
	
	pop cx, ax, di, si
	leave
	ret 4
convert_ascii_oct_to_bin endp

; PROC string_bitshift_left
;
; Takes 3 parameters:
;	1. string address
;	2. how many bits to shift
;
; Shifts the bits of a string to left (like SHL, but for string)
string_bitshift_left proc near
	enter
	push si, ax, cx
	
	sub cx, cx
	mov cl, [bp+4]	; how many bits to shift
	l1:
		sub ax, ax	; al is used for carry
	
		; point si to last char
		mov si, [bp+6]
		add si, [p_align_index]
		dec si
		
		push cx
		mov cx, [p_align_index] ; loop through whole string
		l2:
			shl b[si], 1
			
			jnc >l3
			; if (leftmost bit was a 1)
				push 1	; carry 1
				jmp >l4
			l3:
			; if (leftmost bit was a 0)
				push 0	; carry 0
			l4:
			
			add [si], al	; add old carry
			pop ax			; save new carry (from stack)
			dec si
		loop l2
		pop cx
	loop l1
	
	pop cx, ax, si
	leave
	ret 4
string_bitshift_left endp

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
	call align_ascii_number
	
	mov bx, [bp+4]
	push bx, offset p_align_buffer+2
	call copy_string
	
	pop bx, ax
	leave
	ret 2
get_aligned_input endp

; PROC align_ascii_number
;
; takes 2 parameters
;	1. address of string
;	2. length of string
; 
; takes an ascii number and moves its contents #(alignment index - length of string) spaces to the right
; the spaces to the left of the first number after moving is filled with '0'
;	
;	Given: "1234", length=4, alignment=10 (therefore, moves contents by 10-4=6 steps)
;	After: "0000001234" - the last char '4' is now at index 9=alignment-1
;
; NOTE: Assumes that the string has enough usable space to the right
; Useful for aligning 2 ASCII number strings
; 	Instead of:
;		"1234"
;	  + "123456789"
;	We can shift them such that it becomes:
;		"0000001234"
;	  + "0123456789"	// the extra zero is for potential carry
align_ascii_number proc near
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
align_ascii_number endp

; PROC print_ascii_number
;
;	Takes 1 parameter: address of string
;
;	Prints the ascii number string starting from the first non-zero digit from the left
print_ascii_number proc near
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
print_ascii_number endp

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
;	1. convert_ascii_oct_to_bin	- convert ascii octal to NON-ascii binary
;	1. convert_bin_to_ascii_hex - convert NON-ascii binary to ascii hex
;	1. string_bitshift_left		- bitshift whole string to the left
;	3. get_aligned_input	- get the user input and aligns it such that the input can be used or add/mul
;	4. align_ascii_number	- aligns the an ascii decimal regardless off its length
;	5. print_ascii_number	- prints only the significant digits of an ascii decimal (no leading zeroes)
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
;	4. p_hex_char_array is defined as:
;
;		 p_hex_char_array  db '0123456789ABCDEF$'
;
;	5. These variables SHOULD NEVER be changed during program execution
;
; As long as all of these things are followed, everything should work seamlessly

; how many characters are allowed for input
p_max_input dw 16	

; how many digits each number should represented in, aligned to the right	
p_align_index dw 48		
; An alignment index of 5 means all numbers are represented as 5 digits. So:
;	"123" 	becomes "00123"
;	"1" 	becomes "00001"
;	"30" 	becomes "00030"
;   "12345" becomes "12345"
; This makes them easier to add/mul

; used by get_aligned_input to temporarily store the non-aligned version of the input
p_align_buffer db 17, 0, 49 dup '$' 

; gives the hex char representation of an index (0-15 maps to 0-F)
p_hex_char_array  db '0123456789ABCDEF$' 
