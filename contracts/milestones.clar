;; Meridian Quest Protocol - A decentralized task completion and reward system
;; where clients can post quests with escrow rewards, progress tracking, and dispute resolution

;; Constants
(define-constant protocol-admin tx-sender)
(define-constant quest-status-posted u0)
(define-constant quest-status-active u1)
(define-constant quest-status-completed u2)
(define-constant quest-status-cancelled u3)
(define-constant quest-status-disputed u4)

;; Error constants
(define-constant ERROR_UNAUTHORIZED_EXECUTOR (err u100))
(define-constant ERROR_INVALID_QUEST_STATUS (err u101))
(define-constant ERROR_INSUFFICIENT_REWARD (err u102))
(define-constant ERROR_QUEST_ALREADY_EXISTS (err u103))
(define-constant ERROR_QUEST_NOT_FOUND (err u104))
(define-constant ERROR_INVALID_MILESTONE_INDEX (err u105))
(define-constant ERROR_INVALID_INPUT (err u106))
(define-constant ERROR_INVALID_EXECUTOR_ADDRESS (err u107))
(define-constant ERROR_INVALID_MILESTONE_DATA (err u108))

;; Data structures
(define-map quest-registry
    { quest-id: uint }
    {
        executor-address: principal,
        client-address: principal,
        total-compensation: uint,
        quest-status: uint,
        initiation-block: uint,
        completion-deadline: uint,
        dispute-window: uint,
        milestone-objectives: (list 5 {
            milestone-description: (string-utf8 100),
            milestone-reward: uint,
            milestone-achieved: bool
        })
    }
)

(define-map escrow-treasury
    { quest-id: uint }
    { secured-funds: uint }
)

(define-map protocol-disputes
    { quest-id: uint }
    {
        dispute-narrative: (string-utf8 200),
        dispute-initiator: principal,
        admin-resolution: (optional (string-utf8 200))
    }
)

;; Read-only functions
(define-read-only (get-quest-details (quest-id uint))
    (map-get? quest-registry { quest-id: quest-id })
)

(define-read-only (get-secured-funds (quest-id uint))
    (default-to { secured-funds: u0 }
        (map-get? escrow-treasury { quest-id: quest-id })
    )
)

(define-read-only (get-dispute-details (quest-id uint))
    (map-get? protocol-disputes { quest-id: quest-id })
)

;; Private functions
(define-private (verify-quest-stakeholder (quest-id uint))
    (let ((quest-data (unwrap! (get-quest-details quest-id) false)))
        (or
            (is-eq tx-sender protocol-admin)
            (is-eq tx-sender (get executor-address quest-data))
            (is-eq tx-sender (get client-address quest-data))
        )
    )
)

(define-private (milestone-achieved? (milestone {
    milestone-description: (string-utf8 100),
    milestone-reward: uint,
    milestone-achieved: bool
}))
    (get milestone-achieved milestone))

(define-private (verify-all-milestones-complete (milestone-objectives (list 5 {
        milestone-description: (string-utf8 100),
        milestone-reward: uint,
        milestone-achieved: bool
    })))
    (and
        (milestone-achieved? (unwrap-panic (element-at milestone-objectives u0)))
        (milestone-achieved? (unwrap-panic (element-at milestone-objectives u1)))
        (milestone-achieved? (unwrap-panic (element-at milestone-objectives u2)))
        (milestone-achieved? (unwrap-panic (element-at milestone-objectives u3)))
        (milestone-achieved? (unwrap-panic (element-at milestone-objectives u4)))
    )
)

(define-private (validate-executor-address (executor principal))
    (and 
        (not (is-eq executor tx-sender))  ;; Executor cannot be the client
        (not (is-eq executor protocol-admin))  ;; Executor cannot be the protocol admin
        (not (is-eq executor (as-contract tx-sender)))  ;; Executor cannot be the contract itself
    )
)

(define-private (validate-milestone-rewards (milestones (list 5 {
        milestone-description: (string-utf8 100),
        milestone-reward: uint,
        milestone-achieved: bool
    })) 
    (total-compensation uint))
    (let ((total-milestone-rewards (+ 
            (get milestone-reward (unwrap-panic (element-at milestones u0)))
            (get milestone-reward (unwrap-panic (element-at milestones u1)))
            (get milestone-reward (unwrap-panic (element-at milestones u2)))
            (get milestone-reward (unwrap-panic (element-at milestones u3)))
            (get milestone-reward (unwrap-panic (element-at milestones u4)))
        )))
        (and 
            (is-eq total-milestone-rewards total-compensation)  ;; Sum of milestone rewards must equal total compensation
            (> (len (get milestone-description (unwrap-panic (element-at milestones u0)))) u0)  ;; Validate descriptions
            (> (len (get milestone-description (unwrap-panic (element-at milestones u1)))) u0)
            (> (len (get milestone-description (unwrap-panic (element-at milestones u2)))) u0)
            (> (len (get milestone-description (unwrap-panic (element-at milestones u3)))) u0)
            (> (len (get milestone-description (unwrap-panic (element-at milestones u4)))) u0)
        )
    )
)

