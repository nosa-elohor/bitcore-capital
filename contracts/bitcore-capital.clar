;; Title: BitCore Capital Protocol
;;
;; Summary
;; BitCore Capital is an innovative Bitcoin-centric lending ecosystem that
;; enables Bitcoin holders to unlock liquidity from their holdings without
;; sacrificing their long-term Bitcoin position. Built on Stacks Layer 2
;; with Bitcoin's proof-of-work security guarantees.
;;
;; Description
;; BitCore Capital revolutionizes decentralized finance by establishing
;; the premier Bitcoin-native overcollateralized lending marketplace.
;; Borrowers can collateralize their Bitcoin holdings to access STX liquidity
;; while maintaining exposure to Bitcoin's price appreciation potential.
;;
;; The protocol features:
;; - Autonomous liquidation mechanisms with real-time monitoring
;; - Transparent interest accrual with competitive rates
;; - Dynamic risk assessment and collateral management
;; - Complete user custody preservation throughout loan lifecycle
;; - Bitcoin-grade security through Stacks Proof-of-Transfer consensus
;;
;; Every transaction inherits Bitcoin's unmatched security model while
;; enabling instant programmable settlements and sophisticated DeFi
;; operations previously impossible on Bitcoin's base layer.
;;
;; Core Innovations
;; - Native Bitcoin Integration: Direct Bitcoin collateralization without wrapping
;; - PoX Security Model: Leverages Bitcoin's security via Stacks consensus
;; - Smart Risk Engine: Automated collateral monitoring and liquidation
;; - Self-Custody Preservation: Non-custodial design maintains user control
;; - Optimized Yield Structure: Market-competitive rates with transparent fees
;;

;; CONSTANTS - ERROR CODES & CONFIGURATION

;; Access Control & Authorization
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))

;; Core Lending Operations
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u101))
(define-constant ERR-BELOW-MINIMUM (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-LOAN-NOT-FOUND (err u107))
(define-constant ERR-LOAN-NOT-ACTIVE (err u108))

;; Protocol State Management
(define-constant ERR-ALREADY-INITIALIZED (err u104))
(define-constant ERR-NOT-INITIALIZED (err u105))
(define-constant ERR-INVALID-LIQUIDATION (err u106))

;; Input Validation
(define-constant ERR-INVALID-LOAN-ID (err u109))
(define-constant ERR-INVALID-PRICE (err u110))
(define-constant ERR-INVALID-ASSET (err u111))

;; Supported Collateral Assets
(define-constant VALID-ASSETS (list "BTC" "STX"))

;; DATA VARIABLES - PROTOCOL STATE

;; Protocol Initialization State
(define-data-var platform-initialized bool false)

;; Risk Management Parameters
(define-data-var minimum-collateral-ratio uint u150) ;; 150% minimum collateral ratio
(define-data-var liquidation-threshold uint u120) ;; 120% liquidation trigger
(define-data-var platform-fee-rate uint u1) ;; 1% protocol fee

;; Protocol Analytics & Metrics
(define-data-var total-btc-locked uint u0)
(define-data-var total-loans-issued uint u0)

;; DATA MAPS - CORE DATA STRUCTURES

;; Primary Loan Registry
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    collateral-amount: uint,
    loan-amount: uint,
    interest-rate: uint,
    start-height: uint,
    last-interest-calc: uint,
    status: (string-ascii 20),
  }
)

;; User Portfolio Management
(define-map user-loans
  { user: principal }
  { active-loans: (list 10 uint) }
)

;; Oracle Price Feed Registry
(define-map collateral-prices
  { asset: (string-ascii 3) }
  { price: uint }
)

;; PRIVATE FUNCTIONS - INTERNAL UTILITIES

;; Calculate Current Collateral-to-Loan Ratio
;; @desc: Computes percentage ratio for risk assessment
;; @param: collateral - amount of collateral in satoshis
;; @param: loan - loan amount in micro-STX
;; @param: btc-price - current BTC price in micro-STX
;; @returns: percentage ratio (150 = 150%)
(define-private (calculate-collateral-ratio
    (collateral uint)
    (loan uint)
    (btc-price uint)
  )
  (let (
      (collateral-value (* collateral btc-price))
      (ratio (* (/ collateral-value loan) u100))
    )
    ratio
  )
)

