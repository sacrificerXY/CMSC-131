
                jmp     .main    
                
; ***********************************************************
            
.variables:     msg_intro           db '  This program checks if a string is a palindrome.', 0ah, '  - Characters besides letters and numbers are ignored.', 0ah, '  - Lowercase and uppercase letters are considered equal.', 0ah, '  - Input can contain up to 50 characters.', 0ah, '$'
                msg_input           db '         Enter string : $'
                msg_sanitized       db '        Clean version : $'
                msg_reversed        db '             Reversed : $'
                msg_yes             db '               Output = YES, the string is a palindrome.$'
                msg_no              db '               Output = NO, the string is NOT a palindrome.$'
                buffer_sanitized    db 50 dup 0, '$'
                input               db 51, 0, 52 dup '$'
            
; ***********************************************************
 
.main:          mov     ax, 3
                int     10h                             ; clear screen

                call    print_newline
                
                push    OFFSET msg_intro
                call    print_string                    ; print intro
                
                call    print_newline
                call    print_newline

;       Ask the user for input

                push    OFFSET msg_input
                call    print_string
            
                lea     dx, input
                mov     ah, 10
                int     21h

;       Now, we sanitize the input by:
;         1. Removing non-alphanumeric characters
;         2. Converting all UPPERCASE letters to lowercase
;       This makes the job of determining if it's a palindrome easier

                push    OFFSET input+2
                push    OFFSET buffer_sanitized
                call    remove_non_alphanumeric         ; Step #1     
            
;       IMPORTANT: After the above call, the size of input might 
;         have changed so its length stored in [input+1] is no longer valid.
;         To loop through, we need to check for '$' instead of using cx

                push    OFFSET buffer_sanitized
                call    to_lowercase                    ; Step #2

;       Print sanitized version

                call    print_newline
                call    print_newline
            
                push    OFFSET msg_sanitized
                call    print_string
            
                push    OFFSET buffer_sanitized
                call    print_string
            
                call    print_newline

;        Print reversed version of the sanitized

                push    OFFSET msg_reversed
                call    print_string
            
                push    OFFSET buffer_sanitized
                call    print_string_reversed
                
                call    print_newline
                call    print_newline

;       To check if our input is a palindrome (using the sanitized version)
;         1. Push all characters into the stack, one by one, from left to right.
;              This means that popping from the stack will give back the characters
;              in reverse order.
;         2. Pop each character from the stack, comparing each with the characters
;              from the original sanitized string. (Starting from left, to right)
;
;      If there is a pairing of characters from the stack and the string which are not
;        the same, then the string is NOT a palindrome.
;      If all comparisons are done with all characters being equal, then the string
;        is a palindrome.

;       Step #1 Loop

                lea     si, buffer_sanitized            ; si points to 1st char of string
stackPush:      sub     ax, ax                          ; clear ax
                mov     al, [si]                        ; al = current character
                push    ax                              ; push current character to stack
                inc     si                              ; move to next char
                cmp     b[si], '$'                      ; check if we reached end of string
                jne     stackPush                       ; if not, loop back
    
;       Step #2 Loop

                lea     si, buffer_sanitized            ; si points to 1st char of string
compareChars:   pop     ax                              ; get the character mirrored by current char
                cmp     [si], al                        ; check if they are equal
                jne     noPalin                         ; if not equal, not palindrome. Break the loop immediately
                inc     si                              ; else, continue to next char
                cmp     b[si], '$'                      ; check if we reach end of string
                jne     compareChars                    ; if not, loop back

;       Output if palindrome
    
yesPalin:       push    offset msg_yes
                call    print_string
                
                jmp     endMAIN
                
;       Output if not palindrome

noPalin:        push    offset msg_no
                call    print_string

endMAIN:        call    print_newline
                call    print_newline
                
                int     20h

; ***********************************************************

.functions:

;   --------------------------------------------------------
;   is_within_range
;
;       Checks if a value is contained in a certain range. (inclusive)
;
;       Parameters:
;         1. value to check
;         2. minimum range
;         3. maximum range
;       
;       Changes bl based on the algorithm below:
;         if (value to check < minimum range) 
;             bl = 0
;         else if (value to check > maximum range) 
;             bl = 0
;         else
;             bl = 1
;
is_within_range:
                enter                                   ; create stack frame
                push    dx                              ; save registers
                
                mov     dh, b[bp+8]                     ; dh = value
                
                cmp     dh, b[bp+6]                     ; if (dh < min_range)
                jl      notInRangeIWR                   ;   not in range
                
                cmp     dh, b[bp+4]                     ; if (dh > max_range)
                jg      notInRangeIWR                   ;   not in range
                
inRangeIWR:     mov     bl, 1
                jmp     endIWR
                
notInRangeIWR:  mov     bl, 0

endIWR:         pop     dx                              ; restore registers
                leave                                   ; destroy stack frame
                ret     6                               ; pop parameters then return
                
;   --------------------------------------------------------
;   remove_non_alphanumeric
;
;       Returns a string with all non-letter and non-number characters in the input string removed.
;         If the resultant is smaller, all extra space are filled with '$'
;         Does not modify the original string.
;
;       Parameters:
;         1. address of input string    - not modified
;         2. address of output buffer   - stores return value
;
remove_non_alphanumeric:
                enter                                   ; create stack frame
                push    si, di, ax, bx                  ; save registers

;       si is used to index the input string - always increments every iteration unless end of string is reached
;       di is used to index to output buffer - only incremented if an alphanumeric character is read
;         (since non-alphanumeric characters are skipped)

                mov     si, [bp+6]                      ; si points to 1st char of input
                mov     di, [bp+4]                      ; di points to 1st char of output
                
