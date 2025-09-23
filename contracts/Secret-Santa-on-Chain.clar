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
(define-constant ERR_WISHLIST_FULL (err u111))
(define-constant ERR_WISHLIST_ITEM_NOT_FOUND (err u112))
(define-constant ERR_ALREADY_RATED (err u113))
(define-constant ERR_INVALID_RATING (err u114))
(define-constant ERR_CANNOT_RATE_SELF (err u115))
(define-constant ERR_GIFT_NOT_REVEALED (err u116))
(define-constant ERR_RATING_PERIOD_EXPIRED (err u117))

(define-data-var contract-owner principal tx-sender)
(define-data-var game-active bool false)
(define-data-var registration-open bool false)
(define-data-var pairing-complete bool false)
(define-data-var total-participants uint u0)
(define-data-var min-gift-amount uint u1000000)
(define-data-var registration-deadline uint u0)
(define-data-var reveal-deadline uint u0)
(define-data-var game-round uint u0)
(define-data-var rating-period-blocks uint u144)
(define-data-var min-reputation-score int 0)
(define-data-var reputation-threshold int 50)

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

(define-map wishlists principal (list 5 (string-ascii 100)))

(define-map wishlist-preferences principal {
    min-price-range: uint,
    max-price-range: uint,
    special-notes: (string-ascii 200)
})

(define-map gift-ratings { recipient: principal, round: uint } {
    rating: uint,
    feedback: (string-ascii 500),
    rated-at: uint,
    gift-value-rating: uint,
    creativity-rating: uint,
    timeliness-rating: uint
})

(define-map participant-reputation principal {
    total-score: int,
    games-participated: uint,
    total-ratings-received: uint,
    average-rating: uint,
    five-star-count: uint,
    one-star-count: uint,
    last-game-round: uint
})

(define-map round-performance { participant: principal, round: uint } {
    gift-sent-on-time: bool,
    gift-rating-received: uint,
    feedback-received: (optional (string-ascii 500)),
    bonus-points: int
})

(define-map reputation-badges principal {
    super-santa: bool,
    consistent-giver: bool,
    creative-genius: bool,
    punctual-elf: bool,
    earned-at: uint
})

