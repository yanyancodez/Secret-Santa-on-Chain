(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_GAME_NOT_ACTIVE (err u103))
(define-constant ERR_REGISTRATION_CLOSED (err u104))
(define-constant ERR_PAIRING_NOT_READY (err u105))
(define-constant ERR_ALREADY_PAIRED (err u106))
(define-constant ERR_INSUFFICIENT_FUNDS (err u107))
(define-constant ERR_GIFT_ALREADY_SENT (err u108))
(define-constant ERR_NOT_YOUR_RECIPIENT (err u109))
(define-constant ERR_GAME_ALREADY_ENDED (err u110))

(define-data-var contract-owner principal tx-sender)
(define-data-var game-active bool false)
(define-data-var registration-open bool false)
(define-data-var pairing-complete bool false)
(define-data-var total-participants uint u0)
(define-data-var min-gift-amount uint u1000000)
(define-data-var registration-deadline uint u0)
(define-data-var reveal-deadline uint u0)
(define-data-var game-round uint u0)

(define-map participants principal {
    registered: bool,
    gift-amount: uint,
    recipient: (optional principal),
    gift-sent: bool,
    gift-received: bool,
    joined-round: uint
})

(define-map participant-list uint principal)
(define-map gifts principal {
    sender: principal,
    amount: uint,
    message: (string-ascii 280),
    revealed: bool,
    sent-at: uint
})

(define-public (initialize-game (reg-deadline uint) (reveal-deadline-param uint) (min-amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (not (var-get game-active)) ERR_GAME_ALREADY_ENDED)
        (asserts! (> reg-deadline stacks-block-height) ERR_UNAUTHORIZED)
        (asserts! (> reveal-deadline-param reg-deadline) ERR_UNAUTHORIZED)
        (var-set game-active true)
        (var-set registration-open true)
        (var-set pairing-complete false)
        (var-set total-participants u0)
        (var-set min-gift-amount min-amount)
        (var-set registration-deadline reg-deadline)
        (var-set reveal-deadline reveal-deadline-param)
        (var-set game-round (+ (var-get game-round) u1))
        (ok true)
    )
)

(define-public (register (gift-amount uint))
    (let 
        (
            (participant tx-sender)
            (current-round (var-get game-round))
        )
        (asserts! (var-get game-active) ERR_GAME_NOT_ACTIVE)
        (asserts! (var-get registration-open) ERR_REGISTRATION_CLOSED)
        (asserts! (<= stacks-block-height (var-get registration-deadline)) ERR_REGISTRATION_CLOSED)
        (asserts! (>= gift-amount (var-get min-gift-amount)) ERR_INSUFFICIENT_FUNDS)
        (match (map-get? participants participant)
            existing-participant 
                (if (is-eq (get joined-round existing-participant) current-round)
                    ERR_ALREADY_REGISTERED
                    (begin
                        (map-set participants participant {
                            registered: true,
                            gift-amount: gift-amount,
                            recipient: none,
                            gift-sent: false,
                            gift-received: false,
                            joined-round: current-round
                        })
                        (try! (stx-transfer? gift-amount participant (as-contract tx-sender)))
                        (map-set participant-list (var-get total-participants) participant)
                        (var-set total-participants (+ (var-get total-participants) u1))
                        (ok true)
                    )
                )
            (begin
                (map-set participants participant {
                    registered: true,
                    gift-amount: gift-amount,
                    recipient: none,
                    gift-sent: false,
                    gift-received: false,
                    joined-round: current-round
                })
                (try! (stx-transfer? gift-amount participant (as-contract tx-sender)))
                (map-set participant-list (var-get total-participants) participant)
                (var-set total-participants (+ (var-get total-participants) u1))
                (ok true)
            )
        )
    )
)

(define-public (close-registration)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (var-get registration-open) ERR_REGISTRATION_CLOSED)
        (var-set registration-open false)
        (ok true)
    )
)



(define-public (generate-pairings)
    (let 
        (
            (total (var-get total-participants))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (not (var-get registration-open)) ERR_REGISTRATION_CLOSED)
        (asserts! (not (var-get pairing-complete)) ERR_ALREADY_PAIRED)
        (asserts! (>= total u2) ERR_UNAUTHORIZED)
        (try! (fold pair-single-participant (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19) (ok u0)))
        (var-set pairing-complete true)
        (ok true)
    )
)

