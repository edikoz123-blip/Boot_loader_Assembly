[bits 64]
[org 0x4000]           

;bootloader finish! part 1 start:


trying_vmptrld:
mov rax, 0x01B22FE4 
mov cr4, rax

xor rax, rax 
mov rdi, 0x7C00
mov rcx, 64
stosq

mov rdi, 0x4000
mov rcx, 0x400 
rep stosq 

mov ecx, 0x480
rdmsr 

mov ebx, 0x8000 
mov dword [rbx], eax        
vmxon [rbx]    


mov ecx, 0x4000
mov dword [ecx], eax
vmclear [rcx]
vmptrld [rcx]

jmp $ ; DEBUGGING

; PART 2 HOST:
Host_area:    

    mov rax, 0x00006c14       ;HOST_DR7 
    mov rbx, 0x00B00408       
    vmwrite rax, rbx          


    mov eax, 0x00006C00          ; HOST_CR0
    mov rbx, 0x80010031
    vmwrite rax, rbx 

mov rax, 0x00006C04
mov rbx, cr4
or rbx, 0x01B22FE4                  ; HOST_CR4
mov cr4, rbx
vmwrite rax, rbx    

.continue:

    mov rax, 0x8000000000001000   
    mov cr3, rax                   ; PML4 

    mov eax, 0x00006c02           ; HOST_CR3
    mov rbx, cr3
    vmwrite rax, rbx   

    mov eax, 0x00006C14          ; HOST_RSP
    mov rbx, 0x0000000000001F00
    vmwrite rax, rbx

    mov eax, 0x00006C16          ; HOST_RIP 
    mov ebx, VM_Exit_Handler                                     ; <-------------------------------------- NEEDS TO BE USED 
    vmwrite rax, rbx

mov rbx, cs
and rbx, ~7                  
mov rax, 0x00000C02          ; HOST_CS_SELECTOR
vmwrite rax, rbx           

mov rbx, ds
and rbx, ~7
mov rax, 0x00000C06          ; HOST_DS_SELECTOR
vmwrite rax, rbx

mov rbx, es
and rbx, ~7
mov rax, 0x00000C00          ; HOST_ES_SELECTOR
vmwrite rax, rbx

mov rbx, ss
and rbx, ~7
mov rax, 0x00000C04          ; HOST_SS_SELECTOR
vmwrite rax, rbx

xor rbx, rbx
mov rax, 0x00000C08          ; HOST_FS_SELECTOR
vmwrite rax, rbx

mov rax, 0x00000C0A          ; HOST_GS_SELECTOR
vmwrite rax, rbx

    xor ebx, ebx
    
    mov eax, 0x00004C00          ; HOST_IA32_SYSENTER_CS
    vmwrite rax, rbx
    
    mov eax, 0x00006C10          ; HOST_IA32_SYSENTER_ESP
    vmwrite rax, rbx
    
    mov eax, 0x00006C12          ; HOST_IA32_SYSENTER_EIP
    vmwrite rax, rbx

    mov ebx, 0x0008              ; RECENT
    mov eax, 0x00000C0C          ; HOST_TR_SELECTOR
    vmwrite rax, rbx

    mov eax, 0x00004002          ; PRIMARY_PROCESSOR_BASED_VM_EXEC_CONTROLS
    mov ebx, 0x94006172          
    vmwrite rax, rbx             

    mov ecx, 0xC0000080          ; IA32_EFER MSR
    rdmsr                        
    shl rdx, 32
    or rdx, rax                  
    
    mov eax, 0x00004C02          ; HOST_IA32_EFER 
    vmwrite rax, rdx             
 
    mov eax, 0x0000400C          ; VM_EXIT_CONTROLS [Chapter 24]
    mov ebx, 0x00008200       
    vmwrite rbx, rax

    mov eax, 0x00004012          ; VM_ENTRY_CONTROLS [Chapter 24]
    mov ebx, 0x00000200             ;CHECK
    vmwrite rax, rbx                       

    mov eax, 0x00006C06          ; HOST_FS_BASE
    mov ecx, 2                

.host_bases_loop:
    vmwrite rax, rcx            
    add eax, 2                
    loop .host_bases_loop      

    mov eax, 0x00006C0A          ; HOST_TR_BASE 
    vmwrite rax, rcx            

    mov eax, 0x00006C0C          ; HOST_GDTR_BASE 
    sub rsp, 10                 
    sgdt [rsp]                   
    mov rbx, [rsp + 2]           ;Check it 
    add rsp, 10                  
    vmwrite rax, rbx             

    mov eax, 0x00002004          ; Exception Bitmap -> RAX
    mov ebx, 0x00227558        
    vmwrite rax, rbx             
   

    mov eax, 0x0000201A          ; EPT_POINTER 
    mov ebx, 0x0000601E                 ; <-------------------------------- USE IT EPT POINTER
    vmwrite rax, rbx             

    mov eax, 0x00006C0E          ; HOST_IDTR_BASE
    lea rbx, [rel host_idt_table]       ; <-------------------------------- MISTAKE HERE 
    vmwrite rax, rbx                        

