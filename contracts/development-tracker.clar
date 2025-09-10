;; Development Tracker Smart Contract
;; Tracks fusion energy project milestones, research progress, and development metrics

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-PROJECT-NOT-FOUND (err u501))
(define-constant ERR-PROJECT-EXISTS (err u502))
(define-constant ERR-MILESTONE-NOT-FOUND (err u503))
(define-constant ERR-MILESTONE-EXISTS (err u504))
(define-constant ERR-INVALID-DATA (err u505))
(define-constant ERR-MILESTONE-COMPLETED (err u506))
(define-constant ERR-UNAUTHORIZED-VALIDATOR (err u507))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-MILESTONES-PER-PROJECT u20)
(define-constant MAX-PROJECT-DESCRIPTION u1000)
(define-constant MAX-MILESTONE-DESCRIPTION u500)

;; Data variables
(define-data-var project-counter uint u0)
(define-data-var milestone-counter uint u0)
(define-data-var report-counter uint u0)

;; Fusion energy project registry
(define-map fusion-projects uint {
  project-id: uint,
  lead-researcher: principal,
  project-name: (string-ascii 200),
  description: (string-ascii 1000),
  technology-type: (string-ascii 100),
  target-energy-output: uint,
  estimated-timeline: uint,
  total-milestones: uint,
  completed-milestones: uint,
  current-phase: (string-ascii 50),
  funding-required: uint,
  created-date: uint,
  last-updated: uint,
  is-active: bool
})

;; Project milestones
(define-map project-milestones {project-id: uint, milestone-id: uint} {
  milestone-name: (string-ascii 200),
  description: (string-ascii 500),
  target-date: uint,
  completion-criteria: (string-ascii 400),
  funding-release: uint,
  is-completed: bool,
  completion-date: (optional uint),
  validator: (optional principal),
  evidence-hash: (optional (buff 32)),
  created-date: uint
})

;; Progress reports
(define-map progress-reports uint {
  project-id: uint,
  milestone-id: uint,
  researcher: principal,
  report-date: uint,
  progress-percentage: uint,
  technical-details: (string-ascii 800),
  challenges: (string-ascii 400),
  next-steps: (string-ascii 400),
  energy-metrics: (optional uint),
  verified: bool,
  validator: (optional principal)
})

;; Authorized research institutions
(define-map authorized-researchers principal {
  institution: (string-ascii 200),
  specialization: (string-ascii 100),
  credentials-hash: (buff 32),
  authorization-date: uint,
  is-active: bool
})

;; Milestone validators (scientific review board)
(define-map milestone-validators principal {
  expertise-area: (string-ascii 100),
  reputation-score: uint,
  validations-completed: uint,
  authorization-date: uint,
  is-active: bool
})

;; Project milestone counters
(define-map project-milestone-count uint uint)

;; Initialize contract owner as authorized researcher and validator
(map-set authorized-researchers CONTRACT-OWNER {
  institution: "Contract Administration",
  specialization: "System Management",
  credentials-hash: 0x0000000000000000000000000000000000000000000000000000000000000000,
  authorization-date: u0,
  is-active: true
})

(map-set milestone-validators CONTRACT-OWNER {
  expertise-area: "System Validation",
  reputation-score: u100,
  validations-completed: u0,
  authorization-date: u0,
  is-active: true
})

;; Public functions

;; Register new fusion energy project
(define-public (register-project
    (project-name (string-ascii 200))
    (description (string-ascii 1000))
    (technology-type (string-ascii 100))
    (target-energy-output uint)
    (estimated-timeline uint)
    (funding-required uint)
  )
  (let (
    (project-id (var-get project-counter))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (researcher-info (unwrap! (map-get? authorized-researchers tx-sender) ERR-NOT-AUTHORIZED))
  )
    ;; Validate researcher authorization
    (asserts! (get is-active researcher-info) ERR-NOT-AUTHORIZED)
    
    ;; Validate inputs
    (asserts! (> (len project-name) u0) ERR-INVALID-DATA)
    (asserts! (> target-energy-output u0) ERR-INVALID-DATA)
    (asserts! (> funding-required u0) ERR-INVALID-DATA)
    
    ;; Register project
    (map-set fusion-projects project-id {
      project-id: project-id,
      lead-researcher: tx-sender,
      project-name: project-name,
      description: description,
      technology-type: technology-type,
      target-energy-output: target-energy-output,
      estimated-timeline: estimated-timeline,
      total-milestones: u0,
      completed-milestones: u0,
      current-phase: "PLANNING",
      funding-required: funding-required,
      created-date: current-time,
      last-updated: current-time,
      is-active: true
    })
    
    ;; Initialize milestone counter for project
    (map-set project-milestone-count project-id u0)
    
    ;; Update global counter
    (var-set project-counter (+ project-id u1))
    
    (ok project-id)
  )
)

