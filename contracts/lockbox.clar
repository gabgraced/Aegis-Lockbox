;; Aegis Lockbox
;; Built for decentralized knowledge preservation and controlled dissemination

;; Response Status Codes
;; These represent various status responses during contract execution
(define-constant STATUS_UNAUTHORIZED (err u100))
(define-constant STATUS_INVALID_INPUT (err u101))
(define-constant STATUS_ITEM_NOT_FOUND (err u102))
(define-constant STATUS_ITEM_EXISTS (err u103))
(define-constant STATUS_NARRATIVE_ISSUE (err u104))
(define-constant STATUS_INSUFFICIENT_PRIVILEGES (err u105))
(define-constant STATUS_DURATION_ISSUE (err u106))
(define-constant STATUS_ROLE_MISMATCH (err u107))
(define-constant STATUS_CATEGORY_INVALID (err u108))
(define-constant SYSTEM_CONTROLLER tx-sender)

;; Access Tier Constants
;; Available privilege levels for vault access delegation
(define-constant ACCESS_BASIC "read")
(define-constant ACCESS_MODIFY "write")
(define-constant ACCESS_COMPLETE "admin")

;; System Counter Variables
;; Track system-wide metrics
(define-data-var vault-sequence uint u0)

;; Data Structure Definitions 
;; Main repository for all managed documents
(define-map vault-repository
    { vault-id: uint }
    {
        title: (string-ascii 50),
        owner: principal,
        fingerprint: (string-ascii 64),
        narrative: (string-ascii 200),
        creation-block: uint,
        modification-block: uint,
        category: (string-ascii 20),
        keywords: (list 5 (string-ascii 30))
    }
)

;; Privilege Management Table - Controls access delegation
(define-map vault-privileges
    { vault-id: uint, delegate: principal }
    {
        access-level: (string-ascii 10),
        issuance-time: uint,
        expiration-time: uint,
        modifications-allowed: bool
    }
)

;; ===== Input Validation Utilities =====
;; Functions to ensure data integrity and proper formatting

;; Validates document title structure and length
(define-private (is-title-valid? (title (string-ascii 50)))
    (and
        (> (len title) u0)
        (<= (len title) u50)
    )
)

;; Verifies document fingerprint meets cryptographic standards
(define-private (is-fingerprint-valid? (fingerprint (string-ascii 64)))
    (and
        (is-eq (len fingerprint) u64)
        (> (len fingerprint) u0)
    )
)

;; Ensures keyword collections are properly formatted
(define-private (are-keywords-valid? (keyword-set (list 5 (string-ascii 30))))
    (and
        (>= (len keyword-set) u1)
        (<= (len keyword-set) u5)
        (is-eq (len (filter is-keyword-valid? keyword-set)) (len keyword-set))
    )
)

;; Validates a single keyword's structure
(define-private (is-keyword-valid? (keyword (string-ascii 30)))
    (and
        (> (len keyword) u0)
        (<= (len keyword) u30)
    )
)

;; Verifies document narrative meets length requirements
(define-private (is-narrative-valid? (narrative (string-ascii 200)))
    (and
        (>= (len narrative) u1)
        (<= (len narrative) u200)
    )
)

;; Ensures document category is system-compliant
(define-private (is-category-valid? (category (string-ascii 20)))
    (and
        (>= (len category) u1)
        (<= (len category) u20)
    )
)

;; Validates privilege level against system standards
(define-private (is-access-level-valid? (access-level (string-ascii 10)))
    (or
        (is-eq access-level ACCESS_BASIC)
        (is-eq access-level ACCESS_MODIFY)
        (is-eq access-level ACCESS_COMPLETE)
    )
)

;; Verifies access duration is within acceptable boundaries
(define-private (is-duration-valid? (duration uint))
    (and
        (> duration u0)
        (<= duration u52560) ;; Approximately one year in blocks
    )
)

;; Prevents self-delegation of privileges
(define-private (is-delegate-valid? (delegate principal))
    (not (is-eq delegate tx-sender))
)

;; Verifies ownership claim on document
(define-private (is-vault-owner? (vault-id uint) (user principal))
    (match (map-get? vault-repository { vault-id: vault-id })
        document (is-eq (get owner document) user)
        false
    )
)

;; Confirms document exists in system
(define-private (does-vault-exist? (vault-id uint))
    (is-some (map-get? vault-repository { vault-id: vault-id }))
)

;; Validates modification permission flag
(define-private (is-modification-flag-valid? (modifications-allowed bool))
    (or (is-eq modifications-allowed true) (is-eq modifications-allowed false))
)

;; ===== Primary Interface Functions =====
;; Core functions for vault interactions

