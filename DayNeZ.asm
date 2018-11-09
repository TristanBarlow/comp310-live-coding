    .inesprg 1   ; 1x 16KB PRG code
    .ineschr 1   ; 1x  8KB CHR data
    .inesmap 0   ; mapper 0 = NROM, no bank swapping
    .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

;---------------- CONSTANT ADDRESSES -------------------
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014

JOYPAD1   = $4016
JOYPAD2   = $4017

BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001

COLLIDE_RIGHT= %00000001
COLLIDE_LEFT = %00000010
COLLIDE_UP   = %00000100
COLLIDE_DOWN = %00001000

ENEMY_SQUAD_WIDTH = 1
ENEMY_SQUAD_HEIGHT = 2
NUM_ENEMIES  = ENEMY_SQUAD_HEIGHT * ENEMY_SQUAD_WIDTH
ENEMY_SPACING = 16
ENEMY_DECENT_SPEED = 5

GRAVITY  = 8         ; Sub pixel per frame 
MAX_Y_SPEED = 2      ; pixel per frame
FLOORHEIGHT = 220
GROUND_FRICTION = 1  ; Sub pixel per frame


    .rsset $0000
joyPad1_state   .rs 1
bullet_active   .rs 1
temp_x          .rs 1
temp_y          .rs 1
enemy_info      .rs 4 * NUM_ENEMIES
enemy_movement  .rs 5 * NUM_ENEMIES
bigNumber       .rs 2
outVec          .rs 2
collisionFlag   .rs 1
jumpDest        .rs 2
player_movement .rs 5

    .rsset $0000
speedY  .rs 2 ; sub pixels per frame
speedX  .rs 2 ; sub pixels per frame
pos     .rs 2

    .rsset $0200
sprite_player .rs 4
sprite_bullet .rs 4
sprite_wall   .rs 4
sprite_enemy  .rs 4 * NUM_ENEMIES


    .rsset $0000
SPRITE_Y .rs 1
SPRITE_TILE .rs 1
SPRITE_ATTR .rs 1
SPRITE_X .rs 1

    .rsset $0000
ENEMY_SPEED .rs 1
enemyStatus .rs 1
enemyWidth  .rs 1
enemyHeight .rs 1



    .bank 0
    .org $C000 

;---------------------------- MACROS ---------------------;
SignFlip .macro 
    EOR #%11111111
    CLC 
    ADC #1
    .endm

; 1st param adress second param value to add
AddValueInLoop .macro
    LDA \1,x
    CLC
    ADC \2
    STA \1,x
    .endm

; 1st param adress second param value to add
AddValue .macro
    LDA \1
    CLC
    ADC \2
    STA \1
    .endm

;| 1: 16 variable | 2: 16bit Value to add| 
Add16Bit .macro 
    LDA \1
    CLC
    ADC #LOW(\2)
    STA \1
    LDA \1 + 1 ;high 8 bits
    ADC #HIGH(\2) ; DIDNT CLEAR CARRY
    STA \1 + 1
    .endm

;| 1: Movement Variable | 2: 
ApplyPhysics .macro

    .endm
GetDirection .macro 
    ;Get X dir
    LDA \3
    SEC
    SBC \1
    STA \5 + vecX

    LDA \4
    SEC
    SBC \2
    STA \5 + vecY
    .endm

CielingValue .macro
    LDA \2
    CMP \1
    BCC Cap\@
    JMP Fin\@
Cap\@:
    STA \1
Fin\@:
    .endm
