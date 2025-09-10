;; Energy Fund Smart Contract
;; Manages investment pooling, fund distribution, and investor returns for fusion energy projects

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u600))
(define-constant ERR-INSUFFICIENT-FUNDS (err u601))
(define-constant ERR-INVALID-AMOUNT (err u602))
(define-constant ERR-PROJECT-NOT-FOUND (err u603))
(define-constant ERR-INVESTMENT-NOT-FOUND (err u604))
(define-constant ERR-MILESTONE-NOT-COMPLETED (err u605))
(define-constant ERR-FUNDS-ALREADY_RELEASED (err u606))
(define-constant ERR-INVALID-PERCENTAGE (err u607))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-INVESTMENT u1000000) ;; 1 STX minimum
(define-constant MAX-INVESTMENT u100000000000) ;; 100,000 STX maximum
(define-constant MANAGEMENT-FEE-RATE u5) ;; 5% management fee
(define-constant SUCCESS-BONUS-RATE u10) ;; 10% bonus for successful projects

;; Data variables
(define-data-var total-fund-balance uint u0)
(define-data-var total-investments uint u0)
(define-data-var investment-counter uint u0)
(define-data-var fund-paused bool false)

;; Investment pool tracking
(define-map investor-portfolios principal {
  total-invested: uint,
  total-returns: uint,
  active-investments: uint,
  investment-count: uint,
  last-investment-date: uint,
  risk-profile: (string-ascii 20)
})

;; Individual investment records
(define-map investment-records uint {
  investor: principal,
  project-id: uint,
  amount-invested: uint,
  investment-date: uint,
  expected-return-rate: uint,
  risk-level: (string-ascii 20),
  is-active: bool,
  returns-claimed: uint,
  last-return-date: (optional uint)
})

;; Project funding tracking
(define-map project-funding uint {
  project-id: uint,
  total-raised: uint,
  funding-target: uint,
  funds-released: uint,
  investor-count: uint,
  funding-phase: (string-ascii 30),
  expected-returns: uint,
  actual-returns: uint,
  completion-bonus: uint,
  is-fully-funded: bool
})

;; Milestone funding releases
(define-map milestone-releases {project-id: uint, milestone-id: uint} {
  release-amount: uint,
  release-date: uint,
  approved-by: principal,
  conditions-met: bool,
  funds-distributed: bool
})

;; Return distributions
(define-map return-distributions uint {
  project-id: uint,
  distribution-date: uint,
  total-amount: uint,
  per-token-rate: uint,
  distribution-type: (string-ascii 30),
  completed: bool
})

;; Authorized fund managers
(define-map fund-managers principal {
  authorization-date: uint,
  permissions-level: uint,
  projects-managed: uint,
  is-active: bool
})

;; Distribution counter
(define-data-var distribution-counter uint u0)

;; Initialize contract owner as fund manager
(map-set fund-managers CONTRACT-OWNER {
  authorization-date: u0,
  permissions-level: u100,
  projects-managed: u0,
  is-active: true
})

;; Public functions

;; Invest in fusion energy fund
(define-public (invest-in-fund
    (project-id uint)
    (amount uint)
    (risk-profile (string-ascii 20))
  )
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (investment-id (var-get investment-counter))
    (investor-portfolio (default-to {total-invested: u0, total-returns: u0, active-investments: u0, investment-count: u0, last-investment-date: u0, risk-profile: "MODERATE"} (map-get? investor-portfolios tx-sender)))
    (project-funding-info (default-to {project-id: project-id, total-raised: u0, funding-target: u0, funds-released: u0, investor-count: u0, funding-phase: "INITIAL", expected-returns: u0, actual-returns: u0, completion-bonus: u0, is-fully-funded: false} (map-get? project-funding project-id)))
  )
    ;; Validate investment amount
    (asserts! (>= amount MIN-INVESTMENT) ERR-INVALID-AMOUNT)
    (asserts! (<= amount MAX-INVESTMENT) ERR-INVALID-AMOUNT)
    (asserts! (not (var-get fund-paused)) ERR-NOT-AUTHORIZED)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Create investment record
    (map-set investment-records investment-id {
      investor: tx-sender,
      project-id: project-id,
      amount-invested: amount,
      investment-date: current-time,
      expected-return-rate: (calculate-expected-return risk-profile),
      risk-level: risk-profile,
      is-active: true,
      returns-claimed: u0,
      last-return-date: none
    })
    
    ;; Update investor portfolio
    (map-set investor-portfolios tx-sender {
      total-invested: (+ (get total-invested investor-portfolio) amount),
      total-returns: (get total-returns investor-portfolio),
      active-investments: (+ (get active-investments investor-portfolio) u1),
      investment-count: (+ (get investment-count investor-portfolio) u1),
      last-investment-date: current-time,
      risk-profile: risk-profile
    })
    
    ;; Update project funding
    (map-set project-funding project-id {
      project-id: project-id,
      total-raised: (+ (get total-raised project-funding-info) amount),
      funding-target: (get funding-target project-funding-info),
      funds-released: (get funds-released project-funding-info),
      investor-count: (+ (get investor-count project-funding-info) u1),
      funding-phase: "ACTIVE",
      expected-returns: (get expected-returns project-funding-info),
      actual-returns: (get actual-returns project-funding-info),
      completion-bonus: (get completion-bonus project-funding-info),
      is-fully-funded: (get is-fully-funded project-funding-info)
    })
    
    ;; Update global tracking
    (var-set total-fund-balance (+ (var-get total-fund-balance) amount))
    (var-set total-investments (+ (var-get total-investments) amount))
    (var-set investment-counter (+ investment-id u1))
    
    (ok investment-id)
  )
)