mov ecx, 0xC0000080      
rdmsr                       
shl rdx, 32                 
or  rax, rdx                 
mov rax, 0x00002C02          ;VMCS_HOST_EFER
vmwrite rax, rbx             

mov ecx, 0x00000277          
rdmsr
shl rdx, 32
or  rdx, rax
mov eax, 0x00002C00          ; VMCS_HOST_PAT
vmwrite rax, rdx            
      
mov ecx, 0x0000038F          ; IA32_PERF_GLOBAL_CTRL
rdmsr                       
shl rdx, 32                  
or  rdx, rax               
mov eax, 0x00002C04          
vmwrite rax, rdx             


    mov eax, 0x00006C18          ; HOST_IA32_S_CET [Chapter 27]
    mov ecx, 4                 

.host_security_loop:
    vmwrite rax, rcx          
    add eax, 2                   
    loop .host_security_loop   

    mov eax, 0x00004C04          ; HOST_IA32_PERF_GLOBAL_CTRL [Chapter 27]
    vmwrite rax, rcx            

    mov eax, 0x00004010          ; VM_EXIT_MSR_LOAD_COUNT [Chapter 24]
    add ecx, 1              
    vmwrite rax, rcx             ; <---------------------------------------- MISTAKE HERE          

    jmp $ ;DEBUGGING HOST 

    ;----- HOST FINISH DEBUGGING ONLY -----

;----------------- GUEST -------------


Guest_area:
    ;IDT
    sub rsp, 16                  ;  (Long Mode Alignment)
    sidt [rsp]                   
    mov rbx, [rsp + 2]           ; Base Address IDTR
    add rsp, 16              

    mov eax, 0x00006818          ; VMCS_GUEST_IDTR_BASE 
    vmwrite rax, rbx                                    ;CHECK

    mov eax, 0x00002000          ; VMCS_GUEST_CR0_GUEST_HOST_MASK 
    mov ebx, 0xFFFFFFFF         
    vmwrite rax, rbx             

    mov eax, 0x00002002          ; VMCS_GUEST_CR4_GUEST_HOST_MASK 
    mov ebx, 0xFFFFFFFF          
    vmwrite rax, rbx             

    mov eax, 0x00004002          ; CPU_BASED_VM_EXEC_CONTROLS 
    vmread rbx, rax              
    or ebx, (1 << 15) | (1 << 16)           ;CHECK  
    vmwrite rax, rbx           

    mov eax, 0x0000400A          ; VMCS_CTRL_CR3_TARGET_COUNT 
    xor ebx, ebx                 
    vmwrite rax, rbx            

    ; =========================================================================
    ; חלק 2: הגדרת כתובות כניסה (RIP), מחסנית (RSP) ודגלי החומרה (RFLAGS)
    ; =========================================================================
    mov eax, 0x0000681E          ; VMCS_GUEST_RIP 
    lea rbx, [rel Guest_Code_Entry]     ; <----------------- MISTAKE FORGOT REL 
    vmwrite rax, rbx            

    mov eax, 0x0000681C          ; VMCS_GUEST_RSP 
    xor ebx, ebx                 
    vmwrite rax, rbx           

    mov eax, 0x00006820          ; VMCS_GUEST_RFLAGS 
    mov ebx, 0x00000002          
    vmwrite rax, rbx           

    ; =========================================================================
    ; חלק 3: חוקי אבטחה והרשאות זיכרון של הסגמנטים (Access Rights)              ; CHECK
    ; =========================================================================
    mov eax, 0x00004816          ; VMCS_GUEST_CS_ACCESS_RIGHTS
    mov ebx, 0x0000209B          
    vmwrite rax, rbx            

    mov eax, 0x00004818          ; VMCS_GUEST_SS_ACCESS_RIGHTS
    mov ebx, 0x00004093         
    vmwrite rax, rbx

    mov ebx, 0x00010000          ;(Unusable Segments Flag)
    mov eax, 0x00004812          ; VMCS_GUEST_ES_ACCESS_RIGHTS 
    mov ecx, 5                  

.compact_destroy_loop:
    vmwrite rax, rbx       
    add eax, 2               
    cmp eax, 0x00004814          ; CS_AR
    jne .skip_cs_protection
    add eax, 4                   ;CS SS                  