;; Add milestone to project
(define-public (add-milestone
    (project-id uint)
    (milestone-name (string-ascii 200))
    (description (string-ascii 500))
    (target-date uint)
    (completion-criteria (string-ascii 400))
    (funding-release uint)
  )
  (let (
    (project-info (unwrap! (map-get? fusion-projects project-id) ERR-PROJECT-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (milestone-id (default-to u0 (map-get? project-milestone-count project-id)))
    (total-milestones (get total-milestones project-info))
  )
    ;; Validate project ownership
    (asserts! (is-eq tx-sender (get lead-researcher project-info)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active project-info) ERR-NOT-AUTHORIZED)
    
    ;; Check milestone limit
    (asserts! (< total-milestones MAX-MILESTONES-PER-PROJECT) ERR-INVALID-DATA)
    
    ;; Validate inputs
    (asserts! (> (len milestone-name) u0) ERR-INVALID-DATA)
    (asserts! (> funding-release u0) ERR-INVALID-DATA)
    
    ;; Create milestone
    (map-set project-milestones {project-id: project-id, milestone-id: milestone-id} {
      milestone-name: milestone-name,
      description: description,
      target-date: target-date,
      completion-criteria: completion-criteria,
      funding-release: funding-release,
      is-completed: false,
      completion-date: none,
      validator: none,
      evidence-hash: none,
      created-date: current-time
    })
    
    ;; Update project milestone count
    (map-set project-milestone-count project-id (+ milestone-id u1))
    
    ;; Update project total milestones
    (map-set fusion-projects project-id {
      project-id: (get project-id project-info),
      lead-researcher: (get lead-researcher project-info),
      project-name: (get project-name project-info),
      description: (get description project-info),
      technology-type: (get technology-type project-info),
      target-energy-output: (get target-energy-output project-info),
      estimated-timeline: (get estimated-timeline project-info),
      total-milestones: (+ total-milestones u1),
      completed-milestones: (get completed-milestones project-info),
      current-phase: (get current-phase project-info),
      funding-required: (get funding-required project-info),
      created-date: (get created-date project-info),
      last-updated: current-time,
      is-active: (get is-active project-info)
    })
    
    (ok milestone-id)
  )
)

;; Submit progress report
(define-public (submit-progress-report
    (project-id uint)
    (milestone-id uint)
    (progress-percentage uint)
    (technical-details (string-ascii 800))
    (challenges (string-ascii 400))
    (next-steps (string-ascii 400))
    (energy-metrics (optional uint))
  )
  (let (
    (project-info (unwrap! (map-get? fusion-projects project-id) ERR-PROJECT-NOT-FOUND))
    (milestone-info (unwrap! (map-get? project-milestones {project-id: project-id, milestone-id: milestone-id}) ERR-MILESTONE-NOT-FOUND))
    (report-id (var-get report-counter))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    ;; Validate project ownership
    (asserts! (is-eq tx-sender (get lead-researcher project-info)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active project-info) ERR-NOT-AUTHORIZED)
    
    ;; Validate progress percentage
    (asserts! (<= progress-percentage u100) ERR-INVALID-DATA)
    
    ;; Create progress report
    (map-set progress-reports report-id {
      project-id: project-id,
      milestone-id: milestone-id,
      researcher: tx-sender,
      report-date: current-time,
      progress-percentage: progress-percentage,
      technical-details: technical-details,
      challenges: challenges,
      next-steps: next-steps,
      energy-metrics: energy-metrics,
      verified: false,
      validator: none
    })
    
    ;; Update report counter
    (var-set report-counter (+ report-id u1))
    
    (ok report-id)
  )
)

;; Validate milestone completion
(define-public (validate-milestone
    (project-id uint)
    (milestone-id uint)
    (evidence-hash (buff 32))
    (validation-approved bool)
  )
  (let (
    (project-info (unwrap! (map-get? fusion-projects project-id) ERR-PROJECT-NOT-FOUND))
    (milestone-info (unwrap! (map-get? project-milestones {project-id: project-id, milestone-id: milestone-id}) ERR-MILESTONE-NOT-FOUND))
    (validator-info (unwrap! (map-get? milestone-validators tx-sender) ERR-UNAUTHORIZED-VALIDATOR))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    ;; Validate validator authorization
    (asserts! (get is-active validator-info) ERR-UNAUTHORIZED-VALIDATOR)
    
    ;; Check milestone not already completed
    (asserts! (not (get is-completed milestone-info)) ERR-MILESTONE-COMPLETED)
    
    ;; Update milestone status
    (map-set project-milestones {project-id: project-id, milestone-id: milestone-id} {
      milestone-name: (get milestone-name milestone-info),
      description: (get description milestone-info),
      target-date: (get target-date milestone-info),
      completion-criteria: (get completion-criteria milestone-info),
      funding-release: (get funding-release milestone-info),
      is-completed: validation-approved,
      completion-date: (if validation-approved (some current-time) none),
      validator: (some tx-sender),
      evidence-hash: (some evidence-hash),
      created-date: (get created-date milestone-info)
    })
    
    ;; If milestone approved, update project completed count
    (if validation-approved
      (map-set fusion-projects project-id {
        project-id: (get project-id project-info),
        lead-researcher: (get lead-researcher project-info),
        project-name: (get project-name project-info),
        description: (get description project-info),
        technology-type: (get technology-type project-info),
        target-energy-output: (get target-energy-output project-info),
        estimated-timeline: (get estimated-timeline project-info),
        total-milestones: (get total-milestones project-info),
        completed-milestones: (+ (get completed-milestones project-info) u1),
        current-phase: "IN-PROGRESS",
        funding-required: (get funding-required project-info),
        created-date: (get created-date project-info),
        last-updated: current-time,
        is-active: (get is-active project-info)
      })
      true
    )
    
    ;; Update validator statistics
    (map-set milestone-validators tx-sender {
      expertise-area: (get expertise-area validator-info),
      reputation-score: (get reputation-score validator-info),
      validations-completed: (+ (get validations-completed validator-info) u1),
      authorization-date: (get authorization-date validator-info),
      is-active: (get is-active validator-info)
    })
    
    (ok validation-approved)
  )
)

;; Admin functions

;; Authorize new researcher
(define-public (authorize-researcher
    (researcher principal)
    (institution (string-ascii 200))
    (specialization (string-ascii 100))
    (credentials-hash (buff 32))
  )
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set authorized-researchers researcher {
      institution: institution,
      specialization: specialization,
      credentials-hash: credentials-hash,
      authorization-date: current-time,
      is-active: true
    })
    
    (ok true)
  )
)

;; Authorize new milestone validator
(define-public (authorize-validator
    (validator principal)
    (expertise-area (string-ascii 100))
    (initial-reputation uint)
  )
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set milestone-validators validator {
      expertise-area: expertise-area,
      reputation-score: initial-reputation,
      validations-completed: u0,
      authorization-date: current-time,
      is-active: true
    })
    
    (ok true)
  )
)

;; Read-only functions

;; Get project information
(define-read-only (get-project (project-id uint))
  (map-get? fusion-projects project-id)
)

;; Get milestone information
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? project-milestones {project-id: project-id, milestone-id: milestone-id})
)

;; Get progress report
(define-read-only (get-progress-report (report-id uint))
  (map-get? progress-reports report-id)
)

;; Check researcher authorization
(define-read-only (is-authorized-researcher (researcher principal))
  (match (map-get? authorized-researchers researcher)
    researcher-data (get is-active researcher-data)
    false
  )
)

;; Check validator authorization
(define-read-only (is-authorized-validator (validator principal))
  (match (map-get? milestone-validators validator)
    validator-data (get is-active validator-data)
    false
  )
)

;; Get project milestone count
(define-read-only (get-project-milestone-count (project-id uint))
  (default-to u0 (map-get? project-milestone-count project-id))
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-projects: (var-get project-counter),
    total-milestones: (var-get milestone-counter),
    total-reports: (var-get report-counter),
    contract-owner: CONTRACT-OWNER
  }
)


;; title: development-tracker
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