(define-private (pair-single-participant (index uint) (prev-result (response uint uint)))
    (if (and (is-ok prev-result) (< index (var-get total-participants)))
        (let 
            (
                (participant (unwrap! (map-get? participant-list index) ERR_NOT_REGISTERED))
                (recipient-index (mod (+ index u1) (var-get total-participants)))
                (recipient (unwrap! (map-get? participant-list recipient-index) ERR_NOT_REGISTERED))
                (participant-data (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
            )
            (map-set participants participant 
                (merge participant-data { recipient: (some recipient) })
            )
            (ok (+ index u1))
        )
        prev-result
    )
)

(define-public (send-gift (recipient principal) (message (string-ascii 280)))
    (let 
        (
            (sender tx-sender)
            (sender-data (unwrap! (map-get? participants sender) ERR_NOT_REGISTERED))
            (recipient-data (unwrap! (map-get? participants recipient) ERR_NOT_REGISTERED))
        )
        (asserts! (var-get pairing-complete) ERR_PAIRING_NOT_READY)
        (asserts! (not (get gift-sent sender-data)) ERR_GIFT_ALREADY_SENT)
        (asserts! (is-eq (some recipient) (get recipient sender-data)) ERR_NOT_YOUR_RECIPIENT)
        (asserts! (<= stacks-block-height (var-get reveal-deadline)) ERR_GAME_ALREADY_ENDED)
        
        (map-set participants sender 
            (merge sender-data { gift-sent: true })
        )
        (map-set participants recipient 
            (merge recipient-data { gift-received: true })
        )
        (map-set gifts recipient {
            sender: sender,
            amount: (get gift-amount sender-data),
            message: message,
            revealed: false,
            sent-at: stacks-block-height
        })
        (ok true)
    )
)

(define-public (reveal-gift)
    (let 
        (
            (recipient tx-sender)
            (gift-data (unwrap! (map-get? gifts recipient) ERR_NOT_REGISTERED))
        )
        (asserts! (not (get revealed gift-data)) ERR_GIFT_ALREADY_SENT)
        (map-set gifts recipient 
            (merge gift-data { revealed: true })
        )
        (try! (as-contract (stx-transfer? (get amount gift-data) tx-sender recipient)))
        (ok true)
    )
)

(define-public (emergency-withdraw)
    (let 
        (
            (participant tx-sender)
            (participant-data (unwrap! (map-get? participants participant) ERR_NOT_REGISTERED))
        )
        (asserts! (> stacks-block-height (var-get reveal-deadline)) ERR_GAME_NOT_ACTIVE)
        (asserts! (not (get gift-sent participant-data)) ERR_GIFT_ALREADY_SENT)
        (try! (as-contract (stx-transfer? (get gift-amount participant-data) tx-sender participant)))
        (ok true)
    )
)

(define-public (end-game)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (> stacks-block-height (var-get reveal-deadline)) ERR_GAME_NOT_ACTIVE)
        (var-set game-active false)
        (var-set registration-open false)
        (var-set pairing-complete false)
        (ok true)
    )
)

(define-read-only (get-participant-info (participant principal))
    (map-get? participants participant)
)

(define-read-only (get-gift-info (recipient principal))
    (map-get? gifts recipient)
)

(define-read-only (get-game-status)
    {
        game-active: (var-get game-active),
        registration-open: (var-get registration-open),
        pairing-complete: (var-get pairing-complete),
        total-participants: (var-get total-participants),
        min-gift-amount: (var-get min-gift-amount),
        registration-deadline: (var-get registration-deadline),
        reveal-deadline: (var-get reveal-deadline),
        current-block: stacks-block-height,
        game-round: (var-get game-round)
    }
)

(define-read-only (get-my-recipient)
    (match (map-get? participants tx-sender)
        participant-data (get recipient participant-data)
        none
    )
)

(define-read-only (is-registered (participant principal))
    (match (map-get? participants participant)
        participant-data 
            (and 
                (get registered participant-data)
                (is-eq (get joined-round participant-data) (var-get game-round))
            )
        false
    )
)

(define-read-only (can-reveal-gift (recipient principal))
    (match (map-get? gifts recipient)
        gift-data (not (get revealed gift-data))
        false
    )
)

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender))
)