.skip_cs_protection:
    loop .compact_destroy_loop

    ; =========================================================================
    ; חלק 4: חקיקת רגיסטרי הסלקטורים (Selectors) בסיליקון
    ; =========================================================================
    mov rbx, cs
    and rbx, ~3                  

    mov eax, 0x00000802          ; VMCS_GUEST_CS_SELECTOR
    vmwrite rax, rbx

    mov eax, 0x00000804          ; VMCS_GUEST_SS_SELECTOR
    vmwrite rax, rbx
    
    mov eax, 0x00000800          ; VMCS_GUEST_ES_SELECTOR
    vmwrite rax, rcx

    mov eax, 0x00000806          ; VMCS_GUEST_DS_SELECTOR
    vmwrite rax, rcx

    mov eax, 0x00000808          ; VMCS_GUEST_FS_SELECTOR
    vmwrite rax, rcx

    mov eax, 0x0000080A          ; VMCS_GUEST_GS_SELECTOR
    vmwrite rax, rcx

    mov eax, 0x0000080C          ; VMCS_GUEST_LDTR_SELECTOR
    vmwrite rax, rcx

    mov eax, 0x0000080E          ; VMCS_GUEST_TR_SELECTOR
    vmwrite rax, rcx

    mov eax, 0x00000810          ; VMCS_GUEST_INTERRUPT_STATUS
    vmwrite rax, rcx

    mov eax, 0x00000812          ; VMCS_GUEST_PML_INDEX
    vmwrite rax, rcx

    ; =========================================================================
    ; חלק 5: הגדרת שדות 64-ביט משניים (Hex Dumps) של הברזלים
    ; =========================================================================
    mov eax, 0x00002800          ; VMCS_GUEST_VMCS_LINK_POINTER
    mov rbx, 0xFFFFFFFFFFFFFFFF 
    vmwrite rax, rbx             

    mov eax, 0x00002802          ; VMCS_GUEST_DEBUGCTL
    vmwrite rax, rcx             

    mov eax, 0x00002804          ; VMCS_GUEST_PAT
    vmwrite rax, rcx             

    mov eax, 0x00002806          ; VMCS_GUEST_EFER
    mov ebx, 0x00000D01          ;Long Mode Active (LME/LMA/SCE)
    vmwrite rax, rbx             

    mov eax, 0x00002808          ; VMCS_GUEST_PERF_GLOBAL_CTRL
    vmwrite rax, rcx             

    mov eax, 0x0000280A          ; VMCS_GUEST_PDPTE0
    vmwrite rax, rcx             

    mov eax, 0x0000280C          ; VMCS_GUEST_PDPTE1
    vmwrite rax, rcx             

    mov eax, 0x0000280E          ; VMCS_GUEST_PDPTE2
    vmwrite rax, rcx             

    mov eax, 0x00002810          ; VMCS_GUEST_PDPTE3
    vmwrite rax, rcx             

    ; =========================================================================
    ; חלק 6: הגדרת גבולות (Limits) ובסיסים (Bases) של מרחב הזיכרון השטוח
    ; =========================================================================
    mov ebx, 0xFFFFFFFF          

    mov eax, 0x00004402          ; VMCS_GUEST_CS_LIMIT 
    vmwrite rax, rbx             ; 0x4402

    mov eax, 0x00004406          ; VMCS_GUEST_DS_LIMIT 
    vmwrite rax, rbx             ; 0x4406

    mov eax, 0x00004408          ; VMCS_GUEST_SS_LIMIT
    vmwrite rax, rbx             ; 0x4408

    mov eax, 0x00004400          ; VMCS_GUEST_ES_LIMIT
    vmwrite rax, rcx             ; 0x4400

    mov eax, 0x00004404          ; VMCS_GUEST_SS_LIMIT
    vmwrite rax, rcx             ; 0x4404

    mov eax, 0x0000440A          ; VMCS_GUEST_GS_LIMIT
    vmwrite rax, rcx             ; 0x440A

    mov eax, 0x0000440C          ; VMCS_GUEST_LDTR_LIMIT
    vmwrite rax, rcx             ; 0x440C

    mov eax, 0x0000440E          ; VMCS_GUEST_TR_LIMIT
    vmwrite rax, rcx             ; 0x440E

    mov eax, 0x00006806          ; VMCS_GUEST_ES_BASE 
    vmwrite rax, rcx             ; 0x6806

    mov eax, 0x00006808          ; VMCS_GUEST_CS_BASE
    vmwrite rax, rcx             ; 0x6808

    add eax, 2                   ; VMCS_GUEST_SS_BASE
    vmwrite rax, rcx             ; 0x680A

    add eax, 2                   ; VMCS_GUEST_DS_BASE 
    vmwrite rax, rcx             ; 0x680C

    add eax, 2                   ; VMCS_GUEST_FS_BASE 
    vmwrite rax, rcx             ; 0x680E

    add eax, 2                   ; VMCS_GUEST_GS_BASE 
    vmwrite rax, rcx             ; 0x6810

    add eax, 2                   ; VMCS_GUEST_LDTR_BASE 
    vmwrite rax, rcx             ; 0x6812

    add eax, 2                   ; VMCS_GUEST_TR_BASE 
    vmwrite rax, rcx             ; 0x6814

    mov eax, 0x0000482A          ; VMCS_GUEST_IA32_DEBUGCTL 
    vmwrite rax, rcx             ; 0x482A   AI said: 0x2802 
    
    add eax, 2                   ; VMCS_GUEST_SYSENTER_CS
    vmwrite rax, rcx             ; 0x482C
    
    mov eax, 0x00006822          ; VMCS_GUEST_PENDING_DEBUG_EXCEPTIONS
    vmwrite rax, rcx             ; 0x6822
    
    add eax, 2                   ; VMCS_GUEST_SYSENTER_ESP
    vmwrite rax, rcx             ; 0x6824
    
    add eax, 2                   ; VMCS_GUEST_SYSENTER_EIP
    vmwrite rax, rcx             ; 0x6826

    ; =========================================================================
    ; (GDTR/IDTR) Host Guest
    ; =========================================================================
    sub rsp, 16
    sgdt [rsp]                   ; GDT 
    mov rbx, [rsp + 2]           ; GDT Base 
    movzx rdx, word [rsp]        ; GDT Limit
    add rsp, 16

    mov eax, 0x00006816          ; VMCS_GUEST_GDTR_BASE
    vmwrite rax, rbx

    mov eax, 0x00004410          ; VMCS_GUEST_GDTR_LIMIT
    vmwrite rax, rdx

    mov eax, 0x00006818          ; VMCS_GUEST_IDTR_BASE
    vmwrite rax, rcx
    
    mov eax, 0x00004412          ; VMCS_GUEST_IDTR_LIMIT
    vmwrite rax, rcx

    mov eax, 0x00004828          ; VMCS_GUEST_DR7 
    mov ebx, 0x00000400          
    vmwrite rax, rbx            

    mov eax, 0x00004824          ; VMCS_GUEST_INTERRUPTIBILITY_STATE
    vmwrite rax, rcx             

    mov eax, 0x0000400E          ; VMCS_CTRL_VMX_LINK_POINTER 
    mov ebx, 0xFFFFFFFFFFFFFFFF  
    vmwrite rax, rbx             
    
    mov eax, 0x0000482E          ; VMCS_GUEST_IA32_PERF_GLOBAL_CTRL
    vmwrite rax, rcx             
    
    mov eax, 0x00006828          ; VMCS_GUEST_IA32_PAT
    vmwrite rax, rcx

    mov eax, 0x0000682A          ; VMCS_GUEST_IA32_EFER
    mov ebx, 0x00000D01          ; Long Mode Active
    vmwrite rax, rbx

    mov eax, 0x0000682C          ; VMCS_GUEST_IA32_BNDCFGS
    vmwrite rax, rcx             
    
    mov eax, 0x0000682E          ; VMCS_GUEST_IA32_RTIT_CTL
    vmwrite rax, rcx             
    
    mov eax, 0x00006830          ; VMCS_GUEST_IA32_LBR_CTL
    vmwrite rax, rcx             