; SET X REG TO 0 IF NOT IN LOOP WITH CONSTANT COLLISION SIZES
;| 1: sprite1| 2 : w1 | 3 : h1 | 4 : sprite2 | 5 : w2 | 6 :  h2|
CheckSpriteCollisionWithXReg .macro 
    LDA #%00000000
    STA collisionFlag

    LDA \1 + SPRITE_X, x      ; load x1
    SEC
    SBC \5          ; subtract w2
    CMP \4 + SPRITE_X          ;compare with x2  
    BCS NoCollision\@ ; branch if x1-w2 >=


    CLC 
    ADC \2 + \5     ; Add width 1 and width 2 to A 
    CMP \4 + SPRITE_X          ; compare to x2
    BCC NoCollision\@ ; branch if no collision
    
    LDA \1 + SPRITE_Y, x ; caluclate y_enemy - bullet width(y1 - h2)
    SEC
    SBC \6                         ; assume w2 = 8
    CMP \4+SPRITE_Y ;compare with x  bullet   
    BCS NoCollision\@ ; branch if x1-w2 >=

    CLC 
    ADC \3+\6                    ; Calculat x_enemy + w_eneym (x1 + w1) assuming w1 = 8
    CMP \4+SPRITE_Y
    BCS EndCollision\@ ; 

NoCollision\@
    LDA #%00000001
    STA collisionFlag
EndCollision\@
    .endm

;----------------------------- RESET ---------------------;
RESET:
    SEI          ; disable IRQs
    CLD          ; disable decimal mode
    LDX #$40
    STX $4017    ; disable APU frame IRQ
    LDX #$FF
    TXS          ; Set up stack
    INX          ; now X = 0
    STX PPUCTRL    ; disable NMI
    STX PPUMASK    ; disable rendering
    STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
    BIT PPUSTATUS
    BPL vblankwait1

clrmem:
    LDA #$00
    STA $0000, x
    STA $0100, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
        
    STA $0200, x

    INX
    BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
    BIT PPUSTATUS
    BPL vblankwait2


;    LDA #%10000000   ;intensify blues
;    STA PPUMASK

    ;Reset PPU h/l latch
    LDA PPUSTATUS

    ; Write Address $3F10 (Bakcground colour) to the ppu
    LDA #$3F
    STA PPUADDR  
    LDA #$10
    STA PPUADDR

; Write pallet 00
    LDA #$0F
    STA PPUDATA
    LDA #$17
    STA PPUDATA
    LDA #$20
    STA PPUDATA
    LDA #$39
    STA PPUDATA


;--------------------- Sprite Data --------------;
    ; Write sprite data for 0 OAM memory Object memory
    LDA  #120       ; Y pos
    STA  sprite_player + SPRITE_Y

    LDA  #$00         ; Tile number
    STA  sprite_player + SPRITE_TILE

    LDA  #%00000000         ; Attributes ????
    STA sprite_player + SPRITE_ATTR

    LDA #128    ; X pos
    STA sprite_player + SPRITE_X

;--------------------- wall Data --------------;
    ; Write sprite data for 0 OAM memory Object memory
    LDA  #FLOORHEIGHT      ; Y pos
    STA  sprite_wall + SPRITE_Y

    LDA  #$10         ; Tile number
    STA  sprite_wall + SPRITE_TILE

    LDA  #%00000000         ; Attributes ????
    STA sprite_wall + SPRITE_ATTR

    LDA #128    ; X pos
    STA sprite_wall + SPRITE_X

;---------------------------- Init enemies -------------------------;
    LDX #0
    LDA #ENEMY_SQUAD_HEIGHT  * ENEMY_SPACING
    STA temp_y
InitEnemiesLoop_Y:
    LDA #ENEMY_SQUAD_WIDTH *ENEMY_SPACING
    STA temp_x
InitEnemiesLoop_X:
    ; Accumlator  = temp_x here

    STA sprite_enemy + SPRITE_X, x
    LDA temp_y
    STA sprite_enemy + SPRITE_Y,x
    LDA #2 
    STA sprite_enemy + SPRITE_TILE, X
    LDA #%00000000   
    STA sprite_enemy+ SPRITE_ATTR, x

    STA enemy_info + enemyStatus,x

    LDA #8
    STA enemy_info + enemyHeight, x

    LDA #1
    STA enemy_info + ENEMY_SPEED, x


    ;Increment X by 4
    TXA
    CLC
    ADC #4
    TAX

    LDA temp_x
    SEC
    SBC #ENEMY_SPACING
    STA temp_x
    BNE InitEnemiesLoop_X

    LDA temp_y
    SEC
    SBC #ENEMY_SPACING
    STA temp_y
    BNE InitEnemiesLoop_Y

