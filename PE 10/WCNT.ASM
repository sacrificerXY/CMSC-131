; clear screen
mov ax, 3
int 10h

push offset msg_getInput
call print_string

; get input
lea dx, input
mov ah, 10
int 21h
call print_newline

; setup loop
lea si, input+2
sub cx, cx
mov cl, b[ds:input+1]

loopMain:
	; Number is not considered punctuation
	; if char is number, pretend it doesn't exits
	; 		just skip
	push w[si], '0', '9'
	call is_within_range
	cmp bl, 0
	jnz l_end
	
	; use dl as accumulator flag
	; dl = is_small_letter | is_big_letter
	mov dl, 0
	
	; check if small letter
	push w[si], 'a', 'z'
	call is_within_range
	or dl, bl
	
	; check if big letter
	push w[si], 'A', 'Z'
	call is_within_range
	or dl, bl
	
	; test dl
	cmp dl, 0
	jz l_notALetter
	; if (isLetter)
		cmp b[flag_word], 0 ; check if we are currently reading a word
		jnz l_print_char
		; if (isLetter and notReadingAWord)
			push offset msg_wordPrefix
			call print_string
			mov b[flag_word], 1 ; we are now reading a word
		; endif
		
		l_print_char:
		push w[si]
		call print_char
		jmp l_end
	; endif
		
	l_notALetter:
	; if (isNotLetter)
		cmp b[flag_word], 0
		jz l_end
		; if (isNotLetter and flag = 1) if we were reading a word but encountered a non-letter char
			call print_newline
			inc b[word_count]	; words += 1
			mov b[flag_word], 0 ; whenever a non-letter is found, set flag to zero
			jmp l_end
		;endif
	;endif
	l_end:

	inc si
loop loopMain

; the above loop does not count the last word if its
;	last letter is the last input char
; so check for that specific case
cmp b[flag_word], 0
jz l_end2
; if (readingAWord) 
	inc b[word_count]
; endif
l_end2:

call print_newline

push offset msg_numWords
call print_string

; convert count to ASCII
sub ax, ax
sub bx, bx

mov al, b[word_count]	; al = word count
aam						; ah = 10s digit of word count, al = 1s digit of word count
or ax, 3030h			; convert them to ascii
mov bl, ah				; bh = al
sub ah, ah				; now, bx represents 10s digit and ax represents 1s digit

cmp bx, '0'
je l_skip_10s
; if (10s digit is NOT zero)
	; print 10s digit
	push bx
	call print_char
; endif
l_skip_10s:

; print 1s
push ax
call print_char

call print_newline
	

int 20h
; end ------------------------------


; ------------- FUNCTIONS -------------

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

; no params. Just prints a newline
print_newline proc near
	enter
	push 0ah
	call print_char
	leave
	ret
print_newline endp


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

; --------- VARIABLES ------------
msg_getInput db 0ah, '  Enter string: $'
msg_numWords db '  Word count: $'
msg_wordPrefix db '    - $'
input db 41, 255 dup '$'
flag_word db 0
word_count db 0