mov eax, 0x686C           ; CHECK   0x686C
mov edx, 3

.guest_cet_loop:
vmwrite rax, rcx
add eax, 2
dec edx
jnz .guest_cet_loop

mov eax, 0x00004826 ; VMCS_GUEST_ACTIVITY_STATE 0x4826
mov edx, 2

.guest_activity_loop:
vmwrite rax, rcx
add eax, 2
dec edx
jnz .guest_activity_loop

mov eax, 0x00006844 ; VMCS_GUEST_IA32_SPEC_CTRL 0x6844                 Check Them Out 
vmwrite rax, rcx

mov eax, 0x00004832 ; VMCS_CTRL_VMX_PREEMPTION_TIMER_VALUE  0x4832
vmwrite rax, rcx

mov eax, 0x00000810     ;0x0810
mov edx, 2                                                    ; CHECK
.loop_pair_1:

vmwrite rax, rcx
add eax, 2
dec edx
jnz .loop_pair_1

mov eax, 0x0000280A        ;0x280A
mov edx, 4                                                    ; CHECK
.loop_pair_2:

vmwrite rax, rcx
add eax, 2
dec edx                                                       ; CHECK
jnz .loop_pair_2

jmp $ ;DEBUGGING 

;GUEST FINISH! 

;----------------- PART: 4  VM-Execution Control Fields -----------------
VM_Execution_Control_Fields:
    mov ecx, 0x48D                  ; IA32_VMX_TRUE_PINBASED_CTLS MSR   0x48D
    rdmsr                       
    
    or  eax, 0x000000A9       
    and eax, edx               

    mov ecx, 0x00004000             ; PIN_BASED_VM_EXEC_CONTROLS    0x4000
    vmwrite rcx, rax         
          
    mov ecx, 0x48E                  ; IA32_VMX_TRUE_PROCBASED_CTLS  0x48E
    rdmsr                           

    and eax, edx                
    or  eax, 0x11016280             ;HLT, INVLPG, CR3, DR, I/O, MSR Bitmaps
    and eax, edx            

    mov ecx, 0x00004002             ; VMCS Encode Primary Processor Controls    0x4002
    vmwrite rcx, rax           

    mov ecx, 0x48B                  ; IA32_VMX_PROCBASED_CTLS2  0x48B
    rdmsr                          

    and eax, edx                
    or  eax, 0x00000846             ;  EPT(1), Descriptor Tables(2), WBINVD(6), RDRAND(11) 0x0846
    and eax, edx            

    mov ecx, 0x0000401E             ; VMCS Encode Secondary Controls [zRjldk]   0x401E
    vmwrite rcx, rax              

    mov ecx, 0x49F                  ; IA32_VMX_PROCBASED_CTLS3 [zRjldk]    0x49F
    rdmsr                           

    and eax, edx                
    or  eax, 0x00000000             
    and eax, edx            

    mov ecx, 0x00004022             ; VMCS Encode Tertiary Controls [zRjldk]    0x4022
    vmwrite rcx, rax                