;; Release milestone funding
(define-public (release-milestone-funding
    (project-id uint)
    (milestone-id uint)
    (release-amount uint)
    (conditions-verified bool)
  )
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (manager-info (unwrap! (map-get? fund-managers tx-sender) ERR-NOT-AUTHORIZED))
    (project-funding-info (unwrap! (map-get? project-funding project-id) ERR-PROJECT-NOT-FOUND))
  )
    ;; Validate manager authorization
    (asserts! (get is-active manager-info) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get permissions-level manager-info) u50) ERR-NOT-AUTHORIZED)
    
    ;; Validate conditions and funding availability
    (asserts! conditions-verified ERR-MILESTONE-NOT-COMPLETED)
    (asserts! (<= release-amount (var-get total-fund-balance)) ERR-INSUFFICIENT-FUNDS)
    
    ;; Check if milestone funding already released
    (asserts! (is-none (map-get? milestone-releases {project-id: project-id, milestone-id: milestone-id})) ERR-FUNDS-ALREADY_RELEASED)
    
    ;; Record milestone release
    (map-set milestone-releases {project-id: project-id, milestone-id: milestone-id} {
      release-amount: release-amount,
      release-date: current-time,
      approved-by: tx-sender,
      conditions-met: conditions-verified,
      funds-distributed: true
    })
    
    ;; Update project funding tracking
    (map-set project-funding project-id {
      project-id: (get project-id project-funding-info),
      total-raised: (get total-raised project-funding-info),
      funding-target: (get funding-target project-funding-info),
      funds-released: (+ (get funds-released project-funding-info) release-amount),
      investor-count: (get investor-count project-funding-info),
      funding-phase: "DEPLOYED",
      expected-returns: (get expected-returns project-funding-info),
      actual-returns: (get actual-returns project-funding-info),
      completion-bonus: (get completion-bonus project-funding-info),
      is-fully-funded: (get is-fully-funded project-funding-info)
    })
    
    ;; Deduct from fund balance
    (var-set total-fund-balance (- (var-get total-fund-balance) release-amount))
    
    (ok release-amount)
  )
)

;; Distribute returns to investors
(define-public (distribute-returns
    (project-id uint)
    (total-return-amount uint)
    (distribution-type (string-ascii 30))
  )
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (distribution-id (var-get distribution-counter))
    (manager-info (unwrap! (map-get? fund-managers tx-sender) ERR-NOT-AUTHORIZED))
    (project-funding-info (unwrap! (map-get? project-funding project-id) ERR-PROJECT-NOT-FOUND))
    (management-fee (* total-return-amount MANAGEMENT-FEE-RATE))
    (net-returns (- total-return-amount (/ management-fee u100)))
  )
    ;; Validate manager authorization
    (asserts! (get is-active manager-info) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get permissions-level manager-info) u75) ERR-NOT-AUTHORIZED)
    
    ;; Validate return amount
    (asserts! (> total-return-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Record distribution
    (map-set return-distributions distribution-id {
      project-id: project-id,
      distribution-date: current-time,
      total-amount: total-return-amount,
      per-token-rate: (/ net-returns (get total-raised project-funding-info)),
      distribution-type: distribution-type,
      completed: false
    })
    
    ;; Update project funding with actual returns
    (map-set project-funding project-id {
      project-id: (get project-id project-funding-info),
      total-raised: (get total-raised project-funding-info),
      funding-target: (get funding-target project-funding-info),
      funds-released: (get funds-released project-funding-info),
      investor-count: (get investor-count project-funding-info),
      funding-phase: "RETURNING",
      expected-returns: (get expected-returns project-funding-info),
      actual-returns: (+ (get actual-returns project-funding-info) net-returns),
      completion-bonus: (get completion-bonus project-funding-info),
      is-fully-funded: (get is-fully-funded project-funding-info)
    })
    
    ;; Update distribution counter
    (var-set distribution-counter (+ distribution-id u1))
    
    (ok distribution-id)
  )
)