;; Creates a new document in the vault system
(define-public (register-document 
    (title (string-ascii 50))
    (fingerprint (string-ascii 64))
    (narrative (string-ascii 200))
    (category (string-ascii 20))
    (keywords (list 5 (string-ascii 30)))
)
    (let
        (
            (new-vault-id (+ (var-get vault-sequence) u1))
            (current-time block-height)
        )
        ;; Input validation checks
        (asserts! (is-title-valid? title) STATUS_INVALID_INPUT)
        (asserts! (is-fingerprint-valid? fingerprint) STATUS_INVALID_INPUT)
        (asserts! (is-narrative-valid? narrative) STATUS_NARRATIVE_ISSUE)
        (asserts! (is-category-valid? category) STATUS_CATEGORY_INVALID)
        (asserts! (are-keywords-valid? keywords) STATUS_NARRATIVE_ISSUE)

        ;; Document registration
        (map-set vault-repository
            { vault-id: new-vault-id }
            {
                title: title,
                owner: tx-sender,
                fingerprint: fingerprint,
                narrative: narrative,
                creation-block: current-time,
                modification-block: current-time,
                category: category,
                keywords: keywords
            }
        )

        ;; Update system counter
        (var-set vault-sequence new-vault-id)
        (ok new-vault-id)
    )
)

;; Updates an existing document with new information
(define-public (update-document
    (vault-id uint)
    (new-title (string-ascii 50))
    (new-fingerprint (string-ascii 64))
    (new-narrative (string-ascii 200))
    (new-keywords (list 5 (string-ascii 30)))
)
    (let
        (
            (document (unwrap! (map-get? vault-repository { vault-id: vault-id }) STATUS_ITEM_NOT_FOUND))
        )
        ;; Authorization and validation
        (asserts! (is-vault-owner? vault-id tx-sender) STATUS_UNAUTHORIZED)
        (asserts! (is-title-valid? new-title) STATUS_INVALID_INPUT)
        (asserts! (is-fingerprint-valid? new-fingerprint) STATUS_INVALID_INPUT)
        (asserts! (is-narrative-valid? new-narrative) STATUS_NARRATIVE_ISSUE)
        (asserts! (are-keywords-valid? new-keywords) STATUS_NARRATIVE_ISSUE)

        ;; Apply updates
        (map-set vault-repository
            { vault-id: vault-id }
            (merge document {
                title: new-title,
                fingerprint: new-fingerprint,
                narrative: new-narrative,
                modification-block: block-height,
                keywords: new-keywords
            })
        )
        (ok true)
    )
)

;; Delegates access to another user
(define-public (delegate-document-access
    (vault-id uint)
    (delegate principal)
    (access-level (string-ascii 10))
    (duration uint)
    (modifications-allowed bool)
)
    (let
        (
            (current-time block-height)
            (expiration-time (+ current-time duration))
        )
        ;; Validation sequence
        (asserts! (does-vault-exist? vault-id) STATUS_ITEM_NOT_FOUND)
        (asserts! (is-vault-owner? vault-id tx-sender) STATUS_UNAUTHORIZED)
        (asserts! (is-delegate-valid? delegate) STATUS_INVALID_INPUT)
        (asserts! (is-access-level-valid? access-level) STATUS_ROLE_MISMATCH)
        (asserts! (is-duration-valid? duration) STATUS_DURATION_ISSUE)
        (asserts! (is-modification-flag-valid? modifications-allowed) STATUS_INVALID_INPUT)

        ;; Create delegation record
        (map-set vault-privileges
            { vault-id: vault-id, delegate: delegate }
            {
                access-level: access-level,
                issuance-time: current-time,
                expiration-time: expiration-time,
                modifications-allowed: modifications-allowed
            }
        )
        (ok true)
    )
)

;; ===== Alternative Implementation Functions =====
;; Enhanced implementations with different approaches

;; Streamlined document update function with improved clarity
(define-public (revise-existing-document
    (vault-id uint)
    (new-title (string-ascii 50))
    (new-fingerprint (string-ascii 64))
    (new-narrative (string-ascii 200))
    (new-keywords (list 5 (string-ascii 30)))
)
    (let
        (
            (document (unwrap! (map-get? vault-repository { vault-id: vault-id }) STATUS_ITEM_NOT_FOUND))
        )
        ;; Owner authentication
        (asserts! (is-vault-owner? vault-id tx-sender) STATUS_UNAUTHORIZED)

        ;; Create updated document record
        (let
            (
                (revised-document (merge document {
                    title: new-title,
                    fingerprint: new-fingerprint,
                    narrative: new-narrative,
                    keywords: new-keywords,
                    modification-block: block-height
                }))
            )
            ;; Save updated document
            (map-set vault-repository { vault-id: vault-id } revised-document)
            (ok true)
        )
    )
)