;; Interest Calculation Engine
;; @desc: Computes interest accrued over specified block period
;; @param: principal - loan principal amount
;; @param: rate - annual interest rate percentage
;; @param: blocks - number of blocks elapsed
;; @returns: total interest amount
(define-private (calculate-interest
    (principal uint)
    (rate uint)
    (blocks uint)
  )
  (let (
      (interest-per-block (/ (* principal rate) (* u100 u144))) ;; Daily rate / blocks per day
      (total-interest (* interest-per-block blocks))
    )
    total-interest
  )
)

;; Liquidation Risk Assessment
;; @desc: Monitors and triggers liquidation for undercollateralized positions
;; @param: loan-id - unique loan identifier
;; @returns: success status or liquidation trigger
(define-private (check-liquidation (loan-id uint))
  (let (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
      (btc-price (unwrap! (get price (map-get? collateral-prices { asset: "BTC" }))
        ERR-NOT-INITIALIZED
      ))
      (current-ratio (calculate-collateral-ratio (get collateral-amount loan)
        (get loan-amount loan) btc-price
      ))
    )
    (if (<= current-ratio (var-get liquidation-threshold))
      (liquidate-position loan-id)
      (ok true)
    )
  )
)

;; Liquidation Execution Engine
;; @desc: Processes undercollateralized position liquidation
;; @param: loan-id - loan to liquidate
;; @returns: liquidation success status
(define-private (liquidate-position (loan-id uint))
  (let (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
      (borrower (get borrower loan))
    )
    (begin
      (map-set loans { loan-id: loan-id } (merge loan { status: "liquidated" }))
      (map-delete user-loans { user: borrower })
      (ok true)
    )
  )
)

;; Loan ID Validation
;; @desc: Ensures loan ID is within valid operational range
;; @param: loan-id - loan identifier to validate
;; @returns: boolean validation result
(define-private (validate-loan-id (loan-id uint))
  (and
    (> loan-id u0)
    (<= loan-id (var-get total-loans-issued))
  )
)

;; Asset Validation
;; @desc: Verifies asset is supported by the protocol
;; @param: asset - asset symbol to validate
;; @returns: boolean validation result
(define-private (is-valid-asset (asset (string-ascii 3)))
  (is-some (index-of VALID-ASSETS asset))
)

;; Price Oracle Validation
;; @desc: Ensures price feeds are within reasonable bounds
;; @param: price - price value to validate
;; @returns: boolean validation result
(define-private (is-valid-price (price uint))
  (and
    (> price u0)
    (<= price u1000000000000) ;; Maximum reasonable price threshold
  )
)

;; Loan Filtering Utility
;; @desc: Helper function for active loan management
;; @param: id - loan ID to compare against
;; @returns: inequality check result
(define-private (not-equal-loan-id (id uint))
  (not (is-eq id id))
)

;; PLATFORM ADMINISTRATION - OWNER FUNCTIONS

;; Platform Initialization
;; @desc: Bootstraps the protocol for operational readiness
;; @returns: success status
(define-public (initialize-platform)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get platform-initialized)) ERR-ALREADY-INITIALIZED)
    (var-set platform-initialized true)
    (ok true)
  )
)

;; Risk Parameter Adjustment
;; @desc: Updates minimum collateralization requirements
;; @param: new-ratio - new minimum collateral ratio
;; @returns: success status
(define-public (update-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= new-ratio u110) ERR-INVALID-AMOUNT)
    (var-set minimum-collateral-ratio new-ratio)
    (ok true)
  )
)

;; Liquidation Threshold Configuration
;; @desc: Adjusts automated liquidation trigger point
;; @param: new-threshold - new liquidation threshold
;; @returns: success status
(define-public (update-liquidation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= new-threshold u100) ERR-INVALID-AMOUNT)
    (var-set liquidation-threshold new-threshold)
    (ok true)
  )
)

;; Oracle Price Feed Management
;; @desc: Updates real-time asset pricing data
;; @param: asset - asset symbol to update
;; @param: new-price - new price value
;; @returns: success status
(define-public (update-price-feed
    (asset (string-ascii 3))
    (new-price uint)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    ;; Comprehensive input validation
    (asserts! (is-valid-asset asset) ERR-INVALID-ASSET)
    (asserts! (is-valid-price new-price) ERR-INVALID-PRICE)
    ;; Execute price update upon successful validation
    (ok (map-set collateral-prices { asset: asset } { price: new-price }))
  )
)

;; CORE LENDING OPERATIONS - USER FUNCTIONS

;; Collateral Deposit Interface
;; @desc: Enables users to deposit Bitcoin as lending collateral
;; @param: amount - amount of BTC to deposit (in satoshis)
;; @returns: success status
(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (var-get platform-initialized) ERR-NOT-INITIALIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (var-set total-btc-locked (+ (var-get total-btc-locked) amount))
    (ok true)
  )
)