(define-private (update-milestone-at-index 
    (milestone {
        milestone-description: (string-utf8 100),
        milestone-reward: uint,
        milestone-achieved: bool
    })
    (target-index uint)
    (index uint))
    {
        milestone-description: (get milestone-description milestone),
        milestone-reward: (get milestone-reward milestone),
        milestone-achieved: (if (is-eq index target-index) 
                               true 
                               (get milestone-achieved milestone))
    }
)

;; Public functions
(define-public (initialize-quest (quest-id uint) 
                           (executor-address principal)
                           (total-compensation uint)
                           (execution-duration uint)
                           (milestone-objectives (list 5 {
                               milestone-description: (string-utf8 100),
                               milestone-reward: uint,
                               milestone-achieved: bool
                           })))
    (let ((current-block block-height))
        (asserts! (is-none (get-quest-details quest-id)) ERROR_QUEST_ALREADY_EXISTS)
        (asserts! (> total-compensation u0) ERROR_INSUFFICIENT_REWARD)
        (asserts! (> execution-duration u0) ERROR_INVALID_INPUT)
        (asserts! (validate-executor-address executor-address) ERROR_INVALID_EXECUTOR_ADDRESS)
        (asserts! (validate-milestone-rewards milestone-objectives total-compensation) ERROR_INVALID_MILESTONE_DATA)
        
        (map-set quest-registry
            { quest-id: quest-id }
            {
                executor-address: executor-address,
                client-address: tx-sender,
                total-compensation: total-compensation,
                quest-status: quest-status-posted,
                initiation-block: current-block,
                completion-deadline: (+ current-block execution-duration),
                dispute-window: (+ (+ current-block execution-duration) u144), ;; ~1 day after deadline (assuming ~10min blocks)
                milestone-objectives: milestone-objectives
            }
        )
        
        (map-set escrow-treasury
            { quest-id: quest-id }
            { secured-funds: u0 }
        )
        
        (ok true)
    )
)

(define-public (fund-quest-escrow (quest-id uint) (funding-amount uint))
    (let ((quest-data (unwrap! (get-quest-details quest-id) ERROR_QUEST_NOT_FOUND))
          (current-escrow-balance (get secured-funds (get-secured-funds quest-id))))
        
        (asserts! (is-eq tx-sender (get client-address quest-data)) ERROR_UNAUTHORIZED_EXECUTOR)
        (asserts! (is-eq (get quest-status quest-data) quest-status-posted) ERROR_INVALID_QUEST_STATUS)
        (asserts! (> funding-amount u0) ERROR_INVALID_INPUT)
        
        (try! (stx-transfer? funding-amount tx-sender (as-contract tx-sender)))
        
        (let ((new-escrow-balance (+ current-escrow-balance funding-amount)))
            (map-set escrow-treasury
                { quest-id: quest-id }
                { secured-funds: new-escrow-balance }
            )
            
            (if (>= new-escrow-balance (get total-compensation quest-data))
                (map-set quest-registry
                    { quest-id: quest-id }
                    (merge quest-data { quest-status: quest-status-active })
                )
                true
            )
            
            (ok true)
        )
    )
)

(define-public (achieve-milestone (quest-id uint) (milestone-index uint))
    (let ((quest-data (unwrap! (get-quest-details quest-id) ERROR_QUEST_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get executor-address quest-data)) ERROR_UNAUTHORIZED_EXECUTOR)
        (asserts! (is-eq (get quest-status quest-data) quest-status-active) ERROR_INVALID_QUEST_STATUS)
        (asserts! (< milestone-index (len (get milestone-objectives quest-data))) ERROR_INVALID_MILESTONE_INDEX)
        
        (let ((milestones (get milestone-objectives quest-data))
              (updated-milestone-objectives 
                (list 
                    (update-milestone-at-index (unwrap-panic (element-at milestones u0)) milestone-index u0)
                    (update-milestone-at-index (unwrap-panic (element-at milestones u1)) milestone-index u1)
                    (update-milestone-at-index (unwrap-panic (element-at milestones u2)) milestone-index u2)
                    (update-milestone-at-index (unwrap-panic (element-at milestones u3)) milestone-index u3)
                    (update-milestone-at-index (unwrap-panic (element-at milestones u4)) milestone-index u4)
                )))
            
            (map-set quest-registry
                { quest-id: quest-id }
                (merge quest-data { milestone-objectives: updated-milestone-objectives })
            )
            
            (if (verify-all-milestones-complete updated-milestone-objectives)
                (map-set quest-registry
                    { quest-id: quest-id }
                    (merge quest-data { 
                        quest-status: quest-status-completed,
                        milestone-objectives: updated-milestone-objectives 
                    })
                )
                true
            )
            
            (ok true)
        )
    )
)