(define-map feedback-history { sender: principal, recipient: principal, round: uint } {
    feedback: (string-ascii 500),
    anonymous: bool,
    timestamp: uint
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

(define-public (create-wishlist (items (list 5 (string-ascii 100))) (min-price uint) (max-price uint) (notes (string-ascii 200)))
    (let 
        (
            (participant tx-sender)
        )
        (asserts! (is-registered participant) ERR_NOT_REGISTERED)
        (asserts! (<= min-price max-price) ERR_UNAUTHORIZED)
        (asserts! (<= (len items) u5) ERR_WISHLIST_FULL)
        (map-set wishlists participant items)
        (map-set wishlist-preferences participant {
            min-price-range: min-price,
            max-price-range: max-price,
            special-notes: notes
        })
        (ok true)
    )
)

(define-public (add-wishlist-item (new-item (string-ascii 100)))
    (let 
        (
            (participant tx-sender)
            (current-wishlist (default-to (list) (map-get? wishlists participant)))
        )
        (asserts! (is-registered participant) ERR_NOT_REGISTERED)
        (asserts! (< (len current-wishlist) u5) ERR_WISHLIST_FULL)
        (map-set wishlists participant (unwrap! (as-max-len? (append current-wishlist new-item) u5) ERR_WISHLIST_FULL))
        (ok true)
    )
)

(define-public (remove-wishlist-item (item-index uint))
    (let 
        (
            (participant tx-sender)
            (current-wishlist (default-to (list) (map-get? wishlists participant)))
            (wishlist-length (len current-wishlist))
        )
        (asserts! (is-registered participant) ERR_NOT_REGISTERED)
        (asserts! (< item-index wishlist-length) ERR_WISHLIST_ITEM_NOT_FOUND)
        (map-set wishlists participant 
            (unwrap! (as-max-len? 
                (concat 
                    (unwrap! (slice? current-wishlist u0 item-index) ERR_WISHLIST_ITEM_NOT_FOUND)
                    (unwrap! (slice? current-wishlist (+ item-index u1) wishlist-length) ERR_WISHLIST_ITEM_NOT_FOUND)
                ) 
                u5) 
            ERR_WISHLIST_ITEM_NOT_FOUND)
        )
        (ok true)
    )
)

(define-public (update-wishlist-preferences (min-price uint) (max-price uint) (notes (string-ascii 200)))
    (let 
        (
            (participant tx-sender)
        )
        (asserts! (is-registered participant) ERR_NOT_REGISTERED)
        (asserts! (<= min-price max-price) ERR_UNAUTHORIZED)
        (map-set wishlist-preferences participant {
            min-price-range: min-price,
            max-price-range: max-price,
            special-notes: notes
        })
        (ok true)
    )
)

(define-read-only (get-recipient-wishlist (recipient principal))
    (let 
        (
            (sender tx-sender)
            (sender-data (map-get? participants sender))
        )
        (match sender-data
            participant-info
                (if (is-eq (some recipient) (get recipient participant-info))
                    {
                        wishlist: (map-get? wishlists recipient),
                        preferences: (map-get? wishlist-preferences recipient)
                    }
                    {
                        wishlist: none,
                        preferences: none
                    }
                )
            {
                wishlist: none,
                preferences: none
            }
        )
    )
)

(define-read-only (get-my-wishlist)
    {
        wishlist: (map-get? wishlists tx-sender),
        preferences: (map-get? wishlist-preferences tx-sender)
    }
)

(define-read-only (has-wishlist (participant principal))
    (is-some (map-get? wishlists participant))
)

(define-public (rate-gift 
    (overall-rating uint) 
    (value-rating uint)
    (creativity-rating uint)
    (timeliness-rating uint)
    (feedback (string-ascii 500)))
    (let 
        (
            (recipient tx-sender)
            (current-round (var-get game-round))
            (gift-data (unwrap! (map-get? gifts recipient) ERR_NOT_REGISTERED))
            (rating-key { recipient: recipient, round: current-round })
        )
        (asserts! (get revealed gift-data) ERR_GIFT_NOT_REVEALED)
        (asserts! (is-none (map-get? gift-ratings rating-key)) ERR_ALREADY_RATED)
        (asserts! (and (>= overall-rating u1) (<= overall-rating u5)) ERR_INVALID_RATING)
        (asserts! (and (>= value-rating u1) (<= value-rating u5)) ERR_INVALID_RATING)
        (asserts! (and (>= creativity-rating u1) (<= creativity-rating u5)) ERR_INVALID_RATING)
        (asserts! (and (>= timeliness-rating u1) (<= timeliness-rating u5)) ERR_INVALID_RATING)
        (asserts! (<= stacks-block-height (+ (var-get reveal-deadline) (var-get rating-period-blocks))) ERR_RATING_PERIOD_EXPIRED)
        
        (map-set gift-ratings rating-key {
            rating: overall-rating,
            feedback: feedback,
            rated-at: stacks-block-height,
            gift-value-rating: value-rating,
            creativity-rating: creativity-rating,
            timeliness-rating: timeliness-rating
        })
        
        (let 
            (
                (sender (get sender gift-data))
                (sender-reputation (default-to 
                    {
                        total-score: 0,
                        games-participated: u0,
                        total-ratings-received: u0,
                        average-rating: u0,
                        five-star-count: u0,
                        one-star-count: u0,
                        last-game-round: u0
                    }
                    (map-get? participant-reputation sender)))
                (new-total-ratings (+ (get total-ratings-received sender-reputation) u1))
                (rating-points (calculate-rating-points overall-rating))
                (new-total-score (+ (get total-score sender-reputation) rating-points))
                (new-avg (/ (+ (* (get average-rating sender-reputation) (get total-ratings-received sender-reputation)) overall-rating) new-total-ratings))
            )
            
            (map-set participant-reputation sender {
                total-score: new-total-score,
                games-participated: (if (is-eq (get last-game-round sender-reputation) current-round) 
                    (get games-participated sender-reputation)
                    (+ (get games-participated sender-reputation) u1)),
                total-ratings-received: new-total-ratings,
                average-rating: new-avg,
                five-star-count: (if (is-eq overall-rating u5) 
                    (+ (get five-star-count sender-reputation) u1) 
                    (get five-star-count sender-reputation)),
                one-star-count: (if (is-eq overall-rating u1) 
                    (+ (get one-star-count sender-reputation) u1) 
                    (get one-star-count sender-reputation)),
                last-game-round: current-round
            })
            
            (map-set round-performance { participant: sender, round: current-round } {
                gift-sent-on-time: true,
                gift-rating-received: overall-rating,
                feedback-received: (some feedback),
                bonus-points: rating-points
            })
            
            (map-set feedback-history { sender: sender, recipient: recipient, round: current-round } {
                feedback: feedback,
                anonymous: true,
                timestamp: stacks-block-height
            })
            
            (unwrap-panic (check-and-award-badges sender))
        )
        
        (ok true)
    )
)

(define-private (calculate-rating-points (rating uint))
    (if (is-eq rating u5)
        10
        (if (is-eq rating u4)
            5
            (if (is-eq rating u3)
                0
                (if (is-eq rating u2)
                    -5
                    -10
                )
            )
        )
    )
)

(define-private (check-and-award-badges (participant principal))
    (match (map-get? participant-reputation participant)
        reputation
            (let 
                (
                    (current-badges (default-to 
                        {
                            super-santa: false,
                            consistent-giver: false,
                            creative-genius: false,
                            punctual-elf: false,
                            earned-at: u0
                        }
                        (map-get? reputation-badges participant)))
                )
                (map-set reputation-badges participant {
                    super-santa: (or (get super-santa current-badges) (>= (get total-score reputation) 100)),
                    consistent-giver: (or (get consistent-giver current-badges) (and (>= (get games-participated reputation) u5) (>= (get average-rating reputation) u4))),
                    creative-genius: (or (get creative-genius current-badges) (>= (get five-star-count reputation) u10)),
                    punctual-elf: (or (get punctual-elf current-badges) (>= (get games-participated reputation) u3)),
                    earned-at: stacks-block-height
                })
                (ok true)
            )
        (err ERR_NOT_REGISTERED)
    )
)

(define-public (provide-anonymous-feedback (recipient principal) (feedback (string-ascii 500)))
    (let 
        (
            (sender tx-sender)
            (current-round (var-get game-round))
            (sender-data (unwrap! (map-get? participants sender) ERR_NOT_REGISTERED))
        )
        (asserts! (is-eq (some recipient) (get recipient sender-data)) ERR_NOT_YOUR_RECIPIENT)
        (asserts! (get gift-sent sender-data) ERR_GIFT_NOT_REVEALED)
        
        (map-set feedback-history { sender: sender, recipient: recipient, round: current-round } {
            feedback: feedback,
            anonymous: true,
            timestamp: stacks-block-height
        })
        (ok true)
    )
)

(define-public (set-reputation-threshold (new-threshold int))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set reputation-threshold new-threshold)
        (ok true)
    )
)