Suffocate_APIC_Interrupts:
    mov rbx, 0xFFFFFFFFFFFFFFFF    
    mov eax, 0x0000201E             ; EOI_EXIT0 0x201E
    vmwrite rax, rbx                

    add eax, 2                      ; EOI_EXIT1 0x00002020
    xor ecx, ecx
    vmwrite rax, rcx               

    add eax, 2                      ; EOI_EXIT2 0x00002022
    vmwrite rax, rcx               

    add eax, 2                      ; EOI_EXIT3 0x00002024
    vmwrite rax, rcx         

Suffocate_Exceptions_And_Registers:
    mov ebx, 0xFFFFFFFF           
    mov eax, 0x00004004             ;  Exception Bitmap 
    vmwrite rax, rbx                

Setup_EPT_Pointer_Hardware:
    mov rbx, rdi                        ;CHECK      
    or  rbx, 0x7E            
    mov eax, 0x0000201A             ;  EPT Pointer (EPTP) 
    vmwrite rax, rbx                                ; <---------------------- MISTAKE HERE        

Suffocate_VM_Functions:
    xor edx, edx               
    
    mov eax, 0x00002018             ; VM-Function Controls 
    vmwrite rax, rdx               

Suffocate_SGX_And_Encryption:
    mov rbx, 0xFFFFFFFFFFFFFFFF     

    mov eax, 0x0000202E             ; ENCLS-Exiting Bitmap 0x0000202E   AI said: 0x00002030 
    vmwrite rax, rbx                

    add eax, 16                     ; PCONFIG-Exiting Bitmap 0x0000203E AI said: 0x0000203E
    vmwrite rax, rbx               

    mov eax, 0x00002034             ; XSS-Exiting Bitmap 0x00002034
    vmwrite rax, rbx                

Suffocate_SPP_And_HLAT:
    xor ebx, ebx                    

    mov eax, 0x00002030             ; Sub-Page-Permission-Table Pointer 
    vmwrite rax, rbx               

    mov eax, 0x00002040             ; HLAT Pointer 
    vmwrite rax, rbx               

Suffocate_PASID_Timeout_And_SEAM:
    mov eax, 0x00004020             ; Instruction-Timeout Control 
    vmwrite rax, rbx              

    mov eax, 0x00002042             ; SEAM Shared EPTP 0x2042
    vmwrite rax, rbx                

Suffocate_APIC_Timer:
    mov eax, 0x0000203A             ; Guest Deadline Shadow   0x203A
    vmwrite rax, rbx                   ; <------------------------------------- MISTAKE HERE          