(define-public (release-compensation (quest-id uint))
    (let ((quest-data (unwrap! (get-quest-details quest-id) ERROR_QUEST_NOT_FOUND))
          (treasury-data (get-secured-funds quest-id)))
        
        (asserts! (is-eq tx-sender (get client-address quest-data)) ERROR_UNAUTHORIZED_EXECUTOR)
        (asserts! (is-eq (get quest-status quest-data) quest-status-completed) ERROR_INVALID_QUEST_STATUS)
        
        (try! (as-contract (stx-transfer? 
            (get secured-funds treasury-data)
            (as-contract tx-sender)
            (get executor-address quest-data)
        )))
        
        (map-set escrow-treasury
            { quest-id: quest-id }
            { secured-funds: u0 }
        )
        
        (ok true)
    )
)

(define-public (initiate-protocol-dispute (quest-id uint) (dispute-narrative (string-utf8 200)))
    (let ((quest-data (unwrap! (get-quest-details quest-id) ERROR_QUEST_NOT_FOUND)))
        (asserts! (verify-quest-stakeholder quest-id) ERROR_UNAUTHORIZED_EXECUTOR)
        (asserts! (< block-height (get dispute-window quest-data)) ERROR_INVALID_QUEST_STATUS)
        (asserts! (> (len dispute-narrative) u0) ERROR_INVALID_INPUT)
        
        (map-set protocol-disputes
            { quest-id: quest-id }
            {
                dispute-narrative: dispute-narrative,
                dispute-initiator: tx-sender,
                admin-resolution: none
            }
        )
        
        (map-set quest-registry
            { quest-id: quest-id }
            (merge quest-data { quest-status: quest-status-disputed })
        )
        
        (ok true)
    )
)

(define-public (issue-admin-resolution (quest-id uint) 
                                  (resolution-details (string-utf8 200))
                                  (client-refund-percentage uint))
    (let ((quest-data (unwrap! (get-quest-details quest-id) ERROR_QUEST_NOT_FOUND))
          (treasury-data (get-secured-funds quest-id)))
        
        (asserts! (is-eq tx-sender protocol-admin) ERROR_UNAUTHORIZED_EXECUTOR)
        (asserts! (is-eq (get quest-status quest-data) quest-status-disputed) ERROR_INVALID_QUEST_STATUS)
        (asserts! (<= client-refund-percentage u100) ERROR_INVALID_INPUT)
        (asserts! (> (len resolution-details) u0) ERROR_INVALID_INPUT)
        
        (let ((client-refund-amount (/ (* (get secured-funds treasury-data) client-refund-percentage) u100))
              (executor-reward-amount (- (get secured-funds treasury-data) client-refund-amount)))
            
            ;; Process client refund
            (if (> client-refund-amount u0)
                (try! (as-contract (stx-transfer? 
                    client-refund-amount
                    (as-contract tx-sender)
                    (get client-address quest-data)
                )))
                true
            )
            
            ;; Process executor reward
            (if (> executor-reward-amount u0)
                (try! (as-contract (stx-transfer? 
                    executor-reward-amount
                    (as-contract tx-sender)
                    (get executor-address quest-data)
                )))
                true
            )
            
            ;; Update dispute resolution
            (let ((dispute-data (unwrap! (get-dispute-details quest-id) ERROR_QUEST_NOT_FOUND)))
                (map-set protocol-disputes
                    { quest-id: quest-id }
                    (merge dispute-data { admin-resolution: (some resolution-details) })
                )
            )
            
            ;; Clear treasury and update status
            (map-set escrow-treasury
                { quest-id: quest-id }
                { secured-funds: u0 }
            )
            
            (map-set quest-registry
                { quest-id: quest-id }
                (merge quest-data { quest-status: quest-status-completed })
            )
            
            (ok true)
        )
    )
)

(define-public (terminate-quest (quest-id uint))
    (let ((quest-data (unwrap! (get-quest-details quest-id) ERROR_QUEST_NOT_FOUND))
          (treasury-data (get-secured-funds quest-id)))
        
        (asserts! (verify-quest-stakeholder quest-id) ERROR_UNAUTHORIZED_EXECUTOR)
        (asserts! (is-eq (get quest-status quest-data) quest-status-posted) ERROR_INVALID_QUEST_STATUS)
        
        ;; Return secured funds to client
        (if (> (get secured-funds treasury-data) u0)
            (try! (as-contract (stx-transfer? 
                (get secured-funds treasury-data)
                (as-contract tx-sender)
                (get client-address quest-data)
            )))
            true
        )
        
        (map-set escrow-treasury
            { quest-id: quest-id }
            { secured-funds: u0 }
        )
        
        (map-set quest-registry
            { quest-id: quest-id }
            (merge quest-data { quest-status: quest-status-cancelled })
        )
        
        (ok true)
    )
)