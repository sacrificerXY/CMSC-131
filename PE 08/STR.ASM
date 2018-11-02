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

; convert to lowercase
push offset input+2
call to_lowercase

; print output
call print_newline
push offset msg_output
call print_string
push offset input+2
call print_string

call print_newline
call print_newline
int 20h ; END --------------------------------------------------------


; Variables -----------------------------
msg_intro       db '  This program takes a string, and converts', 0ah,  '  all its uppercase letters to lowercase.', 0ah, '  - Input can contain up to 50 characters.', 0ah, '$'
msg_input       db '      Enter string : $'
msg_output      db '            Output = $'

input db 51, 0, 52 dup '$'

; Procedures ---------------------------

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

; takes 3 parameters - value, min_range, max_range (pushed in that order)
; if min_range <= value <= max_range then bl=1
; else bl = 0
is_within_range proc near
    enter
    push dx
    mov dh, b[bp+8] ; dh = value
    
    cmp dh, b[bp+6]         ; if (value < min_range)
    jl is_within_range_no   ;   not in range
    
    cmp dh, b[bp+4]         ; if (value > max_range)
    jg is_within_range_no   ;   not in range
    
    
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

; no params. Just prints a newline
print_newline proc near
    enter
    push ax, dx
    mov dl, 0ah
    mov ah, 2
    int 21h
    pop dx, ax
    leave
    ret
print_newline endp