;----------- End Enemy loop -------------;

    LDA #%10000000  ;binary notation to Enable NMI
    STA PPUCTRL  

    LDA #%00010000  ; Enable Sprites
    STA PPUMASK

Forever:
    JMP Forever     ;jump back to Forever, infinite loop


;------------------------------- GAME UPDATE -------------------------;
NMI:

; Update  And Check Controller
    JSR ControllerRead

; Perform game update
    JSR GameUpdate

    ;copy sprite data to the ppu#
    LDA #0
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    RTI
    
;--------------------------------- CONTROLLER ----------------------------;
ControllerRead:
    ;Init Controller 1
    LDA #1
    STA JOYPAD1
    LDA #0
    STA JOYPAD1

    ;Read joypad A is already 0
    LDX #0
    STX joyPad1_state

ReadController:
    LDA JOYPAD1
    LSR A 
    ROL joyPad1_state
    INX
    CPX #8
    BNE ReadController

;----------- A BUTTON--------;
    LDA joyPad1_state
    AND #BUTTON_A
    BEQ  LookAt_B   ;Branch if equal
    JSR TrySpawnBullet

;----------- B BUTTON--------;
LookAt_B:
    ;Read B Button
    LDA joyPad1_state
    AND #BUTTON_B
    BEQ  LookAt_UP   ;Branch if equal
    LDA sprite_player + SPRITE_X
    CLC
    ADC #1
    STA sprite_player + SPRITE_X

;----------- UP BUTTON--------;
LookAt_UP:
    LDA joyPad1_state
    AND #BUTTON_UP
    BEQ  LookAt_LEFT   ;Branch if equal
    LDA sprite_player + SPRITE_Y
    CLC
    ADC #-1
    STA sprite_player + SPRITE_Y

;----------- LEFT BUTTON--------;
LookAt_LEFT:
    LDA joyPad1_state
    AND #BUTTON_LEFT
    BEQ  LookAt_RIGHT   ;Branch if equal
    AddValue sprite_player + SPRITE_X, #-1
    LDX 1
    CheckSpriteCollisionWithXReg sprite_player, #8, #8, sprite_wall, #8,#8
    LDA collisionFlag
    BNE LookAt_RIGHT
    AddValue sprite_player + SPRITE_X, #1

    
;----------- RIGHT BUTTON--------;
LookAt_RIGHT:
    LDA joyPad1_state
    AND #BUTTON_RIGHT
    BEQ  LookAt_START  ;Branch if equal
    AddValue sprite_player + SPRITE_X, #1
    LDX 1
    CheckSpriteCollisionWithXReg sprite_player, #8, #8, sprite_wall, #8,#8
    LDA collisionFlag
    BNE LookAt_START
    AddValue sprite_player + SPRITE_X, #-1

;----------- START BUTTON--------;
LookAt_START:
    LDA joyPad1_state
    AND #BUTTON_START
    BEQ  LookAt_SELECT   ;Branch if equal
    LDA sprite_player + SPRITE_Y
    CLC
    ADC #1
    STA sprite_player + SPRITE_Y

 
;----------- SELECT BUTTON--------;
LookAt_SELECT:
    LDA joyPad1_state
    AND #BUTTON_SELECT
    BEQ  ControllerReadFinished   ;Branch if equal
    LDA sprite_player + SPRITE_Y
    CLC
    ADC #1
    STA sprite_player + SPRITE_Y

;----------- CONTROLLER FINISHED --------;
ControllerReadFinished:   

ApplyPlayerPhysics:
    Add16Bit player_movement + speedY, GRAVITY
    AddValue player_movement + pos + 1, player_movement + speedY

    ; Apply the new new speed
    LDA sprite_player + SPRITE_Y
    ADC player_movement + speedY + 1


    ;CHeck to see if its not greater than floorHeight
    CMP #FLOORHEIGHT
    BCS OnGround
    STA sprite_player + SPRITE_Y
    JMP ReturnFromPLayerUpdate