(define-public (set-rating-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (> new-period u0) ERR_UNAUTHORIZED)
        (var-set rating-period-blocks new-period)
        (ok true)
    )
)

(define-read-only (get-participant-reputation (participant principal))
    (default-to 
        {
            total-score: 0,
            games-participated: u0,
            total-ratings-received: u0,
            average-rating: u0,
            five-star-count: u0,
            one-star-count: u0,
            last-game-round: u0
        }
        (map-get? participant-reputation participant)
    )
)

(define-read-only (get-gift-rating (recipient principal) (round uint))
    (map-get? gift-ratings { recipient: recipient, round: round })
)

(define-read-only (get-round-performance (participant principal) (round uint))
    (map-get? round-performance { participant: participant, round: round })
)

(define-read-only (get-participant-badges (participant principal))
    (default-to 
        {
            super-santa: false,
            consistent-giver: false,
            creative-genius: false,
            punctual-elf: false,
            earned-at: u0
        }
        (map-get? reputation-badges participant)
    )
)

(define-read-only (get-feedback-for-round (sender principal) (recipient principal) (round uint))
    (map-get? feedback-history { sender: sender, recipient: recipient, round: round })
)

(define-read-only (is-eligible-for-premium-game (participant principal))
    (let 
        (
            (reputation (get-participant-reputation participant))
        )
        (>= (get total-score reputation) (var-get reputation-threshold))
    )
)

(define-read-only (get-reputation-stats)
    {
        threshold: (var-get reputation-threshold),
        rating-period: (var-get rating-period-blocks),
        current-round: (var-get game-round)
    }
)

(define-read-only (calculate-reputation-percentile (participant principal))
    (let 
        (
            (reputation (get-participant-reputation participant))
            (score (get total-score reputation))
        )
        (if (> score 80)
            u95
            (if (> score 50)
                u75
                (if (> score 20)
                    u50
                    (if (> score 0)
                        u25
                        u0
                    )
                )
            )
        )
    )
)
