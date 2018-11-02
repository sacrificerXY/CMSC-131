; clear screen
mov ax, 3
int 10h

call print_newline

; print intro
push offset msg_intro
call print_string

call print_newline
call print_newline

; get input
push offset msg_input
call print_string
lea dx, input
mov ah, 10
int 21h

; sanitize the input
push offset input+2, offset buffer_sanitized
call remove_non_alphanumeric
; IMPORTANT: After this call, the size of input might have changed
;	so its length stored in [input+1] is no longer valid
;	To loop through, we need to check for '$' instead of using cx
push offset buffer_sanitized
call to_lowercase		; lowercase

; print sanitized version
call print_newline
call print_newline
push offset msg_sanitized
call print_string
push offset buffer_sanitized
call print_string
call print_newline

; print reversed version
push offset msg_reversed
call print_string
push offset buffer_sanitized
call print_string_reversed

; first, push all characters of the string to the stack, from left to right
; point si to first char
lea si, buffer_sanitized

l1:
	sub ax, ax
	mov al, [si]
	push ax
	inc si
	cmp b[si], '$'
	jne l1
	
; second, popping from the stack will give the reversed order of the string
; so just compare each popped character with the orig string from left to right

; point si to first char
lea si, buffer_sanitized

l1:
	pop ax		 ; get char mirrored by [si]
	cmp [si], al
	jne no_palin ; if not equal, not palindrome. Break the loop immediately
	
	inc si
	cmp b[si], '$'
	jne l1

; reaching this point means the string is a palindrome
	
yes_palin:
	call print_newline
	call print_newline
	push offset msg_yes
	call print_string
	jmp program_end

no_palin:
	call print_newline
	call print_newline
	push offset msg_no
	call print_string

program_end:
call print_newline
call print_newline
int 20h	; END --------------------------------------------------------


; Variables -----------------------------
msg_intro 		db '  This program checks if a string is a palindrome.', 0ah, '  - Characters besides letters and numbers are ignored.', 0ah, '  - Lowercase and uppercase letters are considered equal.', 0ah, '  - Input can contain up to 50 characters.', 0ah, '$'
msg_input		db '         Enter string : $'
msg_sanitized	db '        Clean version : $'
msg_reversed	db '             Reversed : $'
msg_yes 		db '               Output = YES, the string is a palindrome.$'
msg_no 			db '               Output = NO, the string is NOT a palindrome.$'

buffer_sanitized db 50 dup 0, '$'

input db 51, 0, 52 dup '$'

; Procedures ---------------------------

; takes 3 parameters - value, min_range, max_range (pushed in that order)
; if min_range <= value <= max_range then bl=1
; else bl = 0
is_within_range proc near
	enter
	push dx
	mov dh, b[bp+8]	; dh = value
	
	cmp dh, b[bp+6]			; if (value < min_range)
	jl is_within_range_no	; 	not in range
	
	cmp dh, b[bp+4]			; if (value > max_range)
	jg is_within_range_no	; 	not in range
	
	
	is_within_range_yes:
	; if (withinRange)
		mov bl, 1
		jmp is_within_range_end
	; endif
	is_within_range_no:
	; if (notInRange)
		mov bl, 0
	; endif
	is_within_range_end:
	pop dx
	leave
	ret 6
is_within_range endp

; PROC remove_non_alphanumeric
;
; Takes 1 parameter:
;	1. Address of string
;	2. Output buffer
;
; Returns a string with all non-letter and non-number characters in the input string removed.
; If the resultant is smaller, all extra space are filled with '$'
remove_non_alphanumeric proc near
	enter
	
	push si, di, ax, bx
	
	mov si, [bp+6]	; si points to input
	mov di, [bp+4]	; di points to output
	l1:
		sub ax, ax
		sub bx, bx
		; check if [si] = '$'
		cmp b[si], '$'
		je >l2	; if [si] is '$', jump to copy
		
		push w[si], 'a', 'z'
		call is_within_range
		or al, bl
		
		push w[si], 'A', 'Z'
		call is_within_range
		or al, bl
		
		push w[si], '0', '9'
		call is_within_range
		or al, bl
		
		; al = 0 means it is not alphanumeric
		
		cmp al, 0
		jne >l2
		; if (not alphanumeric)
			; move si to next char, go back to top of loop
			inc si
			jmp l1
		l2:
		; execution reaches here if [si] is alphanumeri or '$'
		
		; copy [si] to [di]
		mov [di], al, [si]
		
		cmp b[si], '$'
		je >l3	; dont increment si if it already reached '$'
			inc si
		l3:
		
		inc di
		cmp b[di], '$'
		jne l1
	
	pop bx, ax, di, si
	leave
	ret 4
remove_non_alphanumeric endp

; Takes 1 parameter: Address of string
; Converts any uppercase letter in the string to lowercase
to_lowercase proc near
	enter
	push si, bx
	
	sub bx, bx
	
	mov si, [bp+4]
	l1:
		push w[si], 'A', 'Z'
		call is_within_range
		
		cmp bl, 1
		jne >l2
		; if (char is uppercase)
			; convert to lowercase
			add b[si], 20h
		l2:
		inc si
		cmp b[si], '$'
		jne l1
	
	leave
	ret 2 
to_lowercase endp

; take 1 param: address of string (use OFFSET operator when passing)
print_string proc near
	enter
	push ax, dx
	mov dx, [bp+4]
	mov ah, 9
	int 21h
	pop dx, ax
	leave
	ret 2
print_string endp

; take 1 param: address of string (use OFFSET operator when passing)
; prints the reverse of the string
print_string_reversed proc near
	enter
	push si, cx
	
	mov si, [bp+4] ; si points to first char
	mov cx, 0	   ; cx will count the length of string
	l1:
		inc cx
		inc si
		cmp b[si], '$'
		jne l1
	
	; at this point, si is pointing at '$'
	; so move back
	dec si
	
	; cx = length of string
	l1:
		push w[si]
		call print_char
		dec si
	loop l1
	
	pop cx, si
	leave
	ret 2
print_string_reversed endp

; no params. Just prints a newline
print_newline proc near
	enter
	push ax
	push 0ah
	call print_char
	pop ax
	leave
	ret
print_newline endp

; take 1 param: a byte representing an ASCII character
print_char proc near
	enter
	push ax, dx
	mov dl, [bp+4]
	mov ah, 2
	int 21h
	pop dx, ax
	leave
	ret 2
print_char endp