OnGround:
    LDA #0
    STA player_movement +speedY
    STA player_movement +speedY+1
    ;STA player_movement + su
    LDA #FLOORHEIGHT
    STA sprite_player + SPRITE_Y

ReturnFromPLayerUpdate:
    CielingValue player_movement + speedY + 1, #MAX_Y_SPEED
    RTS

;--------------------------------------SPAWNING----------------------------;
TrySpawnBullet:
    LDA bullet_active
    BEQ SpawnBullet
    RTS

SpawnBullet:

    ; Spawn a bullet
    LDA  sprite_player + SPRITE_Y       ; Y pos
    STA  sprite_bullet + SPRITE_Y

    LDA  #1         ; Tile number
    STA  sprite_bullet + SPRITE_TILE

    LDA  #%00000000         ; Attributes ????
    STA sprite_bullet + SPRITE_ATTR

    LDA sprite_player + SPRITE_X     ; X pos
    STA sprite_bullet + SPRITE_X

    LDA #1
    STA bullet_active
    RTS


GameUpdate:

UpdateBullet:
    LDA bullet_active
    BEQ UpdateEnemies
    LDA sprite_bullet + SPRITE_Y
    SEC
    SBC #1
    STA sprite_bullet + SPRITE_Y
    BCS UpdateEnemies
    LDA #0
    STA bullet_active
    JMP UpdateEnemies


UpdateEnemies:
    LDX #(NUM_ENEMIES-1)*4

UpdateEnemiesLoop:
    LDA enemy_info + enemyStatus, x
    BEQ NotDead
    JMP UpdateEnemiesNoCollision

NotDead:

    LDA sprite_enemy+SPRITE_X, x
    CLC
    ADC enemy_info + ENEMY_SPEED, x
    STA sprite_enemy+SPRITE_X,X
    CMP  #256 - ENEMY_SPACING 
    BCS EnemyReverse
    CMP #ENEMY_SPACING
    BCC EnemyReverse
    JMP UpdateEnemiesNoReverse

EnemyReverse:
    LDA enemy_info + ENEMY_SPEED, x
    SignFlip
    STA enemy_info + ENEMY_SPEED, x


    AddValueInLoop sprite_enemy + SPRITE_Y, #ENEMY_DECENT_SPEED
    LDA sprite_enemy+SPRITE_ATTR,X
    EOR #%01000000
    STA sprite_enemy+SPRITE_ATTR,X

UpdateEnemiesNoReverse:
    ; check collisions

    CheckSpriteCollisionWithXReg sprite_enemy, #8, #8, sprite_bullet, #8,#8

    LDA collisionFlag
    BNE CheckPlayerCollision

    LDA #%00000001
    STA enemy_info + enemyStatus, x

    LDA #128
    STA sprite_enemy + SPRITE_X, x
    STA sprite_enemy + SPRITE_Y, x

CheckPlayerCollision:
    CheckSpriteCollisionWithXReg sprite_enemy, #8,#8, sprite_player, #8,#8

    LDA collisionFlag
    BNE UpdateEnemiesNoCollision
    JMP RESET

UpdateEnemiesNoCollision:
    DEX
    DEX
    DEX
    DEX
    BMI UpdateReturnJump
    JMP UpdateEnemiesLoop

UpdateReturnJump:
    RTS


do_action:
       asl A
       tax
       lda table+1,x
       pha
       lda table,x
       pha
       rts


;--------------------- Data tabe-------------;
table: 
     .dw UpdateEnemiesNoCollision-1  



;;;;;;;;;;;;;;   
  
  

    .bank 1
    .org $FFFA     ;first of the three vectors starts here
    .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                    ;processor will jump to the label NMI:
    .dw RESET      ;when the processor first turns on or is reset, it will jump
                    ;to the label RESET:
    .dw 0          ;external interrupt IRQ is not used in this tutorial

  
;;;;;;;;;;;;;;  
  
  
    .bank 2
    .org $0000
    .incbin "Sprites/Face.chr"   ;includes 8KB graphics file from SMB1