;; Performance-focused document creation implementation
(define-public (expedited-document-registration
    (title (string-ascii 50))
    (fingerprint (string-ascii 64))
    (narrative (string-ascii 200))
    (category (string-ascii 20))
    (keywords (list 5 (string-ascii 30)))
)
    (let
        (
            (new-vault-id (+ (var-get vault-sequence) u1))
            (current-time block-height)
        )
        ;; Batch validation for all inputs
        (asserts! (is-title-valid? title) STATUS_INVALID_INPUT)
        (asserts! (is-fingerprint-valid? fingerprint) STATUS_INVALID_INPUT)
        (asserts! (is-narrative-valid? narrative) STATUS_NARRATIVE_ISSUE)
        (asserts! (is-category-valid? category) STATUS_CATEGORY_INVALID)
        (asserts! (are-keywords-valid? keywords) STATUS_NARRATIVE_ISSUE)

        ;; Execute document registration
        (map-set vault-repository
            { vault-id: new-vault-id }
            {
                title: title,
                owner: tx-sender,
                fingerprint: fingerprint,
                narrative: narrative,
                creation-block: current-time,
                modification-block: current-time,
                category: category,
                keywords: keywords
            }
        )

        ;; Update document counter and return result
        (var-set vault-sequence new-vault-id)
        (ok new-vault-id)
    )
)

;; Enhanced security document update implementation
(define-public (protected-document-revision
    (vault-id uint)
    (new-title (string-ascii 50))
    (new-fingerprint (string-ascii 64))
    (new-narrative (string-ascii 200))
    (new-keywords (list 5 (string-ascii 30)))
)
    (let
        (
            (document (unwrap! (map-get? vault-repository { vault-id: vault-id }) STATUS_ITEM_NOT_FOUND))
        )
        ;; Multi-level security checks
        (asserts! (is-vault-owner? vault-id tx-sender) STATUS_UNAUTHORIZED)
        (asserts! (is-title-valid? new-title) STATUS_INVALID_INPUT)
        (asserts! (is-fingerprint-valid? new-fingerprint) STATUS_INVALID_INPUT)
        (asserts! (is-narrative-valid? new-narrative) STATUS_NARRATIVE_ISSUE)
        (asserts! (are-keywords-valid? new-keywords) STATUS_NARRATIVE_ISSUE)

        ;; Apply validated updates
        (map-set vault-repository
            { vault-id: vault-id }
            (merge document {
                title: new-title,
                fingerprint: new-fingerprint,
                narrative: new-narrative,
                modification-block: block-height,
                keywords: new-keywords
            })
        )

        ;; Return success status
        (ok true)
    )
)

;; Alternative storage structure with optimized retrieval paths
(define-map enhanced-vault-repository
    { vault-id: uint }
    {
        title: (string-ascii 50),
        owner: principal,
        fingerprint: (string-ascii 64),
        narrative: (string-ascii 200),
        creation-block: uint,
        modification-block: uint,
        category: (string-ascii 20),
        keywords: (list 5 (string-ascii 30))
    }
)

;; Implementation leveraging optimized storage structure
(define-public (high-performance-document-creation
    (title (string-ascii 50))
    (fingerprint (string-ascii 64))
    (narrative (string-ascii 200))
    (category (string-ascii 20))
    (keywords (list 5 (string-ascii 30)))
)
    (let
        (
            (new-vault-id (+ (var-get vault-sequence) u1))
            (current-time block-height)
        )
        ;; Comprehensive input validation
        (asserts! (is-title-valid? title) STATUS_INVALID_INPUT)
        (asserts! (is-fingerprint-valid? fingerprint) STATUS_INVALID_INPUT)
        (asserts! (is-narrative-valid? narrative) STATUS_NARRATIVE_ISSUE)
        (asserts! (is-category-valid? category) STATUS_CATEGORY_INVALID)
        (asserts! (are-keywords-valid? keywords) STATUS_NARRATIVE_ISSUE)

        ;; Execute optimized document storage
        (map-set enhanced-vault-repository
            { vault-id: new-vault-id }
            {
                title: title,
                owner: tx-sender,
                fingerprint: fingerprint,
                narrative: narrative,
                creation-block: current-time,
                modification-block: current-time,
                category: category,
                keywords: keywords
            }
        )

        ;; Update system counter and return result
        (var-set vault-sequence new-vault-id)
        (ok new-vault-id)
    )
)