;; Claim investment returns
(define-public (claim-returns (investment-id uint))
  (let (
    (investment-info (unwrap! (map-get? investment-records investment-id) ERR-INVESTMENT-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (investor-portfolio (unwrap! (map-get? investor-portfolios (get investor investment-info)) ERR-INVESTMENT-NOT-FOUND))
  )
    ;; Validate investor ownership
    (asserts! (is-eq tx-sender (get investor investment-info)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active investment-info) ERR-NOT-AUTHORIZED)
    
    ;; Calculate available returns (simplified calculation)
    (let (
      (return-amount (* (get amount-invested investment-info) (get expected-return-rate investment-info)))
      (net-return (/ return-amount u100))
    )
      ;; Transfer returns to investor
      (try! (as-contract (stx-transfer? net-return tx-sender (get investor investment-info))))
      
      ;; Update investment record
      (map-set investment-records investment-id {
        investor: (get investor investment-info),
        project-id: (get project-id investment-info),
        amount-invested: (get amount-invested investment-info),
        investment-date: (get investment-date investment-info),
        expected-return-rate: (get expected-return-rate investment-info),
        risk-level: (get risk-level investment-info),
        is-active: false,
        returns-claimed: (+ (get returns-claimed investment-info) net-return),
        last-return-date: (some current-time)
      })
      
      ;; Update investor portfolio
      (map-set investor-portfolios (get investor investment-info) {
        total-invested: (get total-invested investor-portfolio),
        total-returns: (+ (get total-returns investor-portfolio) net-return),
        active-investments: (- (get active-investments investor-portfolio) u1),
        investment-count: (get investment-count investor-portfolio),
        last-investment-date: (get last-investment-date investor-portfolio),
        risk-profile: (get risk-profile investor-portfolio)
      })
      
      (ok net-return)
    )
  )
)

;; Admin functions

;; Authorize fund manager
(define-public (authorize-fund-manager
    (manager principal)
    (permissions-level uint)
  )
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= permissions-level u100) ERR-INVALID-PERCENTAGE)
    
    (map-set fund-managers manager {
      authorization-date: current-time,
      permissions-level: permissions-level,
      projects-managed: u0,
      is-active: true
    })
    
    (ok true)
  )
)

;; Set fund pause status
(define-public (set-fund-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set fund-paused paused)
    (ok paused)
  )
)

;; Emergency withdraw
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get total-fund-balance)) ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    (var-set total-fund-balance (- (var-get total-fund-balance) amount))
    
    (ok amount)
  )
)

;; Read-only functions

;; Get investor portfolio
(define-read-only (get-investor-portfolio (investor principal))
  (map-get? investor-portfolios investor)
)

;; Get investment record
(define-read-only (get-investment-record (investment-id uint))
  (map-get? investment-records investment-id)
)

;; Get project funding info
(define-read-only (get-project-funding (project-id uint))
  (map-get? project-funding project-id)
)

;; Get milestone release info
(define-read-only (get-milestone-release (project-id uint) (milestone-id uint))
  (map-get? milestone-releases {project-id: project-id, milestone-id: milestone-id})
)

;; Get return distribution
(define-read-only (get-return-distribution (distribution-id uint))
  (map-get? return-distributions distribution-id)
)

;; Check if principal is fund manager
(define-read-only (is-fund-manager (manager principal))
  (match (map-get? fund-managers manager)
    manager-data (get is-active manager-data)
    false
  )
)

;; Get fund statistics
(define-read-only (get-fund-stats)
  {
    total-fund-balance: (var-get total-fund-balance),
    total-investments: (var-get total-investments),
    investment-count: (var-get investment-counter),
    distribution-count: (var-get distribution-counter),
    is-paused: (var-get fund-paused),
    contract-owner: CONTRACT-OWNER
  }
)

;; Private helper functions

;; Calculate expected return based on risk profile
(define-private (calculate-expected-return (risk-profile (string-ascii 20)))
  (if (is-eq risk-profile "LOW")
    u8  ;; 8% expected return
    (if (is-eq risk-profile "MODERATE")
      u15 ;; 15% expected return
      u25 ;; 25% expected return for HIGH risk
    )
  )
)


;; title: energy-fund
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