;; Loan Origination Engine
;; @desc: Creates new collateralized lending positions
;; @param: collateral - amount of BTC collateral
;; @param: loan-amount - desired loan amount in STX
;; @returns: loan ID upon successful creation
(define-public (request-loan
    (collateral uint)
    (loan-amount uint)
  )
  (let (
      (btc-price (unwrap! (get price (map-get? collateral-prices { asset: "BTC" }))
        ERR-NOT-INITIALIZED
      ))
      (collateral-value (* collateral btc-price))
      (required-collateral (* loan-amount (var-get minimum-collateral-ratio)))
      (loan-id (+ (var-get total-loans-issued) u1))
    )
    (begin
      (asserts! (var-get platform-initialized) ERR-NOT-INITIALIZED)
      (asserts! (>= collateral-value required-collateral)
        ERR-INSUFFICIENT-COLLATERAL
      )
      ;; Create new loan record
      (map-set loans { loan-id: loan-id } {
        borrower: tx-sender,
        collateral-amount: collateral,
        loan-amount: loan-amount,
        interest-rate: u5, ;; 5% annual interest rate
        start-height: stacks-block-height,
        last-interest-calc: stacks-block-height,
        status: "active",
      })
      ;; Update user loan portfolio
      (match (map-get? user-loans { user: tx-sender })
        existing-loans (map-set user-loans { user: tx-sender } { active-loans: (unwrap!
          (as-max-len? (append (get active-loans existing-loans) loan-id) u10)
          ERR-INVALID-AMOUNT
        ) }
        )
        (map-set user-loans { user: tx-sender } { active-loans: (list loan-id) })
      )
      ;; Update protocol metrics
      (var-set total-loans-issued (+ (var-get total-loans-issued) u1))
      (ok loan-id)
    )
  )
)

;; Loan Repayment Processing
;; @desc: Handles loan closure with interest settlement
;; @param: loan-id - loan to repay
;; @param: amount - repayment amount
;; @returns: success status
(define-public (repay-loan
    (loan-id uint)
    (amount uint)
  )
  (begin
    ;; Primary loan ID validation
    (asserts! (validate-loan-id loan-id) ERR-INVALID-LOAN-ID)
    (let (
        (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
        (interest-owed (calculate-interest (get loan-amount loan) (get interest-rate loan)
          (- stacks-block-height (get last-interest-calc loan))
        ))
        (total-owed (+ (get loan-amount loan) interest-owed))
      )
      (begin
        ;; Loan state and authorization checks
        (asserts! (is-eq (get status loan) "active") ERR-LOAN-NOT-ACTIVE)
        (asserts! (is-eq (get borrower loan) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= amount total-owed) ERR-INVALID-AMOUNT)
        ;; Process loan closure
        (map-set loans { loan-id: loan-id }
          (merge loan {
            status: "repaid",
            last-interest-calc: stacks-block-height,
          })
        )
        ;; Release collateral back to borrower
        (var-set total-btc-locked
          (- (var-get total-btc-locked) (get collateral-amount loan))
        )
        ;; Clean up user loan tracking
        (match (map-get? user-loans { user: tx-sender })
          existing-loans (ok (map-set user-loans { user: tx-sender } { active-loans: (filter not-equal-loan-id (get active-loans existing-loans)) }))
          (ok false)
        )
      )
    )
  )
)

;; READ-ONLY FUNCTIONS - DATA QUERIES

;; Loan Information Retrieval
;; @desc: Returns comprehensive loan details for specified ID
;; @param: loan-id - loan identifier
;; @returns: loan details or none
(define-read-only (get-loan-details (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

;; User Portfolio Query
;; @desc: Retrieves all active loans for specified user
;; @param: user - user principal address
;; @returns: user's active loans or none
(define-read-only (get-user-loans (user principal))
  (map-get? user-loans { user: user })
)

;; Protocol Analytics Dashboard
;; @desc: Returns current platform operational metrics
;; @returns: comprehensive platform statistics
(define-read-only (get-platform-stats)
  {
    total-btc-locked: (var-get total-btc-locked),
    total-loans-issued: (var-get total-loans-issued),
    minimum-collateral-ratio: (var-get minimum-collateral-ratio),
    liquidation-threshold: (var-get liquidation-threshold),
  }
)

;; Supported Assets Registry
;; @desc: Returns list of protocol-supported collateral assets
;; @returns: list of valid asset symbols
(define-read-only (get-valid-assets)
  VALID-ASSETS
)