;----------------- PART 5: VM-Exit Control Fields -----------------
init_secondary_and_msr_controls:
    ; IA32_VMX_EXIT_CTLS2 MSR
    mov ecx, 0x493                  
    rdmsr                                           
    and edx, eax                    

    ; SECONDARY_VM_EXIT_CONTROLS
    mov eax, 0x2044                         ;CHECK THE MSRS            
    vmwrite rax, rbx 

    ; VM-Exit MSR-Store Count
    mov eax, 0x400E                  
    vmwrite rax, rbx                

    ; VM-Exit MSR-Store Address
    mov eax, 0x4010             
    vmwrite rax, rbx                

    ; VM-Exit MSR-Load Count
    mov eax, 0x2006            
    vmwrite rax, rbx                

    ; VM-Exit MSR-Load Address
    mov eax, 0x2008             
    vmwrite rax, rbx

configure_vmcs_raw:
    ; --- Notification Vector ---
    mov eax, 0x0002                     ; CHECK
    mov ebx, 0x0002         
    vmwrite rax, rbx        

    ; --- EPTP  ---
    mov eax, 0x0004        
    mov ebx, 0x0000        
    vmwrite rax, rbx       

;----------------- PART 6: VM-ENTRY CONTROL FIELDS -----------------

  mov ecx, 0x48C                  ; IA32_VMX_TRUE_ENTRY_CTLS MSR
    rdmsr                          

    mov ebx, 0x204                      ; CHECK HERE
    and ebx, edx                  
    or  ebx, eax           

    mov eax, 0x4012                 ; VM_ENTRY_CONTROLS
    vmwrite rax, rbx               

    mov ebx, 0x80000B0D                            

.write_event:
    mov eax, 0x00004016             ; VM_ENTRY_INTR_INFO_FIELD
    vmwrite rax, rbx 
; ---------------- The fields I forgot to do -----------------------

; Check it after the optimization because there can be some things you didnt consider

configure_vmcs_64bit_controls_raw:
    ; --- IO-A 
    mov eax, 0x2000                     ; 0x2000                      ; CHECK
    mov ebx, 0x00081000     
    vmwrite rax, rbx

    ; --- IO-B 
    add eax, 2                          ; 0x2002                           ;CHECK
    mov ebx, 0x00082000             
    vmwrite rax, rbx

    ; --- MSR   
    add eax, 2                          ; 0x2004
    mov ebx, 0x00083000     
    vmwrite rax, rbx

    ; --- MSR 
    add eax, 2                          ; 0x2006
    mov ebx, 0x00084000     
    vmwrite rax, rbx

    ; --- MSR
    add eax, 2                          ; 0x2008
    xor ebx, ebx    
    vmwrite rax, rbx

    ; --- MSR
    add eax, 2                          ; 0x200a                                                   ; CHECK    
    vmwrite rax, rbx    

    ; --- VMCS 
    add eax, 2                          ; 0x200c                                                   ; CHECK
    mov rbx, 0xffffffffffffffff ;Executive VMCS)
    vmwrite rax, rbx

    ; EPT
    add eax, 14                         ; 0x201a
    mov ebx, 0x0008001e     
    vmwrite rax, rbx

    ; --- PML 
    add eax, 12                         ; 0x200e
    xor ebx, ebx
    vmwrite rax, rbx

    ; --- 0x2010 ---
    add eax, 2                          ; 0x2010
    vmwrite rax, rbx

    ; --- PIC 
    add eax, 2                          ; 0x2012
    vmwrite rax, rbx

    ; --- PIC 
    add eax, 2                          ; 0x2014
    vmwrite rax, rbx

    ; --- Posted Interrupt Descriptor 
    add eax, 2                          ; 0x2016
    vmwrite rax, rbx

    ; --- 0x2018
    add eax, 2                          ; 0x2018
    vmwrite rax, rbx

configure_vmcs_64bit_controls_extended_raw:
    ; VMCS_CTRL_EOI_EXIT_BITMAP_0
    add eax, 4                          ; 0x201c     
    vmwrite rax, rbx

    ; VMCS_CTRL_EOI_EXIT_BITMAP_1
    add eax, 2                          ; 0x201e
    vmwrite rax, rbx

    ; VMCS_CTRL_EOI_EXIT_BITMAP_2
    add eax, 2                          ; 0x2020
    vmwrite rax, rbx

    ; VMCS_CTRL_EOI_EXIT_BITMAP_3
    add eax, 2                          ; 0x2022
    vmwrite rax, rbx

    ; VMCS_CTRL_EPT_POINTER_LIST_ADDRESS
    add eax, 2                          ; 0x2024
    vmwrite rax, rbx

    ; VMCS_CTRL_VMREAD_BITMAP_ADDRESS
    add eax, 2                          ; 0x2026
    vmwrite rax, rbx

    ; VMCS_CTRL_VMWRITE_BITMAP_ADDRESS
    add eax, 2                          ; 0x2028
    vmwrite rax, rbx

    ; VMCS_CTRL_VIRTUALIZATION_EXCEPTION_INFORMATION_ADDRESS
    add eax, 2                          ; 0x202a
    vmwrite rax, rbx

    ; VMCS_CTRL_XSS_EXITING_BITMAP
    add eax, 2                          ; 0x202c
    vmwrite rax, rbx

    ; VMCS_CTRL_ENCLS_EXITING_BITMAP
    add eax, 2                          ; 0x202e
    vmwrite rax, rbx

    ; VMCS_CTRL_TSC_MULTIPLIER
    add eax, 3                          ; 0x2032
    vmwrite rax, rbx

