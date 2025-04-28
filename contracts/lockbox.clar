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
