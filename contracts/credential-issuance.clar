;; Continuing Education Contract
;; This contract tracks ongoing professional development

;; Define data variables
(define-map continuing-education
  {record-id: uint}
  {credential-id: uint,
   activity-type: (string-ascii 50),
   activity-name: (string-ascii 100),
   provider: (string-ascii 100),
   completion-date: uint,
   credits: uint,
   verified: bool,
   verification-date: (optional uint),
   metadata: (string-utf8 200)})

;; Define error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_EXISTS u2)
(define-constant ERR_NOT_FOUND u3)

;; Define trait for credential issuance
(define-trait credential-trait
  ((get-credential (uint) (optional {
    institution-id: uint,
    student-id: (string-ascii 50),
    credential-type: (string-ascii 50),
    credential-name: (string-ascii 100),
    issue-date: uint,
    expiration-date: (optional uint),
    metadata: (string-utf8 500)
  }))))

;; Add a continuing education record
(define-public (add-continuing-education
                (record-id uint)
                (credential-id uint)
                (activity-type (string-ascii 50))
                (activity-name (string-ascii 100))
                (provider (string-ascii 100))
                (credits uint)
                (metadata (string-utf8 200))
                (credential-contract <credential-trait>))
  (let ((credential (contract-call? credential-contract get-credential credential-id)))
    (begin
      ;; Check if the credential exists
      (asserts! (is-some credential) (err ERR_NOT_FOUND))
      ;; Check if record already exists
      (asserts! (is-none (map-get? continuing-education {record-id: record-id}))
                (err ERR_ALREADY_EXISTS))
      ;; Add the record
      (ok (map-set continuing-education
                  {record-id: record-id}
                  {credential-id: credential-id,
                   activity-type: activity-type,
                   activity-name: activity-name,
                   provider: provider,
                   completion-date: block-height,
                   credits: credits,
                   verified: false,
                   verification-date: none,
                   metadata: metadata})))))

;; Verify a continuing education record (provider or institution only)
(define-public (verify-continuing-education
                (record-id uint)
                (credential-contract <credential-trait>))
  (match (map-get? continuing-education {record-id: record-id})
    record (let ((credential (contract-call? credential-contract get-credential (get credential-id record))))
             (begin
               ;; Check if caller is authorized (provider or issuing institution)
               (asserts! (is-some credential) (err ERR_UNAUTHORIZED))
               ;; Update the record
               (ok (map-set continuing-education
                           {record-id: record-id}
                           (merge record
                                 {verified: true,
                                  verification-date: (some block-height)})))))
    (err ERR_NOT_FOUND)))

;; Get continuing education record details
(define-read-only (get-continuing-education (record-id uint))
  (map-get? continuing-education {record-id: record-id}))

;; Get all continuing education records for a credential
(define-read-only (get-records-for-credential (credential-id uint))
  (filter continuing-education (lambda (record-id record)
            (is-eq (get credential-id record) credential-id))))

;; Calculate total verified credits for a credential
(define-read-only (get-total-credits (credential-id uint))
  (fold +
        (map get-record-credits (get-records-for-credential credential-id))
        u0))

;; Helper function to get credits from a record if verified
(define-private (get-record-credits (record {
  credential-id: uint,
  activity-type: (string-ascii 50),
  activity-name: (string-ascii 100),
  provider: (string-ascii 100),
  completion-date: uint,
  credits: uint,
  verified: bool,
  verification-date: (optional uint),
  metadata: (string-utf8 200)
}))
  (if (get verified record)
      (get credits record)
      u0))