configure_vmcs_32bit_controls_raw:
    ; VMCS_CTRL_PIN_BASED_VM_EXECUTION_CONTROLS
    mov eax, 0x4000                     ; 0x4000
    mov ebx, 0x0000001f
    vmwrite rax, rbx

    ; VMCS_CTRL_PROCESSOR_BASED_VM_EXECUTION_CONTROLS
    add eax, 2                          ; 0x4002
    mov ebx, 0x04006172
    vmwrite rax, rbx

    ; VMCS_CTRL_EXCEPTION_BITMAP
    add eax, 2                          ; 0x4004
    mov ebx, 0x00040000
    vmwrite rax, rbx

    ; VMCS_CTRL_PAGEFAULT_ERROR_CODE_MASK
    add eax, 2                          ; 0x4006
    mov ebx, 0x00000000
    vmwrite rax, rbx

    ; VMCS_CTRL_CR3_TARGET_COUNT
    add eax, 4                          ; 0x400a
    mov ebx, 0x00000004
    vmwrite rax, rbx

    ; VMCS_CTRL_VMEXIT_CONTROLS
    add eax, 2                          ; 0x400c
    mov ebx, 0x0036efff
    vmwrite rax, rbx

    ; VMCS_CTRL_VMEXIT_MSR_STORE_COUNT
    add eax, 2                          ; 0x400e
    mov ebx, 0x00000001     
    vmwrite rax, rbx

    ; VMCS_CTRL_VMEXIT_MSR_LOAD_COUNT
    add eax, 2                          ; 0x4010
    xor ebx, ebx
    vmwrite rax, rbx

    ; VMCS_CTRL_PAGEFAULT_ERROR_CODE_MATCH
    sub eax, 2                          ; 0x4008
    vmwrite rax, rbx    

    ; VMCS_CTRL_VMENTRY_CONTROLS
    add eax, 4                          ; 0x4012
    mov ebx, 0x000011ff
    vmwrite rax, rbx
   
    ; VMCS_CTRL_VMENTRY_MSR_LOAD_COUNT
    add eax, 2                          ; 0x4014
    vmwrite rax, rbx

    ; VMCS_CTRL_VMENTRY_INTERRUPTION_INFORMATION_FIELD
    add eax, 2                          ; 0x4016
    vmwrite rax, rbx

    ; VMCS_CTRL_VMENTRY_EXCEPTION_ERROR_CODE
    add eax, 2                          ; 0x4018
    vmwrite rax, rbx

    ; VMCS_CTRL_VMENTRY_INSTRUCTION_LENGTH
    add eax, 2                          ; 0x401a
    vmwrite rax, rbx

    ; VMCS_CTRL_TPR_THRESHOLD
    add eax, 2                          ; 0x401c
    vmwrite rax, rbx

    ; VMCS_CTRL_PLE_GAP
    add eax, 4                          ; 0x4020
    vmwrite rax, rbx

    ; VMCS_CTRL_PLE_WINDOW
    add eax, 2                          ; 0x4022
    vmwrite rax, rbx

    ; VMCS_CTRL_SECONDARY_PROCESSOR_BASED_VM_EXECUTION_CONTROLS
    mov eax, 0x401e
    mov ebx, 0x000000a0
    vmwrite rax, rbx

    mov rdi, 0x7000
    
    mov dword [rdi], 0xC0000080  
    mov dword [rdi + 4], 0
    mov qword [rdi + 8], 0x500
      
    mov eax, 0x0000200A          ; HOST_IA32_MSR_LOAD_ADDR [Chapter 24]
    mov ebx, 0x00007000      
    vmwrite rax, rbx