loopRNA:        sub     ax, ax                          ; clear ax - used as a flag
                sub     bx, bx                          ; clear bx - stores return value of function is_within_range
               
;       Check if we have reached the end of the input string.
;         If we do, that means there is no more characters to read. So skip the comparing part.
;         Now we just have to fill the remaining space in the output buffer with '$'.

                cmp     b[si], '$'                      
                je      alphaNumRNA                     ; why alphanumeric? go to label for more info                     
                
;       In this segment, we check if the character is a small letter, a big letter, or is a number
;         using the is_within_range function.
;       The return value of each call to is_withing_range function is OR-ed to al such that:
;       
;         al = is_small_letter OR is_big_letter OR is_number
;
;       Thus, when al = 0, the current character is non-alphanumeric

                push    w[si], 'a', 'z'
                call    is_within_range
                or      al, bl                          ; al = al OR is_small_letter - NOTE: al is zero at this point
                                                        ;   So, this becomes: al = is_small_letter
                push    w[si], 'A', 'Z'
                call    is_within_range
                or      al, bl                          ; al = is_small_letter OR is_big_letter
                
                push    w[si], '0', '9'
                call    is_within_range
                or      al, bl                          ; al = is_small_letter OR is_big_letter OR is_number
                

                cmp     al, 0                           ; Check if current char is not alphanumeric
                jne     alphaNumRNA                     

notAlphaNumRNA: inc     si                              ; If not alphanumeric, skip. Move to next char.
                jmp     loopRNA                         ; end this iteration and loop back. (NOTE: di is NOT incremented this iteration)
                
;       IMPORTANT: If si is pointing to '$' (end of string), execution will still
;         pass through the label alphaNumRNA.
;       The code segment below just copies the character pointed by si, into the output buffer
;         indexed by di. So if si points to '$', what happens is the output buffer is filled with
;         '$' up to the end of the output buffer.
             
alphaNumRNA:    mov     [di], al, [si]                  ; copy current char to output buffer
                
                cmp     b[si], '$'                      
                je      endRNA                          ; if we reached end of input string, skip incrementing si
                inc     si                              ; else, increment
                
endRNA:         inc     di                              ; advance to next output buffer character location

                cmp     b[di], '$'
                jne     loopRNA                         ; if we didn't reach the end of output buffer yet, loop back
    
                pop     bx, ax, di, si                  ; restore registers
                leave                                   ; destroy stack frame
                ret     4                               ; pop parameters then return

;   --------------------------------------------------------
;   to_lowercase
;
;       Takes a string and modifies it such that all its UPPERCASE letters are converted
;         to lowercase.
;
;       Parameters:
;         1. address of input string    - will be modified
;
to_lowercase:
                enter                                   ; create stack frame
                push    si, bx                          ; save registers
                
                sub     bx, bx                          ; clear bx - used as a flag
                
                mov     si, [bp+4]                      ; si points to 1st char of input string
                
loopTL:         push    w[si], 'A', 'Z'
                call    is_within_range
                
                cmp     bl, 1                           ; check if current char is a BIG letter
                jne     isNotBigTL                      ; if not, skip converting
                
isBigTL:        add     b[si], 20h                      ; convert BIG to small

isNotBigTL:     inc     si                              ; advance to next char
                cmp     b[si], '$'
                jne     loopTL                          ; if not end of string, loop back
                
                pop bx, si                              ; restore registers
                leave                                   ; destroy stack frame
                ret 2                                   ; pop parameters then return

;   --------------------------------------------------------
;   print_string
;
;       Takes a string and prints it.
;
;       Parameters:
;         1. address of input string    - not modified
;
print_string:
                enter                                   ; create stack frame
                push    ax, dx                          ; save registers
                sub     ax, ax                          ; clear ax
                mov     dx, [bp+4]                      ; move address of input string to dx
                mov     ah, 9
                int     21h                             ; print string
                pop     dx, ax                          ; restore registers
                leave                                   ; destroy stack frame
                ret     2                               ; pop parameters then return

;   --------------------------------------------------------
;   print_string_reversed
;
;       Takes a string and prints it in reverse order, character by character.
;
;       Parameters:
;         1. address of input string    - not modified
;
print_string_reversed:
                enter                                   ; create stack frame
                push    si, cx                          ; save registers
                
                mov     si, [bp+4]                      ; si points to first char
                mov     cx, 0                           ; cx will count the size of string (since no size is passed)
                
sizeCountPSR:   inc     cx, si                          
                cmp     b[si], '$'
                jne     sizeCountPSR                    ; if not end of string, loop back
                
;       At this point, si is pointing at '$' of input string. So move back to point to last char

                dec     si
                
;       This is a counter loop. No need to set cx since it is equal to size of input string

outputPSR:      push    w[si]
                call    print_char                      ; output current character
                dec     si                              ; move left
                loop    outputPSR
                
                pop     cx, si                          ; restore register
                leave                                   ; destroy stack frame
                ret     2                               ; pop parameters then return

;   --------------------------------------------------------
;   print_newline
;
;       Prints a newline.
;
;       Parameters: NONE
;
;       NOTE: Stack frame not needed since no parameters are passed
;
print_newline:
            push    0ah
            call    print_char                          ; print newline character
            ret

;   --------------------------------------------------------
;   print_char
;
;       Prints an ASCII character.
;
;       Parameters:
;         1. ASCII character to print
;
print_char:
                enter                                   ; create stack frame
                push    ax, dx                          ; save registers
                sub     ax, ax                          ; clear ax
                sub     dx, dx                          ; clear dx
                mov     dl, [bp+4]                      ; move input char to dl
                mov     ah, 2
                int     21h                             ; output char
                pop     dx, ax                          ; restore registers
                leave                                   ; destroy stack frame
                ret     2                               ; pop parameters then return