;----------------- PART 7: Defender IN OUT and EPT, TSS, CONFIRM FRAGMENT AND MORE! -----------------

    ; --------------------------------------------------------------------------
    ;  Speculative Execution Mitigations (Spectre/Meltdown)
    ; --------------------------------------------------------------------------
    mov ecx, 0x00000048         
    rdmsr                        
    or eax, 0x00000003          
    xor edx, edx               
    wrmsr                        

    ; --------------------------------------------------------------------------
    ;  VT-d IOMMU Page Table Initialization & Hardware Synchronization
    ; --------------------------------------------------------------------------
    xor rax, rax
    mov rcx, 1024                
    mov rdi, 0x00095000          
    rep stosq                    

    mov rax, 0x00096001          
    mov [0x00095000], rax        

    mov rax, 0x00080015          
    mov [0x00096000], rax        

    mov rbx, 0xFED90000          
    mov rax, 0x00095000          
    mov [rbx + 0x20], rax        

    mov eax, [rbx + 0x18]        
    or eax, 0x80000000           
    mov [rbx + 0x18], eax        

.vtd_sync_loop:
    mov eax, [rbx + 0x1C]        
    and eax, 0x80000000          
    jz .vtd_sync_loop  

    ; --------------------------------------------------------------------------
    ;  Block 3: Constructing Sterile EPT Partition for Sandbox Isolation
    ; --------------------------------------------------------------------------
    xor rax, rax
    mov rcx, 0x600
    mov rdi, 0x00080000        
    rep stosq

    mov rax, 0x00081007 
    mov [0x00080000], rax

    mov rax, 0x00082007
    mov [0x00081000], rax

    xor rdx, rdx
    xor rcx, rcx              

Predator_loop:
    mov rax, rdx  
    or rax, 0x9C
    mov [0x00082000 + rcx * 8], rax
    add rdx, 0x00200000            
    inc rcx
    cmp rcx, 512
    jne Predator_loop 

    mov rax, 0x0008001E           
    mov edx, 0x0000201A           
    vmwrite rdx, rax 
    
    ; Advanced EPT Setup
    ; 1. Enable hardware capabilities via MSR (Includes Secondary Controls & RDTSC)
    mov ecx, 0x0000048B      
    rdmsr
    or eax, 0x00641040          
    wrmsr

    ; 2. Read, Modify, and Write Secondary Execution Controls (Activate EPT)
    mov rdx, 0x00002012     
    vmread rax, rdx          
    or rax, 0x01940008      
    vmwrite rdx, rax         

    ; 3. Configure Extended Page Table Pointer (EPTP) Address
    mov rax, 0x00002040      
    mov rbx, 0x0008001E     
    vmwrite rax, rbx                

    ; 4. Configure MSRs for optimization and global intercept policy
    mov ecx, 0x00000982          
    rdmsr
    or eax, 0x00000003         
    xor edx, edx
    wrmsr

; --------------------------------------------------------------------------
;  Block 4: TSS Verification and Fragment Validation Engine inside VM-Exit
; --------------------------------------------------------------------------
align 16
_tss_fragment_confirm:
    str cx                       
    sgdt [rsp - 10]             
    
    mov rbx, [rsp - 8]           
    movzx rcx, cx
    add rbx, rcx              
    
    movzx edx, word [rbx + 2]  
    mov eax, [rbx + 4]          
    and eax, 0xFF000000       
    or edx, eax                 
    mov eax, [rbx + 7]          
    and eax, 0x00FF0000        
    or edx, eax                 
    
    mov rsi, [rbx + 8]       
    shl rsi, 32
    or rdx, rsi              

    mov rsi, [rdx + 4]          
    mov rdi, 0x0000681C          
    vmread rax, rdi           
    
    cmp rax, rsi
    jae _hardware_trap_triggered 
    

_hardware_trap_triggered:
    mov rdx, 0x00006C16          
    xor rax, rax                 
    vmwrite rdx, rax
    vmcall                  

    ; Intercept and Block CPUID Modifications
    mov ecx, 0x000001A0          ; MSR Register: IA32_MISC_ENABLE
    rdmsr
    
    or edx, 0x00000001          
    wrmsr

    or rax, 0x00001000          
    vmwrite rdx, rax
    jmp vmlaunch_starting              

;----------------- PART 8: LAUNCHING -----------------

vmlaunch_starting:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor ebp, ebp 
    xor edi, edi
    xor r8, r8
    xor r9, r9
    xor r10, r10
    xor r11, r11

    vmlaunch          
        

VM_Exit_Handler:
push rax 
push rbx
push rcx 
push rdx



pop rdx
pop rcx
pop rbx 
pop rax
xor rbp, rbp

section .data
    align 4096

vmxon_region: 
    times 4096 db 0     

    vmxon_pointer: dq 0
    guest_stack_top: dq 0 

    align 16
host_idt_table: times 256 dq 0 

    Guest_Code_Entry:
    mov eax, 0xABCDEF  
    
section .bss
    align 16
guest_stack_bottom:
    resb 1024           
guest_stack_limit: